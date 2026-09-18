param(
  [Parameter(Mandatory = $true)]
  [string]$SourceRoot
)

$ErrorActionPreference = 'Stop'

function Convert-HexToBytes([string]$hex) {
  if ($hex -notmatch '^[0-9a-fA-F]{64}$') { throw 'RD_BUILD_KEY secret is missing or invalid.' }
  [byte[]]$bytes = for ($i = 0; $i -lt $hex.Length; $i += 2) {
    [Convert]::ToByte($hex.Substring($i, 2), 16)
  }
  return $bytes
}

function Get-Sha256Hex([byte[]]$bytes) {
  return [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
}

if ($env:RD_BUILD_KEY -notmatch '^[0-9a-fA-F]{64}$') {
  throw 'RD_BUILD_KEY secret is missing or invalid.'
}

$meta = Get-Content -Raw (Join-Path $PSScriptRoot '..\highend\patch-meta.json') | ConvertFrom-Json
$parts = Get-ChildItem -Path (Join-Path $PSScriptRoot '..\highend\patch.enc.b64.*') -File | Sort-Object Name
if ($parts.Count -ne [int]$meta.parts) {
  throw "Expected $($meta.parts) encrypted high-end patch parts, found $($parts.Count)."
}

for ($i = 0; $i -lt $parts.Count; $i++) {
  $length = (Get-Content -Raw $parts[$i].FullName).Trim().Length
  $expected = [int]$meta.part_lengths[$i]
  if ($length -ne $expected) {
    throw "Encrypted patch part $($parts[$i].Name) has length $length, expected $expected."
  }
}

$patchB64 = ($parts | ForEach-Object { (Get-Content -Raw $_.FullName).Trim() }) -join ''
if ($patchB64.Length -ne [int]$meta.base64_length) {
  throw "Combined encrypted patch Base64 length is $($patchB64.Length), expected $($meta.base64_length)."
}

[byte[]]$patchBlob = [Convert]::FromBase64String($patchB64)
if ($patchBlob.Length -ne [int]$meta.encrypted_bytes) {
  throw "Encrypted patch size is $($patchBlob.Length), expected $($meta.encrypted_bytes)."
}
$encryptedHash = Get-Sha256Hex $patchBlob
if ($encryptedHash -ne [string]$meta.encrypted_sha256) {
  throw "Encrypted high-end patch SHA256 mismatch: $encryptedHash"
}
if ([Text.Encoding]::ASCII.GetString($patchBlob, 0, 5) -ne 'RDHP1') {
  throw 'Invalid high-end patch encrypted magic.'
}

[byte[]]$master = Convert-HexToBytes $env:RD_BUILD_KEY
[byte[]]$privateBlob = [Convert]::FromBase64String((Get-Content -Raw (Join-Path $PSScriptRoot '..\highend\key-private.enc.b64')).Trim())
if ([Text.Encoding]::ASCII.GetString($privateBlob, 0, 5) -ne 'RDHK1') {
  throw 'Invalid encrypted high-end private key magic.'
}

[byte[]]$privateNonce = $privateBlob[5..16]
[byte[]]$privateTag = $privateBlob[17..32]
[byte[]]$privateCipher = $privateBlob[33..($privateBlob.Length - 1)]
[byte[]]$privateKey = New-Object byte[] $privateCipher.Length
[byte[]]$keyAad = [Text.Encoding]::ASCII.GetBytes('RD-DRIVE-HIGHEND-KEY-v1')

$aesKeyStore = [System.Security.Cryptography.AesGcm]::new($master, 16)
try {
  $aesKeyStore.Decrypt($privateNonce, $privateCipher, $privateTag, $privateKey, $keyAad)
}
finally {
  $aesKeyStore.Dispose()
  [Array]::Clear($master, 0, $master.Length)
}

$rsa = [System.Security.Cryptography.RSA]::Create()
[byte[]]$patchKey = $null
[byte[]]$patchPlain = $null
try {
  [int]$bytesRead = 0
  $rsa.ImportPkcs8PrivateKey($privateKey, [ref]$bytesRead)
  if ($bytesRead -ne $privateKey.Length) {
    throw "Imported only $bytesRead of $($privateKey.Length) private-key bytes."
  }

  [byte[]]$wrappedKey = [Convert]::FromBase64String((Get-Content -Raw (Join-Path $PSScriptRoot '..\highend\patch-key.rsa.b64')).Trim())
  if ($wrappedKey.Length -ne [int]$meta.wrapped_key_bytes) {
    throw "Wrapped high-end patch key size is $($wrappedKey.Length), expected $($meta.wrapped_key_bytes)."
  }
  $patchKey = $rsa.Decrypt($wrappedKey, [System.Security.Cryptography.RSAEncryptionPadding]::OaepSHA256)
  if ($patchKey.Length -ne 32) {
    throw "Unwrapped high-end patch key has invalid size $($patchKey.Length)."
  }

  [byte[]]$patchNonce = $patchBlob[5..16]
  [byte[]]$patchTag = $patchBlob[17..32]
  [byte[]]$patchCipher = $patchBlob[33..($patchBlob.Length - 1)]
  $patchPlain = New-Object byte[] $patchCipher.Length
  [byte[]]$patchAad = [Text.Encoding]::ASCII.GetBytes('RD-DRIVE-HIGHEND-PATCH-v1')

  $aesPatch = [System.Security.Cryptography.AesGcm]::new($patchKey, 16)
  try {
    $aesPatch.Decrypt($patchNonce, $patchCipher, $patchTag, $patchPlain, $patchAad)
  }
  finally {
    $aesPatch.Dispose()
  }

  $plainHash = Get-Sha256Hex $patchPlain
  if ($plainHash -ne [string]$meta.plaintext_sha256) {
    throw "Decrypted high-end patch SHA256 mismatch: $plainHash"
  }

  $archive = Join-Path $env:RUNNER_TEMP 'rd-drive-highend-patch.tar.gz'
  [IO.File]::WriteAllBytes($archive, $patchPlain)
  tar -xzf $archive -C $SourceRoot
  if ($LASTEXITCODE -ne 0) {
    throw "High-end patch extraction failed with exit code $LASTEXITCODE."
  }

  $required = @(
    'package.json',
    'src/App.tsx',
    'src/components/DriveBrowser.tsx',
    'src/components/MediaViewer.tsx',
    'src/domain/media.ts',
    'src-tauri/Cargo.toml',
    'src-tauri/src/archive.rs',
    'src-tauri/src/local_import.rs',
    'src-tauri/src/media.rs',
    'src-tauri/src/telegram.rs',
    'tests/media.test.ts',
    'tests/release_safety.test.ts'
  )
  foreach ($relative in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $SourceRoot $relative) -PathType Leaf)) {
      throw "Patched source is missing required file: $relative"
    }
  }


  # Apply two deterministic UI regression fixes found by the Windows contract suite.
  $appPath = Join-Path $SourceRoot 'src/App.tsx'
  $appSource = Get-Content -Raw $appPath
  $appSource = $appSource.Replace("const [active, setActive] = useState('Übersicht');", "const [active, setActive] = useState('Dateien');")
  $appSource = $appSource.Replace('<div className="brand-mark" aria-hidden="true">RD</div>', '<img className="brand-mark" src={new URL(''./assets/rd-drive-icon.png'', import.meta.url).href} alt="" aria-hidden="true" />')
  Set-Content -LiteralPath $appPath -Value $appSource -Encoding utf8

  $appVerify = Get-Content -Raw $appPath
  if ($appVerify -notmatch "useState\('Dateien'\)") {
    throw 'Drive is not configured as the default surface.'
  }
  if ($appVerify -notmatch 'rd-drive-icon\.png') {
    throw 'RD Drive artwork is not wired as the browser brand asset.'
  }

  $cargo = Get-Content -Raw (Join-Path $SourceRoot 'src-tauri/Cargo.toml')
  if ($cargo -notmatch 'sevenz-rust2\s*=\s*"0\.21\.5"') {
    throw 'Patched Cargo.toml does not contain sevenz-rust2 0.21.5.'
  }
  if ($cargo -notmatch 'rust-version\s*=\s*"1\.93"') {
    throw 'Patched Cargo.toml does not require Rust 1.93.'
  }

  Write-Host "RD Drive high-end patch decrypted, SHA256 verified and applied: $plainHash"
}
finally {
  $rsa.Dispose()
  if ($null -ne $patchKey) { [Array]::Clear($patchKey, 0, $patchKey.Length) }
  if ($null -ne $patchPlain) { [Array]::Clear($patchPlain, 0, $patchPlain.Length) }
  [Array]::Clear($privateKey, 0, $privateKey.Length)
}

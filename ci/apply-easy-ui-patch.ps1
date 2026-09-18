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

$meta = Get-Content -Raw (Join-Path $PSScriptRoot '..\easy-ui\patch-meta.json') | ConvertFrom-Json
$parts = Get-ChildItem -Path (Join-Path $PSScriptRoot '..\easy-ui\patch.enc.b64.*') -File | Sort-Object Name
if ($parts.Count -ne [int]$meta.parts) {
  throw "Expected $($meta.parts) encrypted easy-workspace patch parts, found $($parts.Count)."
}
for ($i = 0; $i -lt $parts.Count; $i++) {
  $length = (Get-Content -Raw $parts[$i].FullName).Trim().Length
  $expected = [int]$meta.part_lengths[$i]
  if ($length -ne $expected) { throw "Easy workspace patch part $($parts[$i].Name) has length $length, expected $expected." }
}

$patchB64 = ($parts | ForEach-Object { (Get-Content -Raw $_.FullName).Trim() }) -join ''
if ($patchB64.Length -ne [int]$meta.base64_length) {
  throw "Combined easy workspace Base64 length is $($patchB64.Length), expected $($meta.base64_length)."
}
[byte[]]$patchBlob = [Convert]::FromBase64String($patchB64)
if ($patchBlob.Length -ne [int]$meta.encrypted_bytes) {
  throw "Encrypted easy workspace patch size is $($patchBlob.Length), expected $($meta.encrypted_bytes)."
}
$encryptedHash = Get-Sha256Hex $patchBlob
if ($encryptedHash -ne [string]$meta.encrypted_sha256) { throw "Encrypted easy workspace SHA256 mismatch: $encryptedHash" }
if ([Text.Encoding]::ASCII.GetString($patchBlob, 0, 5) -ne 'RDEU1') { throw 'Invalid easy workspace patch encrypted magic.' }

[byte[]]$master = Convert-HexToBytes $env:RD_BUILD_KEY
[byte[]]$privateBlob = [Convert]::FromBase64String((Get-Content -Raw (Join-Path $PSScriptRoot '..\highend\key-private.enc.b64')).Trim())
if ([Text.Encoding]::ASCII.GetString($privateBlob, 0, 5) -ne 'RDHK1') { throw 'Invalid encrypted high-end private key magic.' }

[byte[]]$privateNonce = $privateBlob[5..16]
[byte[]]$privateTag = $privateBlob[17..32]
[byte[]]$privateCipher = $privateBlob[33..($privateBlob.Length - 1)]
[byte[]]$privateKey = New-Object byte[] $privateCipher.Length
[byte[]]$keyAad = [Text.Encoding]::ASCII.GetBytes('RD-DRIVE-HIGHEND-KEY-v1')
$aesKeyStore = [System.Security.Cryptography.AesGcm]::new($master, 16)
try { $aesKeyStore.Decrypt($privateNonce, $privateCipher, $privateTag, $privateKey, $keyAad) }
finally { $aesKeyStore.Dispose(); [Array]::Clear($master, 0, $master.Length) }

$rsa = [System.Security.Cryptography.RSA]::Create()
[byte[]]$patchKey = $null
[byte[]]$patchPlain = $null
try {
  [int]$bytesRead = 0
  $rsa.ImportPkcs8PrivateKey($privateKey, [ref]$bytesRead)
  if ($bytesRead -ne $privateKey.Length) { throw "Imported only $bytesRead of $($privateKey.Length) private-key bytes." }

  [byte[]]$wrappedKey = [Convert]::FromBase64String((Get-Content -Raw (Join-Path $PSScriptRoot '..\easy-ui\patch-key.rsa.b64')).Trim())
  if ($wrappedKey.Length -ne [int]$meta.wrapped_key_bytes) { throw "Wrapped easy workspace key has invalid size $($wrappedKey.Length)." }
  $patchKey = $rsa.Decrypt($wrappedKey, [System.Security.Cryptography.RSAEncryptionPadding]::OaepSHA256)
  if ($patchKey.Length -ne 32) { throw "Unwrapped easy workspace key has invalid size $($patchKey.Length)." }

  [byte[]]$patchNonce = $patchBlob[5..16]
  [byte[]]$patchTag = $patchBlob[17..32]
  [byte[]]$patchCipher = $patchBlob[33..($patchBlob.Length - 1)]
  $patchPlain = New-Object byte[] $patchCipher.Length
  [byte[]]$patchAad = [Text.Encoding]::ASCII.GetBytes('RD-DRIVE-EASY-UI-PATCH-v1')
  $aesPatch = [System.Security.Cryptography.AesGcm]::new($patchKey, 16)
  try { $aesPatch.Decrypt($patchNonce, $patchCipher, $patchTag, $patchPlain, $patchAad) }
  finally { $aesPatch.Dispose() }

  $plainHash = Get-Sha256Hex $patchPlain
  if ($plainHash -ne [string]$meta.plaintext_sha256) { throw "Decrypted easy workspace SHA256 mismatch: $plainHash" }

  $archive = Join-Path $env:RUNNER_TEMP 'rd-drive-easy-workspace.tar.gz'
  [IO.File]::WriteAllBytes($archive, $patchPlain)
  tar -xzf $archive -C $SourceRoot
  if ($LASTEXITCODE -ne 0) { throw "Easy workspace extraction failed with exit code $LASTEXITCODE." }

  $required = @(
    'src/App.tsx',
    'src/components/DriveBrowser.tsx',
    'src/styles/app.css',
    'src-tauri/src/drive.rs',
    'src-tauri/src/commands.rs',
    'src-tauri/src/lib.rs',
    'tests/easy_workspace.test.ts'
  )
  foreach ($relative in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $SourceRoot $relative) -PathType Leaf)) { throw "Easy workspace source is missing: $relative" }
  }

  $app = Get-Content -Raw (Join-Path $SourceRoot 'src/App.tsx')
  $browser = Get-Content -Raw (Join-Path $SourceRoot 'src/components/DriveBrowser.tsx')
  $drive = Get-Content -Raw (Join-Path $SourceRoot 'src-tauri/src/drive.rs')
  $commands = Get-Content -Raw (Join-Path $SourceRoot 'src-tauri/src/commands.rs')
  $styles = Get-Content -Raw (Join-Path $SourceRoot 'src/styles/app.css')
  foreach ($token in @('setupFlowActive','Konto','Meine Dateien')) {
    if ($app -notmatch [regex]::Escape($token)) { throw "Easy workspace App is missing marker: $token" }
  }
  if ($browser -notmatch 'DriveScope') { throw 'Scoped drive browser is missing.' }
  if ($drive -notmatch 'list_scope') { throw 'Scoped drive backend is missing.' }
  if ($commands -notmatch 'drive_list_scope') { throw 'Scoped drive Tauri command is missing.' }
  if ($styles -notmatch '\.compact-shell') { throw 'Fixed compact workspace styles are missing.' }
  if ($styles -notmatch 'overflow:\s*hidden') { throw 'Fixed workspace overflow guard is missing.' }

  Write-Host "RD Drive easy workspace patch decrypted, SHA256 verified and applied: $plainHash"
}
finally {
  $rsa.Dispose()
  if ($null -ne $patchKey) { [Array]::Clear($patchKey, 0, $patchKey.Length) }
  if ($null -ne $patchPlain) { [Array]::Clear($patchPlain, 0, $patchPlain.Length) }
  [Array]::Clear($privateKey, 0, $privateKey.Length)
}

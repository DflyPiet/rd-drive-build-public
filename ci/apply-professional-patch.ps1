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

$meta = Get-Content -Raw (Join-Path $PSScriptRoot '..\professional\patch-meta.json') | ConvertFrom-Json
$parts = Get-ChildItem -Path (Join-Path $PSScriptRoot '..\professional\patch.enc.b64.*') -File | Sort-Object Name
if ($parts.Count -ne [int]$meta.parts) {
  throw "Expected $($meta.parts) professional patch parts, found $($parts.Count)."
}
for ($i = 0; $i -lt $parts.Count; $i++) {
  $length = (Get-Content -Raw $parts[$i].FullName).Trim().Length
  $expected = [int]$meta.part_lengths[$i]
  if ($length -ne $expected) {
    throw "Professional patch part $($parts[$i].Name) has length $length, expected $expected."
  }
}

$patchB64 = ($parts | ForEach-Object { (Get-Content -Raw $_.FullName).Trim() }) -join ''
if ($patchB64.Length -ne [int]$meta.base64_length) {
  throw "Combined professional patch Base64 length is $($patchB64.Length), expected $($meta.base64_length)."
}
[byte[]]$patchBlob = [Convert]::FromBase64String($patchB64)
if ($patchBlob.Length -ne [int]$meta.encrypted_bytes) {
  throw "Encrypted professional patch size is $($patchBlob.Length), expected $($meta.encrypted_bytes)."
}
$encryptedHash = Get-Sha256Hex $patchBlob
if ($encryptedHash -ne [string]$meta.encrypted_sha256) {
  throw "Encrypted professional patch SHA256 mismatch: $encryptedHash"
}
if ([Text.Encoding]::ASCII.GetString($patchBlob, 0, 5) -ne 'RDPR1') {
  throw 'Invalid professional patch encrypted magic.'
}

[byte[]]$master = Convert-HexToBytes $env:RD_BUILD_KEY
[byte[]]$privateBlob = [Convert]::FromBase64String((Get-Content -Raw (Join-Path $PSScriptRoot '..\highend\key-private.enc.b64')).Trim())
if ([Text.Encoding]::ASCII.GetString($privateBlob, 0, 5) -ne 'RDHK1') {
  throw 'Invalid encrypted build private key magic.'
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

  [byte[]]$wrappedKey = [Convert]::FromBase64String((Get-Content -Raw (Join-Path $PSScriptRoot '..\professional\patch-key.rsa.b64')).Trim())
  if ($wrappedKey.Length -ne [int]$meta.wrapped_key_bytes) {
    throw "Wrapped professional patch key has invalid size $($wrappedKey.Length)."
  }
  $patchKey = $rsa.Decrypt($wrappedKey, [System.Security.Cryptography.RSAEncryptionPadding]::OaepSHA256)
  if ($patchKey.Length -ne 32) { throw "Professional patch key has invalid size $($patchKey.Length)." }

  [byte[]]$patchNonce = $patchBlob[5..16]
  [byte[]]$patchTag = $patchBlob[17..32]
  [byte[]]$patchCipher = $patchBlob[33..($patchBlob.Length - 1)]
  $patchPlain = New-Object byte[] $patchCipher.Length
  [byte[]]$patchAad = [Text.Encoding]::ASCII.GetBytes([string]$meta.aad)
  $aesPatch = [System.Security.Cryptography.AesGcm]::new($patchKey, 16)
  try {
    $aesPatch.Decrypt($patchNonce, $patchCipher, $patchTag, $patchPlain, $patchAad)
  }
  finally {
    $aesPatch.Dispose()
  }

  $plainHash = Get-Sha256Hex $patchPlain
  if ($plainHash -ne [string]$meta.plaintext_sha256) {
    throw "Decrypted professional patch SHA256 mismatch: $plainHash"
  }

  $archive = Join-Path $env:RUNNER_TEMP 'rd-drive-professional-patch.tar.gz'
  [IO.File]::WriteAllBytes($archive, $patchPlain)
  tar -xzf $archive -C $SourceRoot
  if ($LASTEXITCODE -ne 0) { throw "Professional patch extraction failed with exit code $LASTEXITCODE." }

  $required = @(
    'src/App.tsx',
    'src/components/DriveBrowser.tsx',
    'src/components/ShareCenter.tsx',
    'src/styles/app.css',
    'src-tauri/src/drive.rs',
    'src-tauri/src/telegram.rs',
    'src-tauri/src/commands.rs',
    'src-tauri/src/lib.rs',
    'src-tauri/src/storage.rs',
    'src-tauri/src/diagnostics.rs',
    'src-tauri/src/sharing.rs',
    'db/profile.sql',
    'tests/easy_workspace.test.ts',
    'tests/test_schema.py',
    'tests/test_final_release_contract.py'
  )
  foreach ($relative in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $SourceRoot $relative) -PathType Leaf)) {
      throw "Professional source is missing required file: $relative"
    }
  }

  $app = Get-Content -Raw (Join-Path $SourceRoot 'src/App.tsx')
  $browser = Get-Content -Raw (Join-Path $SourceRoot 'src/components/DriveBrowser.tsx')
  $commands = Get-Content -Raw (Join-Path $SourceRoot 'src-tauri/src/commands.rs')
  $telegram = Get-Content -Raw (Join-Path $SourceRoot 'src-tauri/src/telegram.rs')
  $sharing = Get-Content -Raw (Join-Path $SourceRoot 'src-tauri/src/sharing.rs')
  $schema = Get-Content -Raw (Join-Path $SourceRoot 'db/profile.sql')

  foreach ($marker in @('Freigaben')) {
    if ($app -notmatch [regex]::Escape($marker)) { throw "App is missing professional marker: $marker" }
  }
  foreach ($marker in @('Papierkorb leeren','Endgültig löschen','Link erstellen','Direkt senden')) {
    if ($browser -notmatch [regex]::Escape($marker)) { throw "Drive browser is missing professional action: $marker" }
  }
  foreach ($marker in @('drive_empty_trash','drive_purge','share_publish_link','share_send_telegram','share_revoke')) {
    if ($commands -notmatch [regex]::Escape($marker)) { throw "Tauri command is missing: $marker" }
  }
  if ($telegram -notmatch 'https://t\.me/') { throw 'Real Telegram link generation is missing.' }
  if ($sharing -notmatch 'share_publications') { throw 'Encrypted share publication history is missing.' }
  if ($schema -notmatch 'CREATE TABLE IF NOT EXISTS share_publications') { throw 'Share publication schema is missing.' }

  Write-Host "RD Drive professional patch decrypted, SHA256 verified and applied: $plainHash"
}
finally {
  $rsa.Dispose()
  if ($null -ne $patchKey) { [Array]::Clear($patchKey, 0, $patchKey.Length) }
  if ($null -ne $patchPlain) { [Array]::Clear($patchPlain, 0, $patchPlain.Length) }
  [Array]::Clear($privateKey, 0, $privateKey.Length)
}

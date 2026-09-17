$ErrorActionPreference = 'Stop'

if ($env:RD_BUILD_KEY -notmatch '^[0-9a-fA-F]{64}$') { throw 'RD_BUILD_KEY secret is missing or invalid.' }

function Get-KeyBytes {
  [byte[]]$key = for ($i = 0; $i -lt 64; $i += 2) { [Convert]::ToByte($env:RD_BUILD_KEY.Substring($i, 2), 16) }
  return $key
}

# 1) Reconstruct and decrypt the proven RD Drive 1.0.0 CI source base.
$baseParts = @(
  'payload/rd-drive.enc.b64.00','payload/rd-drive.enc.b64.01','payload/rd-drive.enc.b64.02',
  'payload/rd-drive.enc.b64.03','payload/rd-drive.enc.b64.04','payload/rd-drive.enc.b64.05',
  'payload/rd-drive.enc.b64.06a','payload/rd-drive.enc.b64.06b','payload/rd-drive.enc.b64.07',
  'payload/rd-drive.enc.b64.08','payload/rd-drive.enc.b64.09'
)
foreach ($part in $baseParts) { if (-not (Test-Path $part)) { throw "Missing base fragment: $part" } }
$baseB64 = ($baseParts | ForEach-Object { Get-Content -Raw $_ }) -join ''
[IO.File]::WriteAllBytes('rd-drive-base.enc', [Convert]::FromBase64String($baseB64))
$baseEncryptedHash = (Get-FileHash -Algorithm SHA256 'rd-drive-base.enc').Hash.ToLowerInvariant()
if ($baseEncryptedHash -ne '0ee2f7ab3567c73c19571a4738d63549c9eeef74a07a63a044013835ad30b6da') { throw "Base encrypted SHA256 mismatch: $baseEncryptedHash" }
[byte[]]$baseBlob = [IO.File]::ReadAllBytes('rd-drive-base.enc')
if ([Text.Encoding]::ASCII.GetString($baseBlob[0..5]) -ne 'RDENC1') { throw 'Invalid base encrypted magic.' }
[byte[]]$baseNonce = $baseBlob[6..17]
[byte[]]$baseTag = $baseBlob[18..33]
[byte[]]$baseCipher = $baseBlob[34..($baseBlob.Length - 1)]
[byte[]]$basePlain = New-Object byte[] $baseCipher.Length
[byte[]]$baseAad = [Text.Encoding]::ASCII.GetBytes('RD-DRIVE-CI-v1')
[byte[]]$key = Get-KeyBytes
$aes = [System.Security.Cryptography.AesGcm]::new($key, 16)
try { $aes.Decrypt($baseNonce, $baseCipher, $baseTag, $basePlain, $baseAad) }
finally { $aes.Dispose(); [Array]::Clear($key, 0, $key.Length) }
[IO.File]::WriteAllBytes('rd-drive-base.zip', $basePlain)
[Array]::Clear($basePlain, 0, $basePlain.Length)
$basePlainHash = (Get-FileHash -Algorithm SHA256 'rd-drive-base.zip').Hash.ToLowerInvariant()
if ($basePlainHash -ne 'dfe1cdf5f6b9fdf30cca6b76f9b984fc03ba1c58858476ea980232f3e04249c8') { throw "Base source SHA256 mismatch: $basePlainHash" }
Remove-Item source -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force source | Out-Null
Expand-Archive -Path 'rd-drive-base.zip' -DestinationPath source -Force
Remove-Item 'rd-drive-base.enc','rd-drive-base.zip' -Force

# 2) Reconstruct and decrypt the clean-room browser + media redesign overlay.
$overlayParts = 0..5 | ForEach-Object { 'redesign-v2/overlay.part{0:d2}.b64' -f $_ }
foreach ($part in $overlayParts) { if (-not (Test-Path $part)) { throw "Missing redesign fragment: $part" } }
$overlayB64 = ($overlayParts | ForEach-Object { Get-Content -Raw $_ }) -join ''
[IO.File]::WriteAllBytes('rd-drive-redesign.enc', [Convert]::FromBase64String($overlayB64))
$overlayEncryptedHash = (Get-FileHash -Algorithm SHA256 'rd-drive-redesign.enc').Hash.ToLowerInvariant()
if ($overlayEncryptedHash -ne '65dfba6ebdb187d5d102539f5f9baa639ca0699bfc54e3d3c4fd20e052ccf289') { throw "Redesign encrypted SHA256 mismatch: $overlayEncryptedHash" }
[byte[]]$overlayBlob = [IO.File]::ReadAllBytes('rd-drive-redesign.enc')
if ([Text.Encoding]::ASCII.GetString($overlayBlob[0..4]) -ne 'RDRD2') { throw 'Invalid redesign encrypted magic.' }
[byte[]]$overlayNonce = $overlayBlob[5..16]
[byte[]]$overlayTag = $overlayBlob[17..32]
[byte[]]$overlayCipher = $overlayBlob[33..($overlayBlob.Length - 1)]
[byte[]]$overlayPlain = New-Object byte[] $overlayCipher.Length
[byte[]]$overlayAad = [Text.Encoding]::ASCII.GetBytes('RD-DRIVE-REDESIGN-v2')
[byte[]]$key2 = Get-KeyBytes
$aes2 = [System.Security.Cryptography.AesGcm]::new($key2, 16)
try { $aes2.Decrypt($overlayNonce, $overlayCipher, $overlayTag, $overlayPlain, $overlayAad) }
finally { $aes2.Dispose(); [Array]::Clear($key2, 0, $key2.Length) }
[IO.File]::WriteAllBytes('rd-drive-redesign.zip', $overlayPlain)
[Array]::Clear($overlayPlain, 0, $overlayPlain.Length)
$overlayPlainHash = (Get-FileHash -Algorithm SHA256 'rd-drive-redesign.zip').Hash.ToLowerInvariant()
if ($overlayPlainHash -ne '073f56f3a4db40114e371fc1ddcc7a40319f7aafdaa4c10461c167f4d21e7e63') { throw "Redesign source SHA256 mismatch: $overlayPlainHash" }
Expand-Archive -Path 'rd-drive-redesign.zip' -DestinationPath source -Force
Remove-Item 'rd-drive-redesign.enc','rd-drive-redesign.zip' -Force

# Contract marker expected by the source test suite.
New-Item -ItemType Directory -Force -Path 'source/.github/workflows' | Out-Null
Copy-Item '.github/workflows/redesign-release.yml' -Destination 'source/.github/workflows/windows-release.yml' -Force

python -m pip install --disable-pip-version-check pytest pillow
if ($LASTEXITCODE -ne 0) { throw 'Python build dependencies installation failed.' }

Push-Location source
try {
  & '..\ci\prepare-rd-drive-final.ps1'

  # Frontend branding image is generated from the same verified RD artwork used by the Windows icon.
  New-Item -ItemType Directory -Force -Path 'src/assets' | Out-Null
  Copy-Item 'src-tauri/icons/128x128@2x.png' -Destination 'src/assets/rd-drive-icon.png' -Force

  npm install
  if ($LASTEXITCODE -ne 0) { throw 'npm install failed.' }
  npm test
  if ($LASTEXITCODE -ne 0) { throw 'TypeScript browser/media tests failed.' }
  python -m pytest tests -q
  if ($LASTEXITCODE -ne 0) { throw 'Python browser/media contracts failed.' }
  npm run build
  if ($LASTEXITCODE -ne 0) { throw 'Frontend TypeScript/Vite production build failed.' }

  cargo test --manifest-path src-tauri/Cargo.toml --all-targets
  if ($LASTEXITCODE -ne 0) { throw 'Rust tests failed.' }

  # Installed build + NSIS setup.
  npm run tauri build -- --target x86_64-pc-windows-msvc
  if ($LASTEXITCODE -ne 0) { throw 'Installed Tauri redesign release build failed.' }
}
finally { Pop-Location }

$out = Join-Path $PWD 'release-artifacts-redesign'
Remove-Item $out -Recurse -Force -ErrorAction SilentlyContinue
$setupDir = Join-Path $out 'Setup'
$portableDir = Join-Path $out 'Portable'
New-Item -ItemType Directory -Force -Path $setupDir,$portableDir | Out-Null

$installedRaw = 'source/src-tauri/target/x86_64-pc-windows-msvc/release/rd-drive.exe'
if (-not (Test-Path $installedRaw)) { throw 'Installed redesign EXE was not produced.' }
& '.\ci\verify-rd-drive-pe.ps1' -Path $installedRaw
$bundleRoot = 'source/src-tauri/target/x86_64-pc-windows-msvc/release/bundle'
$setups = Get-ChildItem -Path $bundleRoot -Recurse -File -Include '*.exe','*.msi'
if (-not $setups) { throw 'No Windows setup artifact was produced.' }
foreach ($file in $setups) { Copy-Item $file.FullName -Destination $setupDir -Force }

# True portable: embedded production frontend + portable storage feature, no localhost/dev server.
Push-Location source
try {
  $portableConfig = @{
    build = @{
      devUrl = $null
      frontendDist = '../dist'
      features = @('portable')
    }
    bundle = @{ active = $false }
  } | ConvertTo-Json -Depth 10
  $portableConfig | Set-Content -Path 'src-tauri/tauri.portable.conf.json' -Encoding utf8
  npm run tauri build -- --target x86_64-pc-windows-msvc --no-bundle --config src-tauri/tauri.portable.conf.json
  if ($LASTEXITCODE -ne 0) { throw 'Portable Tauri redesign release build failed.' }
}
finally { Pop-Location }

$portableRaw = 'source/src-tauri/target/x86_64-pc-windows-msvc/release/rd-drive.exe'
if (-not (Test-Path $portableRaw)) { throw 'Portable redesign EXE was not produced.' }
& '.\ci\verify-rd-drive-pe.ps1' -Path $portableRaw
$portableBytes = [IO.File]::ReadAllBytes($portableRaw)
$portableAscii = [Text.Encoding]::ASCII.GetString($portableBytes)
if ($portableAscii.Contains('http://localhost:1420')) { throw 'Portable redesign still contains development localhost URL.' }
Copy-Item $portableRaw -Destination (Join-Path $portableDir 'RD-Drive-Portable.exe') -Force

@(
  'RD Drive 1.0.0 - Browser/Media Redesign',
  'Clean-room UI inspired by familiar desktop cloud-drive workflows.',
  'Portable data directory: RDDriveData next to RD-Drive-Portable.exe.',
  'Integrated image, PDF, audio and video preview uses a temporary verified preview cache.',
  'Archives currently download/open externally; archive browsing is not claimed in this build.'
) | Set-Content -Path (Join-Path $out 'RELEASE-NOTES.txt') -Encoding utf8

$files = Get-ChildItem -Path $out -Recurse -File | Where-Object { $_.Name -ne 'SHA256SUMS.txt' }
$lines = foreach ($file in $files) {
  $relative = [IO.Path]::GetRelativePath($out, $file.FullName)
  $hash = (Get-FileHash -Algorithm SHA256 -Path $file.FullName).Hash.ToLowerInvariant()
  "$hash  $relative"
}
$lines | Set-Content -Path (Join-Path $out 'SHA256SUMS.txt') -Encoding ascii
Get-ChildItem $out -Recurse -File | Select-Object FullName,Length | Format-Table -AutoSize

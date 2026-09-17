$ErrorActionPreference = 'Stop'

if ($env:RD_BUILD_KEY -notmatch '^[0-9a-fA-F]{64}$') { throw 'RD_BUILD_KEY secret is missing or invalid.' }

$partNames = @(
  'payload/rd-drive.enc.b64.00',
  'payload/rd-drive.enc.b64.01',
  'payload/rd-drive.enc.b64.02',
  'payload/rd-drive.enc.b64.03',
  'payload/rd-drive.enc.b64.04',
  'payload/rd-drive.enc.b64.05',
  'payload/rd-drive.enc.b64.06a',
  'payload/rd-drive.enc.b64.06b',
  'payload/rd-drive.enc.b64.07',
  'payload/rd-drive.enc.b64.08',
  'payload/rd-drive.enc.b64.09'
)
foreach ($part in $partNames) {
  if (-not (Test-Path $part)) { throw "Missing encrypted payload fragment: $part" }
}

$b64 = ($partNames | ForEach-Object { Get-Content -Raw $_ }) -join ''
[IO.File]::WriteAllBytes('rd-drive-ci-source.enc', [Convert]::FromBase64String($b64))
$encryptedHash = (Get-FileHash -Algorithm SHA256 'rd-drive-ci-source.enc').Hash.ToLowerInvariant()
if ($encryptedHash -ne '0ee2f7ab3567c73c19571a4738d63549c9eeef74a07a63a044013835ad30b6da') {
  throw "Encrypted payload SHA256 mismatch: $encryptedHash"
}

[byte[]]$key = for ($i = 0; $i -lt 64; $i += 2) { [Convert]::ToByte($env:RD_BUILD_KEY.Substring($i, 2), 16) }
[byte[]]$blob = [IO.File]::ReadAllBytes('rd-drive-ci-source.enc')
if ($blob.Length -lt 35) { throw 'Encrypted payload is too short.' }
if ([Text.Encoding]::ASCII.GetString($blob[0..5]) -ne 'RDENC1') { throw 'Invalid encrypted payload magic.' }
[byte[]]$nonce = $blob[6..17]
[byte[]]$tag = $blob[18..33]
[byte[]]$cipher = $blob[34..($blob.Length - 1)]
[byte[]]$plain = New-Object byte[] $cipher.Length
[byte[]]$aad = [Text.Encoding]::ASCII.GetBytes('RD-DRIVE-CI-v1')
$aes = [System.Security.Cryptography.AesGcm]::new($key, 16)
try { $aes.Decrypt($nonce, $cipher, $tag, $plain, $aad) }
finally { $aes.Dispose(); [Array]::Clear($key, 0, $key.Length) }
[IO.File]::WriteAllBytes('rd-drive-ci-source.zip', $plain)
[Array]::Clear($plain, 0, $plain.Length)

$sourceHash = (Get-FileHash -Algorithm SHA256 'rd-drive-ci-source.zip').Hash.ToLowerInvariant()
if ($sourceHash -ne 'dfe1cdf5f6b9fdf30cca6b76f9b984fc03ba1c58858476ea980232f3e04249c8') {
  throw "Decrypted source SHA256 mismatch: $sourceHash"
}

Remove-Item 'source' -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path 'source' | Out-Null
Expand-Archive -Path 'rd-drive-ci-source.zip' -DestinationPath 'source' -Force
New-Item -ItemType Directory -Force -Path 'source/.github/workflows' | Out-Null
Copy-Item '.github/workflows/windows-release-v3.yml' -Destination 'source/.github/workflows/windows-release.yml' -Force
Remove-Item 'rd-drive-ci-source.enc','rd-drive-ci-source.zip' -Force

python -m pip install --disable-pip-version-check pytest pillow
if ($LASTEXITCODE -ne 0) { throw 'Python build dependencies installation failed.' }

Push-Location 'source'
try {
  & '..\ci\prepare-rd-drive-final.ps1'

  npm install
  if ($LASTEXITCODE -ne 0) { throw 'npm install failed.' }
  npm test
  if ($LASTEXITCODE -ne 0) { throw 'TypeScript domain tests failed.' }
  python -m pytest tests -q
  if ($LASTEXITCODE -ne 0) { throw 'Python contract tests failed.' }
  npm run build
  if ($LASTEXITCODE -ne 0) { throw 'Frontend production build failed.' }

  cargo test --manifest-path src-tauri/Cargo.toml --all-targets
  if ($LASTEXITCODE -ne 0) { throw 'Rust tests failed.' }
  cargo check --manifest-path src-tauri/Cargo.toml --features portable --target x86_64-pc-windows-msvc
  if ($LASTEXITCODE -ne 0) { throw 'Portable Rust feature check failed.' }

  npm run tauri build -- --target x86_64-pc-windows-msvc
  if ($LASTEXITCODE -ne 0) { throw 'Installed Tauri release build failed.' }
}
finally {
  Pop-Location
}

$out = Join-Path $PWD 'release-artifacts-final'
Remove-Item $out -Recurse -Force -ErrorAction SilentlyContinue
$setupDir = Join-Path $out 'Setup'
$portableDir = Join-Path $out 'Portable'
New-Item -ItemType Directory -Force -Path $setupDir | Out-Null
New-Item -ItemType Directory -Force -Path $portableDir | Out-Null

$installedRaw = 'source/src-tauri/target/x86_64-pc-windows-msvc/release/rd-drive.exe'
if (-not (Test-Path $installedRaw)) { throw 'Installed RD Drive release EXE was not produced.' }
& '.\ci\verify-rd-drive-pe.ps1' -Path $installedRaw

$bundleRoot = 'source/src-tauri/target/x86_64-pc-windows-msvc/release/bundle'
$setups = Get-ChildItem -Path $bundleRoot -Recurse -File -Include '*.exe','*.msi'
if (-not $setups) { throw 'No Windows setup artifact was produced.' }
foreach ($file in $setups) { Copy-Item $file.FullName -Destination $setupDir }

Push-Location 'source'
try {
  cargo build --manifest-path src-tauri/Cargo.toml --release --features portable --target x86_64-pc-windows-msvc
  if ($LASTEXITCODE -ne 0) { throw 'Portable Windows release build failed.' }
}
finally {
  Pop-Location
}

$portableRaw = 'source/src-tauri/target/x86_64-pc-windows-msvc/release/rd-drive.exe'
if (-not (Test-Path $portableRaw)) { throw 'Portable RD Drive release EXE was not produced.' }
& '.\ci\verify-rd-drive-pe.ps1' -Path $portableRaw
Copy-Item $portableRaw -Destination (Join-Path $portableDir 'RD-Drive-Portable.exe')

$note = @(
  'RD Drive 1.0.0 Portable',
  '',
  'Diese Ausgabe benötigt keine Installation.',
  'Alle RD-Drive-Programmdaten werden im Ordner "RDDriveData" direkt neben RD-Drive-Portable.exe gespeichert.',
  'Zum vollständigen Entfernen der portablen Ausgabe genügt es, RD-Drive-Portable.exe und den zugehörigen Ordner RDDriveData zu löschen.',
  '',
  'Die Portable-EXE ist als Windows-GUI-Anwendung gebaut und darf kein CMD-Fenster öffnen.',
  'Das Windows-App-Icon basiert auf dem vom Nutzer hochgeladenen RD-Drive-Motiv.'
)
$note | Set-Content -Path (Join-Path $portableDir 'PORTABLE-HINWEIS.txt') -Encoding utf8

$files = Get-ChildItem -Path $out -Recurse -File | Where-Object { $_.Name -ne 'SHA256SUMS.txt' }
if (-not $files) { throw 'No final Windows artifacts were produced.' }
$lines = foreach ($file in $files) {
  $relative = [IO.Path]::GetRelativePath($out, $file.FullName)
  $hash = (Get-FileHash -Algorithm SHA256 -Path $file.FullName).Hash.ToLowerInvariant()
  "$hash  $relative"
}
$lines | Set-Content -Path (Join-Path $out 'SHA256SUMS.txt') -Encoding ascii
Get-ChildItem $out -Recurse -File | Select-Object FullName,Length | Format-Table -AutoSize

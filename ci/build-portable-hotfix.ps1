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
Remove-Item 'rd-drive-ci-source.enc','rd-drive-ci-source.zip' -Force

python -m pip install --disable-pip-version-check pillow
if ($LASTEXITCODE -ne 0) { throw 'Pillow installation failed.' }

Push-Location 'source'
try {
  & '..\ci\prepare-rd-drive-final.ps1'

  npm install
  if ($LASTEXITCODE -ne 0) { throw 'npm install failed.' }
  npm run build
  if ($LASTEXITCODE -ne 0) { throw 'Frontend production build failed.' }

  $portableConfig = @{
    build = @{
      devUrl = $null
      frontendDist = '../dist'
      features = @('portable')
    }
    bundle = @{
      active = $false
    }
  } | ConvertTo-Json -Depth 10
  $portableConfig | Set-Content -Path 'src-tauri/tauri.portable.conf.json' -Encoding utf8

  npm run tauri build -- --target x86_64-pc-windows-msvc --no-bundle --config src-tauri/tauri.portable.conf.json
  if ($LASTEXITCODE -ne 0) { throw 'Tauri portable release build failed.' }
}
finally {
  Pop-Location
}

$portableRaw = 'source/src-tauri/target/x86_64-pc-windows-msvc/release/rd-drive.exe'
if (-not (Test-Path $portableRaw)) { throw 'Portable release EXE was not produced.' }
& '.\ci\verify-rd-drive-pe.ps1' -Path $portableRaw

$bytes = [IO.File]::ReadAllBytes($portableRaw)
$ascii = [Text.Encoding]::ASCII.GetString($bytes)
if ($ascii.Contains('http://localhost:1420')) {
  throw 'Portable binary still contains the development localhost URL.'
}

$out = Join-Path $PWD 'portable-hotfix-artifact'
Remove-Item $out -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $out | Out-Null
Copy-Item $portableRaw -Destination (Join-Path $out 'RD-Drive-Portable.exe') -Force
$hash = (Get-FileHash -Algorithm SHA256 (Join-Path $out 'RD-Drive-Portable.exe')).Hash.ToLowerInvariant()
"$hash  RD-Drive-Portable.exe" | Set-Content -Path (Join-Path $out 'SHA256SUMS.txt') -Encoding ascii
@(
  'RD Drive 1.0.0 Portable Hotfix',
  'Frontend ist in die EXE eingebettet; es wird kein localhost-Dev-Server verwendet.',
  'Programmdaten: RDDriveData direkt neben RD-Drive-Portable.exe.'
) | Set-Content -Path (Join-Path $out 'PORTABLE-HINWEIS.txt') -Encoding utf8
Write-Host "Portable hotfix SHA256: $hash"

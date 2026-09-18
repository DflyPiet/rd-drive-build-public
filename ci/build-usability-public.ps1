$ErrorActionPreference = 'Stop'

python .\ci\decrypt-usability.py
if ($LASTEXITCODE -ne 0) { throw 'Encrypted source decryption failed.' }

$expected = (Get-Content -Raw 'payload-usability/usability.source.sha256').Trim().Split(' ')[0].ToLowerInvariant()
$actual = (Get-FileHash -Algorithm SHA256 'rd-drive-usability-source.tar.xz').Hash.ToLowerInvariant()
if ($actual -ne $expected) { throw "Decrypted source SHA256 mismatch. Expected $expected, got $actual" }

Remove-Item source -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path source | Out-Null
tar -xJf rd-drive-usability-source.tar.xz -C source
if ($LASTEXITCODE -ne 0) { throw 'Source extraction failed.' }
if (-not (Test-Path 'source/package.json')) { throw 'Source package.json missing after extraction.' }
if (-not (Test-Path 'source/src-tauri/Cargo.toml')) { throw 'Cargo.toml missing after extraction.' }

$main = 'source/src-tauri/src/main.rs'
$mainText = Get-Content -Raw $main
$attr = '#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]'
if (-not $mainText.Contains($attr)) {
  Set-Content -Path $main -Value ($attr + "`r`n`r`n" + $mainText) -Encoding utf8 -NoNewline
}

$cargo = 'source/src-tauri/Cargo.toml'
$cargoText = Get-Content -Raw $cargo
if ($cargoText -notmatch '(?m)^\[features\]\s*$') {
  $cargoText = [regex]::Replace($cargoText, '(?m)^\[lib\]\s*$', "[features]`r`ndefault = []`r`nportable = []`r`n`r`n[lib]", 1)
} elseif ($cargoText -notmatch '(?m)^portable\s*=\s*\[\]\s*$') {
  $cargoText = $cargoText.Replace('[features]', "[features]`r`nportable = []")
}
if ($cargoText -notmatch 'glass_pumpkin\s*=') {
  $anchor = 'grammers-stringsession = "0.1.1"'
  if ($cargoText.Contains($anchor)) {
    $cargoText = $cargoText.Replace($anchor, $anchor + "`r`nglass_pumpkin = `"=2.0.0-rc0`"")
  }
}
Set-Content -Path $cargo -Value $cargoText -Encoding utf8 -NoNewline

$telegramPath = 'source/src-tauri/src/telegram.rs'
$telegramText = Get-Content -Raw $telegramPath
$oldTelegram = 'InputMessage::text("").file(uploaded)'
$newTelegram = 'InputMessage::new().text("").file(uploaded)'
if ($telegramText.Contains($oldTelegram)) {
  $telegramText = $telegramText.Replace($oldTelegram, $newTelegram)
  Set-Content -Path $telegramPath -Value $telegramText -Encoding utf8 -NoNewline
}

$teamPath = 'source/src-tauri/src/team_share.rs'
$teamText = Get-Content -Raw $teamPath
$oldTeam = 'pub fn members(root:&Path,p:&str,share_id:&str)->Result<Vec<ShareMemberRecord>,AppError>{let conn=db(root,p)?;let mut st=conn.prepare("SELECT member_id,role,key_version,revoked_at,added_at FROM share_members WHERE share_id=?1 ORDER BY added_at ASC")?;Ok(st.query_map(params![share_id],|r|Ok(ShareMemberRecord{member_id:r.get(0)?,role:r.get(1)?,key_version:r.get::<_,i64>(2)? as u32,revoked:r.get::<_,Option<String>>(3)?.is_some(),added_at:r.get(4)?}))?.collect::<Result<Vec<_>,_>>()?)}'
$newTeam = 'pub fn members(root:&Path,p:&str,share_id:&str)->Result<Vec<ShareMemberRecord>,AppError>{let conn=db(root,p)?;let mut st=conn.prepare("SELECT member_id,role,key_version,revoked_at,added_at FROM share_members WHERE share_id=?1 ORDER BY added_at ASC")?;let rows=st.query_map(params![share_id],|r|Ok(ShareMemberRecord{member_id:r.get(0)?,role:r.get(1)?,key_version:r.get::<_,i64>(2)? as u32,revoked:r.get::<_,Option<String>>(3)?.is_some(),added_at:r.get(4)?}))?;let out=rows.collect::<Result<Vec<_>,_>>()?;Ok(out)}'
if ($teamText.Contains($oldTeam)) {
  $teamText = $teamText.Replace($oldTeam, $newTeam)
  Set-Content -Path $teamPath -Value $teamText -Encoding utf8 -NoNewline
}

$appPath = 'source/src/App.tsx'
$appText = Get-Content -Raw $appPath
$dragOld = "event.payload.type === 'cancel'"
$dragNew = "event.payload.type === 'leave'"
if ($appText.Contains($dragOld)) {
  $appText = $appText.Replace($dragOld, $dragNew)
  Set-Content -Path $appPath -Value $appText -Encoding utf8 -NoNewline
}

$commands = 'source/src-tauri/src/commands.rs' 
$commandsText = Get-Content -Raw $commands
if (-not $commandsText.Contains('RDDriveData')) {
  $pattern = 'fn app_root\(app: &AppHandle\) -> Result<PathBuf, String> \{\s*app\.path\(\)\.app_data_dir\(\)\.map_err\(\|error\| format!\("app_data_dir:\{error\}"\)\)\s*\}'
  $replacement = @'
#[cfg(feature = "portable")]
fn app_root(_app: &AppHandle) -> Result<PathBuf, String> {
    let executable = std::env::current_exe().map_err(|error| format!("current_exe:{error}"))?;
    let directory = executable.parent().ok_or_else(|| "current_exe:no_parent".to_string())?;
    Ok(directory.join("RDDriveData"))
}

#[cfg(not(feature = "portable"))]
fn app_root(app: &AppHandle) -> Result<PathBuf, String> {
    app.path().app_data_dir().map_err(|error| format!("app_data_dir:{error}"))
}
'@
  $updated = [regex]::Replace($commandsText, $pattern, $replacement, 1)
  if ($updated -eq $commandsText) { throw 'Portable app_root patch failed.' }
  Set-Content -Path $commands -Value $updated -Encoding utf8 -NoNewline
}

New-Item -ItemType Directory -Force -Path 'source/src-tauri/icons' | Out-Null
$iconB64 = (Get-Content -Raw 'ci/icon.ico.b64') -replace '\s',''
[IO.File]::WriteAllBytes('source/src-tauri/icons/icon.ico', [Convert]::FromBase64String($iconB64))
$configPath = 'source/src-tauri/tauri.conf.json'
$config = Get-Content -Raw $configPath | ConvertFrom-Json
$config.bundle | Add-Member -NotePropertyName icon -NotePropertyValue @('icons/icon.ico') -Force
$config | ConvertTo-Json -Depth 100 | Set-Content -Path $configPath -Encoding utf8

rustup default stable
if ($LASTEXITCODE -ne 0) { throw 'rustup default stable failed.' }
rustup target add x86_64-pc-windows-msvc
if ($LASTEXITCODE -ne 0) { throw 'Rust Windows target installation failed.' }
rustc --version
cargo --version
node --version
npm --version

Push-Location source
try {
  npm install
  if ($LASTEXITCODE -ne 0) { throw 'npm install failed.' }

  npm test
  if ($LASTEXITCODE -ne 0) { throw 'Frontend tests failed.' }

  python -m pytest tests -q
  if ($LASTEXITCODE -ne 0) { throw 'Backend contract tests failed.' }

  npm run build
  if ($LASTEXITCODE -ne 0) { throw 'Frontend production build failed.' }

  cargo test --manifest-path src-tauri/Cargo.toml --all-targets
  if ($LASTEXITCODE -ne 0) { throw 'Rust tests failed.' }

  npm run tauri build -- --target x86_64-pc-windows-msvc
  if ($LASTEXITCODE -ne 0) { throw 'Installed Windows Tauri build failed.' }
}
finally {
  Pop-Location
}

$out = Join-Path $PWD 'release-artifacts'
Remove-Item $out -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path "$out/Setup" | Out-Null
New-Item -ItemType Directory -Force -Path "$out/Portable" | Out-Null

$installedRaw = 'source/src-tauri/target/x86_64-pc-windows-msvc/release/rd-drive.exe'
if (-not (Test-Path $installedRaw)) { throw 'Installed RD Drive EXE was not produced.' }
Copy-Item $installedRaw "$out/RD-Drive.exe" -Force

$bundleRoot = 'source/src-tauri/target/x86_64-pc-windows-msvc/release/bundle'
$setups = @(Get-ChildItem -Path $bundleRoot -Recurse -File -Include '*.exe','*.msi' -ErrorAction SilentlyContinue)
if ($setups.Count -eq 0) { throw 'No Windows installer bundle was produced.' }
foreach ($file in $setups) { Copy-Item $file.FullName "$out/Setup/$($file.Name)" -Force }

$portableConfig = @{
  build = @{
    devUrl = $null
    frontendDist = '../dist'
    features = @('portable')
  }
  bundle = @{ active = $false }
} | ConvertTo-Json -Depth 10
$portableConfig | Set-Content -Path 'source/src-tauri/tauri.portable.conf.json' -Encoding utf8

Push-Location source
try {
  npm run tauri build -- --target x86_64-pc-windows-msvc --no-bundle --config src-tauri/tauri.portable.conf.json
  if ($LASTEXITCODE -ne 0) { throw 'Portable Windows Tauri build failed.' }
}
finally {
  Pop-Location
}

$portableRaw = 'source/src-tauri/target/x86_64-pc-windows-msvc/release/rd-drive.exe'
if (-not (Test-Path $portableRaw)) { throw 'Portable RD Drive EXE was not produced.' }
$bytes = [IO.File]::ReadAllBytes($portableRaw)
$ascii = [Text.Encoding]::ASCII.GetString($bytes)
if ($ascii.Contains('http://localhost:1420')) { throw 'Portable EXE still contains the development localhost URL.' }
Copy-Item $portableRaw "$out/Portable/RD-Drive-Portable.exe" -Force
@(
  'RD Drive 1.0.0 Portable',
  '',
  'Keine Installation erforderlich.',
  'Programmdaten werden im Ordner RDDriveData neben der EXE gespeichert.'
) | Set-Content "$out/Portable/PORTABLE-HINWEIS.txt" -Encoding utf8

$files = Get-ChildItem -Path $out -Recurse -File | Where-Object { $_.Name -ne 'SHA256SUMS.txt' }
$lines = foreach ($file in $files) {
  $relative = [IO.Path]::GetRelativePath($out, $file.FullName)
  $hash = (Get-FileHash -Algorithm SHA256 -Path $file.FullName).Hash.ToLowerInvariant()
  "$hash  $relative"
}
$lines | Set-Content -Path (Join-Path $out 'SHA256SUMS.txt') -Encoding ascii
Get-ChildItem $out -Recurse -File | Select-Object FullName,Length | Format-Table -AutoSize
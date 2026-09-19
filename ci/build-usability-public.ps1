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
}
$oldTelegramCaption = 'InputMessage::text(caption.trim()).file(uploaded)'
$newTelegramCaption = 'InputMessage::new().text(caption.trim()).file(uploaded)'
if ($telegramText.Contains($oldTelegramCaption)) {
  $telegramText = $telegramText.Replace($oldTelegramCaption, $newTelegramCaption)
}
$telegramText = $telegramText.Replace('LoginToken::LoginToken(token)', 'LoginToken::Token(token)')
Set-Content -Path $telegramPath -Value $telegramText -Encoding utf8 -NoNewline

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
}
$shareUnionOld = 'shareSource?.id === item.id'
$shareUnionNew = "shareSource && 'id' in shareSource && shareSource.id === item.id"
if ($appText.Contains($shareUnionOld)) {
  $appText = $appText.Replace($shareUnionOld, $shareUnionNew)
}
Set-Content -Path $appPath -Value $appText -Encoding utf8 -NoNewline

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

# Windows Autostart hotfix: use HKCU Run with the actual running EXE path.
# This works for installed and portable builds without admin rights.
$cargo = 'source/src-tauri/Cargo.toml'
$cargoText = Get-Content -Raw $cargo
$cargoText = [regex]::Replace($cargoText, '(?m)^\s*tauri-plugin-autostart\s*=\s*"2"\s*\r?\n', '')
if ($cargoText -notmatch '(?m)^winreg\s*=\s*"0\.55"\s*$') {
  if ($cargoText -match "(?m)^\[target\.'cfg\(windows\)'\.dependencies\]\s*$") {
    $cargoText = [regex]::Replace(
      $cargoText,
      "(?m)^(\[target\.'cfg\(windows\)'\.dependencies\]\s*)$",
      "`$1`r`nwinreg = `"0.55`"",
      1
    )
  } else {
    $cargoText = $cargoText.Replace(
      '[dev-dependencies]',
      "[target\.'cfg(windows)\'.dependencies]`r`nwinreg = `"0.55`"`r`n`r`n[dev-dependencies]"
    )
  }
}
Set-Content -Path $cargo -Value $cargoText -Encoding utf8 -NoNewline

$libPath = 'source/src-tauri/src/lib.rs'
$libText = Get-Content -Raw $libPath
if (-not $libText.Contains('mod windows_autostart;')) {
  if (-not $libText.Contains('mod vault;')) { throw 'Could not locate lib.rs module anchor for autostart fix.' }
  $libText = $libText.Replace('mod vault;', "mod vault;`r`nmod windows_autostart;")
}
$libText = [regex]::Replace(
  $libText,
  '(?m)^\s*\.plugin\(tauri_plugin_autostart::Builder::new\(\)\.build\(\)\)\s*\r?\n',
  ''
)
Set-Content -Path $libPath -Value $libText -Encoding utf8 -NoNewline

$commandsPath = 'source/src-tauri/src/commands.rs'
$commandsText = Get-Content -Raw $commandsPath
$commandsText = [regex]::Replace(
  $commandsText,
  '(?m)^use tauri_plugin_autostart::ManagerExt;\s*\r?\n',
  ''
)
if (-not $commandsText.Contains('team_share, windows_autostart,')) {
  $commandsText = $commandsText.Replace(
    'cache, desktop, diagnostics, legacy_share, local_services, network_settings, picker, preview, quick_share, remote_import, team_share,',
    'cache, desktop, diagnostics, legacy_share, local_services, network_settings, picker, preview, quick_share, remote_import, team_share, windows_autostart,'
  )
}
$commandsText = $commandsText.Replace(
  'app.autolaunch().is_enabled()',
  'windows_autostart::is_enabled()'
)
$oldAutostartBlock = @'
    let manager = app.autolaunch();
    let autostart_result = if requested_autostart { manager.enable() } else { manager.disable() };
    autostart_result.map_err(|error| format!("autostart:{error}"));
'@
$newAutostartBlock = @'
    let previous_autostart = windows_autostart::is_enabled().unwrap_or(previous.autostart_enabled);
    windows_autostart::set_enabled(requested_autostart)
        .map_err(|error| format!("autostart:{error}"))?;
'@
if ($commandsText.Contains($oldAutostartBlock)) {
  $commandsText = $commandsText.Replace($oldAutostartBlock, $newAutostartBlock)
}
$commandsText = $commandsText.Replace(
  'saved.autostart_enabled = manager.is_enabled().unwrap_or(requested_autostart);',
  'saved.autostart_enabled = windows_autostart::is_enabled().unwrap_or(requested_autostart);'
)
$commandsText = $commandsText.Replace(
 'let _ = if previous.autostart_enabled { manager.enable() } else { manager.disable() };',
  'let _ = windows_autostart::set_enabled(previous_autostart);'
)
$commandsText = $commandsText.Replace('    let manager = app.autolaunch();', '')
$commandsText = $commandsText.Replace(
  '    let autostart_result = if requested_autostart { manager.enable() } else { manager.disable() };',
  "    let previous_autostart = windows_autostart::is_enabled().unwrap_or(previous.autostart_enabled);`r`n    windows_autostart::set_enabled(requested_autostart)"
)
$commandsText = $commandsText.Replace(
  '    autostart_result.map_err(|error| format!("autostart:{error}"))?;',
  '        .map_err(|error| format!("autostart:{error}"))?;'
)
Set-Content -Path $commandsPath -Value $commandsText -Encoding utf8 -NoNewline

$windowsAutostartPath = 'source/src-tauri/src/windows_autostart.rs'
@'
#[cfg(windows)]
mod platform {
    use std::{env, io, path::PathBuf};

    use winreg::{enums::HKEY_CURRENT_USER, RegKey};

    const RUN_KEY: &str = r"Software\Microsoft\Windows\CurrentVersion\Run";
    const VALUE_NAME: &str = "RD Drive";

    fn current_executable() -> Result<PathBuf, String> {
        let exe = env::current_exe().map_err(|error| format!("current_exe:{error}"))?;
        if !exe.is_file() {
            return Err(format!("current_exe_missing:{}", exe.display()));
        }
        Ok(exe)
    }

    fn startup_command() -> Result<String, String> {
        let exe = current_executable()?;
        Ok(format!("\"{}\"", exe.display()))
    }

    fn not_found(error: &io::Error) -> bool {
        error.kind() == io::ErrorKind::NotFound || error.raw_os_error() == Some(2)
    }

    pub fn set_enabled(enabled: bool) -> Result<(), String> {
        let hkcu = RegKey::predef(HKEY_CURRENT_USER);
        let (run_key, _) = hkcu
            .create_subkey(RUN_KEY)
            .map_err(|error| format!("run_key_open:{error}"))?;

        if enabled {
            let command = startup_command()?;
            run_key
                .set_value(VALUE_NAME, &command)
                .map_err(|error| format!("run_key_write:{error}"))?;
            return Ok(());
        }

        match run_key.delete_value(VALUE_NAME) {
            Ok(()) => Ok(()),
            Err(error) if not_found(&error) => Ok(()),
            Err(error) => Err(format!("run_key_delete:{error}")),
        }
    }

    pub fn is_enabled() -> Result<bool, String> {
        let hkcu = RegKey::predef(HKEY_CURRENT_USER);
        let run_key = match hkcu.open_subkey(RUN_KEY) {
            Ok(key) => key,
            Err(error) if not_found(&error) => return Ok(false),
            Err(error) => return Err(format!("run_key_open:{error}"))),
        };

        let configured: String = match run_key.get_value(VALUE_NAME) {
            Ok(value) => value,
            Err(error) if not_found(&error) => return Ok(false),
            Err(error) => return Err(format!("run_key_read:{error}")),
        };

        let expected = startup_command()?;
        Ok(configured.trim().eq_ignore_ascii_case(expected.trim()))
    }
}

#[cfg(not(windows))]
mod platform {
    pub fn set_enabled(_enabled: bool) -> Result<(), String> {
        Ok(())
    }

    pub fn is_enabled() -> Result<bool, String> {
        Ok(false)
    }
}

pub use platform::{is_enabled, set_enabled};
'@ | Set-Content -Path $windowsAutostartPath -Encoding utf8 -NoNewline

$autostartTestPath = 'source/tests/test_usability_backend_contract.py'
$autostartTest = Get-Content -Raw $autostartTestPath
$autostartTest = $autostartTest.Replace(
  '    assert ''tauri-plugin-autostart = "2"'' in cargo',
  '    assert ''winreg = "0.55"'' in cargo'
)
$autostartTest = $autostartTest.Replace(
  '    assert ''app.autolaunch()'' in commands',
  @'
    autostart = (ROOT / "src-tauri" / "src" / "windows_autostart.rs").read_text(encoding="utf-8")
    assert 'windows_autostart::set_enabled' in commands
    assert 'HKEY_CURRENT_USER' in autostart and 'CurrentVersion\\Run' in autostart
    assert 'current_exe' in autostart and 'eq_ignore_ascii_case' in autostart
'@
)
Set-Content -Path $autostartTestPath -Value $autostartTest -Encoding utf8 -NoNewline
$cargoCheck = Get-Content -Raw $cargo
$libCheck = Get-Content -Raw $libPath
$commandsCheck = Get-Content -Raw $commandsPath
if ($cargoCheck.Contains('tauri-plugin-autostart')) { throw 'Old Tauri autostart dependency is still present.' }
if (-not $cargoCheck.Contains('winreg = "0.55"')) { throw 'winreg dependency missing after autostart fix.' }
if ($libCheck.Contains('tauri_plugin_autostart')) { throw 'Old Tauri autostart plugin is still registered.' }
if (-not $libCheck.Contains('mod windows_autostart;')) { throw 'windows_autostart module is not registered.' }
if ($commandsCheck.Contains('ManagerExt') -or $commandsCheck.Contains('app.autolaunch()')) { throw 'Old autostart API is still referenced.' }
if (-not $commandsCheck.Contains('windows_autostart::set_enabled(requested_autostart)')) { throw 'New autostart setter is missing.' }
if (-not (Test-Path $windowsAutostartPath)) { throw 'windows_autostart.rs was not created.' }


python .\ci\make-rd-icons.py
if ($LASTEXITCODE -ne 0) { throw 'RD Drive icon generation failed.' }
if (-not (Test-Path 'source/src/assets/rd-drive-icon.jpg')) { throw 'Frontend RD Drive icon missing after generation.' }
@'
declare module '*.jpg' {
  const src: string;
  export default src;
}
declare module '*.jpeg' {
  const src: string;
  export default src;
}
declare module '*.png' {
  const src: string;
  export default src;
}
declare module '*.ico' {
  const src: string;
  export default src;
}
'@ | Set-Content -Path 'source/src/assets.d.ts' -Encoding utf8
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
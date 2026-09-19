from pathlib import Path
import re

ROOT = Path('source')

WINDOWS_AUTOSTART_RS = r'''#[cfg(windows)]
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
            Err(error) => return Err(format!("run_key_open:{error}")),
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
    pub fn set_enabled(_enabled: bool) -> Result<(), String> { Ok(()) }
    pub fn is_enabled() -> Result<bool, String> { Ok(false) }
}

pub use platform::{is_enabled, set_enabled};
'''


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding='utf-8')


def write(rel: str, content: str) -> None:
    (ROOT / rel).write_text(content, encoding='utf-8', newline='\n')


write('src-tauri/src/windows_autostart.rs', WINDOWS_AUTOSTART_RS)

lib = read('src-tauri/src/lib.rs')
if 'mod windows_autostart;' not in lib:
    lib = lib.replace('mod vault;\n', 'mod vault;\nmod windows_autostart;\n')
lib = re.sub(r'^\s*\.plugin\(tauri_plugin_autostart::Builder::new\(\)\.build\(\)\)\s*\n', '', lib, flags=re.M)
write('src-tauri/src/lib.rs', lib)

commands = read('src-tauri/src/commands.rs')
commands = commands.replace('use tauri_plugin_autostart::ManagerExt;\n', '')
if 'use crate::windows_autostart;' not in commands:
    commands = commands.replace('use serde::Serialize;\n', 'use serde::Serialize;\nuse crate::windows_autostart;\n')
commands, n_get = re.subn(
    r'if let Ok\(enabled\) = app\.autolaunch\(\)\.is_enabled\(\) \{\s*record\.autostart_enabled = enabled;\s*\}',
    'if let Ok(enabled) = windows_autostart::is_enabled() {\n        record.autostart_enabled = enabled;\n    }',
    commands,
    count=1,
    flags=re.S,
)
old_update = r'''    let requested_autostart = settings_record.autostart_enabled;
    let manager = app.autolaunch();
    let autostart_result = if requested_autostart { manager.enable() } else { manager.disable() };
    autostart_result.map_err(|error| format!("autostart:{error}"))?;

    match settings::update(&root, &profile_id, settings_record) {
        Ok(mut saved) => {
            saved.autostart_enabled = manager.is_enabled().unwrap_or(requested_autostart);
            desktop_runtime.set_close_to_tray(saved.close_to_tray);
            Ok(saved)
        }
        Err(error) => {
            let _ = if previous.autostart_enabled { manager.enable() } else { manager.disable() };
            Err(error.to_string())
        }
    }'''
replacement = r'''    let requested_autostart = settings_record.autostart_enabled;
    let previous_autostart = windows_autostart::is_enabled().unwrap_or(previous.autostart_enabled);
    windows_autostart::set_enabled(requested_autostart)
        .map_err(|error| format!("autostart:{error}"))?;

    match settings::update(&root, &profile_id, settings_record) {
        Ok(mut saved) => {
            saved.autostart_enabled = windows_autostart::is_enabled().unwrap_or(requested_autostart);
            desktop_runtime.set_close_to_tray(saved.close_to_tray);
            Ok(saved)
        }
        Err(error) => {
            let _ = windows_autostart::set_enabled(previous_autostart);
            Err(error.to_string())
        }
    }'''
n_update = commands.count(old_update)
commands = commands.replace(old_update, replacement, 1)
if n_get != 1:
    raise SystemExit(f'autostart settings_get patch count: {n_get}')
if n_update != 1:
    raise SystemExit(f'autostart settings_update patch count: {n_update}')
write('src-tauri/src/commands.rs', commands)

cargo = read('src-tauri/Cargo.toml')
cargo = re.sub(r'^tauri-plugin-autostart\s*=.*\n', '', cargo, flags=re.M)
if 'winreg = "0.55"' not in cargo:
    cargo = cargo.replace('[dev-dependencies]', '[target.\\'cfg(windows)\\'.dependencies]\nwinreg = "0.55"\n\n[dev-dependencies]')
write('src-tauri/Cargo.toml', cargo)

contract = ROOT / 'tests/test_usability_backend_contract.py'
if contract.exists():
    test = contract.read_text(encoding='utf-8')
    test = test.replace("assert 'tauri-plugin-autostart = \"2\"' in cargo", "assert 'winreg = \"0.55\"' in cargo")
    test = test.replace(
        "assert 'app.autolaunch()' in commands",
        "autostart = (ROOT / 'src-tauri' / 'src' / 'windows_autostart.rs').read_text(encoding='utf-8')\n    assert 'windows_autostart::set_enabled' in commands\n    assert 'HKEY_CURRENT_USER' in autostart and 'CurrentVersion\\\\Run' in autostart",
    )
    contract.write_text(test, encoding='utf-8', newline='\n')

print('RD Drive Windows autostart repair applied.')

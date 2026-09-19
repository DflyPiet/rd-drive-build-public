from pathlib import Path
import re

root = Path("source")
cargo = root / "src-tauri" / "Cargo.toml"
lib = root / "src-tauri" / "src" / "lib.rs"
commands = root / "src-tauri" / "src" / "commands.rs"
autostart = root / "src-tauri" / "src" / "windows_autostart.rs"

cargo_text = cargo.read_text(encoding="utf-8")
cargo_text = re.sub(r'(?m)^\s*tauri-plugin-autostart\s*=\s*"2"\s*\r?\n', "", cargo_text)
if 'winreg = "0.55"' not in cargo_text:
    target = "[target.'cfg(windows)'.dependencies]"
    if target in cargo_text:
        cargo_text = cargo_text.replace(target, target + '\nwinreg = "0.55"', 1)
    else:
        cargo_text = cargo_text.replace("[dev-dependencies]", target + '\nwinreg = "0.55"\n\n[dev-dependencies]', 1)
cargo.write_text(cargo_text, encoding="utf-8", newline="\n")

lib_text = lib.read_text(encoding="utf-8")
if "mod windows_autostart;" not in lib_text:
    lib_text = lib_text.replace("mod vault;", "mod vault;\nmod windows_autostart;", 1)
lib_text = re.sub(r'(?m)^\s*\.plugin\(tauri_plugin_autostart::Builder::new\(\)\.build\(\)\)\s*\r?\n', "", lib_text)
lib.write_text(lib_text, encoding="utf-8", newline="\n")

cmd = commands.read_text(encoding="utf-8")
cmd = re.sub(r'(?m)^use tauri_plugin_autostart::ManagerExt;\s*\r?\n', "", cmd)
if "team_share, windows_autostart," not in cmd:
    cmd = cmd.replace(
        "cache, desktop, diagnostics, legacy_share, local_services, network_settings, picker, preview, quick_share, remote_import, team_share,",
        "cache, desktop, diagnostics, legacy_share, local_services, network_settings, picker, preview, quick_share, remote_import, team_share, windows_autostart,",
        1,
    )
cmd = cmd.replace("app.autolaunch().is_enabled()", "windows_autostart::is_enabled()")
cmd = cmd.replace(
    """    let manager = app.autolaunch();
    let autostart_result = if requested_autostart { manager.enable() } else { manager.disable() };
    autostart_result.map_err(|error| format!("autostart:{error}"))?;
""",
    """    let previous_autostart = windows_autostart::is_enabled().unwrap_or(previous.autostart_enabled);
    windows_autostart::set_enabled(requested_autostart)
        .map_err(|error| format!("autostart:{error}"))?;
""",
)
cmd = cmd.replace(
    "saved.autostart_enabled = manager.is_enabled().unwrap_or(requested_autostart);",
    "saved.autostart_enabled = windows_autostart::is_enabled().unwrap_or(requested_autostart);",
)
cmd = cmd.replace(
    "let _ = if previous.autostart_enabled { manager.enable() } else { manager.disable() };",
    "let _ = windows_autostart::set_enabled(previous_autostart);",
)
commands.write_text(cmd, encoding="utf-8", newline="\n")

autostart.write_text(r'''#[cfg(windows)]
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
        Ok(format!("\\\"{}\\\"", exe.display()))
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
''', encoding="utf-8", newline="\n")

checks = {
    "old dependency": "tauri-plugin-autostart" in cargo.read_text(encoding="utf-8"),
    "missing winreg": 'winreg = "0.55"' not in cargo.read_text(encoding="utf-8"),
    "old plugin": "tauri_plugin_autostart" in lib.read_text(encoding="utf-8"),
    "old manager": "app.autolaunch()" in commands.read_text(encoding="utf-8"),
    "missing setter": "windows_autostart::set_enabled(requested_autostart)" not in commands.read_text(encoding="utf-8"),
}
failed = [name for name, bad in checks.items() if bad]
if failed:
    raise SystemExit("Autostart hotfix verification failed: " + ", ".join(failed))
print("RD Drive Windows autostart hotfix applied.")

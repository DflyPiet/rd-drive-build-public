$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$sourceRoot = Join-Path $repoRoot 'source'
Push-Location $sourceRoot
try {

$manifest = 'src-tauri/Cargo.toml'
$text = Get-Content -Raw $manifest

if ($text -notmatch '(?m)^\[features\]\s*$') {
  $text = [regex]::Replace(
    $text,
    '(?m)^\[lib\]\s*$',
    "[features]`r`ndefault = []`r`nportable = []`r`n`r`n[lib]",
    1
  )
}
if ($text -notmatch '(?m)^portable\s*=\s*\[\]\s*$') { throw 'Portable Cargo feature was not added.' }

if ($text.Contains('tauri = { version = "2", features = [] }')) {
  $text = $text.Replace('tauri = { version = "2", features = [] }', 'tauri = { version = "2", features = ["protocol-asset"] }')
}
if ($text -notmatch 'tauri\s*=\s*\{[^\r\n]*protocol-asset') { throw 'Tauri protocol-asset feature was not enabled.' }

if ($text -notmatch 'glass_pumpkin = "=2\.0\.0-rc0"') {
  $needle = 'grammers-stringsession = "0.1.1"'
  if (-not $text.Contains($needle)) { throw 'Could not locate grammers dependency anchor.' }
  $text = $text.Replace($needle, $needle + "`r`nglass_pumpkin = `"=2.0.0-rc0`"")
}
Set-Content -Path $manifest -Value $text -Encoding utf8 -NoNewline

$iconCarrier = Join-Path $repoRoot 'ci\rd-icon-source-128-q65.b64'
$iconSource = Join-Path $env:RUNNER_TEMP 'rd-drive-icon-source.jpg'
$iconOutput = Join-Path $sourceRoot 'src-tauri\icons'
if (-not (Test-Path $iconCarrier)) { throw 'RD Drive icon carrier is missing.' }
$iconPayload = (Get-Content -Raw $iconCarrier) -replace '\s',''
try {
  [System.IO.File]::WriteAllBytes($iconSource, [System.Convert]::FromBase64String($iconPayload))
}
catch {
  throw "RD Drive icon carrier decode failed: $($_.Exception.Message)"
}
$iconHash = (Get-FileHash -Algorithm SHA256 $iconSource).Hash.ToLowerInvariant()
if ($iconHash -ne '5a0d653aa640fed37c45b2e181317a161323bdcbb147ad14eb7a55fac81753f2') {
  throw "RD Drive icon source hash mismatch after decode: $iconHash"
}
& python (Join-Path $repoRoot 'ci\make-rd-icon.py') --source $iconSource --output $iconOutput
if ($LASTEXITCODE -ne 0) { throw 'RD Drive icon generation from uploaded artwork failed.' }
$iconPath = Join-Path $iconOutput 'icon.ico'
if (-not (Test-Path $iconPath)) { throw 'Generated RD Drive icon.ico is missing.' }

$configPath = 'src-tauri/tauri.conf.json'
$config = Get-Content -Raw $configPath | ConvertFrom-Json
$config.bundle | Add-Member -NotePropertyName icon -NotePropertyValue @(
  'icons/32x32.png',
  'icons/128x128.png',
  'icons/128x128@2x.png',
  'icons/icon.ico'
) -Force
$config | ConvertTo-Json -Depth 100 | Set-Content -Path $configPath -Encoding utf8
$configCheck = Get-Content -Raw $configPath
if (-not $configCheck.Contains('icons/icon.ico')) { throw 'Tauri bundle icon configuration was not applied.' }

$telegramPath = 'src-tauri/src/telegram.rs'
$telegram = Get-Content -Raw $telegramPath
$oldTelegram = 'InputMessage::text("").file(uploaded)'
$newTelegram = 'InputMessage::new().text("").file(uploaded)'
if ($telegram.Contains($oldTelegram)) {
  $telegram = $telegram.Replace($oldTelegram, $newTelegram)
  Set-Content -Path $telegramPath -Value $telegram -Encoding utf8 -NoNewline
}
if (-not (Get-Content -Raw $telegramPath).Contains($newTelegram)) {
  throw 'Telegram InputMessage builder compatibility fix was not applied.'
}

$teamPath = 'src-tauri/src/team_share.rs'
$team = Get-Content -Raw $teamPath
$oldTeam = 'pub fn members(root:&Path,p:&str,share_id:&str)->Result<Vec<ShareMemberRecord>,AppError>{let conn=db(root,p)?;let mut st=conn.prepare("SELECT member_id,role,key_version,revoked_at,added_at FROM share_members WHERE share_id=?1 ORDER BY added_at ASC")?;Ok(st.query_map(params![share_id],|r|Ok(ShareMemberRecord{member_id:r.get(0)?,role:r.get(1)?,key_version:r.get::<_,i64>(2)? as u32,revoked:r.get::<_,Option<String>>(3)?.is_some(),added_at:r.get(4)?}))?.collect::<Result<Vec<_>,_>>()?)}'
$newTeam = 'pub fn members(root:&Path,p:&str,share_id:&str)->Result<Vec<ShareMemberRecord>,AppError>{let conn=db(root,p)?;let mut st=conn.prepare("SELECT member_id,role,key_version,revoked_at,added_at FROM share_members WHERE share_id=?1 ORDER BY added_at ASC")?;let rows=st.query_map(params![share_id],|r|Ok(ShareMemberRecord{member_id:r.get(0)?,role:r.get(1)?,key_version:r.get::<_,i64>(2)? as u32,revoked:r.get::<_,Option<String>>(3)?.is_some(),added_at:r.get(4)?}))?;let out=rows.collect::<Result<Vec<_>,_>>()?;Ok(out)}'
if ($team.Contains($oldTeam)) {
  $team = $team.Replace($oldTeam, $newTeam)
  Set-Content -Path $teamPath -Value $team -Encoding utf8 -NoNewline
}
if (-not (Get-Content -Raw $teamPath).Contains('let out=rows.collect::<Result<Vec<_>,_>>()?;Ok(out)')) {
  throw 'Team Share rusqlite lifetime fix was not applied.'
}

$mainPath = 'src-tauri/src/main.rs'
$main = Get-Content -Raw $mainPath
$guiAttr = '#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]'
if (-not $main.Contains($guiAttr)) {
  $main = $guiAttr + "`r`n`r`n" + $main
  Set-Content -Path $mainPath -Value $main -Encoding utf8 -NoNewline
}
if (-not (Get-Content -Raw $mainPath).Contains($guiAttr)) {
  throw 'Windows GUI subsystem attribute was not applied.'
}

$commandsPath = 'src-tauri/src/commands.rs'
$commands = Get-Content -Raw $commandsPath
if (-not $commands.Contains('RDDriveData')) {
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
  $updated = [regex]::Replace($commands, $pattern, $replacement, 1)
  if ($updated -eq $commands) { throw 'Could not locate app_root for portable storage patch.' }
  Set-Content -Path $commandsPath -Value $updated -Encoding utf8 -NoNewline
}
$commandsCheck = Get-Content -Raw $commandsPath
if (-not $commandsCheck.Contains('RDDriveData')) { throw 'Portable RDDriveData storage path was not applied.' }
if (-not $commandsCheck.Contains('#[cfg(feature = "portable")]')) { throw 'Portable app_root cfg was not applied.' }
if (-not $commandsCheck.Contains('#[cfg(not(feature = "portable"))]')) { throw 'Installed app_root cfg was not preserved.' }
if (-not $commandsCheck.Contains('app.path().app_data_dir()')) { throw 'Installed AppData storage path was not preserved.' }

# TypeScript production-compile fixes for the clean-room browser redesign.
Set-Content -Path 'src/vite-env.d.ts' -Value '/// <reference types="vite/client" />' -Encoding utf8
$driveDomainPath = 'src/domain/drive.ts'
$driveDomain = Get-Content -Raw $driveDomainPath
$oldFilter = 'export function filterDriveItems(items: DriveItemView[], query: string): DriveItemView[] {'
$newFilter = 'export function filterDriveItems<T extends DriveItemView>(items: T[], query: string): T[] {'
if ($driveDomain.Contains($oldFilter)) { $driveDomain = $driveDomain.Replace($oldFilter, $newFilter) }
$oldSort = 'export function sortDriveItems(items: DriveItemView[], sort: DriveSort, direction: SortDirection): DriveItemView[] {'
$newSort = 'export function sortDriveItems<T extends DriveItemView>(items: T[], sort: DriveSort, direction: SortDirection): T[] {'
if ($driveDomain.Contains($oldSort)) { $driveDomain = $driveDomain.Replace($oldSort, $newSort) }
Set-Content -Path $driveDomainPath -Value $driveDomain -Encoding utf8 -NoNewline
$driveDomainCheck = Get-Content -Raw $driveDomainPath
if (-not $driveDomainCheck.Contains($newFilter)) { throw 'Generic drive filter type preservation fix was not applied.' }
if (-not $driveDomainCheck.Contains($newSort)) { throw 'Generic drive sort type preservation fix was not applied.' }
if (-not (Test-Path 'src/vite-env.d.ts')) { throw 'Vite asset type declaration was not created.' }
}
finally {
  Pop-Location
}

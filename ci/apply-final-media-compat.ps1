param(
  [Parameter(Mandatory = $true)]
  [string]$SourceRoot
)

$ErrorActionPreference = 'Stop'

$commandsPath = Join-Path $SourceRoot 'src-tauri/src/commands.rs'
$libPath = Join-Path $SourceRoot 'src-tauri/src/lib.rs'
$mediaPath = Join-Path $SourceRoot 'src-tauri/src/media.rs'
$configPath = Join-Path $SourceRoot 'src-tauri/tauri.conf.json'
$archivePath = Join-Path $SourceRoot 'src-tauri/src/archive.rs'


$archive = Get-Content -Raw $archivePath
$archiveOld = @'
    let basename = Path::new(&name.replace('\', "/"))
        .file_name()
        .and_then(|part| part.to_str())
        .unwrap_or("entry.bin");
'@
$archiveNew = @'
    let normalized_name = name.replace('\', "/");
    let basename = Path::new(&normalized_name)
        .file_name()
        .and_then(|part| part.to_str())
        .unwrap_or("entry.bin");
'@
if ($archive.Contains($archiveOld)) {
  $archive = $archive.Replace($archiveOld, $archiveNew)
  Set-Content -LiteralPath $archivePath -Value $archive -Encoding utf8
} elseif ($archive -match 'Path::new\(&name\.replace') {
  throw 'Archive lifetime fix target changed unexpectedly.'
}

$commands = Get-Content -Raw $commandsPath
if ($commands -notmatch 'pub async fn media_preview_prepare') {
  $alias = @'
#[tauri::command]
pub async fn media_preview_prepare(
    app: AppHandle,
    sessions: State<'_, VaultSessionStore>,
    telegram: State<'_, crate::telegram::TelegramClientStore>,
    profile_id: String,
    item_id: String,
) -> Result<media::PreparedMedia, String> {
    media_prepare_preview(app, sessions, telegram, profile_id, item_id).await
}

'@
  $pattern = '(?m)^#\[tauri::command\]\r?\npub fn media_master_hls\('
  $updated = [regex]::Replace($commands, $pattern, ($alias + "#[tauri::command]`r`npub fn media_master_hls("), 1)
  if ($updated -eq $commands) { throw 'Could not locate media_master_hls insertion point.' }
  $commands = $updated
  Set-Content -LiteralPath $commandsPath -Value $commands -Encoding utf8
}

$commands = Get-Content -Raw $commandsPath
if ($commands -notmatch 'pub fn media_preview_cleanup') {
  $cleanup = @'
#[tauri::command]
pub fn media_preview_cleanup(
    app: AppHandle,
    profile_id: String,
) -> Result<media::MediaCacheStatus, String> {
    let root = app_root(&app)?;
    media::clear_cache(&root, &profile_id).map_err(|e| e.to_string())
}

'@
  $pattern = '(?m)^#\[tauri::command\]\r?\npub fn media_master_hls\('
  $updated = [regex]::Replace($commands, $pattern, ($cleanup + "#[tauri::command]`r`npub fn media_master_hls("), 1)
  if ($updated -eq $commands) { throw 'Could not locate media cleanup insertion point.' }
  $commands = $updated
  Set-Content -LiteralPath $commandsPath -Value $commands -Encoding utf8
}

$lib = Get-Content -Raw $libPath
if ($lib -notmatch 'commands::media_preview_prepare') {
  $lib = $lib.Replace('            commands::media_prepare_preview,', "            commands::media_prepare_preview,`r`n            commands::media_preview_prepare,")
}
if ($lib -notmatch 'commands::media_preview_cleanup') {
  $lib = $lib.Replace('            commands::media_preview_prepare,', "            commands::media_preview_prepare,`r`n            commands::media_preview_cleanup,")
}
Set-Content -LiteralPath $libPath -Value $lib -Encoding utf8

$media = Get-Content -Raw $mediaPath
$cachePattern = '(?s)pub fn cache_root\(root: &Path, profile_id: &str\) -> Result<PathBuf, AppError> \{.*?\r?\n\}\r?\n\r?\nfn original_dir'
$cacheReplacement = @'
pub fn cache_root(root: &Path, profile_id: &str) -> Result<PathBuf, AppError> {
    // Reuse the profile-path validator, but keep browser-readable previews in a
    // narrowly scoped temporary directory instead of exposing all application data.
    let _ = paths::profile_dir(root, profile_id)?;
    let path = std::env::temp_dir()
        .join("RDDrivePreview")
        .join(profile_id)
        .join(MEDIA_DIR);
    fs::create_dir_all(&path)?;
    Ok(path)
}

fn original_dir
'@
$updatedMedia = [regex]::Replace($media, $cachePattern, $cacheReplacement, 1)
if ($updatedMedia -eq $media) { throw 'Could not replace media cache root.' }
Set-Content -LiteralPath $mediaPath -Value $updatedMedia -Encoding utf8

$config = Get-Content -Raw $configPath | ConvertFrom-Json
$config.app.security.assetProtocol.enable = $true
$config.app.security.assetProtocol.scope = @('$TEMP/RDDrivePreview/**')
$config.app.security.csp = "default-src 'self'; img-src 'self' asset: http://asset.localhost data: blob:; media-src 'self' asset: http://asset.localhost blob:; frame-src 'self' asset: http://asset.localhost; style-src 'self' 'unsafe-inline'; font-src 'self' data:; connect-src 'self' ipc: http://ipc.localhost http://asset.localhost"
$config | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $configPath -Encoding utf8

$verifyArchive = Get-Content -Raw $archivePath
if ($verifyArchive -match 'Path::new\(&name\.replace') { throw 'Archive lifetime regression is still present.' }

$verifyCommands = Get-Content -Raw $commandsPath
$verifyLib = Get-Content -Raw $libPath
$verifyMedia = Get-Content -Raw $mediaPath
$verifyConfig = Get-Content -Raw $configPath
if ($verifyCommands -notmatch 'pub async fn media_preview_prepare') { throw 'Legacy media preview compatibility command was not added.' }
if ($verifyCommands -notmatch 'pub fn media_preview_cleanup') { throw 'Legacy media preview cleanup command was not added.' }
if ($verifyCommands -notmatch 'materialize_drive_item') { throw 'Verified Telegram materialization path is missing from media preview.' }
if ($verifyLib -notmatch 'commands::media_preview_prepare') { throw 'Legacy media preview compatibility command is not registered.' }
if ($verifyLib -notmatch 'commands::media_preview_cleanup') { throw 'Legacy media preview cleanup command is not registered.' }
if (($verifyMedia -notmatch 'temp_dir\(\)') -or ($verifyMedia -notmatch 'RDDrivePreview')) { throw 'Media cache is not rooted in the restricted temporary preview directory.' }
if ($verifyConfig -notmatch '\$TEMP/RDDrivePreview/\*\*') { throw 'Tauri asset protocol is not restricted to the temporary preview directory.' }
if (($verifyConfig -notmatch 'frame-src') -or ($verifyConfig -notmatch 'asset:')) { throw 'Tauri CSP does not allow restricted asset frames.' }

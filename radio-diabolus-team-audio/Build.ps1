# Radio Diabolus Team Audio. Build using the GPLv3 SoundSwitch source.
# Windows x64, portable and unsigned Inno Setup installer.
[CmdletBinding()] param()
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
$upstream = "ee7def135eb96c7ac951e2d1535c7a661dfefbef"
$root = $PSScriptRoot
$work = Join-Path $root "work"
$out = Join-Path $root "output"
$portable = Join-Path $out "Portable"
$release = Join-Path $out "Release"
New-Item -ItemType Directory -Force -Path $work,$out,$portable,$release | Out-Null
$archive = Join-Path $work "upstream.zip"
Invoke-WebRequest -Uri "https://codeload.github.com/Belphemur/SoundSwitch/zip/$upstream" -OutFile $archive
Expand-Archive -Path $archive -DestinationPath (Join-Path $work "source") -Force
$folders = @(Get-ChildItem (Join-Path $work "source") -Directory | Where-Object Name -like "SoundSwitch-*")
if ($folders.Count -ne 1) { throw "Expected exactly one source directory" }
$source = $folders[0].FullName
if (-not (Test-Path (Join-Path $source "LICENSE.txt"))) { throw "SoundSwitch license file missing" }

function Patch([string]$relative, [string]$old, [string]$replacement) {
    $file = Join-Path $source $relative
    $txt = [IO.File]::ReadAllText($file)
    $idx = $txt.IndexOf($old,[StringComparison]::Ordinal)
    if ($idx -lt 0) { throw "Patch anchor missing in $relative" }
    if ($txt.IndexOf($old,$idx+$old.Length,[StringComparison]::Ordinal) -ge 0) { throw "Ambiguous patch anchor in $relative" }
    $txt = $txt.Substring(0,$idx) + $replacement + $txt.Substring($idx + $old.Length)
    [IO.File]::WriteAllText($file,$txt,[Text.UTF8Encoding]::new($false))
}

$asm = "SoundSwitch/Properties/AssemblyInfo.cs"
Patch $asm '[assembly: AssemblyTitle("SoundSwitch")]' '[assembly: AssemblyTitle("RD Soundtool")]'
Patch $asm '[assembly: AssemblyDescription("Manage the default audio device.")]' '[assembly: AssemblyDescription("Radio Diabolus audio controls based on SoundSwitch.")]'
Patch $asm '[assembly: AssemblyCompany("SoundSwitch")]' '[assembly: AssemblyCompany("Radio Diabolus")]'
Patch $asm '[assembly: AssemblyProduct("SoundSwitch")]' '[assembly: AssemblyProduct("RD Soundtool")]'
Patch "SoundSwitch/SoundSwitch.csproj" "<StartupObject>SoundSwitch.Program</StartupObject>" "<StartupObject>SoundSwitch.Program</StartupObject><AssemblyName>RD.Soundtool</AssemblyName>"
Patch $asm '[assembly: AssemblyFileVersion("7.3.3")]' '[assembly: AssemblyFileVersion("1.1.0")]'
Patch $asm '[assembly: AssemblyInformationalVersion("7.3.3")]' '[assembly: AssemblyInformationalVersion("1.1.0")]'
Patch "SoundSwitch/Program.cs" 'public static bool SkipUpdate { get; private set; }' 'public static bool SkipUpdate { get; private set; } = true;'
Patch "SoundSwitch/Program.cs" 'Application.SetColorMode(SystemColorMode.System);' 'Application.SetColorMode(SystemColorMode.Dark);'
Patch "SoundSwitch/Program.cs" 'private const string SentryDsn = "https://7d52dfb4f6554bf0b58b256337835332@o631137.ingest.sentry.io/5755327";' 'private const string SentryDsn = "";'
Patch "SoundSwitch.IPC/Pipe/PipeConstants.cs" 'private const string APP_NAME = "SoundSwitch";' 'private const string APP_NAME = "RDSoundtool";'
Patch "SoundSwitch/Framework/Configuration/SoundSwitchConfiguration.cs" 'public UpdateMode UpdateMode { get; set; } = UpdateMode.Notify;' 'public UpdateMode UpdateMode { get; set; } = UpdateMode.Never;'
Patch "SoundSwitch/Framework/Configuration/SoundSwitchConfiguration.cs" 'public bool Telemetry { get; set; } = true;' 'public bool Telemetry { get; set; } = false;'
Patch "SoundSwitch/UI/Component/TrayIcon.cs" '        _settingsMenu.Items.Add(_updateMenuItem);' '        // Team build does not offer upstream updates.'
$menuAnchor = '        _settingsMenu.Items.Add(TrayIconStrings.settings, ResourceSettingsSmallBitmap,'
Patch "SoundSwitch/UI/Component/TrayIcon.cs" $menuAnchor ('        _settingsMenu.Items.Add("Radio Diabolus | Soundtool", SoundSwitchLogoIcon.ToBitmap(), (sender, e) => new TeamCenterForm().Show());' + [Environment]::NewLine + $menuAnchor)
Copy-Item (Join-Path $root "TeamCenterForm.cs") (Join-Path $source "SoundSwitch/UI/Forms/TeamCenterForm.cs")
# Hide legacy SoundSwitch links and remove the obsolete support notice from Troubleshooting.
$tray = "SoundSwitch/UI/Component/TrayIcon.cs"
Patch $tray '(sender, e) => new About().Show());' '(sender, e) => new RdAboutForm().Show());'
Patch $tray '        _settingsMenu.Items.Add(TrayIconStrings.help, ResourceGitHubHelpBitmap,' '        /* Disabled old SoundSwitch links:
        _settingsMenu.Items.Add(TrayIconStrings.help, ResourceGitHubHelpBitmap,'
Patch $tray '            SettingsForm.DonateLink_LinkClicked);' '            SettingsForm.DonateLink_LinkClicked); */'
Patch "SoundSwitch/UI/Forms/Settings.cs" '        LocalizeForm();' @'
        LocalizeForm();
        Icon = Resources.Switch_SoundWave;
        Text = "RD Soundtool | " + SettingsStrings.settings;
        appNameLabel.Image = Resources.Switch_SoundWave.ToBitmap();
        gitHubHelpLinkLabel.Visible = false;
        discordCommunityLinkLabel.Visible = false;
        donateLinkLabel.Visible = false;
        troubleshootingLabel.Visible = false;
        updateSettingsGroupBox.Enabled = false;
'@
Copy-Item (Join-Path $root "RdAboutForm.cs") (Join-Path $source "SoundSwitch/UI/Forms/RdAboutForm.cs")


# Use the supplied artwork. The Base64 file contains a compact original raster of image 4.
Add-Type -AssemblyName System.Drawing
$logoFile = Join-Path $root "RadioDiabolusIcon.png.base64"
$logoData = [Convert]::FromBase64String(([IO.File]::ReadAllText($logoFile)).Trim())
$logoStream = [IO.MemoryStream]::new($logoData)
$bitmap = [Drawing.Bitmap]::new($logoStream)
$hicon = $bitmap.GetHicon()
$icon = [Drawing.Icon]::FromHandle($hicon)
$ico = Join-Path $source "SoundSwitch/Resources/Switch-SoundWave.ico"
$fs = [IO.File]::Create($ico)
try { $icon.Save($fs) } finally { $fs.Dispose(); $icon.Dispose(); $bitmap.Dispose(); $logoStream.Dispose() }
[System.Runtime.InteropServices.Marshal]::GetLastWin32Error() | Out-Null
# Update all icons shown by the app, including the embedded executable and tray icon.
foreach ($name in @("program.ico","Blue Icon.ico","AppIcon-Dark.ico","AppIcon-Light.ico")) {
    Copy-Item $ico (Join-Path $source "SoundSwitch/Resources/$name") -Force
}
Copy-Item $ico (Join-Path $source "SoundSwitch/Resources/RadioDiabolus.ico") -Force
[IO.File]::WriteAllBytes((Join-Path $source "SoundSwitch/Resources/RadioDiabolusIcon.png"), $logoData)

Push-Location $source
try {
    Write-Host "Publishing Radio Diabolus Team Audio win-x64 ..."
    dotnet publish "SoundSwitch/SoundSwitch.csproj" -c Release -r win-x64 --self-contained true -o $portable
    if ($LASTEXITCODE -ne 0) { throw "GUI publish failed ($LASTEXITCODE)" }
    $cli = Join-Path $out "CLI"
    dotnet publish "SoundSwitch.CLI/SoundSwitch.CLI.csproj" -c Release -r win-x64 --self-contained true -o $cli
    if ($LASTEXITCODE -ne 0) { throw "CLI publish failed ($LASTEXITCODE)" }
    Get-ChildItem $cli | Copy-Item -Destination $portable -Recurse -Force
} finally { Pop-Location }
$exe = Join-Path $portable "RD.Soundtool.exe"
if (-not (Test-Path $exe)) { throw "EXE was not produced" }
Copy-Item (Join-Path $source "LICENSE.txt") (Join-Path $portable "LICENSE.txt")
Copy-Item $ico (Join-Path $portable "RadioDiabolus.ico") -Force
@"
RD Soundtool 1.1.0
Windows 10/11 x64. Portable distribution.
Based on SoundSwitch, GPLv3, https://github.com/Belphemur/SoundSwitch
Original revision: $upstream
The complete modified source is provided as a separate ZIP archive.
Audio profiles and configuration are per-user. The installer is unsigned.
"@ | Set-Content (Join-Path $portable "TEAM_README.txt") -Encoding utf8
$zip = Join-Path $release "RD_Soundtool_Windows_x64_Portable.zip"
$sourcezip = Join-Path $release "RD_Soundtool_Modified_Source.zip"
Compress-Archive -Path (Join-Path $portable "*") -DestinationPath $zip -CompressionLevel Optimal -Force
Compress-Archive -Path (Join-Path $source "*") -DestinationPath $sourcezip -CompressionLevel Optimal -Force

$paths = @("C:\Program Files (x86)\Inno Setup 6\ISCC.exe","C:\Program Files\Inno Setup 6\ISCC.exe")
$iscc = $paths | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $iscc) {
    choco install innosetup --no-progress -y
    if ($LASTEXITCODE -ne 0) { throw "Inno Setup installation failed" }
    $iscc = $paths | Where-Object { Test-Path $_ } | Select-Object -First 1
}
if (-not $iscc) { throw "Inno Setup ISCC.exe not found" }
& $iscc (Join-Path $root "Installer.iss")
if ($LASTEXITCODE -ne 0) { throw "Installer compilation failed ($LASTEXITCODE)" }
if (-not (Test-Path (Join-Path $release "RD_Soundtool_Windows_x64_Setup.exe"))) { throw "Setup.exe not produced" }
Get-ChildItem $release -File | Sort-Object Name | ForEach-Object {
    $hash = (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    "$hash  $($_.Name)"
} | Set-Content (Join-Path $release "SHA256SUMS.txt") -Encoding utf8
Get-ChildItem $release -File | Select-Object Name,Length | Format-Table

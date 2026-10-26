#define MyAppName "RD Soundtool"
#define MyAppVersion "1.2.0"
#define MyAppExeName "RD.Soundtool.exe"

[Setup]
AppId={{A74729BE-4C86-45B2-92E0-F29981D39F43}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher=Radio Diabolus
AppPublisherURL=https://radio-diabolus.dk/site/
AppSupportURL=https://radio-diabolus.dk/site/
DefaultDirName={autopf}\Radio Diabolus\RD Soundtool
DefaultGroupName=Radio Diabolus
UninstallDisplayIcon={app}\{#MyAppExeName}
OutputDir=output\Release
OutputBaseFilename=RD_Soundtool_Windows_x64_Setup
SetupIconFile=output\Portable\RadioDiabolus.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
ChangesAssociations=no
DisableProgramGroupPage=yes
CloseApplications=force
RestartApplications=no
LicenseFile=output\Portable\LICENSE.txt

[Languages]
Name: "german"; MessagesFile: "compiler:Languages\German.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Desktopverknüpfung erstellen"; GroupDescription: "Verknüpfungen:"; Flags: unchecked

[Files]
Source: "output\Portable\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\RD Soundtool"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\RD Soundtool"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "RD Soundtool starten"; Flags: nowait postinstall skipifsilent

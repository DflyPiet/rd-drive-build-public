; Radio Diabolus TeamShare, unsigned single-user installer.
; Compile with: ISCC.exe "/DSourceDir=C:\path\to\Mirall-package" "/DProjectRoot=C:\path\to\repo" installer\TeamShare.iss
#define Brand "Radio Diabolus TeamShare"
#define ReleaseVersion "2.1.0"
#ifndef SourceDir
  #error SourceDir must point at packaged Windows application folder
#endif
#ifndef ProjectRoot
  #error ProjectRoot must point at the build workspace root
#endif
[Setup]
AppId={{E3B7BFF0-76C9-4F47-921E-A9A0081964F8}
AppName={#Brand}
AppVersion={#ReleaseVersion}
AppPublisher=Radio Diabolus
AppPublisherURL=https://www.radio-diabolus.rocks
DefaultDirName={localappdata}\Programs\Radio Diabolus TeamShare
DefaultGroupName={#Brand}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
Compression=lzma2
SolidCompression=yes
OutputDir={#ProjectRoot}\release
OutputBaseFilename=Radio-Diabolus-TeamShare-2.1.0-Setup-x64
SetupIconFile={#ProjectRoot}\mirall-src\resources\win32\icon.ico
LicenseFile={#ProjectRoot}\mirall-src\LICENSE
WizardStyle=modern
CloseApplications=yes
RestartApplications=no
UninstallDisplayIcon={app}\Radio Diabolus TeamShare.exe
[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
[Icons]
Name: "{autoprograms}\Radio Diabolus TeamShare"; Filename: "{app}\Radio Diabolus TeamShare.exe"
Name: "{autodesktop}\Radio Diabolus TeamShare"; Filename: "{app}\Radio Diabolus TeamShare.exe"; Tasks: desktopicon
[Tasks]
Name: desktopicon; Description: "Verknüpfung auf dem Desktop erstellen"; GroupDescription: "Zusätzliche Optionen:"
[Run]
Filename: "{app}\Radio Diabolus TeamShare.exe"; Description: "Radio Diabolus TeamShare starten"; Flags: nowait postinstall skipifsilent

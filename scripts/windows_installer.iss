#define MyAppDir ".."

[Setup]
AppName=HushNet
AppVersion=1.0.0
DefaultDirName={autopf}\HushNet
DefaultGroupName=HushNet
OutputDir=build\windows\installer
OutputBaseFilename=HushNetInstaller
Compression=lzma
SolidCompression=yes
ArchitecturesAllowed=x64os
ArchitecturesInstallIn64BitMode=x64os
SetupIconFile={#MyAppDir}\assets\icons\app.ico

[Files]
Source: "{#MyAppDir}\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\HushNet"; Filename: "{app}\hushnet_frontend.exe"
Name: "{autodesktop}\HushNet"; Filename: "{app}\hushnet_frontend.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create desktop icon"; GroupDescription: "Icons:"

[Run]
Filename: "{app}\hushnet_frontend.exe"; Description: "Launch HushNet"; Flags: nowait postinstall skipifsilent

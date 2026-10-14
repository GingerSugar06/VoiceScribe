; Voice Scribe — Windows kurulum sihirbazı (Inno Setup 6)
; Derleme: tool\make_installer.ps1  (ISCC'yi kendisi çağırır)

#define MyAppName "Voice Scribe"
#define MyAppExe "voice_scribe.exe"
#define MyAppVersion "2.0.0"
#ifndef SourceDir
  #define SourceDir "..\build\windows\x64\runner\Release"
#endif

[Setup]
AppId={{AAE398E7-F1DE-59A8-AF82-9F36C1DB1415}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=Output
OutputBaseFilename=VoiceScribe-Setup-{#MyAppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExe}
WizardStyle=modern
Compression=lzma2/max
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; Yönetici izni gerekmez: kullanıcı profiline kurulur.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "turkish"; MessagesFile: "compiler:Languages\Turkish.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[CustomMessages]
turkish.DesktopIcon=Masaüstüne kısayol oluştur
english.DesktopIcon=Create a desktop shortcut
turkish.LaunchApp={#MyAppName} uygulamasını başlat
english.LaunchApp=Launch {#MyAppName}
turkish.SteamMissing=Bu bilgisayarda Steam bulunamadı.%n%n{#MyAppName}, Steam istemcisiyle birlikte çalışır. Steam'i kurup oturum açtıktan sonra uygulamayı kullanabilirsin.%n%nYine de kuruluma devam edilsin mi?
english.SteamMissing=Steam was not found on this computer.%n%n{#MyAppName} works together with the Steam client. Install Steam and sign in before using the app.%n%nContinue with the installation anyway?


[Tasks]
Name: "desktopicon"; Description: "{cm:DesktopIcon}"; Flags: unchecked


[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; Visual C++ çalışma zamanı DLL'leri uygulamayla birlikte (yönetici izni / ayrı kurulum gerektirmez)
Source: "redist\crt\*.dll"; DestDir: "{app}"; Flags: ignoreversion


[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExe}"; Tasks: desktopicon

[Run]

Filename: "{app}\{#MyAppExe}"; Description: "{cm:LaunchApp}"; Flags: nowait postinstall skipifsilent

[Code]
function SteamInstalled(): Boolean;
var
  p: String;
begin
  Result := False;
  if RegQueryStringValue(HKCU, 'Software\Valve\Steam', 'SteamPath', p) then
    Result := DirExists(p)
  else if RegQueryStringValue(HKLM, 'SOFTWARE\WOW6432Node\Valve\Steam', 'InstallPath', p) then
    Result := DirExists(p);
end;



function InitializeSetup(): Boolean;
begin
  Result := True;

end;

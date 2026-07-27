; AIBA POS — Windows o'rnatuvchi (Inno Setup).
; Per-user o'rnatiladi (LocalAppData) — UAC/admin so'ramaydi, kassir bir
; "Next-Next" bilan o'rnatadi. VC++ runtime DLL'lari CI'da Release papkaga
; qo'shib qo'yiladi, shuning uchun alohida redist kerak emas.

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif

[Setup]
AppId={{7A3B9E1C-AIBA-POS-TERMINAL}}
AppName=AIBA POS
AppVersion={#AppVersion}
AppPublisher=AIBA
DefaultDirName={localappdata}\AIBA POS
DisableDirPage=yes
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputBaseFilename=AIBA-POS-Setup
Compression=lzma2
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=yes
RestartApplications=no
UninstallDisplayIcon={app}\aiba_pos_terminal.exe

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

[Icons]
Name: "{userdesktop}\AIBA POS"; Filename: "{app}\aiba_pos_terminal.exe"
Name: "{userprograms}\AIBA POS"; Filename: "{app}\aiba_pos_terminal.exe"

[Tasks]
Name: "autostart"; Description: "Kompyuter yonganda AIBA POS avtomatik ochilsin"; GroupDescription: "Qo'shimcha:"

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; \
  ValueType: string; ValueName: "AIBA POS"; ValueData: """{app}\aiba_pos_terminal.exe"""; \
  Flags: uninsdeletevalue; Tasks: autostart

[Run]
Filename: "{app}\aiba_pos_terminal.exe"; Description: "AIBA POS ni ochish"; Flags: nowait postinstall skipifsilent

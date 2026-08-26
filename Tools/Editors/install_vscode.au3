#RequireAdmin
#AutoIt3Wrapper_UseX64=y
#NoTrayIcon
#include "..\..\_installer_common.au3"

; VS Code installer (Inno Setup), installed system-wide for all users.
; MERGETASKS="!runcode,..." keeps the "Launch VS Code" post-install step off.
; Argument and exit-code contract: _installer_common.au3.

_InitInstaller("vscode.exe", "VSCode")
_RequireSetup()

_Log("INFO: Checking if VS Code is already installed...")
If _IsVSCodeInstalled() Then
    _Log("INFO: VS Code is already installed. Creating shortcut and exiting with code 10.")
    _CreateShortcut()
    Exit 10
EndIf

Local $sInnoLog = _WorkDir() & "\install_vscode_inno.log"
Local $iExitCode = _RunSetupFlags('/VERYSILENT /NORESTART' & _
    ' /MERGETASKS="!runcode,addcontextmenufiles,addcontextmenufolders,associatewithfiles,addtopath"' & _
    ' /LOG="' & $sInnoLog & '"')
If @error Then Exit 21
_LogInnoFile($sInnoLog, "[VSCode]")

If $iExitCode <> 0 Then
    _Log("ERROR: Installer returned non-zero exit code: " & $iExitCode)
    Exit $iExitCode
EndIf

If _WaitForInstall("_IsVSCodeInstalled", 120) Then
    _Log("INFO: VS Code installation confirmed. Creating shortcut and exiting with code 0.")
    _CreateShortcut()
    Exit 0
EndIf
_Log("ERROR: VS Code installation validation timed out.")
Exit 22

Func _VSCodeExe()
    If FileExists(@ProgramFilesDir & "\Microsoft VS Code\Code.exe") Then Return @ProgramFilesDir & "\Microsoft VS Code\Code.exe"
    If FileExists(@LocalAppDataDir & "\Programs\Microsoft VS Code\Code.exe") Then Return @LocalAppDataDir & "\Programs\Microsoft VS Code\Code.exe"
    Return ""
EndFunc

Func _IsVSCodeInstalled()
    Return _VSCodeExe() <> ""
EndFunc

Func _CreateShortcut()
    If Not $g_bShortcut Then Return
    _CreatePublicShortcut(_VSCodeExe(), "Visual Studio Code")
EndFunc

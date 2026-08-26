#RequireAdmin
#AutoIt3Wrapper_UseX64=y
#NoTrayIcon
#include "..\..\_installer_common.au3"

; TeamViewer installer (/S for silent).
; Argument and exit-code contract: _installer_common.au3.

_InitInstaller("teamviewer.exe")
_RequireSetup()

_Log("INFO: Checking if app is already installed...")
If _IsTeamViewerInstalled() Then
    _Log("INFO: App is already installed. Exiting with code 10.")
    _CreateShortcut()
    Exit 10
EndIf

Local $iExitCode = _RunSetupFlags("/S")
If @error Then Exit 21
If $iExitCode <> 0 Then
    _Log("ERROR: Installer returned non-zero exit code: " & $iExitCode)
    Exit $iExitCode
EndIf

If _WaitForInstall("_IsTeamViewerInstalled", 120) Then
    _Log("INFO: Installation confirmed. Exiting with code 0.")
    _CreateShortcut()
    Exit 0
EndIf
_Log("ERROR: Installation validation timed out.")
Exit 22

Func _TeamViewerExe()
    Local $sDir = RegRead("HKLM64\SOFTWARE\TeamViewer", "InstallationDirectory")
    If @error Or $sDir = "" Then $sDir = RegRead("HKLM\SOFTWARE\TeamViewer", "InstallationDirectory")
    If @error Or $sDir = "" Then $sDir = @ProgramFilesDir & "\TeamViewer"
    Local $sExe = StringRegExpReplace($sDir, "\\+$", "") & "\TeamViewer.exe"
    If FileExists($sExe) Then Return $sExe
    Return ""
EndFunc

Func _IsTeamViewerInstalled()
    Return _TeamViewerExe() <> ""
EndFunc

Func _CreateShortcut()
    If Not $g_bShortcut Then Return
    _CreatePublicShortcut(_TeamViewerExe(), "TeamViewer")
EndFunc

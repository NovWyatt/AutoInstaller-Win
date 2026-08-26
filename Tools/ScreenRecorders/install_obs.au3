#RequireAdmin
#AutoIt3Wrapper_UseX64=y
#NoTrayIcon
#include "..\..\_installer_common.au3"

; OBS Studio installer (Inno Setup, /S for silent).
; Argument and exit-code contract: _installer_common.au3.

_InitInstaller("obs.exe")
_RequireSetup()

_Log("INFO: Checking if app is already installed...")
If _IsOBSInstalled() Then
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

If _WaitForInstall("_IsOBSInstalled", 120) Then
    _Log("INFO: Installation confirmed. Exiting with code 0.")
    _CreateShortcut()
    Exit 0
EndIf
_Log("ERROR: Installation validation timed out.")
Exit 22

Func _OBSExe()
    If FileExists(@ProgramFilesDir & "\obs-studio\bin\64bit\obs64.exe") Then _
        Return @ProgramFilesDir & "\obs-studio\bin\64bit\obs64.exe"
    Local $sRoot = RegRead("HKLM64\SOFTWARE\OBS Studio", "")
    If Not @error And FileExists($sRoot & "\bin\64bit\obs64.exe") Then Return $sRoot & "\bin\64bit\obs64.exe"
    Return ""
EndFunc

Func _IsOBSInstalled()
    Return _OBSExe() <> ""
EndFunc

Func _CreateShortcut()
    If Not $g_bShortcut Then Return
    _CreatePublicShortcut(_OBSExe(), "OBS Studio")
EndFunc

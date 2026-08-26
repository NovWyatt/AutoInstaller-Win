#RequireAdmin
#AutoIt3Wrapper_UseX64=y
#NoTrayIcon
#include "..\..\_installer_common.au3"

; 7-Zip installer (NSIS, /S for silent).
; Argument and exit-code contract: _installer_common.au3.

_InitInstaller("7z.exe")
_RequireSetup()

_Log("INFO: Checking if app is already installed...")
If _Is7ZipInstalled() Then
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

If _WaitForInstall("_Is7ZipInstalled", 60) Then
    _Log("INFO: Installation confirmed. Exiting with code 0.")
    _CreateShortcut()
    Exit 0
EndIf
_Log("ERROR: Installation validation timed out.")
Exit 22

; Install directory, without the trailing backslash the registry value carries.
Func _7ZipDir()
    Local $sDir = RegRead("HKLM64\SOFTWARE\7-Zip", "Path")
    If @error Or $sDir = "" Then $sDir = RegRead("HKLM\SOFTWARE\7-Zip", "Path")
    If @error Or $sDir = "" Then $sDir = @ProgramFilesDir & "\7-Zip"
    Return StringRegExpReplace($sDir, "\\+$", "")
EndFunc

Func _Is7ZipInstalled()
    Return FileExists(_7ZipDir() & "\7z.exe")
EndFunc

Func _CreateShortcut()
    If Not $g_bShortcut Then Return
    Local $sDir = _7ZipDir()
    ; 7zFM.exe is the File Manager, the only GUI entry point
    _CreatePublicShortcut($sDir & "\7zFM.exe", "7-Zip File Manager", $sDir)
EndFunc

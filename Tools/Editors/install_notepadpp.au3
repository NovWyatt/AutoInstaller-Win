#RequireAdmin
#AutoIt3Wrapper_UseX64=y
#NoTrayIcon
#include "..\..\_installer_common.au3"

; Notepad++ installer (NSIS, /S for silent).
;
; The registry entry can lag behind the installer, so a failed post-install check
; is not treated as a failure -- the setup's own exit code is trusted instead.
; Argument and exit-code contract: _installer_common.au3.

_InitInstaller("notepadpp.exe")
_RequireSetup()

_Log("INFO: Checking if app is already installed...")
If _IsNotepadPlusPlusInstalled() Then
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

If _WaitForInstall("_IsNotepadPlusPlusInstalled", 30) Then
    _Log("INFO: Installation confirmed. Exiting with code 0.")
EndIf
_CreateShortcut()
Exit 0

Func _NotepadPlusPlusExe()
    Local $sDir = RegRead("HKLM64\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Notepad++", "InstallLocation")
    If Not @error And $sDir <> "" Then
        Local $sExe = StringRegExpReplace($sDir, "\\+$", "") & "\notepad++.exe"
        If FileExists($sExe) Then Return $sExe
    EndIf
    If FileExists(@ProgramFilesDir & "\Notepad++\notepad++.exe") Then Return @ProgramFilesDir & "\Notepad++\notepad++.exe"
    If FileExists(@ProgramFilesDir & " (x86)\Notepad++\notepad++.exe") Then Return @ProgramFilesDir & " (x86)\Notepad++\notepad++.exe"
    Return ""
EndFunc

Func _IsNotepadPlusPlusInstalled()
    Return _NotepadPlusPlusExe() <> ""
EndFunc

Func _CreateShortcut()
    If Not $g_bShortcut Then Return
    _CreatePublicShortcut(_NotepadPlusPlusExe(), "Notepad++")
EndFunc

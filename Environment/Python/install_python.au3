#RequireAdmin
#AutoIt3Wrapper_UseX64=y
#NoTrayIcon
#include "..\..\_installer_common.au3"

; Python installer.
;
; The major.minor version (e.g. "3.14") is derived from the setup filename, so the
; right registry key and install folder are found at runtime. Bumping the version
; in install-apps.ini is therefore enough -- no recompile needed.
; Argument and exit-code contract: _installer_common.au3.

_InitInstaller("python.exe")

Global $g_sPyMajorMinor = "3"   ; fallback: major only
Global $g_sPyDirSuffix  = "3"   ; fallback: major only
Local $aVer = StringRegExp($g_sSetupFilename, "python-(\d+)\.(\d+)", 1)
If IsArray($aVer) And UBound($aVer) = 2 Then
    $g_sPyMajorMinor = $aVer[0] & "." & $aVer[1]   ; "3.14"
    $g_sPyDirSuffix  = $aVer[0] & $aVer[1]         ; "314"
EndIf

_RequireSetup()

_Log("INFO: Checking if app is already installed...")
If _IsPythonInstalled() Then
    _Log("INFO: App is already installed. Exiting with code 10.")
    _CreateShortcut()
    Exit 10
EndIf

Local $iExitCode = _RunSetupFlags("/quiet InstallAllUsers=1 PrependPath=1 Include_test=0 Include_launcher=1")
If @error Then Exit 21
If $iExitCode <> 0 Then
    _Log("ERROR: Installer returned non-zero exit code: " & $iExitCode)
    Exit $iExitCode
EndIf

If _WaitForInstall("_IsPythonInstalled", 900) Then
    _Log("INFO: Installation confirmed. Exiting with code 0.")
    _CreateShortcut()
    Exit 0
EndIf
_Log("ERROR: Installation validation timed out.")
Exit 22

Func _PythonDir()
    Local $sDir = RegRead("HKLM64\SOFTWARE\Python\PythonCore\" & $g_sPyMajorMinor & "\InstallPath", "")
    If @error Or $sDir = "" Then Return @ProgramFilesDir & "\Python" & $g_sPyDirSuffix
    Return StringRegExpReplace($sDir, "\\+$", "")
EndFunc

Func _IsPythonInstalled()
    Return FileExists(_PythonDir() & "\python.exe")
EndFunc

; IDLE needs an argument ("-m idlelib"), which _CreatePublicShortcut does not take,
; so this one builds its link directly.
Func _CreateShortcut()
    If Not $g_bShortcut Then Return

    Local $sDir    = _PythonDir()
    Local $sTarget = $sDir & "\pythonw.exe"
    If Not FileExists($sTarget) Then Return

    Local $sName = "IDLE (Python " & $g_sPyMajorMinor & ")"
    Local $sLink = _PublicDesktopDir() & "\" & $sName & ".lnk"
    If FileExists($sLink) Then Return

    FileCreateShortcut($sTarget, $sLink, $sDir, "-m idlelib", $sName, $sTarget, "", 0, @SW_SHOW)
    _Log("INFO: Desktop shortcut created: " & $sLink)
EndFunc

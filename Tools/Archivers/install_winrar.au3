#RequireAdmin
#AutoIt3Wrapper_UseX64=y
#NoTrayIcon
#include "..\..\_installer_common.au3"

; WinRAR installer (/S for silent).
;
; Post-install: copies rarreg.key from this folder into the WinRAR install
; directory to apply the bundled licence, when that file is present.
; Argument and exit-code contract: _installer_common.au3.

Global Const $g_sLicKeyPath = @ScriptDir & "\rarreg.key"

_InitInstaller("winrar.exe")
_RequireSetup()

_Log("INFO: Checking if app is already installed...")
If _IsWinRARInstalled() Then
    _Log("INFO: App is already installed. Exiting with code 10.")
    _CopyLicense()
    _CreateShortcut()
    Exit 10
EndIf

Local $iExitCode = _RunSetupFlags("/S")
If @error Then Exit 21
If $iExitCode <> 0 Then
    _Log("ERROR: Installer returned non-zero exit code: " & $iExitCode)
    Exit $iExitCode
EndIf

If _WaitForInstall("_IsWinRARInstalled", 60) Then
    _Log("INFO: Installation confirmed. Exiting with code 0.")
    _CopyLicense()
    _CreateShortcut()
    Exit 0
EndIf
_Log("ERROR: Installation validation timed out.")
Exit 22

; Full path to WinRAR.exe, or "" when WinRAR is not installed.
Func _WinRARExe()
    Local $sPath = RegRead("HKLM64\SOFTWARE\WinRAR", "exe64")
    If Not @error And FileExists($sPath) Then Return $sPath
    Local $sPath32 = RegRead("HKLM\SOFTWARE\WinRAR", "exe32")
    If Not @error And FileExists($sPath32) Then Return $sPath32
    Local $sFallback = @ProgramFilesDir & "\WinRAR\WinRAR.exe"
    If FileExists($sFallback) Then Return $sFallback
    Return ""
EndFunc

Func _IsWinRARInstalled()
    Return _WinRARExe() <> ""
EndFunc

Func _CopyLicense()
    If Not FileExists($g_sLicKeyPath) Then Return
    Local $sExe = _WinRARExe()
    If $sExe = "" Then Return

    Local $sDest = _ParentDir($sExe) & "\rarreg.key"
    If FileExists($sDest) Then Return
    If FileCopy($g_sLicKeyPath, $sDest, 0) Then
        _Log("INFO: Applied bundled rarreg.key licence.")
    Else
        _Log("WARN: Could not copy rarreg.key to " & $sDest)
    EndIf
EndFunc

Func _CreateShortcut()
    If Not $g_bShortcut Then Return
    _CreatePublicShortcut(_WinRARExe(), "WinRAR")
EndFunc

#RequireAdmin
#AutoIt3Wrapper_UseX64=y
#NoTrayIcon
#include "..\..\_installer_common.au3"

; Font installer. Unlike the other mini-installers there is no vendor setup to
; run: install_fonts.ps1 batch-installs every .ttf / .otf / .ttc sitting in this
; folder for all users (copying into the Fonts folder and registering them),
; which is why install-apps.ini points its setup_file at the directory itself.
;
; $CmdLine[2] (desktop shortcut) is ignored -- there is nothing to launch.
; $CmdLine[3] (clean_after_installing) is forwarded as -CleanBroken.
; Argument and exit-code contract: _installer_common.au3.

Global Const $g_sPsScript = @ScriptDir & "\install_fonts.ps1"

_InitInstaller("Fonts", "Fonts")

_Log("INFO: Starting batch font installation from: " & @ScriptDir)
_Log("INFO: clean_after_installing=" & String($g_bClean))

If Not FileExists($g_sPsScript) Then
    _Log("ERROR: Helper script not found: " & $g_sPsScript)
    Exit 20
EndIf

Local $sResultFile = @TempDir & "\autoinst_fonts_result.txt"
FileDelete($sResultFile)

_Log("INFO: Launching PowerShell font installer...")
Local $sPsArgs = '-NonInteractive -NoProfile -ExecutionPolicy Bypass' & _
    ' -File "' & $g_sPsScript & '"' & _
    ' -FontDir "' & @ScriptDir & '"' & _
    ' -ResultFile "' & $sResultFile & '"' & _
    ' -LogFile "' & $g_sLogPath & '"' & _
    ' -CleanBroken ' & ($g_bClean ? "true" : "false")

Local $iPsExit = RunWait('powershell.exe ' & $sPsArgs, @SystemDir, @SW_HIDE)
Local $iLaunchError = @error
If $iLaunchError Then
    _Log("ERROR: Failed to launch PowerShell. AutoIt error=" & $iLaunchError)
    Exit 21
EndIf
If $iPsExit <> 0 Then
    _Log("ERROR: PowerShell exited with code: " & $iPsExit)
    Exit $iPsExit
EndIf

; Summary written by the PS1 helper. IsArray() is checked per match rather than
; @error, which would only ever reflect the last StringRegExp call.
Local $sResult    = FileRead($sResultFile)
Local $aInstalled = StringRegExp($sResult, "installed=(\d+)", 1)
Local $aSkipped   = StringRegExp($sResult, "skipped=(\d+)", 1)
Local $aFailed    = StringRegExp($sResult, "failed=(\d+)", 1)

Local $sInstalled = IsArray($aInstalled) ? $aInstalled[0] : "?"
Local $sSkipped   = IsArray($aSkipped)   ? $aSkipped[0]   : "?"
Local $sFailed    = IsArray($aFailed)    ? $aFailed[0]    : "?"

_Log("INFO: Done. installed=" & $sInstalled & " skipped=" & $sSkipped & " failed=" & $sFailed)
Exit 0

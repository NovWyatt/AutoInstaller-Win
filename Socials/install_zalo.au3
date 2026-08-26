#RequireAdmin
#AutoIt3Wrapper_UseX64=y
#NoTrayIcon
#include "..\_installer_common.au3"

; Zalo installer. Zalo uses NSIS and installs per-user into %LocalAppData%\Zalo.
; Argument and exit-code contract: _installer_common.au3.

_InitInstaller("zalo.exe")
_RequireSetup()

_Log("INFO: Checking if app is already installed...")
If _IsZaloInstalled() Then
    _Log("INFO: App is already installed. Exiting with code 10.")
    _CreateShortcut()
    Exit 10
EndIf

; Dismiss the reinstall/keep-data prompt if the setup raises one.
AdlibRegister("_HandleZaloPopup", 500)

Local $iExitCode = _RunSetupFlags("/S")
If @error Then
    AdlibUnRegister("_HandleZaloPopup")
    Exit 21
EndIf

Sleep(3000)   ; NSIS stubs can return before the inner installer finishes
AdlibUnRegister("_HandleZaloPopup")

If _WaitForInstall("_IsZaloInstalled", 120, 2000) Then
    _Log("INFO: Installation confirmed. Exiting with code 0.")
    _CreateShortcut()
    Exit 0
EndIf
_Log("ERROR: Installation validation timed out.")
Exit 22

; Install path of Zalo, or "" when it is not installed.
Func _ZaloExe()
    If FileExists(@LocalAppDataDir & "\Zalo\Zalo.exe") Then Return @LocalAppDataDir & "\Zalo\Zalo.exe"
    If FileExists(@LocalAppDataDir & "\Programs\Zalo\Zalo.exe") Then Return @LocalAppDataDir & "\Programs\Zalo\Zalo.exe"
    Return ""
EndFunc

Func _IsZaloInstalled()
    Return _ZaloExe() <> ""
EndFunc

Func _CreateShortcut()
    ; Drop whatever Zalo's own installer placed, so a stale link never shadows
    ; the one below. This runs regardless of the flag.
    _DeleteUserShortcut("Zalo")
    Local $sPublicLink = _PublicDesktopDir() & "\Zalo.lnk"
    If FileExists($sPublicLink) Then FileDelete($sPublicLink)

    If Not $g_bShortcut Then Return
    Local $sTarget = _ZaloExe()
    If $sTarget = "" Then Return

    _Log("INFO: Creating Zalo shortcut on Public Desktop.")
    FileCreateShortcut($sTarget, $sPublicLink, _ParentDir($sTarget), "", "Zalo", $sTarget, "", 0, @SW_SHOW)
EndFunc

; The confirmation dialog is labelled "Yes" in English and "Co" (with diacritics)
; in Vietnamese; try both. The Vietnamese label used to be stored mis-encoded in
; this file, so it could never match.
Func _HandleZaloPopup()
    If Not WinExists("Zalo", "") Then Return
    ControlClick("Zalo", "", "&Yes")
    ControlClick("Zalo", "", ChrW(0x0043) & ChrW(0x00F3))
EndFunc

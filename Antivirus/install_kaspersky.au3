#RequireAdmin
#AutoIt3Wrapper_UseX64=y
#NoTrayIcon
#include "..\_installer_common.au3"

; Kaspersky antivirus installer. EULA=1 PRIVACYPOLICY=1 /s /pSKIPPRODUCTCHECK=1
; installs without any UI. Argument and exit-code contract: _installer_common.au3.

Global Const $g_sKasperskyEnv = "HKLM64\SOFTWARE\KasperskyLab\avp22\Environment"

_InitInstaller("kaspersky.exe")
_RequireSetup()

_Log("INFO: Checking if app is already installed...")
If _IsKasperskyInstalled() Then
    _Log("INFO: App is already installed. Exiting with code 10.")
    _CreateShortcut()
    Exit 10
EndIf

Local $iExitCode = _RunSetupFlags("EULA=1 PRIVACYPOLICY=1 /s /pSKIPPRODUCTCHECK=1")
If @error Then Exit 21

; Kaspersky can return 0 while the real install still runs in the background.
Sleep(10000)

If _WaitForInstall("_IsKasperskyInstalled", 300, 5000) Then
    _Log("INFO: Installation confirmed. Exiting with code 0.")
    _CreateShortcut()
    Exit 0
EndIf
_Log("ERROR: Installation validation timed out.")
Exit 22

Func _IsKasperskyInstalled()
    Local $sPath = RegRead($g_sKasperskyEnv, "ProductInstallDir")
    If Not @error And FileExists($sPath & "\avpui.exe") Then Return True
    ; Broader fallback: the product's own uninstall entry
    Local $sDisplay = RegRead("HKLM64\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{8ECDE29A-8617-4E32-AAA0-4DA7D4C5006E}", "DisplayName")
    Return Not @error And StringInStr($sDisplay, "Kaspersky") > 0
EndFunc

Func _CreateShortcut()
    If Not $g_bShortcut Then Return
    Local $sPath = RegRead($g_sKasperskyEnv, "ProductInstallDir")
    If @error Or $sPath = "" Then Return
    _CreatePublicShortcut($sPath & "\avpui.exe", "Kaspersky")
EndFunc

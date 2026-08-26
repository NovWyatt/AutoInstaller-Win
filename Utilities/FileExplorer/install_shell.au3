#RequireAdmin
#AutoIt3Wrapper_UseX64=y
#NoTrayIcon
#include "..\..\_installer_common.au3"

; Nilesoft Shell installer (MSI).
;
; Shell is a shell extension with no standalone executable, so no Desktop
; shortcut is created regardless of the shortcut flag.
; Argument and exit-code contract: _installer_common.au3.

Global Const $g_sProductCode = "{3025C475-D665-4288-99A8-3382654F7E11}"

_InitInstaller("shell.msi")
_RequireSetup()

_Log("INFO: Checking if app is already installed...")
If _IsNilesoftShellInstalled() Then
    _Log("INFO: App is already installed. Exiting with code 10.")
    Exit 10
EndIf

Local $iExitCode = _RunMsi($g_sSetupPath)
If @error Then Exit 21

; msiexec returns 3010 for "success, reboot required" -- treat as success
If $iExitCode <> 0 And $iExitCode <> 3010 Then
    _Log("ERROR: Installer returned non-zero exit code: " & $iExitCode)
    Exit $iExitCode
EndIf

If _WaitForInstall("_IsNilesoftShellInstalled", 900) Then
    _Log("INFO: Installation confirmed. Exiting with code 0.")
    Exit 0
EndIf
_Log("ERROR: Installation validation timed out.")
Exit 22

Func _IsNilesoftShellInstalled()
    Local $sName = RegRead("HKLM64\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\" & $g_sProductCode, "DisplayName")
    If Not @error And $sName = "Nilesoft Shell" Then Return True
    Local $sName32 = RegRead("HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\" & $g_sProductCode, "DisplayName")
    Return Not @error And $sName32 = "Nilesoft Shell"
EndFunc

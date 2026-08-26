#RequireAdmin
#AutoIt3Wrapper_UseX64=y
#NoTrayIcon
#include "..\..\_installer_common.au3"

; LibreOffice MSI installer.
; CREATEDESKTOPLINK=0 suppresses the vendor shortcut; UI_LANGS keeps the UI English.
; Argument and exit-code contract: _installer_common.au3.

_InitInstaller("libreoffice.msi")
_RequireSetup()

_Log("INFO: Checking if app is already installed...")
If _IsLibreOfficeInstalled() Then
    _Log("INFO: App is already installed. Exiting with code 10.")
    _CreateShortcut()
    Exit 10
EndIf

Local $iExitCode = _RunMsi($g_sSetupPath, "CREATEDESKTOPLINK=0 UI_LANGS=en_US")
If @error Then Exit 21

; msiexec returns 3010 for "success, reboot required" -- treat as success
If $iExitCode <> 0 And $iExitCode <> 3010 Then
    _Log("ERROR: Installer returned non-zero exit code: " & $iExitCode)
    Exit $iExitCode
EndIf

If _WaitForInstall("_IsLibreOfficeInstalled", 180, 2000) Then
    _Log("INFO: Installation confirmed. Exiting with code 0.")
    _CreateShortcut()
    Exit 0
EndIf
_Log("ERROR: Installation validation timed out.")
Exit 22

Func _IsLibreOfficeInstalled()
    If FileExists(@ProgramFilesDir & "\LibreOffice\program\soffice.exe") Then Return True
    Local $sPath = RegRead("HKLM64\SOFTWARE\LibreOffice\UNO\InstallPath", "")
    Return Not @error And FileExists($sPath & "\soffice.exe")
EndFunc

Func _CreateShortcut()
    If Not $g_bShortcut Then Return
    _CreatePublicShortcut(@ProgramFilesDir & "\LibreOffice\program\soffice.exe", "LibreOffice")
EndFunc

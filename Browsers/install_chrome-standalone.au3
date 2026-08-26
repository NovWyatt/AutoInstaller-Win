#RequireAdmin
#AutoIt3Wrapper_UseX64=y
#NoTrayIcon
#include "..\_installer_common.au3"

; Chrome installer, handling both the standalone EXE and the Enterprise MSI.
; Argument and exit-code contract: _installer_common.au3.

_InitInstaller(_DetectChromeSetup())
_RequireSetup()

_Log("INFO: Checking if app is already installed...")
If _IsChromeInstalled() Then
    _Log("INFO: App is already installed. Exiting with code 10.")
    _CreateShortcut()
    Exit 10
EndIf

Local $bIsMsi = _SetupHasExt(".msi")
Local $iExitCode
If $bIsMsi Then
    $iExitCode = _RunMsi($g_sSetupPath)
Else
    $iExitCode = _RunSetupFlags("/silent /install")
EndIf
If @error Then Exit 21

; msiexec returns 3010 for "success, reboot required" -- treat that as success
If $iExitCode <> 0 And Not ($bIsMsi And $iExitCode = 3010) Then
    _Log("ERROR: Installer returned non-zero exit code: " & $iExitCode)
    Exit $iExitCode
EndIf

If _WaitForInstall("_IsChromeInstalled", 900) Then
    _Log("INFO: Installation confirmed. Exiting with code 0.")
    _CreateShortcut()
    Exit 0
EndIf
_Log("ERROR: Installation validation timed out.")
Exit 22

; Picks whichever setup file is actually present when no name was passed in.
Func _DetectChromeSetup()
    Local $aCandidates = ["chrome-standalone.msi", "chrome.msi", "chrome-standalone.exe", "chrome.exe"]
    For $sName In $aCandidates
        If FileExists(@ScriptDir & "\" & $sName) Then Return $sName
    Next
    Return "chrome-standalone.exe"
EndFunc

Func _IsChromeInstalled()
    Local $sPath = RegRead("HKLM64\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe", "")
    If Not @error And FileExists($sPath) Then Return True
    Return FileExists(@ProgramFilesDir & "\Google\Chrome\Application\chrome.exe")
EndFunc

Func _CreateShortcut()
    If Not $g_bShortcut Then Return

    ; Chrome's installer drops its own shortcut on the current user's Desktop;
    ; remove it so it does not sit beside the all-users one in the merged view.
    _DeleteUserShortcut("Google Chrome")

    Local $sTarget = RegRead("HKLM64\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe", "")
    If @error Or Not FileExists($sTarget) Then $sTarget = @ProgramFilesDir & "\Google\Chrome\Application\chrome.exe"
    _CreatePublicShortcut($sTarget, "Google Chrome")
EndFunc

#RequireAdmin
#AutoIt3Wrapper_UseX64=y
#NoTrayIcon
#include "..\..\_installer_common.au3"

; Office 2024 ProPlus, driven by the Office Deployment Tool:
;   office2024.exe /configure full_en.xml
;
; Shortcuts are created for every Office app whose EXE is present under Office16
; after the install. That honours the ExcludeApp entries in full_en.xml without
; parsing any XML: an excluded app simply has no EXE on disk.
; Argument and exit-code contract: _installer_common.au3.

Global Const $g_sC2RKey = "HKLM64\SOFTWARE\Microsoft\Office\ClickToRun\Configuration"
Global Const $g_sConfigPath = @ScriptDir & "\full_en.xml"

_InitInstaller("office2024.exe")
_RequireSetup()

If Not FileExists($g_sConfigPath) Then
    _Log("ERROR: ODT configuration file not found: " & $g_sConfigPath)
    Exit 20
EndIf

_Log("INFO: Checking if app is already installed...")
If _IsOffice2024Installed() Then
    _Log("INFO: App is already installed. Exiting with code 10.")
    _CreateShortcuts()
    Exit 10
EndIf

Local $iExitCode = _RunSetupFlags('/configure "' & $g_sConfigPath & '"')
If @error Then Exit 21
If $iExitCode <> 0 Then
    _Log("ERROR: Installer returned non-zero exit code: " & $iExitCode)
    Exit $iExitCode
EndIf

; The ODT can take a while to write its registry keys after the process exits.
; Poll for a minute, then trust the exit code.
If _WaitForInstall("_IsOffice2024Installed", 60, 2000) Then
    _Log("INFO: Installation confirmed. Exiting with code 0.")
EndIf
_CreateShortcuts()
Exit 0

Func _IsOffice2024Installed()
    Local $sIds = RegRead($g_sC2RKey, "ProductReleaseIds")
    If Not @error And StringInStr($sIds, "ProPlus2024Volume") Then Return True
    Local $sRoot = RegRead($g_sC2RKey, "InstallationPath")
    If Not @error And $sRoot <> "" And FileExists($sRoot & "\root\Office16\WINWORD.EXE") Then Return True
    Return False
EndFunc

; One shortcut per Office app that actually landed on disk.
Func _CreateShortcuts()
    If Not $g_bShortcut Then Return

    Local $sOfficePath = RegRead($g_sC2RKey, "InstallationPath")
    If @error Or $sOfficePath = "" Then Return
    Local $sOffice16 = $sOfficePath & "\root\Office16"

    Local $aApps[7][2] = [ _
        ["WINWORD.EXE",  "Microsoft Word"], _
        ["EXCEL.EXE",    "Microsoft Excel"], _
        ["POWERPNT.EXE", "Microsoft PowerPoint"], _
        ["OUTLOOK.EXE",  "Microsoft Outlook"], _
        ["ONENOTE.EXE",  "Microsoft OneNote"], _
        ["MSACCESS.EXE", "Microsoft Access"], _
        ["MSPUB.EXE",    "Microsoft Publisher"]]

    For $i = 0 To UBound($aApps) - 1
        Local $sExe = $sOffice16 & "\" & $aApps[$i][0]
        ; Apps excluded in the ODT config have no EXE. That is expected here, so
        ; skip them quietly rather than logging a warning for each one.
        If Not FileExists($sExe) Then ContinueLoop
        _CreatePublicShortcut($sExe, $aApps[$i][1], $sOffice16)
    Next
EndFunc

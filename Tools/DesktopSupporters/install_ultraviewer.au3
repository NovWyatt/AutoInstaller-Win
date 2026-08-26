#RequireAdmin
#AutoIt3Wrapper_UseX64=y
#NoTrayIcon
#include "..\..\_installer_common.au3"

; UltraViewer remote desktop installer (Inno Setup).
; Argument and exit-code contract: _installer_common.au3.

Global Const $g_sUvUninstall64 = "HKLM64\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\UltraViewer_is1"
Global Const $g_sUvUninstall32 = "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\UltraViewer_is1"

_InitInstaller("ultraviewer.exe")
_RequireSetup()

_Log("INFO: Checking if app is already installed...")
If _IsUltraViewerInstalled() Then
    _Log("INFO: App is already installed. Exiting with code 10.")
    _CreateShortcut()
    Exit 10
EndIf

Local $sInnoLog = _WorkDir() & "\install_ultraviewer_inno.log"
Local $iExitCode = _RunSetupFlags('/VERYSILENT /NORESTART /SUPPRESSMSGBOXES /LOG="' & $sInnoLog & '"')
If @error Then Exit 21
_LogInnoFile($sInnoLog, "[UltraViewer]")

If $iExitCode <> 0 Then
    _Log("ERROR: Installer returned non-zero exit code: " & $iExitCode)
    Exit $iExitCode
EndIf

If _WaitForInstall("_IsUltraViewerInstalled", 60) Then
    _Log("INFO: Installation confirmed. Exiting with code 0.")
    _CreateShortcut()
    Exit 0
EndIf
_Log("ERROR: Installation validation timed out.")
Exit 22

Func _UltraViewerExe()
    Local $sDir = RegRead($g_sUvUninstall64, "InstallLocation")
    If @error Or $sDir = "" Then $sDir = RegRead($g_sUvUninstall32, "InstallLocation")
    If Not @error And $sDir <> "" Then
        Local $sExe = StringRegExpReplace($sDir, "\\+$", "") & "\UltraViewer_Desktop.exe"
        If FileExists($sExe) Then Return $sExe
    EndIf
    If FileExists(@ProgramFilesDir & " (x86)\UltraViewer\UltraViewer_Desktop.exe") Then _
        Return @ProgramFilesDir & " (x86)\UltraViewer\UltraViewer_Desktop.exe"
    If FileExists(@ProgramFilesDir & "\UltraViewer\UltraViewer_Desktop.exe") Then _
        Return @ProgramFilesDir & "\UltraViewer\UltraViewer_Desktop.exe"
    Return ""
EndFunc

Func _IsUltraViewerInstalled()
    Return _UltraViewerExe() <> ""
EndFunc

Func _CreateShortcut()
    If Not $g_bShortcut Then Return
    _CreatePublicShortcut(_UltraViewerExe(), "UltraViewer")
EndFunc

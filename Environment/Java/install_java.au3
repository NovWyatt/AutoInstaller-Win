#RequireAdmin
#AutoIt3Wrapper_UseX64=y
#NoTrayIcon
#include "..\..\_installer_common.au3"

; Java 8 installer.
;
; Detection looks for a JavaSoft runtime whose CurrentVersion starts with "1.8".
; NOTE: Java 11+ uses a different registry layout, so _JavaHome would need
; updating before this could install a newer major version.
; Argument and exit-code contract: _installer_common.au3.

Global Const $g_sJreKey = "HKLM64\SOFTWARE\JavaSoft\Java Runtime Environment"

_InitInstaller("java.exe")
_RequireSetup()

_Log("INFO: Checking if app is already installed...")
If _IsJavaInstalled() Then
    _Log("INFO: App is already installed. Exiting with code 10.")
    _CreateShortcut()
    Exit 10
EndIf

Local $iExitCode = _RunSetupFlags("/s")
If @error Then Exit 21
If $iExitCode <> 0 Then
    _Log("ERROR: Installer returned non-zero exit code: " & $iExitCode)
    Exit $iExitCode
EndIf

If _WaitForInstall("_IsJavaInstalled", 900) Then
    _Log("INFO: Installation confirmed. Exiting with code 0.")
    _CreateShortcut()
    Exit 0
EndIf
_Log("ERROR: Installation validation timed out.")
Exit 22

; Install root of the Java 8 runtime, or "" when no Java 8 is registered.
Func _JavaHome()
    Local $sVersion = RegRead($g_sJreKey, "CurrentVersion")
    If @error Or StringLeft($sVersion, 3) <> "1.8" Then Return ""
    Local $sHome = RegRead($g_sJreKey & "\" & $sVersion, "JavaHome")
    If @error Then Return ""
    Return $sHome
EndFunc

Func _IsJavaInstalled()
    Local $sHome = _JavaHome()
    Return $sHome <> "" And FileExists($sHome & "\bin\java.exe")
EndFunc

Func _CreateShortcut()
    If Not $g_bShortcut Then Return
    Local $sHome = _JavaHome()
    If $sHome = "" Then Return
    _CreatePublicShortcut($sHome & "\bin\javaws.exe", "Java Web Start")
EndFunc

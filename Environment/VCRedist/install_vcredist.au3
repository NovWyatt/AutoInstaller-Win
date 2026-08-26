#RequireAdmin
#AutoIt3Wrapper_UseX64=y
#NoTrayIcon
#include "..\..\_installer_common.au3"

; Visual C++ Redistributable AIO installer (2005-2026, x86 + x64).
; There is no launchable EXE, so the desktop-shortcut flag is ignored.
;
; Detection: vcruntime140.dll must be present for both architectures; that DLL
; covers every runtime from 2015 to 2026.
; Argument and exit-code contract: _installer_common.au3.

_InitInstaller("vcredist-AIO.exe", "VCRedist")
_RequireSetup()

_Log("INFO: Checking if VCRedist is already installed...")
If _IsVCRedistInstalled() Then
    _Log("INFO: VCRedist is already installed. Exiting with code 10.")
    Exit 10
EndIf

; The AIO installer supports /y for a silent install
Local $iExitCode = _RunSetupFlags("/y")
If @error Then Exit 21

; Some AIO builds exit 3010 (success, reboot needed) -- treat as success
If $iExitCode <> 0 And $iExitCode <> 3010 Then
    _Log("ERROR: Installer returned non-zero exit code: " & $iExitCode)
    Exit $iExitCode
EndIf

If _WaitForInstall("_IsVCRedistInstalled", 120, 2000) Then
    _Log("INFO: VCRedist installation confirmed. Exiting with code 0.")
    Exit 0
EndIf
_Log("ERROR: VCRedist installation validation timed out.")
Exit 22

Func _IsVCRedistInstalled()
    Local $bX64 = FileExists(@SystemDir & "\vcruntime140.dll")
    Local $bX86 = FileExists(@WindowsDir & "\SysWOW64\vcruntime140.dll")
    Return $bX64 And $bX86
EndFunc

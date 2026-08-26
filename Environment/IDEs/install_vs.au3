#RequireAdmin
#AutoIt3Wrapper_UseX64=y
#NoTrayIcon
#include "..\..\_installer_common.au3"

; Visual Studio installer -- not implemented yet, and disabled in install-apps.ini.
;
; Exits 10 ("already installed, nothing to do") rather than 0, because 0 means
; "installed and verified" and would put a green Installed row in the report for
; an application that was never touched. Enabling this target in the INI is
; therefore honest about doing nothing until the installer is written.
; Argument and exit-code contract: _installer_common.au3.

_InitInstaller("vs.exe")

_Log("WARN: Visual Studio installer is not implemented; nothing was installed.")
Exit 10

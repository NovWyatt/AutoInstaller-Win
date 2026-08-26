#RequireAdmin
#AutoIt3Wrapper_UseX64=y
#NoTrayIcon
#include "..\_installer_common.au3"

; Discord installer.
;
; Discord's setup is a stub that self-extracts and installs per-user into
; %LocalAppData%\Discord. It has no true silent mode but accepts the NSIS-style
; /S to suppress most of the UI, then hands off to its Squirrel updater.
; Argument and exit-code contract: _installer_common.au3.

Global Const $g_sDiscordDir = @LocalAppDataDir & "\Discord"

_InitInstaller("discord.exe", "Discord")
_RequireSetup()

_Log("INFO: Checking if Discord is already installed...")
If _IsDiscordInstalled() Then
    _Log("INFO: Discord is already installed. Creating shortcut and exiting with code 10.")
    _CreateShortcut()
    Exit 10
EndIf

; Discord installs into %LOCALAPPDATA%, so it runs as the current user (no /RunAs)
Local $iExitCode = _RunSetupFlags("/S")
If @error Then Exit 21

_Log("INFO: Waiting for Squirrel updater (Update.exe) to finish...")
ProcessWait("Update.exe", 30)

; Let it exit on its own so it finishes dropping its shortcuts.
Local $hTimer = TimerInit()
While ProcessExists("Update.exe") And TimerDiff($hTimer) < 120000
    Sleep(1000)
WEnd

_Log("INFO: Terminating any launched Discord processes...")
Local $aProcs = ["Discord.exe", "DiscordSystemHelper.exe", "Update.exe"]
For $i = 1 To 10
    Local $bAnyAlive = False
    For $sProc In $aProcs
        If ProcessExists($sProc) Then
            ProcessClose($sProc)
            $bAnyAlive = True
            _Log("INFO: Terminated " & $sProc)
        EndIf
    Next
    If Not $bAnyAlive Then ExitLoop
    Sleep(500)
Next

_Log("INFO: Validating installation...")
If _IsDiscordInstalled() Then
    _Log("INFO: Discord installation confirmed. Creating shortcut and exiting with code 0.")
    _CreateShortcut()
    Exit 0
EndIf
_Log("ERROR: Discord installation validation failed.")
Exit 22

Func _IsDiscordInstalled()
    ; Discord uses Squirrel; Update.exe in the root is the real entry point
    Return FileExists($g_sDiscordDir & "\Update.exe")
EndFunc

Func _CreateShortcut()
    ; Drop whatever Discord's own installer scattered around first, so a stale
    ; link never shadows the one below. This runs regardless of the flag.
    _DeleteUserShortcut("Discord")
    Local $sPublicLink = _PublicDesktopDir() & "\Discord.lnk"
    If FileExists($sPublicLink) Then FileDelete($sPublicLink)

    If Not $g_bShortcut Then Return
    Local $sTarget = $g_sDiscordDir & "\Update.exe"
    If Not FileExists($sTarget) Then Return

    _Log("INFO: Creating Discord shortcut on Public Desktop.")
    FileCreateShortcut($sTarget, $sPublicLink, $g_sDiscordDir, "--processStart Discord.exe", _
        "Discord", $g_sDiscordDir & "\app.ico", "", 0, @SW_SHOW)
EndFunc

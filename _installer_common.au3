#include-once
#include <AutoItConstants.au3>

; ══════════════════════════════════════════════════════════════════════════════
;  Shared scaffold for the AutoInstaller mini-installers.
;
;  Every install_*.au3 used to carry its own copy of the argument parsing, the
;  logger, the polling loop and the shortcut helper -- roughly forty identical
;  lines per file. Bugs therefore had to be fixed twenty times, and in practice
;  were not: the launch-failure branch was dead in fifteen of them.
;
;  Files with a leading underscore are include-only libraries and are skipped by
;  compile-au2exe.ps1; there is no entry point here.
;
;  ── Argument contract (install-apps.exe passes all four, in this order) ──
;    $CmdLine[1]  setup file name, e.g. "chrome-standalone.exe"
;    $CmdLine[2]  desktop shortcut flag, "true" / "false"
;    $CmdLine[3]  clean_after_installing flag, "true" / "false"
;    $CmdLine[4]  log file path
;    $CmdLine[5]  optional per-target argument from the INI's `option` block,
;                 empty when the target has no entry
;
;  ── Exit code contract (read by install-apps.exe) ──
;     0  installed and verified          10  already installed, nothing to do
;    20  setup file missing              21  setup process could not be started
;    22  installed but could not be verified
; ══════════════════════════════════════════════════════════════════════════════

Global $g_sSetupFilename = ""
Global $g_sSetupPath     = ""
Global $g_bShortcut      = False
Global $g_bClean         = False
Global $g_sLogPath       = "C:\Auto-installer\install-apps.log"
Global $g_sLogTag        = ""
Global $g_sOption        = ""

; ──────────────────────────────────────────────────────────────────────────────
;  Startup
; ──────────────────────────────────────────────────────────────────────────────

; Reads the four standard arguments, falling back to $sDefaultSetupName when the
; installer is run by hand with no arguments. $sLogTag labels this installer's
; lines in the shared log; it defaults to the setup name without its extension.
Func _InitInstaller($sDefaultSetupName, $sLogTag = "")
    $g_sSetupFilename = $sDefaultSetupName
    If $CmdLine[0] >= 1 And $CmdLine[1] <> "" Then $g_sSetupFilename = $CmdLine[1]
    $g_sSetupPath = @ScriptDir & "\" & $g_sSetupFilename

    If $CmdLine[0] >= 2 And StringLower($CmdLine[2]) = "true" Then $g_bShortcut = True
    If $CmdLine[0] >= 3 And StringLower($CmdLine[3]) = "true" Then $g_bClean = True
    If $CmdLine[0] >= 4 And $CmdLine[4] <> "" Then $g_sLogPath = $CmdLine[4]
    If $CmdLine[0] >= 5 Then $g_sOption = $CmdLine[5]

    $g_sLogTag = $sLogTag
    If $g_sLogTag = "" Then $g_sLogTag = StringRegExpReplace($g_sSetupFilename, "\.[^.\\/]+$", "")
EndFunc

; Aborts with exit code 20 when the setup file is absent. FileExists() is true for
; directories too, which is what the font installer relies on.
Func _RequireSetup()
    If FileExists($g_sSetupPath) Then Return
    _Log("ERROR: Setup file not found: " & $g_sSetupPath)
    Exit 20
EndFunc

; ──────────────────────────────────────────────────────────────────────────────
;  Logging
; ──────────────────────────────────────────────────────────────────────────────

Func _Log($sMsg)
    Local $iSlash = StringInStr($g_sLogPath, "\", 0, -1)
    If $iSlash > 1 Then DirCreate(StringLeft($g_sLogPath, $iSlash - 1))

    Local $hLog = FileOpen($g_sLogPath, 1 + 256) ; FO_APPEND (1) + FO_UTF8_NOBOM (256)
    If $hLog = -1 Then Return
    FileWriteLine($hLog, "[" & @YEAR & "-" & StringFormat("%02d", @MON) & "-" & StringFormat("%02d", @MDAY) & _
        " " & @HOUR & ":" & @MIN & ":" & @SEC & "] [" & $g_sLogTag & "] " & $sMsg)
    FileClose($hLog)
EndFunc

; ──────────────────────────────────────────────────────────────────────────────
;  Running the vendor setup
; ──────────────────────────────────────────────────────────────────────────────

; Runs a silent setup command and returns its exit code.
;
; Sets @error (and returns -1) when the process could not be started at all.
; RunWait's @error is captured on the very next line, before anything else can
; clear it: the previous shape of this code logged first and then tested @error,
; by which point _Log's own file calls had already reset it, so a failed launch
; was silently reported as "exit code 0".
Func _RunSetup($sCommand, $sWorkingDir = "")
    If $sWorkingDir = "" Then $sWorkingDir = @ScriptDir

    _Log("INFO: Starting installation...")
    Local $iExitCode = RunWait($sCommand, $sWorkingDir, @SW_HIDE)
    Local $iLaunchError = @error
    If $iLaunchError Then
        _Log("ERROR: RunWait failed with AutoIt error: " & $iLaunchError)
        Return SetError(1, 0, -1)
    EndIf

    _Log("INFO: Installer finished with exit code: " & $iExitCode)
    Return $iExitCode
EndFunc

; Convenience wrapper for the common '"setup.exe" <flags>' shape.
Func _RunSetupFlags($sFlags = "")
    Local $sCommand = '"' & $g_sSetupPath & '"'
    If $sFlags <> "" Then $sCommand &= " " & $sFlags
    Local $iExitCode = _RunSetup($sCommand)
    Return SetError(@error, 0, $iExitCode)
EndFunc

; Runs an .msi through msiexec. 3010 ("success, reboot required") is a success.
Func _RunMsi($sMsiPath, $sExtraFlags = "")
    Local $sCommand = '"' & @SystemDir & '\msiexec.exe" /i "' & $sMsiPath & '" /qn /norestart'
    If $sExtraFlags <> "" Then $sCommand &= " " & $sExtraFlags
    Local $iExitCode = _RunSetup($sCommand)
    Return SetError(@error, 0, $iExitCode)
EndFunc

; ──────────────────────────────────────────────────────────────────────────────
;  Verification
; ──────────────────────────────────────────────────────────────────────────────

; Polls a caller-supplied "is it installed?" function until it returns True or
; $iTimeoutSeconds elapses. $sCheckFunc is the function's *name*, for example
; "_IsChromeInstalled". Returns True once the check succeeds.
Func _WaitForInstall($sCheckFunc, $iTimeoutSeconds, $iPollMs = 1000)
    _Log("INFO: Waiting for app to be fully registered...")

    Local $hTimer = TimerInit()
    While TimerDiff($hTimer) < $iTimeoutSeconds * 1000
        Local $bInstalled = Call($sCheckFunc)
        If @error Then
            _Log("ERROR: Internal error - check function '" & $sCheckFunc & "' does not exist.")
            Return False
        EndIf
        If $bInstalled Then Return True
        Sleep($iPollMs)
    WEnd

    Return False
EndFunc

; ──────────────────────────────────────────────────────────────────────────────
;  Shortcuts
; ──────────────────────────────────────────────────────────────────────────────

; The all-users Desktop, read from the shell folder registry rather than assuming
; C:\Users\Public\Desktop, which is wrong on a system installed to another drive.
Func _PublicDesktopDir()
    Local $sDir = RegRead("HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders", "Common Desktop")
    If @error Or $sDir = "" Then $sDir = @HomeDrive & "\Users\Public\Desktop"
    Return $sDir
EndFunc

; Places a shortcut on the all-users Desktop, but only when this installer was
; asked for one. The working directory defaults to the target's own folder. An
; existing link is left alone so a re-run never clobbers a customised shortcut.
Func _CreatePublicShortcut($sTarget, $sLinkName, $sWorkingDir = "")
    If Not $g_bShortcut Then Return False

    If $sTarget = "" Or Not FileExists($sTarget) Then
        _Log("WARN: Desktop shortcut skipped, target not found: " & $sTarget)
        Return False
    EndIf

    If $sWorkingDir = "" Then
        Local $iSlash = StringInStr($sTarget, "\", 0, -1)
        If $iSlash > 1 Then $sWorkingDir = StringLeft($sTarget, $iSlash - 1)
    EndIf

    Local $sLink = _PublicDesktopDir() & "\" & $sLinkName & ".lnk"
    If FileExists($sLink) Then Return True

    FileCreateShortcut($sTarget, $sLink, $sWorkingDir, "", $sLinkName, $sTarget, "", 0, @SW_SHOW)
    _Log("INFO: Desktop shortcut created: " & $sLink)
    Return True
EndFunc

; Removes a shortcut the vendor setup dropped on the current user's Desktop, so
; it does not sit next to the all-users one in the merged Desktop view.
Func _DeleteUserShortcut($sLinkName)
    Local $sLink = @DesktopDir & "\" & $sLinkName & ".lnk"
    If FileExists($sLink) Then FileDelete($sLink)
EndFunc

; Folds an Inno Setup /LOG file into the shared install log, then deletes it.
; Used by the three Inno-based installers (VS Code, UltraViewer, MPC-HC).
Func _LogInnoFile($sInnoPath, $sTag)
    If Not FileExists($sInnoPath) Then Return

    Local $hInno = FileOpen($sInnoPath, 0)
    If $hInno = -1 Then Return

    Local $hLog = FileOpen($g_sLogPath, 1 + 256)
    If $hLog <> -1 Then
        While True
            Local $sLine = FileReadLine($hInno)
            If @error Then ExitLoop
            If $sLine <> "" Then
                FileWriteLine($hLog, "[" & @YEAR & "-" & StringFormat("%02d", @MON) & "-" & StringFormat("%02d", @MDAY) & _
                    " " & @HOUR & ":" & @MIN & ":" & @SEC & "] " & $sTag & " [INNO] " & $sLine)
            EndIf
        WEnd
        FileClose($hLog)
    EndIf

    FileClose($hInno)
    FileDelete($sInnoPath)
EndFunc

; ──────────────────────────────────────────────────────────────────────────────
;  Small helpers
; ──────────────────────────────────────────────────────────────────────────────

; Directory part of a full file path, without the trailing separator.
Func _ParentDir($sPath)
    Local $iSlash = StringInStr($sPath, "\", 0, -1)
    If $iSlash <= 1 Then Return ""
    Return StringLeft($sPath, $iSlash - 1)
EndFunc

; True when the setup file name ends in the given extension, e.g. _SetupHasExt(".msi").
Func _SetupHasExt($sExt)
    Return StringLower(StringRight($g_sSetupFilename, StringLen($sExt))) = StringLower($sExt)
EndFunc

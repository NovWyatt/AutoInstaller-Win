#RequireAdmin
#AutoIt3Wrapper_UseX64=y
#NoTrayIcon
#include "..\..\_installer_common.au3"

; UniKey Vietnamese input method.
;
; UniKey is portable -- there is no setup program. Installing means:
;   1. create %ProgramFiles%\UniKey
;   2. copy the executable there
;   3. import unikey.reg (with MacroPath rewritten for this user)
;   4. register it to start with Windows
; Argument and exit-code contract: _installer_common.au3.

_InitInstaller("unikey.exe")

Global Const $g_sInstallDir = @ProgramFilesDir & "\UniKey"
Global $g_sInstallExe = $g_sInstallDir & "\" & $g_sSetupFilename

_RequireSetup()

_Log("INFO: Checking if app is already installed...")
If _IsUniKeyInstalled() Then
    _Log("INFO: App is already installed. Exiting with code 10.")
    _CreateShortcut()
    Exit 10
EndIf

If Not DirCreate($g_sInstallDir) Then
    _Log("ERROR: Could not create install directory: " & $g_sInstallDir)
    Exit 21
EndIf
If Not FileCopy($g_sSetupPath, $g_sInstallExe, 1) Then
    _Log("ERROR: Could not copy UniKey to " & $g_sInstallExe)
    Exit 22
EndIf

_Log("INFO: Running UniKey once to initialise its defaults...")
Run('"' & $g_sInstallExe & '"', $g_sInstallDir, @SW_HIDE)
Sleep(2000)

_Log("INFO: Terminating UniKey...")
Local $sExeName = StringTrimLeft($g_sInstallExe, StringInStr($g_sInstallExe, "\", 0, -1))
While ProcessExists($sExeName)
    ProcessClose($sExeName)
    Sleep(500)
WEnd

_ImportSettings()

; Start with Windows. configure-windows.ps1 keeps this entry in its startup allow-list.
RegWrite("HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run", "UniKeyNT", "REG_SZ", '"' & $g_sInstallExe & '"')

_Log("INFO: Restarting UniKey with the new settings...")
Run('"' & $g_sInstallExe & '"', $g_sInstallDir, @SW_HIDE)

_CreateShortcut()
Exit 0

Func _IsUniKeyInstalled()
    If FileExists($g_sInstallExe) Then Return True
    Return FileFindFirstFile($g_sInstallDir & "\unikey*.exe") <> -1
EndFunc

; Rewrites MacroPath for the current user, then imports the .reg file.
Func _ImportSettings()
    Local $sRegFile = @ScriptDir & "\unikey.reg"
    If Not FileExists($sRegFile) Then
        _Log("WARN: unikey.reg not found; keeping UniKey's built-in defaults.")
        Return
    EndIf

    _Log("INFO: Patching and importing unikey.reg settings...")
    Local $sRegContent = FileRead($sRegFile)
    Local $sEscapedMacro = StringReplace(@AppDataDir & "\Unikey\macro.txt", "\", "\\")
    $sRegContent = StringRegExpReplace($sRegContent, '(?m)^"MacroPath"=.*$', '"MacroPath"="' & $sEscapedMacro & '"')

    ; 32 + 2 = UTF-16LE with BOM + overwrite, the encoding reg.exe expects here
    Local $sTempReg = @TempDir & "\unikey_patched.reg"
    Local $hWrite = FileOpen($sTempReg, 32 + 2)
    If $hWrite = -1 Then
        _Log("WARN: Could not write the patched unikey.reg; skipping the import.")
        Return
    EndIf
    FileWrite($hWrite, $sRegContent)
    FileClose($hWrite)

    RunWait('reg.exe import "' & $sTempReg & '"', "", @SW_HIDE)
    FileDelete($sTempReg)
EndFunc

Func _CreateShortcut()
    If Not $g_bShortcut Then Return
    _CreatePublicShortcut($g_sInstallExe, "UniKey", $g_sInstallDir)
EndFunc

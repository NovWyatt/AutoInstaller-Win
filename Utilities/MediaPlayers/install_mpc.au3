#RequireAdmin
#AutoIt3Wrapper_UseX64=y
#NoTrayIcon
#include "..\..\_installer_common.au3"

; MPC-HC (Media Player Classic - Home Cinema) installer, Inno Setup based.
; Audio-output and association settings are applied through the registry after
; the install, because MPC-HC reads them from HKCU rather than setup switches.
; Argument and exit-code contract: _installer_common.au3.

_InitInstaller("mpc.exe", "MPC")
_RequireSetup()

_Log("INFO: Checking if MPC-HC is already installed...")
If _IsMPCInstalled() Then
    _Log("INFO: MPC-HC is already installed. Applying settings, creating shortcut, and exiting with code 10.")
    _ApplySettings()
    _CreateShortcut()
    Exit 10
EndIf

Local $sInnoLog = "C:\Auto-installer\install_mpc_inno.log"
Local $iExitCode = _RunSetupFlags('/VERYSILENT /NORESTART /TASKS="associate" /LOG="' & $sInnoLog & '"')
If @error Then Exit 21
_LogInnoFile($sInnoLog, "[MPC]")

If $iExitCode <> 0 Then
    _Log("ERROR: Installer returned non-zero exit code: " & $iExitCode)
    Exit $iExitCode
EndIf

If _WaitForInstall("_IsMPCInstalled", 120) Then
    _Log("INFO: MPC-HC installation confirmed. Applying settings, creating shortcut, and exiting with code 0.")
    _ApplySettings()
    _CreateShortcut()
    Exit 0
EndIf
_Log("ERROR: MPC-HC installation validation timed out.")
Exit 22

; MPC-HC ships standalone and inside the K-Lite Codec Pack; check both layouts.
Func _MPCExe()
    Local $sReg = RegRead("HKLM64\SOFTWARE\MPC-HC\MPC-HC", "ExePath")
    If Not @error And FileExists($sReg) Then Return $sReg

    Local $aCandidates = [ _
        @ProgramFilesDir & "\MPC-HC\mpc-hc64.exe", _
        @ProgramFilesDir & " (x86)\K-Lite Codec Pack\MPC-HC64\mpc-hc64.exe", _
        @ProgramFilesDir & " (x86)\K-Lite Codec Pack\MPC-HC\mpc-hc.exe", _
        @ProgramFilesDir & "\MPC-HC\mpc-hc.exe", _
        @ProgramFilesDir & " (x86)\MPC-HC\mpc-hc.exe"]
    For $sPath In $aCandidates
        If FileExists($sPath) Then Return $sPath
    Next
    Return ""
EndFunc

Func _IsMPCInstalled()
    Return _MPCExe() <> ""
EndFunc

Func _ApplySettings()
    ; Audio renderer 0 = system default / same as input
    RegWrite("HKCU\Software\MPC-HC\MPC-HC", "AudioRendererType", "REG_DWORD", 0)
    RegWrite("HKCU\Software\MPC-HC\MPC-HC", "AudioMixer", "REG_DWORD", 1)
EndFunc

Func _CreateShortcut()
    If Not $g_bShortcut Then Return
    _CreatePublicShortcut(_MPCExe(), "MPC-HC")
EndFunc

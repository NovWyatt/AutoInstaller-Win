# <img src="icon.png" width="32" height="32" valign="middle" /> AUTOINSTALLER-WIN

![Version](https://img.shields.io/badge/version-0.2-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Platform](https://img.shields.io/badge/platform-Windows-lightgrey)
![Status](https://img.shields.io/badge/status-in_development-orange)

A bootable USB that installs Windows 11, your applications, your drivers and your
settings without you sitting in front of it.

Put the stick in, pick an entry from the boot menu, walk away. It partitions the
disk, installs Windows unattended, strips the bloatware, creates the account,
installs everything listed in `install-apps.ini`, applies the settings in
`configure-windows.ini`, updates drivers, and leaves a Markdown report of what
happened.

---

## 💡 WHY

The old answer to "set up twenty identical machines" was a **GHOST image**: clone
one disk, restore it everywhere. Fast, but it hands you someone else's Windows:

- **Hardware mismatch.** A clone carries the drivers of the machine it came from.
  Different chipset, different GPU — enjoy the BSOD.
- **Someone else's decisions.** Their telemetry settings, their bloatware, their
  personalisation, baked in.
- **Do you trust the image?** A downloaded clone is an opaque binary. You cannot
  read what is inside it.

This does the opposite. Every step is a script you can read, in a repository you
control. The Windows image is Microsoft's own ISO, untouched.

---

## ✨ WHAT IT DOES

**1. A Ventoy boot menu** — [`ventoy/`](ventoy)

Custom GRUB2 theme in dark and light, at 16:9, 4:3 and 16:10, with per-entry
icons and tips. Twelve unattended install profiles combine a disk layout with how
much automation you want:

| | `full` | `noapps` | `nodrivers` |
| :--- | :---: | :---: | :---: |
| Installs apps | ✅ | ❌ | ❌ |
| Installs drivers | ✅ | ✅ | ❌ |
| Configures Windows | ✅ | ❌ | ❌ |

crossed with `C` (one partition), `C_D` (C at 150 GB plus a data drive),
`dyn_C_D` (Ventoy prompts for the size, host name and account name) and `mandisk`
(you pick the partitions yourself).

Every profile bypasses the Windows 11 hardware checks (TPM, Secure Boot, RAM,
CPU), disables BitLocker auto-encryption, removes the provisioned bloatware, and
creates a local account without touching a Microsoft account.

**2. The installers** — run at first logon

| Component | Does |
| :--- | :--- |
| `Auto-installer.exe` | Orchestrates the run and prints live progress |
| `install-apps.exe` | Installs everything enabled in `install-apps.ini` |
| `install-drivers.exe` | Snappy Driver Installer Origin, Windows Update as fallback |
| `configure-windows.exe` | Applies the settings in `configure-windows.ini` |
| `report.exe` | Writes `C:\Auto-installer\report.md` |

Each application has its own small installer under its category folder. They are
not magic: each one knows its vendor setup's silent switches and how to verify
the result afterwards. Adding an app means writing one.

**3. Logs and a report**

Everything lands in `C:\Auto-installer\`, and `report.md` summarises the whole
run — which apps installed, which were already present, which failed and why,
which settings applied, which drivers were touched.

---

## 📁 LAYOUT

```txt
AutoInstaller-Win/
├── <category>/                     Antivirus, Browsers, Environment, Office,
│   └── install_<app>.au3           Socials, Tools, Utilities
├── _installer_common.au3           Shared scaffold every installer includes
├── Unattend/
│   ├── template/                   <- edit here
│   ├── build-unattend.ps1          <- then run this
│   └── *.xml                       12 generated answer files
├── ventoy/
│   ├── theme/
│   │   ├── template/               <- edit here
│   │   ├── build-theme.ps1         <- then run this
│   │   └── autoinstaller/          18 generated theme files + artwork
│   ├── font/cascadia-code/
│   └── ventoy.*.json.example
├── ci/validate.ps1                 Checks every file the repo ships
├── compile-au2exe.ps1              .au3 -> .exe
├── extract.ps1                     Deploys the repo onto the USB
├── install-apps.ini                Which apps, in what order
└── configure-windows.ini           Which Windows settings
```

Full tree: [REPO_STRUCTURE.md](REPO_STRUCTURE.md). USB layout:
[USB_STRUCTURE.md](USB_STRUCTURE.md).

**Generated files are committed.** Deploying the USB never requires running a
build. But if you edit a template, run its build script and commit the result —
CI fails if they drift apart.

---

## 🚀 BUILDING THE USB

> Windows host only.

### Requirements

| | Tool | Note |
| :--- | :--- | :--- |
| Must | [AutoIt v3](https://www.autoitscript.com/site/autoit/downloads/) | Compiles `.au3` to `.exe` |
| Must | PowerShell 5.1 | Ships with Windows 10/11 |
| Must | [Ventoy](https://www.ventoy.net/en/download.html) | Verify the SHA — the download host is not hardened |
| Must | 16 GB+ USB drive | **It will be wiped completely** |
| Optional | [VMware Workstation](https://www.vmware.com/products/workstation-pro.html) | Test without real hardware |
| Optional | [git](https://git-scm.com/downloads), [VS Code](https://code.visualstudio.com/download) | For contributing |

### 1. Prepare the USB with Ventoy

Run `Ventoy2Disk.exe` as administrator, pick your drive, then **Option >
Partition Configuration** and reserve at least 10 GB at the end of the disk.
Install. You end up with an **ISO partition** (Ventoy's own, for Windows images
and answer files) and the reserved space, which you format as a second
**SOFTWARE partition** for the installers.

### 2. Copy the Windows ISO

Download the official [Windows 11 ISO](https://www.microsoft.com/software-download/windows11)
and put it in `Windows/` on the ISO partition.

### 3. Clone this repository

```bash
git clone https://github.com/NovWyatt/AutoInstaller-Win.git
```

Or download the ZIP from the repository page. Extract it somewhere that is **not**
on the USB.

### 4. Deploy to the USB

Open PowerShell as administrator in the repository folder:

```powershell
.\extract.ps1
```

It finds both partitions by their marker files, copies the Ventoy config and the
answer files to the ISO partition, compiles every `.au3`, and copies the
applications and scripts to the SOFTWARE partition. `--dry-run` shows what it
would do; `-i I:S` names the drives explicitly.

Each run records what it placed in a hidden `.autoinstaller-deploy.txt` on each
partition, and the next run removes anything that manifest lists which the repo
no longer produces — a renamed folder, a deleted script. **Files you put on the
USB yourself are never in a manifest and are never touched**, which is why this
does not simply mirror the tree: mirroring would delete every vendor installer,
driver pack and ISO you downloaded. `--no-prune` turns the cleanup off.

Then rename `ventoy/ventoy.json.example` to `ventoy.json` and adjust it — see
[ventoy/README.md](ventoy/README.md).

### 5. Download the vendor setup files

**No installers are included.** They are the vendors' to distribute, not this
repository's. Download each one, rename it to the name in the table, and drop it
in the matching folder on the SOFTWARE partition.

| Index | `setup_file` | Download |
|---|---|---|
| 0 | Browsers/chrome-standalone.exe | [Google Chrome Standalone](https://www.google.com/chrome/eula.html?standalone=1) |
| 1 | Environment/Java/java.exe | [Java Runtime 8u503](https://javadl.oracle.com/webapps/download/AutoDL?BundleId=253608_2fde65a2208f40a5b5f4c844b0dff092) |
| 2 | Environment/Python/python.exe | [Python 3.14.7](https://www.python.org/ftp/python/3.14.7/python-3.14.7-amd64.exe) |
| 3 | Environment/VCRedist/vcredist-AIO.exe | [VCRedist AIO 2005-2026](https://github.com/abbodi1406/vcredist/releases/download/v0.105.0/VisualCppRedist_AIO_x86_x64.exe) |
| 4 | Environment/IDEs/vs.exe | [VS 2026 Community](https://visualstudio.microsoft.com/) — *installer not implemented yet* |
| 5 | Tools/Archivers/7z.exe | [7-Zip 26.02](https://github.com/ip7z/7zip/releases/download/26.02/7z2602-x64.exe) |
| 6 | Tools/Archivers/winrar.exe | [WinRAR 7.23](https://www.win-rar.com/fileadmin/winrar-versions/winrar/winrar-x64-723.exe) |
| 7 | Tools/Editors/notepadpp.exe | [Notepad++ 8.9.8](https://github.com/notepad-plus-plus/notepad-plus-plus/releases/download/v8.9.8/npp.8.9.8.Installer.x64.exe) |
| 8 | Tools/Editors/vscode.exe | [VS Code 1.134](https://code.visualstudio.com/download) |
| 9 | Utilities/MediaPlayers/mpc.exe | [K-Lite Codec Pack Mega 1995](https://files2.codecguide.com/K-Lite_Codec_Pack_1995_Mega.exe) |
| 10 | Utilities/VietnameseKeyboards/unikey.exe | [UniKey 4.6RC2](https://www.unikey.org/assets/release/unikey46RC2-230919-win64.zip) |
| 11 | Tools/ScreenRecorders/obs.exe | [OBS Studio 32.2.2](https://cdn-fastly.obsproject.com/downloads/OBS-Studio-32.2.2-Windows-x64-Installer.exe) |
| 12 | Tools/DesktopSupporters/ultraviewer.exe | [UltraViewer 6.6.133](https://dl2.ultraviewer.net/UltraViewer_setup_6.6.133_vi.exe) |
| 13 | Tools/DesktopSupporters/teamviewer.exe | [TeamViewer](https://download.teamviewer.com/download/TeamViewer_Setup_x64.exe) |
| 14 | Office/Office2024/office2024.exe | [Office Deployment Tool](https://www.microsoft.com/download/details.aspx?id=49117) — see [ODT setup](Office/Office2024/README.md) |
| 15 | Office/LibreOffice/libreoffice.msi | [LibreOffice 26.2.5](https://download.documentfoundation.org/libreoffice/stable/26.2.5/win/x86_64/LibreOffice_26.2.5_Win_x86-64.msi) |
| 16 | Socials/discord.exe | [Discord](https://discord.com/api/downloads/distributions/app/installers/latest?channel=stable&platform=win&arch=x64) |
| 17 | Socials/zalo.exe | [Zalo](https://zalo.me/download/zalo-pc?utm=90000) |
| 18 | Antivirus/kaspersky.exe | [Kaspersky](https://www.kaspersky.com.vn/downloads/antivirus) |
| 19 | Utilities/FileExplorer/shell.msi | [Nilesoft Shell 1.9.18](https://nilesoft.org/download/shell/1.9.18/setup-x64.msi) |
| 20 | Utilities/Fonts | Any `.ttf` / `.otf` / `.ttc` you want installed for all users |

> Doing this by hand is tedious. Automating it is on the list below.

### 6. Configure

`install-apps.ini` decides what gets installed:

```ini
target=[
    # index, setup_file, install_file, install_flag, desktop_shortcut_flag
    5,"Tools/Archivers/7z.exe","Tools/Archivers/install_7z.exe",true,true;
    14,"Office/Office2024/office2024.exe","Office/Office2024/install_office2024.exe",true,true;
];

option=[
    # Optional extra argument for one target
    14,"full_vi.xml";      # Office in Vietnamese; see the ini for the full list
];
```

`configure-windows.ini` decides the Windows settings — Explorer, taskbar, Start
menu, desktop icons, wallpaper, region, and more.

---

## 🧩 EXTENDING IT

### Adding an application

Every installer includes [`_installer_common.au3`](_installer_common.au3), which
supplies the argument parsing, logging, silent-run helper, polling verifier and
shortcut helper. A new one is mostly its own detection logic:

```autoit
#RequireAdmin
#AutoIt3Wrapper_UseX64=y
#NoTrayIcon
#include "..\..\_installer_common.au3"

_InitInstaller("myapp.exe")
_RequireSetup()

If _IsMyAppInstalled() Then Exit 10

Local $iExitCode = _RunSetupFlags("/S")
If @error Then Exit 21
If $iExitCode <> 0 Then Exit $iExitCode

If _WaitForInstall("_IsMyAppInstalled", 60) Then Exit 0
Exit 22

Func _IsMyAppInstalled()
    Return FileExists(@ProgramFilesDir & "\MyApp\myapp.exe")
EndFunc
```

Exit codes are the contract with `install-apps.exe`: `0` installed, `10` already
present, `20` setup missing, `21` could not start, `22` unverified.

### Before committing

```powershell
.\ci\validate.ps1
```

Checks that every XML and JSON parses, every script is syntactically sound, every
`#include` resolves, the generated Unattend and theme files still match their
templates, and no tracked file is hidden by `.gitignore`. GitHub Actions runs the
same script on every push.

---

## ⚠️ KNOWN ISSUES

1. **Taskbar and Start menu pinning does nothing.** Windows 11 22H2 removed the
   shell's `taskbarpin` verb, which is how `configure-windows.ps1` pins and
   unpins. `InvokeVerb` still returns without error, it just has no effect, which
   is why this looked like it worked. Tasks 6, 7 and 12 need a layout XML
   instead. Marked `[BUG]` in `configure-windows.ini`. The run now counts the
   pinned shortcuts before and after and logs an error when nothing moved, so
   the report says so rather than staying quiet.
2. **Downloading the setup files is manual and slow.** The plan is a
   `download_url` column in `install-apps.ini` and a `download-apps.ps1`. Not all
   vendors will cooperate — several gate downloads behind anti-bot checks.
3. **Logs are split across three places.** `C:\Auto-installer\` holds most of it,
   but the unattend scripts also write to `C:\Windows\Setup\Scripts\*.log`, and
   Windows Setup's own log in `C:\Windows\Panther\` is outside our control.
4. **WinRAR's desktop shortcut sometimes does not appear.** The installer now
   logs the target path it resolved and why it gave up, so the next run should
   say what is actually happening.
5. **The boot menu artwork still carries the upstream author's branding**, baked
   into the background images. See [ventoy/theme/README.md](ventoy/theme/README.md)
   for what to redraw.

## 🔮 PLANNED

- Automatic download of setup files
- A GUI for editing the INI files, compiling and deploying
- Making `C:\Auto-installer` configurable everywhere, not just for the main logs

---

## 📚 REFERENCES

- [Unattend Generator (schneegans.de)](https://schneegans.de/windows/unattend-generator/)
- [Microsoft Autounattend reference](https://learn.microsoft.com/en-us/windows-hardware/customize/desktop/unattend/)
- [Ventoy plugin documentation](https://www.ventoy.net/en/plugin_entry.html)
- [GRUB2 theme icons](https://www.gnome-look.org/p/2206122)
- [Cascadia Code](https://fonts.google.com/specimen/Cascadia+Code)
- [AutoIt wiki](https://www.autoitscript.com/wiki/)

## 📄 LICENSE

MIT — see [LICENSE.md](LICENSE.md).

This is a fork of [1172005thinh/AutoInstaller](https://github.com/1172005thinh/AutoInstaller),
maintained independently. The original copyright notice stays as MIT requires.

## 🤝 CONTRIBUTING

Issues and pull requests welcome. Run `.\ci\validate.ps1` before opening one, and
if you change a template, commit the regenerated files with it.

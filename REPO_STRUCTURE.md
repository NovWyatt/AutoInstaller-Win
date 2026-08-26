# REPO STRUCTURE

A complete structure of the AutoInstaller repository.

> Generated from the tracked file list. `.git`, `Drivers/SDIO` (user-supplied
> driver pack) and `report.exe` (build output) are shown for context but are
> not tracked in the repository.

``` txt
AutoInstaller/
├── .git
│   └── ...
├── Antivirus
│   ├── .gitignore
│   ├── install_kaspersky.au3
│   └── README.md
├── Browsers
│   ├── .gitignore
│   ├── install_chrome-standalone.au3
│   └── README.md
├── Drivers
│   ├── SDIO
│   ├── .gitignore
│   └── README.md
├── Environment
│   ├── IDEs
│   │   ├── install_vs.au3
│   │   └── README.md
│   ├── Java
│   │   ├── install_java.au3
│   │   └── README.md
│   ├── Python
│   │   ├── install_python.au3
│   │   └── README.md
│   ├── VCRedist
│   │   └── install_vcredist.au3
│   ├── .gitignore
│   └── README.md
├── Office
│   ├── LibreOffice
│   │   ├── install_libreoffice.au3
│   │   └── README.md
│   ├── Office2024
│   │   ├── full_en.xml
│   │   ├── full_vi.xml
│   │   ├── install_office2024.au3
│   │   ├── README.md
│   │   ├── we_en.xml
│   │   ├── we_vi.xml
│   │   ├── wep_en.xml
│   │   ├── wep_vi.xml
│   │   ├── wepa_en.xml
│   │   └── wepa_vi.xml
│   ├── .gitignore
│   └── README.md
├── Socials
│   ├── .gitignore
│   ├── install_discord.au3
│   ├── install_zalo.au3
│   └── README.md
├── Tools
│   ├── Archivers
│   │   ├── .gitignore
│   │   ├── install_7z.au3
│   │   ├── install_winrar.au3
│   │   ├── rarreg.key.example
│   │   └── README.md
│   ├── DesktopSupporters
│   │   ├── install_teamviewer.au3
│   │   ├── install_ultraviewer.au3
│   │   └── README.md
│   ├── Editors
│   │   ├── install_notepadpp.au3
│   │   ├── install_vscode.au3
│   │   └── README.md
│   ├── ScreenRecorders
│   │   ├── install_obs.au3
│   │   └── README.md
│   ├── .gitignore
│   └── README.md
├── Unattend
│   ├── .gitignore
│   ├── full_C.xml
│   ├── full_C_D.xml
│   ├── full_dyn_C_D.xml
│   ├── full_mandisk.xml
│   ├── noapps_C.xml
│   ├── noapps_C_D.xml
│   ├── noapps_dyn_C_D.xml
│   ├── noapps_mandisk.xml
│   ├── nodrivers_C.xml
│   ├── nodrivers_C_D.xml
│   ├── nodrivers_dyn_C_D.xml
│   ├── nodrivers_mandisk.xml
│   └── README.md
├── Utilities
│   ├── FileExplorer
│   │   ├── install_shell.au3
│   │   └── README.md
│   ├── Fonts
│   │   ├── .gitignore
│   │   ├── install_fonts.au3
│   │   └── install_fonts.ps1
│   ├── MediaPlayers
│   │   ├── install_mpc.au3
│   │   └── README.md
│   ├── VietnameseKeyboards
│   │   ├── install_unikey.au3
│   │   └── unikey.reg
│   ├── .gitignore
│   └── README.md
├── ventoy
│   ├── font
│   │   └── cascadia-code
│   │       ├── cascadia-code_12.pf2
│   │       ├── cascadia-code_14.pf2
│   │       ├── cascadia-code_16.pf2
│   │       ├── cascadia-code_18.pf2
│   │       ├── cascadia-code_20.pf2
│   │       ├── cascadia-code_22.pf2
│   │       ├── cascadia-code_24.pf2
│   │       ├── cascadia-code_26.pf2
│   │       ├── cascadia-code_28.pf2
│   │       ├── cascadia-code_30.pf2
│   │       └── cascadia-code_32.pf2
│   ├── theme
│   │   ├── autoinstaller
│   │   │   ├── icons
│   │   │   │   ├── 4MLinux.png
│   │   │   │   ├── AlpineLinux.png
│   │   │   │   ├── android.png
│   │   │   │   ├── anonymous.png
│   │   │   │   ├── antergos.png
│   │   │   │   ├── arch.png
│   │   │   │   ├── archcraft.png
│   │   │   │   ├── archlinux.png
│   │   │   │   ├── arcolinux.png
│   │   │   │   ├── artix.png
│   │   │   │   ├── brunch-settings.png
│   │   │   │   ├── brunch.png
│   │   │   │   ├── cancel.png
│   │   │   │   ├── chakra.png
│   │   │   │   ├── chimera.png
│   │   │   │   ├── debian.png
│   │   │   │   ├── deepin.png
│   │   │   │   ├── default.png
│   │   │   │   ├── devuan.png
│   │   │   │   ├── driver.png
│   │   │   │   ├── edit.png
│   │   │   │   ├── efi.png
│   │   │   │   ├── elementary.png
│   │   │   │   ├── endeavouros.png
│   │   │   │   ├── fedora.png
│   │   │   │   ├── find.efi.png
│   │   │   │   ├── find.none.png
│   │   │   │   ├── freebsd.png
│   │   │   │   ├── gentoo.png
│   │   │   │   ├── gnu-linux.png
│   │   │   │   ├── gpart.png
│   │   │   │   ├── haiku.png
│   │   │   │   ├── help.png
│   │   │   │   ├── kali.png
│   │   │   │   ├── kaos.png
│   │   │   │   ├── kbd.png
│   │   │   │   ├── kernel.png
│   │   │   │   ├── korora.png
│   │   │   │   ├── kubuntu.png
│   │   │   │   ├── lang.png
│   │   │   │   ├── lfs.png
│   │   │   │   ├── linux.png
│   │   │   │   ├── linuxmint.png
│   │   │   │   ├── lubuntu.png
│   │   │   │   ├── macosx.png
│   │   │   │   ├── mageia.png
│   │   │   │   ├── Manjaro.i686.png
│   │   │   │   ├── manjaro.png
│   │   │   │   ├── Manjaro.x86_64.png
│   │   │   │   ├── manjarolinux.png
│   │   │   │   ├── memtest.png
│   │   │   │   ├── mx-linux.png
│   │   │   │   ├── neon.png
│   │   │   │   ├── nixos.png
│   │   │   │   ├── nobara.png
│   │   │   │   ├── opensuse.png
│   │   │   │   ├── parrot.png
│   │   │   │   ├── pop-os.png
│   │   │   │   ├── pop.png
│   │   │   │   ├── recovery.png
│   │   │   │   ├── regolith.png
│   │   │   │   ├── restart.png
│   │   │   │   ├── shutdown.png
│   │   │   │   ├── siduction.png
│   │   │   │   ├── solus.png
│   │   │   │   ├── steamos.png
│   │   │   │   ├── submenu.png
│   │   │   │   ├── SystemRescueCD.png
│   │   │   │   ├── type.png
│   │   │   │   ├── tz.png
│   │   │   │   ├── ubuntu.png
│   │   │   │   ├── ubuntuDDE.png
│   │   │   │   ├── unknown.png
│   │   │   │   ├── unset.png
│   │   │   │   ├── ventoy.png
│   │   │   │   ├── void.png
│   │   │   │   ├── windows.png
│   │   │   │   ├── xubuntu.png
│   │   │   │   └── zorin.png
│   │   │   ├── background_dark1610_fb.jpg
│   │   │   ├── background_dark1610_gh.jpg
│   │   │   ├── background_dark1610_htc.jpg
│   │   │   ├── background_dark169_fb.jpg
│   │   │   ├── background_dark169_gh.jpg
│   │   │   ├── background_dark169_htc.jpg
│   │   │   ├── background_dark43_fb.jpg
│   │   │   ├── background_dark43_gh.jpg
│   │   │   ├── background_dark43_htc.jpg
│   │   │   ├── background_light1610_fb.jpg
│   │   │   ├── background_light1610_gh.jpg
│   │   │   ├── background_light1610_htc.jpg
│   │   │   ├── background_light169_fb.jpg
│   │   │   ├── background_light169_gh.jpg
│   │   │   ├── background_light169_htc.jpg
│   │   │   ├── background_light43_fb.jpg
│   │   │   ├── background_light43_gh.jpg
│   │   │   ├── background_light43_htc.jpg
│   │   │   ├── cascadia-code_16.pf2
│   │   │   ├── cascadia-code_28.pf2
│   │   │   ├── select_c.png
│   │   │   ├── select_e.png
│   │   │   ├── select_w.png
│   │   │   ├── theme_dark1610_fb.txt
│   │   │   ├── theme_dark1610_gh.txt
│   │   │   ├── theme_dark1610_htc.txt
│   │   │   ├── theme_dark169_fb.txt
│   │   │   ├── theme_dark169_gh.txt
│   │   │   ├── theme_dark169_htc.txt
│   │   │   ├── theme_dark43_fb.txt
│   │   │   ├── theme_dark43_gh.txt
│   │   │   ├── theme_dark43_htc.txt
│   │   │   ├── theme_light1610_fb.txt
│   │   │   ├── theme_light1610_gh.txt
│   │   │   ├── theme_light1610_htc.txt
│   │   │   ├── theme_light169_fb.txt
│   │   │   ├── theme_light169_gh.txt
│   │   │   ├── theme_light169_htc.txt
│   │   │   ├── theme_light43_fb.txt
│   │   │   ├── theme_light43_gh.txt
│   │   │   └── theme_light43_htc.txt
│   │   ├── .gitignore
│   │   ├── preview_dark1610.png
│   │   ├── preview_dark169.png
│   │   ├── preview_dark43.png
│   │   ├── preview_light1610.png
│   │   ├── preview_light169.png
│   │   └── preview_light43.png
│   ├── .gitignore
│   ├── README.md
│   ├── ventoy.1610.json.example
│   ├── ventoy.169.json.example
│   ├── ventoy.43.json.example
│   └── ventoy.json.example
├── .gitignore
├── 5b512ee8a59deb284ad0a6a035ba10b1.md5
├── _installer_common.au3
├── aea541d7f9574587656dc5125116e548.md5
├── compile-au2exe.ps1
├── configure-windows.au3
├── configure-windows.ini
├── configure-windows.ps1
├── extract.ps1
├── icon.ico
├── icon.png
├── install-apps.au3
├── install-apps.ini
├── install-drivers.au3
├── install-drivers.ps1
├── LICENSE.md
├── README.md
├── REPO_STRUCTURE.md
├── report.au3
├── report.exe
├── report.ps1
├── USB_STRUCTURE.md
└── wallpaper.png
```

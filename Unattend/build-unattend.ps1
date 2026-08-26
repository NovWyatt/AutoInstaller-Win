<#
.SYNOPSIS
    Generates the twelve Unattend XML answer files from one template.

.DESCRIPTION
    The twelve answer files differ along exactly two axes and are otherwise
    identical, which previously meant every change to the embedded setup scripts
    had to be repeated twelve times:

      disk layout   C | C_D | dyn_C_D | mandisk
      scope         full | noapps | nodrivers

    template/unattend.template.xml holds everything the variants share.
    template/disk-<layout>.xml holds the <DiskConfiguration> block for one
    layout (empty for mandisk, which lets Windows Setup ask instead). Everything
    else that varies is a placeholder filled in from the tables below.

    Regenerate after editing the template or a fragment. The generated files stay
    committed, so deploying the USB never requires running this script.

.PARAMETER WorkDirectory
    Folder the embedded setup scripts log into. Must match the directory of
    log_path in install-apps.ini, because report.exe looks for setup-scripts.log
    beside the other logs. Baked into the generated files, so change it here and
    regenerate.

.PARAMETER Check
    Generate into memory and compare against the files on disk instead of
    writing. Exits 1 if any file is out of date. Used by CI to prove the
    committed answer files still match the template.

.EXAMPLE
    .\build-unattend.ps1
    # Rewrite all twelve answer files

.EXAMPLE
    .\build-unattend.ps1 -Check
    # Fail if any committed answer file has drifted from the template
#>
[CmdletBinding()]
param(
    [switch] $Check,

    [string] $WorkDirectory = 'C:\Auto-installer'
)

$ErrorActionPreference = 'Stop'

$root         = $PSScriptRoot
$templateDir  = Join-Path $root 'template'
$templatePath = Join-Path $templateDir 'unattend.template.xml'

# ------------------------------------------------------------------------------
# Variant tables
# ------------------------------------------------------------------------------

# The <InstallTo> target never varies between layouts that declare partitions,
# so it lives here rather than in a fragment file. mandisk omits it entirely.
$installToBlock = @(
    "`t`t`t`t`t<InstallTo>"
    "`t`t`t`t`t`t<DiskID>`$`$VT_WINDOWS_DISK_1ST_NONVTOY`$`$</DiskID>"
    "`t`t`t`t`t`t<PartitionID>3</PartitionID>"
    "`t`t`t`t`t</InstallTo>"
) -join "`n"

# dyn_C_D defers the partition size, host name and account name to Ventoy, which
# prompts for them at boot and substitutes the $$DYN_*$$ tokens.
$layouts = [ordered] @{
    'C'       = @{ ComputerName = 'PC'; AccountName = 'OEM'; DisplayName = 'OEM'; InstallTo = $true }
    'C_D'     = @{ ComputerName = 'PC'; AccountName = 'OEM'; DisplayName = 'OEM'; InstallTo = $true }
    'dyn_C_D' = @{ ComputerName = '$$DYN_PC_NAME$$'; AccountName = '$$DYN_ACCOUNT_NAME$$'; DisplayName = '$$DYN_DISPLAY_NAME$$'; InstallTo = $true }
    'mandisk' = @{ ComputerName = 'PC'; AccountName = 'OEM'; DisplayName = 'OEM'; InstallTo = $false }
}

# Which phases Auto-installer.exe runs at first logon.
$scopes = [ordered] @{
    'full'      = @{ Mode = '--full';         Description = 'Install drivers, configured applications, and generate the report' }
    'noapps'    = @{ Mode = '--drivers-only'; Description = 'Install drivers and generate the report' }
    'nodrivers' = @{ Mode = '--report';       Description = 'Generate the installation report without driver or application installation' }
}

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------

# The answer files are UTF-8 without a BOM, CRLF, and carry no trailing newline.
# Read and write through these so a regenerated file is byte-identical.
function Read-TextFile {
    param([string] $Path)
    if (-not (Test-Path -LiteralPath $Path)) { return '' }
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        $bytes = $bytes[3..($bytes.Length - 1)]
    }
    return ([System.Text.Encoding]::UTF8.GetString($bytes)) -replace "`r`n", "`n"
}

function ConvertTo-FileBytes {
    param([string] $Text)
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    return $utf8NoBom.GetBytes(($Text -replace "`n", "`r`n"))
}

function Build-Answer {
    param([string] $Template, [hashtable] $Layout, [hashtable] $Scope, [string] $DiskConfiguration)

    $installTo = if ($Layout.InstallTo) { $installToBlock } else { '' }

    # A placeholder that resolves to nothing must take its whole line with it,
    # so the empty case matches on the trailing newline too.
    $text = $Template
    foreach ($pair in @(
            @{ Name = 'DISK_CONFIGURATION'; Value = $DiskConfiguration },
            @{ Name = 'INSTALL_TO';         Value = $installTo })) {
        $token = '{{' + $pair.Name + '}}'
        if ([string]::IsNullOrEmpty($pair.Value)) {
            $text = $text.Replace($token + "`n", '')
        } else {
            $text = $text.Replace($token, $pair.Value.TrimEnd("`n"))
        }
    }

    $text = $text.Replace('{{COMPUTER_NAME}}', $Layout.ComputerName)
    $text = $text.Replace('{{ACCOUNT_NAME}}', $Layout.AccountName)
    $text = $text.Replace('{{DISPLAY_NAME}}', $Layout.DisplayName)
    $text = $text.Replace('{{WORK_DIR}}', $script:WorkDir)
    $text = $text.Replace('{{AUTOINSTALLER_MODE}}', $Scope.Mode)
    $text = $text.Replace('{{AUTOINSTALLER_DESCRIPTION}}', $Scope.Description)

    $leftover = [regex]::Matches($text, '\{\{[A-Z_]+\}\}')
    if ($leftover.Count -gt 0) {
        throw "Unresolved placeholder(s): $(($leftover | ForEach-Object { $_.Value }) -join ', ')"
    }
    return $text
}

# ------------------------------------------------------------------------------
# Generate
# ------------------------------------------------------------------------------

if (-not (Test-Path -LiteralPath $templatePath)) {
    throw "Template not found: $templatePath"
}
$template = Read-TextFile $templatePath
$script:WorkDir = $WorkDirectory.TrimEnd('\')

$written = 0
$stale = [System.Collections.Generic.List[string]]::new()

foreach ($scopeName in $scopes.Keys) {
    foreach ($layoutName in $layouts.Keys) {
        $fragmentPath = Join-Path $templateDir ("disk-{0}.xml" -f $layoutName)
        $fragment = Read-TextFile $fragmentPath

        $text  = Build-Answer -Template $template -Layout $layouts[$layoutName] `
                              -Scope $scopes[$scopeName] -DiskConfiguration $fragment
        $bytes = ConvertTo-FileBytes $text

        $outPath = Join-Path $root ("{0}_{1}.xml" -f $scopeName, $layoutName)
        $name    = Split-Path $outPath -Leaf

        if ($Check) {
            $current = if (Test-Path -LiteralPath $outPath) { [System.IO.File]::ReadAllBytes($outPath) } else { @() }
            if (-not [System.Linq.Enumerable]::SequenceEqual([byte[]] $current, [byte[]] $bytes)) {
                $stale.Add($name)
                Write-Host ("  [STALE]  {0}" -f $name) -ForegroundColor Red
            } else {
                Write-Host ("  [ok]     {0}" -f $name) -ForegroundColor DarkGray
            }
        } else {
            [System.IO.File]::WriteAllBytes($outPath, $bytes)
            Write-Host ("  [write]  {0}  ({1} lines)" -f $name, ($text -split "`n").Count) -ForegroundColor Green
            $written++
        }
    }
}

if ($Check) {
    if ($stale.Count -gt 0) {
        Write-Host ""
        Write-Host ("{0} answer file(s) do not match the template. Run build-unattend.ps1 and commit the result." -f $stale.Count) -ForegroundColor Red
        exit 1
    }
    Write-Host ""
    Write-Host "All 12 answer files match the template." -ForegroundColor Green
    exit 0
}

Write-Host ""
Write-Host ("Generated {0} answer file(s) from {1}." -f $written, (Split-Path $templatePath -Leaf)) -ForegroundColor Cyan
exit 0

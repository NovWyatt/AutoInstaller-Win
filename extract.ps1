<#
.SYNOPSIS
    Ventoy USB Automated Deployment & Extraction Tool for AutoInstaller.

.DESCRIPTION
    Automates the deployment and extraction of AutoInstaller assets from the local
    workspace to the target Ventoy USB drive partitions (ISO Partition & Software Partition).
    Validates administrative privileges, locates partition drive letters via MD5 marker files
    or explicit CLI flags (-i ISO:SOFTWARE), copies Ventoy configuration and Unattend templates
    to the ISO partition, executes full AutoIt script compilation, and deploys all application
    directories and root binaries to the Software partition.

.PARAMETER InputDrives
    (-i, --input) Explicitly specify target partition drive letters or volume labels
    in the format: <ISO_PARTITION>:<SOFTWARE_PARTITION> (e.g. -i I:S or -i VENTOY:SOFTWARE).
    Prompts for user confirmation if either target resolves to local drive C: or D:.

.PARAMETER DryRun
    (-d, --dry-run) Simulates the deployment process, showing planned file operations,
    target drive locations, and potential errors without modifying the USB drive.

.PARAMETER Log
    (-l, --log) Streams detailed live log output to the console during execution.

.PARAMETER Version
    (-v, --version) Displays tool version (v1.0.0) and author information.

.PARAMETER Help
    (-h, --help) Displays help documentation and usage examples.

.PARAMETER NoPrompt
    Suppresses the interactive 'Press Enter to exit' prompt at completion (for automation/CI).

.EXAMPLE
    .\extract.ps1
    # Standard automated deployment with auto-detected USB partitions

.EXAMPLE
    .\extract.ps1 -i I:S
    # Deploys explicitly to ISO partition I: and Software partition S:

.EXAMPLE
    .\extract.ps1 -i VENTOY:SOFTWARE --dry-run
    # Simulates deployment targeting volumes labeled VENTOY and SOFTWARE

.EXAMPLE
    .\extract.ps1 -i I:S -l
    # Deploys with live verbose streaming log output
#>

[CmdletBinding(PositionalBinding = $false)]
param(
    [Alias('i', 'input')]
    [string]$InputDrives = '',

    [Alias('d', 'dry-run')]
    [switch]$DryRun,

    [Alias('l')]
    [switch]$Log,

    [Alias('v')]
    [switch]$Version,

    [Alias('h', '?')]
    [switch]$Help,

    [switch]$NoPrompt,

    [Alias('no-prune')]
    [switch]$NoPrune,

    [string]$RootDir = '',

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$RemainingArgs
)

$ErrorActionPreference = 'Stop'

# Process remaining arguments for flexible CLI flag variations
if ($RemainingArgs -and $RemainingArgs.Count -gt 0) {
    $currentFlag = $null
    foreach ($arg in $RemainingArgs) {
        $lower = $arg.ToLowerInvariant()
        if ($lower -in @('-l', '--l', '-log', '--log')) {
            $Log = $true
            $currentFlag = $null
        } elseif ($lower -in @('-v', '--v', '-version', '--version')) {
            $Version = $true
            $currentFlag = $null
        } elseif ($lower -in @('-h', '--h', '-help', '--help', '-?')) {
            $Help = $true
            $currentFlag = $null
        } elseif ($lower -in @('-d', '--d', '-dry-run', '--dry-run', '-dryrun', '--dryrun')) {
            $DryRun = $true
            $currentFlag = $null
        } elseif ($lower -in @('-noprompt', '--noprompt', '-no-prompt', '--no-prompt')) {
            $NoPrompt = $true
            $currentFlag = $null
        } elseif ($lower -in @('-noprune', '--noprune', '-no-prune', '--no-prune')) {
            $NoPrune = $true
            $currentFlag = $null
        } elseif ($lower -in @('-i', '--i', '-input', '--input')) {
            $currentFlag = 'input'
        } elseif ($currentFlag -eq 'input') {
            $InputDrives = $arg
            $currentFlag = $null
        } elseif ($arg.StartsWith('-')) {
            $currentFlag = $null
        }
    }
}

$TOOL_NAME    = 'extract'
$TOOL_VERSION = '1.0.0'
$TOOL_AUTHOR  = 'NovWyatt'

# ------------------------------------------------------------------------------
# 1. Version Screen
# ------------------------------------------------------------------------------
if ($Version) {
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host " $TOOL_NAME - Ventoy USB Deployment & Extraction Utility" -ForegroundColor Cyan
    Write-Host " Version : $TOOL_VERSION" -ForegroundColor Green
    Write-Host " Author  : $TOOL_AUTHOR" -ForegroundColor Gray
    Write-Host "======================================================================" -ForegroundColor Cyan
    exit 0
}

# ------------------------------------------------------------------------------
# 2. Help Screen
# ------------------------------------------------------------------------------
if ($Help) {
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host " $TOOL_NAME (v$TOOL_VERSION) - Help & Usage Manual" -ForegroundColor Cyan
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host @"
USAGE:
    .\extract.ps1 [OPTIONS]

OPTIONS:
    -i,  --input <ISO:SOFT> Explicitly specify target partition drive letters or volume labels (e.g. -i I:S).
    -d,  --dry-run          Simulate extraction & show planned copy operations.
    -l,  --log              Stream live verbose log messages in the console.
    -v,  --version          Display tool version (v1.0.0) and author info.
    -h,  --help             Show this help screen.
    --no-prompt             Skip the 'Press Enter to exit' prompt upon completion.
    --no-prune              Keep files left by a previous deployment that this one no longer produces.

PARTITION MARKERS:
    - ISO Partition      : Identified by root marker '5b512ee8a59deb284ad0a6a035ba10b1.md5'
    - SOFTWARE Partition : Identified by root marker 'aea541d7f9574587656dc5125116e548.md5'

DEPLOYMENT FLOW:
    1. Verify Administrator privileges & locate USB partition drive letters.
    2. Copy '/ventoy' directory to the root of the ISO partition.
    3. Copy XML unattended templates from '/Unattend' to the root of the ISO partition.
    4. Compile AutoIt installer scripts via './compile-au2exe.ps1 -a'.
    5. Copy application folders (/Antivirus, /Browsers, /Drivers, /Environment,
       /Office, /Socials, /Tools, /Utilities) and root files to the SOFTWARE partition.
    6. Display vendor setup file download reminder.
    7. Wait for user confirmation before exiting.

EXAMPLES:
    # 1. Normal automated deployment with auto-detection
    .\extract.ps1

    # 2. Explicit drive letter targets
    .\extract.ps1 -i I:S

    # 3. Explicit volume label targets with dry-run
    .\extract.ps1 --input VENTOY:SOFTWARE --dry-run

    # 4. Deployment with live verbose console logs
    .\extract.ps1 -i I:S -l

"@ -ForegroundColor White
    exit 0
}

# ------------------------------------------------------------------------------
# 3. Root Directory Resolution & Logging Initialization
# ------------------------------------------------------------------------------
if ([string]::IsNullOrWhiteSpace($RootDir)) {
    if ($PSScriptRoot) {
        $RootDir = $PSScriptRoot
    } else {
        $RootDir = (Get-Location).Path
    }
}
$RootDir = (Resolve-Path -LiteralPath $RootDir).Path
$logPath = Join-Path $RootDir 'extract.log'

function Write-ExtractLog {
    param(
        [ValidateSet('INFO', 'WARN', 'ERROR', 'SUCCESS', 'DRY-RUN')]
        [string]$Level,
        [string]$Message,
        [ConsoleColor]$ConsoleColor = [ConsoleColor]::Gray
    )

    $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $logLine   = "[$timestamp] [$Level] $Message"
    try {
        Add-Content -LiteralPath $logPath -Value $logLine -Encoding UTF8 -ErrorAction SilentlyContinue
    } catch {}

    if ($Log -or $Level -in @('WARN', 'ERROR', 'SUCCESS')) {
        $color = switch ($Level) {
            'ERROR'   { [ConsoleColor]::Red }
            'WARN'    { [ConsoleColor]::Yellow }
            'SUCCESS' { [ConsoleColor]::Green }
            'DRY-RUN' { [ConsoleColor]::Cyan }
            default   { $ConsoleColor }
        }
        Write-Host "  [$Level] $Message" -ForegroundColor $color
    }
}

# ------------------------------------------------------------------------------
# 4. Administrator Privilege Check
# ------------------------------------------------------------------------------
function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    if ($identity.IsSystem) { return $true }
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Initialize fresh log session
"======================================================================" | Set-Content -LiteralPath $logPath -Encoding UTF8
" extract.ps1 (v$TOOL_VERSION) - Deployment Session Started at $(Get-Date)" | Add-Content -LiteralPath $logPath -Encoding UTF8
"======================================================================" | Add-Content -LiteralPath $logPath -Encoding UTF8

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host " $TOOL_NAME - Ventoy USB Deployment & Extraction Utility" -ForegroundColor Cyan
Write-Host " Root Dir : $RootDir" -ForegroundColor Gray
Write-Host " Log File : $logPath" -ForegroundColor Gray
if ($DryRun) {
    Write-Host " Mode     : DRY-RUN SIMULATION (No files will be modified)" -ForegroundColor Cyan
} else {
    Write-Host " Mode     : LIVE DEPLOYMENT" -ForegroundColor Green
}
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Administrator)) {
    if ($DryRun) {
        Write-ExtractLog WARN "Non-administrator execution detected (Allowed under Dry-Run simulation)."
        Write-Host "  [WARN] Running without Administrator privileges (Allowed under Dry-Run mode).`n" -ForegroundColor Yellow
    } else {
        Write-ExtractLog ERROR "Administrator privileges are required to deploy files to USB partitions."
        Write-Host "`n[ERROR] Administrator privileges are required. Please run PowerShell as Administrator.`n" -ForegroundColor Red
        exit 5
    }
}

# ------------------------------------------------------------------------------
# 5. Locate USB Partitions (via -i / --input flag OR auto-marker discovery)
# ------------------------------------------------------------------------------
$isoMarker      = '5b512ee8a59deb284ad0a6a035ba10b1.md5'
$softwareMarker = 'aea541d7f9574587656dc5125116e548.md5'

$repoDriveRoot  = [System.IO.Path]::GetPathRoot($RootDir).TrimEnd('\')
$isoRoot        = $null
$softwareRoot   = $null

function Resolve-PartitionDrive {
    param([string]$Target)

    if ([string]::IsNullOrWhiteSpace($Target)) { return $null }
    $clean = $Target.Trim().TrimEnd('\').TrimEnd('/')
    
    # Check if single letter or drive letter (e.g. 'I' or 'I:')
    if ($clean -match '^[a-zA-Z]:?$') {
        $letter = $clean.Substring(0, 1).ToUpperInvariant()
        return "$letter`:"
    }

    # Check by Volume FileSystemLabel exact match
    $vol = Get-Volume -FileSystemLabel $clean -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($vol -and $vol.DriveLetter) {
        return "$($vol.DriveLetter):"
    }

    # Check by partial Volume FileSystemLabel match
    $allVols = Get-Volume -ErrorAction SilentlyContinue
    foreach ($v in $allVols) {
        if ($v.FileSystemLabel -and ($v.FileSystemLabel -like "*$clean*" -or $clean -like "*$($v.FileSystemLabel)*")) {
            if ($v.DriveLetter) {
                return "$($v.DriveLetter):"
            }
        }
    }

    return $null
}

Write-Host "[STEP 1/5] Identifying target USB partitions..." -ForegroundColor Cyan

if (-not [string]::IsNullOrWhiteSpace($InputDrives)) {
    # --------------------------------------------------------------------------
    # Explicit Input Mode (-i / --input <ISO>:<SOFTWARE>)
    # --------------------------------------------------------------------------
    Write-ExtractLog INFO "Processing explicit partition targets from CLI flag: '$InputDrives'."
    $raw = $InputDrives.Trim()
    $tokens = @()
    if ($raw -match '^(.*?):+(.*)$') {
        $tokens = @($Matches[1].TrimEnd(':').Trim(), $Matches[2].TrimEnd(':').Trim())
    }

    if ($tokens.Count -ne 2 -or [string]::IsNullOrWhiteSpace($tokens[0]) -or [string]::IsNullOrWhiteSpace($tokens[1])) {
        $errMsg = "Invalid input partition format: '$InputDrives'. Expected format: <ISO_PARTITION>:<SOFTWARE_PARTITION> (e.g. -i I:S or -i VENTOY:SOFTWARE)."
        Write-ExtractLog ERROR $errMsg
        Write-Host "`n[ERROR] $errMsg`n" -ForegroundColor Red
        exit 1
    }

    $isoRoot      = Resolve-PartitionDrive $tokens[0]
    $softwareRoot = Resolve-PartitionDrive $tokens[1]

    if (-not $isoRoot) {
        if ($DryRun) {
            $isoRoot = "$($tokens[0].Substring(0, 1).ToUpperInvariant()):"
        } else {
            $errMsg = "Target ISO partition '$($tokens[0])' could not be resolved to an active drive letter."
            Write-ExtractLog ERROR $errMsg
            Write-Host "`n[ERROR] $errMsg`n" -ForegroundColor Red
            exit 1
        }
    }

    if (-not $softwareRoot) {
        if ($DryRun) {
            $softwareRoot = "$($tokens[1].Substring(0, 1).ToUpperInvariant()):"
        } else {
            $errMsg = "Target SOFTWARE partition '$($tokens[1])' could not be resolved to an active drive letter."
            Write-ExtractLog ERROR $errMsg
            Write-Host "`n[ERROR] $errMsg`n" -ForegroundColor Red
            exit 1
        }
    }
} else {
    # --------------------------------------------------------------------------
    # Auto-Discovery Mode (Probing connected drives)
    # --------------------------------------------------------------------------
    Write-ExtractLog INFO "Scanning filesystem drives (excluding local repo drive '$repoDriveRoot\') for markers."

    $allDrives = Get-PSDrive -PSProvider FileSystem | 
                 Where-Object { $_.Root -and (Test-Path -LiteralPath $_.Root) }

    $externalDrives = @($allDrives | Where-Object { $_.Root.TrimEnd('\') -ne $repoDriveRoot })

    # Pass 1: Direct Marker Search on External/USB Drives
    foreach ($drive in $externalDrives) {
        $dRoot = $drive.Root.TrimEnd('\')
        
        # Check for ISO marker
        if (-not $isoRoot -and (Test-Path -LiteralPath (Join-Path $drive.Root $isoMarker))) {
            $isoRoot = $dRoot
        }

        # Check for Software marker
        if (-not $softwareRoot -and (Test-Path -LiteralPath (Join-Path $drive.Root $softwareMarker))) {
            $softwareRoot = $dRoot
        }
    }

    # Pass 2: Auto-Detection via Volume Label / Ventoy Structure if markers not yet created on USB
    if (-not $isoRoot -or -not $softwareRoot) {
        foreach ($drive in $externalDrives) {
            $dRoot = $drive.Root.TrimEnd('\')
            
            # Detect ISO partition by Ventoy directory or volume label
            if (-not $isoRoot) {
                $isVentoyDir = Test-Path -LiteralPath (Join-Path $drive.Root 'ventoy')
                $isVentoyIso = Test-Path -LiteralPath (Join-Path $drive.Root 'Windows')
                $vol = Get-Volume -DriveLetter $drive.Name -ErrorAction SilentlyContinue
                $isVentoyLabel = $vol -and ($vol.FileSystemLabel -match 'VENTOY|ISO')

                if ($isVentoyDir -or $isVentoyIso -or $isVentoyLabel) {
                    $isoRoot = $dRoot
                    Write-ExtractLog INFO "Auto-detected Ventoy ISO partition at '$isoRoot\' based on volume signatures."
                }
            }

            # Detect SOFTWARE partition by volume label or AutoInstaller markers
            if (-not $softwareRoot -and $dRoot -ne $isoRoot) {
                $vol = Get-Volume -DriveLetter $drive.Name -ErrorAction SilentlyContinue
                $isSoftwareLabel = $vol -and ($vol.FileSystemLabel -match 'SOFTWARE|APPS|AUTOINSTALLER')
                $isSoftwareApps  = (Test-Path -LiteralPath (Join-Path $drive.Root 'install-apps.ini')) -or
                                   (Test-Path -LiteralPath (Join-Path $drive.Root 'Auto-installer.exe'))

                if ($isSoftwareLabel -or $isSoftwareApps) {
                    $softwareRoot = $dRoot
                    Write-ExtractLog INFO "Auto-detected SOFTWARE partition at '$softwareRoot\' based on volume signatures."
                }
            }
        }
    }
}

# Dry-run fallback simulation if USB is not physically attached during dry-run preview
if ($DryRun) {
    if (-not $isoRoot) {
        $isoRoot = "I:"
        Write-ExtractLog DRY-RUN "Simulated ISO Partition at '$isoRoot\' (Marker '$isoMarker')"
    }
    if (-not $softwareRoot) {
        $softwareRoot = "S:"
        Write-ExtractLog DRY-RUN "Simulated SOFTWARE Partition at '$softwareRoot\' (Marker '$softwareMarker')"
    }
}

# ------------------------------------------------------------------------------
# Safety Validations & C: / D: Confirmation Prompt
# ------------------------------------------------------------------------------
if ($isoRoot -and $isoRoot -eq $repoDriveRoot) {
    $errMsg = "Safety Violation: ISO Partition cannot be the same as the local repository drive ($repoDriveRoot\)."
    Write-ExtractLog ERROR $errMsg
    Write-Host "`n[ERROR] $errMsg`n" -ForegroundColor Red
    exit 1
}

if ($softwareRoot -and $softwareRoot -eq $repoDriveRoot) {
    $errMsg = "Safety Violation: SOFTWARE Partition cannot be the same as the local repository drive ($repoDriveRoot\)."
    Write-ExtractLog ERROR $errMsg
    Write-Host "`n[ERROR] $errMsg`n" -ForegroundColor Red
    exit 1
}

if ($isoRoot -and $softwareRoot -and $isoRoot -eq $softwareRoot) {
    $errMsg = "Safety Violation: ISO Partition ($isoRoot\) and SOFTWARE Partition ($softwareRoot\) cannot point to the same drive."
    Write-ExtractLog ERROR $errMsg
    Write-Host "`n[ERROR] $errMsg`n" -ForegroundColor Red
    exit 1
}

$missingMarkers = @()
if (-not $isoRoot) { $missingMarkers += "ISO Partition marker '$isoMarker'" }
if (-not $softwareRoot) { $missingMarkers += "SOFTWARE Partition marker '$softwareMarker'" }

if ($missingMarkers.Count -gt 0) {
    $errMsg = "Missing target partition(s): $($missingMarkers -join ', '). Ensure the Ventoy USB is plugged in or specify target drives explicitly via -i ISO:SOFTWARE (e.g. -i I:S)."
    Write-ExtractLog ERROR $errMsg
    Write-Host "`n[ERROR] $errMsg`n" -ForegroundColor Red
    exit 1
}

# Safety prompt if C: or D: drive is targeted
$isDangerous = ($isoRoot -match '^[CcDd]:') -or ($softwareRoot -match '^[CcDd]:')
if ($isDangerous) {
    Write-Host @"

======================================================================
 [WARNING] POTENTIALLY DANGEROUS TARGET PARTITION DETECTED
======================================================================
 One or more targeted partitions resolves to local system drive C: or D::
   - ISO Partition      : $isoRoot\
   - SOFTWARE Partition : $softwareRoot\

 Extracting to a local system drive may overwrite important system files!
======================================================================
"@ -ForegroundColor Yellow

    if (-not $DryRun) {
        $confirm = Read-Host -Prompt "Are you absolutely sure you want to proceed? (Type 'y' or 'yes' to continue)"
        if ($confirm.Trim().ToLowerInvariant() -notin @('y', 'yes')) {
            Write-Host "`n[ABORTED] Deployment cancelled by user.`n" -ForegroundColor Yellow
            Write-ExtractLog WARN "Deployment cancelled by user upon C:/D: drive warning prompt."
            exit 0
        }
        Write-ExtractLog WARN "User explicitly confirmed deployment to local C:/D: drive ($isoRoot / $softwareRoot)."
    }
}

# Auto-create marker files on target partitions if missing (Live mode only)
if (-not $DryRun) {
    $isoMarkerPath = Join-Path "$isoRoot\" $isoMarker
    if (-not (Test-Path -LiteralPath $isoMarkerPath)) {
        try {
            New-Item -ItemType File -Path $isoMarkerPath -Force -ErrorAction SilentlyContinue | Out-Null
            Write-ExtractLog SUCCESS "Created missing ISO marker '$isoMarker' at '$isoRoot\'"
        } catch {}
    }
    $softMarkerPath = Join-Path "$softwareRoot\" $softwareMarker
    if (-not (Test-Path -LiteralPath $softMarkerPath)) {
        try {
            New-Item -ItemType File -Path $softMarkerPath -Force -ErrorAction SilentlyContinue | Out-Null
            Write-ExtractLog SUCCESS "Created missing SOFTWARE marker '$softwareMarker' at '$softwareRoot\'"
        } catch {}
    }
}

Write-Host ("  [TARGET] ISO Partition      : {0}\ ({1})" -f $isoRoot, $isoMarker) -ForegroundColor Green
Write-Host ("  [TARGET] SOFTWARE Partition : {0}\ ({1})" -f $softwareRoot, $softwareMarker) -ForegroundColor Green
Write-ExtractLog INFO "Confirmed ISO partition at '$isoRoot\' and SOFTWARE partition at '$softwareRoot\'."

$totalOperations = 0
$successCount    = 0
$failCount       = 0
$taskResults     = [System.Collections.Generic.List[pscustomobject]]::new()

# Every file this run places on the USB, recorded so the next run can tell the
# difference between "this used to be ours and is gone from the repo" and "the
# user put this here". Vendor setup binaries, driver packs, font files and
# Windows ISOs never enter this list and are therefore never pruned.
$script:DeployedFiles = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$manifestName = '.autoinstaller-deploy.txt'

function Register-DeployedFile {
    param([string] $Path)
    if ($Path) { [void] $script:DeployedFiles.Add(([System.IO.Path]::GetFullPath($Path))) }
}

function Copy-DeployDirectory {
    param(
        [string]$SourceDir,
        [string]$DestinationDir,
        [string]$Description
    )

    $script:totalOperations++
    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    if (-not (Test-Path -LiteralPath $SourceDir)) {
        Write-ExtractLog WARN "Source directory not found: $SourceDir"
        $script:taskResults.Add([pscustomobject]@{
            Step   = $Description
            Target = $DestinationDir
            Status = 'SKIPPED (Source missing)'
            TimeMs = 0
        })
        return
    }

    if ($DryRun) {
        $sw.Stop()
        # Register even when simulating: otherwise the prune preview below sees an
        # empty plan and announces that everything this run redeploys is stale.
        foreach ($f in (Get-ChildItem -LiteralPath $SourceDir -Recurse -File -Force -ErrorAction SilentlyContinue)) {
            Register-DeployedFile (Join-Path $DestinationDir $f.FullName.Substring($SourceDir.Length).TrimStart('\', '/'))
        }
        Write-Host ("  [DRY-RUN] Directory: {0} -> {1}" -f $SourceDir, $DestinationDir) -ForegroundColor Cyan
        Write-ExtractLog DRY-RUN "Copy directory: '$SourceDir' -> '$DestinationDir'"
        $script:taskResults.Add([pscustomobject]@{
            Step   = $Description
            Target = $DestinationDir
            Status = 'DRY-RUN'
            TimeMs = 0
        })
        $script:successCount++
        return
    }

    try {
        if (-not (Test-Path -LiteralPath $DestinationDir)) {
            $null = New-Item -ItemType Directory -Path $DestinationDir -Force -ErrorAction SilentlyContinue
        }
        Copy-Item -Path (Join-Path $SourceDir '*') -Destination $DestinationDir -Recurse -Force -ErrorAction Stop
        foreach ($f in (Get-ChildItem -LiteralPath $SourceDir -Recurse -File -Force -ErrorAction SilentlyContinue)) {
            $relative = $f.FullName.Substring($SourceDir.Length).TrimStart('\', '/')
            Register-DeployedFile (Join-Path $DestinationDir $relative)
        }
        $sw.Stop()
        Write-Host ("  [SUCCESS] {0} -> {1} ({2} ms)" -f $Description, $DestinationDir, $sw.ElapsedMilliseconds) -ForegroundColor Green
        Write-ExtractLog SUCCESS "Copied directory '$SourceDir' to '$DestinationDir' in $($sw.ElapsedMilliseconds) ms"
        $script:taskResults.Add([pscustomobject]@{
            Step   = $Description
            Target = $DestinationDir
            Status = 'SUCCESS'
            TimeMs = $sw.ElapsedMilliseconds
        })
        $script:successCount++
    } catch {
        $sw.Stop()
        Write-Host ("  [FAILED]  {0} -> {1}: {2}" -f $Description, $DestinationDir, $_.Exception.Message) -ForegroundColor Red
        Write-ExtractLog ERROR "Failed copying directory '$SourceDir' to '$DestinationDir': $($_.Exception.Message)"
        $script:taskResults.Add([pscustomobject]@{
            Step   = $Description
            Target = $DestinationDir
            Status = 'FAILED'
            TimeMs = $sw.ElapsedMilliseconds
        })
        $script:failCount++
    }
}

function Copy-DeployFiles {
    param(
        [string]$SourcePattern,
        [string]$DestinationDir,
        [string]$Description
    )

    $script:totalOperations++
    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    $matchingFiles = @(Get-ChildItem -Path $SourcePattern -File -ErrorAction SilentlyContinue)
    if ($matchingFiles.Count -eq 0) {
        Write-ExtractLog WARN "No files matched pattern: $SourcePattern"
        $script:taskResults.Add([pscustomobject]@{
            Step   = $Description
            Target = $DestinationDir
            Status = 'SKIPPED (No files)'
            TimeMs = 0
        })
        return
    }

    if ($DryRun) {
        $sw.Stop()
        foreach ($file in $matchingFiles) { Register-DeployedFile (Join-Path $DestinationDir $file.Name) }
        Write-Host ("  [DRY-RUN] Files ({0} items): {1} -> {2}" -f $matchingFiles.Count, $SourcePattern, $DestinationDir) -ForegroundColor Cyan
        Write-ExtractLog DRY-RUN "Copy $($matchingFiles.Count) file(s) matching '$SourcePattern' to '$DestinationDir'"
        $script:taskResults.Add([pscustomobject]@{
            Step   = $Description
            Target = $DestinationDir
            Status = 'DRY-RUN'
            TimeMs = 0
        })
        $script:successCount++
        return
    }

    try {
        if (-not (Test-Path -LiteralPath $DestinationDir)) {
            $null = New-Item -ItemType Directory -Path $DestinationDir -Force -ErrorAction SilentlyContinue
        }
        foreach ($file in $matchingFiles) {
            $target = Join-Path $DestinationDir $file.Name
            Copy-Item -LiteralPath $file.FullName -Destination $target -Force -ErrorAction Stop
            Register-DeployedFile $target
        }
        $sw.Stop()
        Write-Host ("  [SUCCESS] {0} ({1} file(s)) -> {2} ({3} ms)" -f $Description, $matchingFiles.Count, $DestinationDir, $sw.ElapsedMilliseconds) -ForegroundColor Green
        Write-ExtractLog SUCCESS "Copied $($matchingFiles.Count) file(s) to '$DestinationDir' in $($sw.ElapsedMilliseconds) ms"
        $script:taskResults.Add([pscustomobject]@{
            Step   = $Description
            Target = $DestinationDir
            Status = 'SUCCESS'
            TimeMs = $sw.ElapsedMilliseconds
        })
        $script:successCount++
    } catch {
        $sw.Stop()
        Write-Host ("  [FAILED]  {0}: {1}" -f $Description, $_.Exception.Message) -ForegroundColor Red
        Write-ExtractLog ERROR "Failed copying files from '$SourcePattern' to '$DestinationDir': $($_.Exception.Message)"
        $script:taskResults.Add([pscustomobject]@{
            Step   = $Description
            Target = $DestinationDir
            Status = 'FAILED'
            TimeMs = $sw.ElapsedMilliseconds
        })
        $script:failCount++
    }
}

# ------------------------------------------------------------------------------
# 6. Step 2: Deploy /ventoy to ISO Partition
# ------------------------------------------------------------------------------
Write-Host "`n[STEP 2/5] Deploying Ventoy configuration to ISO partition..." -ForegroundColor Cyan
$ventoySrc = Join-Path $RootDir 'ventoy'
$ventoyDst = Join-Path $isoRoot 'ventoy'
Copy-DeployDirectory -SourceDir $ventoySrc -DestinationDir $ventoyDst -Description "Ventoy Folder (/ventoy)"

# Automatically rename/initialize ventoy.json from ventoy.json.example on ISO partition
$dstExampleJson = Join-Path $ventoyDst 'ventoy.json.example'
$dstVentoyJson  = Join-Path $ventoyDst 'ventoy.json'

if ($DryRun) {
    Register-DeployedFile $dstVentoyJson
    Write-Host ("  [DRY-RUN] Config Rename: {0}\ventoy.json.example -> {0}\ventoy.json" -f $ventoyDst) -ForegroundColor Cyan
    Write-ExtractLog DRY-RUN "Simulated renaming of 'ventoy.json.example' to 'ventoy.json' in '$ventoyDst'."
} else {
    if (Test-Path -LiteralPath $dstExampleJson) {
        if (-not (Test-Path -LiteralPath $dstVentoyJson)) {
            try {
                Copy-Item -LiteralPath $dstExampleJson -Destination $dstVentoyJson -Force -ErrorAction Stop
                Register-DeployedFile $dstVentoyJson
                Write-Host ("  [SUCCESS] Renamed ventoy.json.example -> ventoy.json in {0}" -f $ventoyDst) -ForegroundColor Green
                Write-ExtractLog SUCCESS "Initialized 'ventoy.json' from 'ventoy.json.example' in '$ventoyDst'."
            } catch {
                Write-Host ("  [WARN]  Failed initializing ventoy.json: {0}" -f $_.Exception.Message) -ForegroundColor Yellow
                Write-ExtractLog WARN "Failed initializing ventoy.json: $($_.Exception.Message)"
            }
        }
    }
}

# ------------------------------------------------------------------------------
# 7. Step 3: Deploy /Unattend XMLs to Root of ISO Partition
# ------------------------------------------------------------------------------
Write-Host "`n[STEP 3/5] Deploying Unattend XML templates to root of ISO partition..." -ForegroundColor Cyan
$unattendSrc = Join-Path $RootDir 'Unattend\*.xml'
Copy-DeployFiles -SourcePattern $unattendSrc -DestinationDir $isoRoot -Description "Unattend XML Templates"

# ------------------------------------------------------------------------------
# 8. Step 4: Recompile AutoIt Scripts
# ------------------------------------------------------------------------------
Write-Host "`n[STEP 4/5] Compiling AutoIt3 executables..." -ForegroundColor Cyan
$compilerScript = Join-Path $RootDir 'compile-au2exe.ps1'
if (Test-Path -LiteralPath $compilerScript) {
    $compileSw = [System.Diagnostics.Stopwatch]::StartNew()
    $compileArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$compilerScript`"", '-a')
    if ($DryRun) { $compileArgs += '--dry-run' }
    if ($Log)    { $compileArgs += '-l' }

    Write-ExtractLog INFO "Executing compilation utility: $compilerScript -a $(if ($DryRun) { '--dry-run' })"
    
    $proc = Start-Process -FilePath "powershell.exe" -ArgumentList ($compileArgs -join ' ') -NoNewWindow -PassThru -Wait
    $compileSw.Stop()
    
    if ($proc.ExitCode -eq 0) {
        Write-Host ("  [SUCCESS] AutoIt scripts recompiled successfully ({0} ms)" -f $compileSw.ElapsedMilliseconds) -ForegroundColor Green
        Write-ExtractLog SUCCESS "Au2exe compilation completed successfully in $($compileSw.ElapsedMilliseconds) ms"
        $script:taskResults.Add([pscustomobject]@{
            Step   = 'Compile AutoIt Executables (-a)'
            Target = 'Workspace Root'
            Status = $(if ($DryRun) { 'DRY-RUN' } else { 'SUCCESS' })
            TimeMs = $compileSw.ElapsedMilliseconds
        })
        $script:successCount++
    } else {
        Write-Host ("  [FAILED]  Compilation utility returned non-zero exit code: {0}" -f $proc.ExitCode) -ForegroundColor Red
        Write-ExtractLog ERROR "Au2exe compilation failed with exit code $($proc.ExitCode)"
        $script:taskResults.Add([pscustomobject]@{
            Step   = 'Compile AutoIt Executables (-a)'
            Target = 'Workspace Root'
            Status = "FAILED ($($proc.ExitCode))"
            TimeMs = $compileSw.ElapsedMilliseconds
        })
        $script:failCount++
    }
} else {
    Write-ExtractLog WARN "Compilation utility '$compilerScript' not found."
}

# ------------------------------------------------------------------------------
# 9. Step 5: Deploy Folders and Assets to SOFTWARE Partition
# ------------------------------------------------------------------------------
Write-Host "`n[STEP 5/5] Deploying application packages and scripts to SOFTWARE partition..." -ForegroundColor Cyan

# Application directories to copy
$appFolders = @(
    'Antivirus',
    'Browsers',
    'Drivers',
    'Environment',
    'Office',
    'Socials',
    'Tools',
    'Utilities'
)

foreach ($folder in $appFolders) {
    $src = Join-Path $RootDir $folder
    $dst = Join-Path $softwareRoot $folder
    if (Test-Path -LiteralPath $src) {
        Copy-DeployDirectory -SourceDir $src -DestinationDir $dst -Description "App Folder (/$folder)"
    }
}

# Root files to copy: *.exe, *.ico, *.png, *.ini and the runtime *.ps1, plus the
# marker md5. Build tooling is deliberately left behind -- it only runs on the
# workstation, and shipping it would put a deployment script on every machine
# this USB installs.
$rootExtensions = @('*.exe', '*.ico', '*.png', '*.ini', '*.ps1')
$excludedFromUsb = @('extract.ps1', 'compile-au2exe.ps1')
$rootFiles = @()
foreach ($ext in $rootExtensions) {
    $rootFiles += Get-ChildItem -Path $RootDir -Filter $ext -File -Force -ErrorAction SilentlyContinue |
                  Where-Object { $excludedFromUsb -notcontains $_.Name }
}

# Include software marker md5
$markerPath = Join-Path $RootDir $softwareMarker
if (Test-Path -LiteralPath $markerPath) {
    $rootFiles += Get-Item -LiteralPath $markerPath -Force -ErrorAction SilentlyContinue
}

if ($rootFiles.Count -gt 0) {
    $script:totalOperations++
    $rootFilesSw = [System.Diagnostics.Stopwatch]::StartNew()
    
    if ($DryRun) {
        $rootFilesSw.Stop()
        foreach ($rf in $rootFiles) { Register-DeployedFile (Join-Path $softwareRoot $rf.Name) }
        Write-Host ("  [DRY-RUN] Root Assets ({0} file(s)) -> {1}\" -f $rootFiles.Count, $softwareRoot) -ForegroundColor Cyan
        Write-ExtractLog DRY-RUN "Copy $($rootFiles.Count) root asset file(s) to '$softwareRoot\'"
        $script:taskResults.Add([pscustomobject]@{
            Step   = "Root Scripts & Binaries"
            Target = "$softwareRoot\"
            Status = 'DRY-RUN'
            TimeMs = 0
        })
        $script:successCount++
    } else {
        try {
            foreach ($rf in $rootFiles) {
                $target = Join-Path $softwareRoot $rf.Name
                Copy-Item -LiteralPath $rf.FullName -Destination $target -Force -ErrorAction Stop
                Register-DeployedFile $target
            }
            $rootFilesSw.Stop()
            Write-Host ("  [SUCCESS] Root Scripts & Binaries ({0} file(s)) -> {1}\ ({2} ms)" -f $rootFiles.Count, $softwareRoot, $rootFilesSw.ElapsedMilliseconds) -ForegroundColor Green
            Write-ExtractLog SUCCESS "Copied $($rootFiles.Count) root files to '$softwareRoot\' in $($rootFilesSw.ElapsedMilliseconds) ms"
            $script:taskResults.Add([pscustomobject]@{
                Step   = "Root Scripts & Binaries"
                Target = "$softwareRoot\"
                Status = 'SUCCESS'
                TimeMs = $rootFilesSw.ElapsedMilliseconds
            })
            $script:successCount++
        } catch {
            $rootFilesSw.Stop()
            Write-Host ("  [FAILED]  Root Scripts & Binaries -> {0}\: {1}" -f $softwareRoot, $_.Exception.Message) -ForegroundColor Red
            Write-ExtractLog ERROR "Failed copying root files to '$softwareRoot\': $($_.Exception.Message)"
            $script:taskResults.Add([pscustomobject]@{
                Step   = "Root Scripts & Binaries"
                Target = "$softwareRoot\"
                Status = 'FAILED'
                TimeMs = $rootFilesSw.ElapsedMilliseconds
            })
            $script:failCount++
        }
    }
}

# ------------------------------------------------------------------------------
# 10. Prune files left by a previous deployment
# ------------------------------------------------------------------------------
# Copy-Item overwrites but never removes, so anything this project stopped
# shipping stays on the USB forever -- a renamed theme folder, a deleted script,
# an answer file that no longer exists. Mirroring the tree would fix that and
# would also delete every vendor setup binary, driver pack and font the user put
# there by hand, none of which live in the repository.
#
# So instead each run records exactly what it placed, and the next run removes
# only what the *previous* run placed and this one did not. A file the user
# supplied was never in a manifest and can never be selected for deletion.

function Invoke-StalePrune {
    param([string] $PartitionRoot, [string] $Label)

    $manifestPath = Join-Path "$PartitionRoot\" $manifestName

    $rootFull = [System.IO.Path]::GetFullPath("$PartitionRoot\")

    # Entries are stored relative to the partition root. Absolute paths would
    # stop matching the moment the stick came back as a different drive letter,
    # which silently disables pruning -- or, worse, could name a path on another
    # disk entirely. A rooted line is from the older format and is ignored.
    $previous = @()
    if (Test-Path -LiteralPath $manifestPath) {
        foreach ($line in (Get-Content -LiteralPath $manifestPath -Encoding UTF8 -ErrorAction SilentlyContinue)) {
            if (-not $line -or $line.StartsWith('#')) { continue }
            if ([System.IO.Path]::IsPathRooted($line)) {
                Write-ExtractLog WARN "Ignoring absolute manifest entry '$line' on $Label (older format)."
                continue
            }
            $previous += [System.IO.Path]::Combine($rootFull, $line)
        }
    }
    $stale = @($previous | Where-Object {
        $_ -and
        -not $script:DeployedFiles.Contains($_) -and
        $_.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase) -and
        (Test-Path -LiteralPath $_ -PathType Leaf)
    })

    if ($stale.Count -gt 0) {
        foreach ($path in $stale) {
            if ($DryRun) {
                Write-Host ("  [DRY-RUN] Prune stale: {0}" -f $path) -ForegroundColor Cyan
                Write-ExtractLog DRY-RUN "Would remove stale file '$path' on $Label"
            } else {
                try {
                    Remove-Item -LiteralPath $path -Force -ErrorAction Stop
                    Write-Host ("  [PRUNED]  {0}" -f $path) -ForegroundColor Yellow
                    Write-ExtractLog INFO "Removed stale file '$path' on $Label"
                } catch {
                    Write-ExtractLog WARN "Could not remove stale file '$path': $($_.Exception.Message)"
                }
            }
        }

        # Directories the pruning emptied are ours too; deepest first.
        if (-not $DryRun) {
            $dirs = $stale | ForEach-Object { Split-Path -Parent $_ } | Sort-Object -Unique |
                    Sort-Object -Property { $_.Length } -Descending
            foreach ($dir in $dirs) {
                while ($dir -and $dir.StartsWith($rootFull.TrimEnd('\'), [System.StringComparison]::OrdinalIgnoreCase) -and
                       $dir.TrimEnd('\') -ne $rootFull.TrimEnd('\') -and
                       (Test-Path -LiteralPath $dir) -and
                       -not (Get-ChildItem -LiteralPath $dir -Force -ErrorAction SilentlyContinue)) {
                    Remove-Item -LiteralPath $dir -Force -ErrorAction SilentlyContinue
                    Write-ExtractLog INFO "Removed emptied directory '$dir' on $Label"
                    $dir = Split-Path -Parent $dir
                }
            }
        }
    }

    Write-Host ("  [{0}] {1}: {2} file(s) deployed, {3} stale removed" -f `
        $(if ($DryRun) { 'DRY-RUN' } else { 'PRUNE' }), $Label,
        @($script:DeployedFiles | Where-Object { $_.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase) }).Count,
        $stale.Count) -ForegroundColor Gray

    # Record this run for the next one.
    if (-not $DryRun) {
        $lines = @(
            "# AutoInstaller-Win deployment manifest -- generated by extract.ps1",
            "# Files listed here were placed by the last deployment and may be removed",
            "# by the next one. Do not add anything by hand.",
            "# $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        ) + @($script:DeployedFiles |
              Where-Object { $_.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase) } |
              ForEach-Object { $_.Substring($rootFull.Length) } |
              Sort-Object)
        try {
            Set-Content -LiteralPath $manifestPath -Value $lines -Encoding UTF8 -ErrorAction Stop
            (Get-Item -LiteralPath $manifestPath -Force).Attributes = 'Hidden'
        } catch {
            Write-ExtractLog WARN "Could not write the deployment manifest to '$manifestPath': $($_.Exception.Message)"
        }
    }
}

Write-Host "`n[CLEANUP] Removing files left by previous deployments..." -ForegroundColor Cyan
if ($NoPrune) {
    Write-Host "  [SKIP]    --no-prune given; stale files are left in place." -ForegroundColor Yellow
    Write-ExtractLog INFO 'Pruning skipped (--no-prune).'
} else {
    Invoke-StalePrune -PartitionRoot $isoRoot      -Label 'ISO partition'
    Invoke-StalePrune -PartitionRoot $softwareRoot -Label 'SOFTWARE partition'
}

# ------------------------------------------------------------------------------
# 11. Summary Table & Vendor Download Reminder
# ------------------------------------------------------------------------------
Write-Host "`n======================================================================" -ForegroundColor Cyan
Write-Host " Deployment Summary" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan
foreach ($r in $script:taskResults) {
    $statColor = switch -Regex ($r.Status) {
        'SUCCESS' { [ConsoleColor]::Green }
        'DRY-RUN' { [ConsoleColor]::Cyan }
        'SKIPPED' { [ConsoleColor]::Yellow }
        default   { [ConsoleColor]::Red }
    }
    Write-Host ("  {0,-35} | {1,-18} | {2}" -f $r.Step, $r.Status, $r.Target) -ForegroundColor $statColor
}
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host (" Total Tasks: {0} | Success: {1} | Failed: {2}" -f $script:taskResults.Count, $script:successCount, $script:failCount) -ForegroundColor $(if ($script:failCount -eq 0) { 'Green' } else { 'Red' })
Write-Host "======================================================================" -ForegroundColor Cyan

# Step 6: Download Reminder
Write-Host @"

======================================================================
 [NOTICE] VENDOR SETUP FILES DOWNLOAD REMINDER
======================================================================
 Please ensure you have manually downloaded and placed the required
 vendor installation binaries into their respective folders on the
 SOFTWARE partition as configured in 'install-apps.ini'.
======================================================================
"@ -ForegroundColor Yellow

Write-ExtractLog INFO "Deployment completed. Total tasks: $($script:taskResults.Count), Success: $script:successCount, Failed: $script:failCount."

# Step 7: Press Enter to exit
if (-not $NoPrompt -and -not $DryRun) {
    Write-Host ""
    $null = Read-Host -Prompt "Press Enter to exit"
}

if ($script:failCount -gt 0) {
    exit 1
}
exit 0

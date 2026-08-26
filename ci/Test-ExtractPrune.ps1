<#
.SYNOPSIS
    Regression test for extract.ps1's stale-file pruning.

.DESCRIPTION
    extract.ps1 removes files a previous deployment left behind. The failure mode
    if that goes wrong is not a broken build -- it is deleting the vendor setup
    binaries, driver packs, font files and Windows ISOs the user downloaded onto
    the USB by hand, none of which live in this repository and none of which can
    be recovered by re-running anything.

    The safety property is: a file is only ever deleted if the *previous*
    deployment recorded placing it. Anything the user supplied was never in a
    manifest, so it can never be selected. This test builds a fake partition
    holding both kinds of file and asserts exactly that.

    Invoke-StalePrune is lifted out of extract.ps1 by parsing it, so the test
    always exercises the shipped implementation rather than a copy.

.EXAMPLE
    .\ci\Test-ExtractPrune.ps1
#>
[CmdletBinding()]
param(
    [string] $RepositoryRoot
)

$ErrorActionPreference = 'Stop'

# $PSScriptRoot is empty in a param() default under [CmdletBinding()] + -File.
$here = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $RepositoryRoot) { $RepositoryRoot = Split-Path -Parent $here }

$extractPath = Join-Path $RepositoryRoot 'extract.ps1'
$lab = Join-Path ([System.IO.Path]::GetTempPath()) ("autoinstaller-prunetest-" + [System.Guid]::NewGuid().ToString('N').Substring(0, 8))

# ---- lift the implementation out of extract.ps1 ------------------------------
$ast = [System.Management.Automation.Language.Parser]::ParseInput(
    (Get-Content -LiteralPath $extractPath -Raw), [ref] $null, [ref] $null)
$wanted = @('Invoke-StalePrune', 'Register-DeployedFile')
$found = $ast.FindAll({ param($n)
    $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $wanted -contains $n.Name }, $true)
if ($found.Count -ne $wanted.Count) {
    Write-Host "FAIL: extract.ps1 no longer defines $($wanted -join ' and ')" -ForegroundColor Red
    exit 1
}
$found | ForEach-Object { Invoke-Expression $_.Extent.Text }

# ---- the ambient state those functions expect --------------------------------
$manifestName = '.autoinstaller-deploy.txt'
$DryRun = $false
function Write-ExtractLog { param($Level, $Message) }

$script:results = @()
function Assert {
    param([string] $Name, [bool] $Condition)
    $script:results += [pscustomobject]@{ Check = $Name; Result = $(if ($Condition) { 'PASS' } else { 'FAIL' }) }
}

function Reset-Lab {
    if (Test-Path -LiteralPath $lab) { Remove-Item -LiteralPath $lab -Recurse -Force }
    New-Item -ItemType Directory -Path "$lab\Browsers" -Force | Out-Null
    New-Item -ItemType Directory -Path "$lab\ventoy\theme\oldname" -Force | Out-Null
    New-Item -ItemType Directory -Path "$lab\Windows" -Force | Out-Null

    # placed by the previous deployment
    Set-Content "$lab\Browsers\install_chrome-standalone.exe" 'deployed' -Encoding ascii
    Set-Content "$lab\ventoy\theme\oldname\theme.txt"         'deployed' -Encoding ascii
    Set-Content "$lab\update_logs.ps1"                        'deployed' -Encoding ascii

    # supplied by the user -- never recorded in any manifest
    Set-Content "$lab\Browsers\chrome-standalone.exe"         'VENDOR SETUP' -Encoding ascii
    Set-Content "$lab\Browsers\my-notes.txt"                  'USER FILE'    -Encoding ascii
    Set-Content "$lab\Windows\win11.iso"                      'USER ISO'     -Encoding ascii
}

# Entries are stored relative to the partition root so a change of drive
# letter cannot silently disable pruning, or point it at another disk.
function Write-Manifest {
    param([string[]] $RelativePaths)
    Set-Content -LiteralPath (Join-Path "$lab\" $manifestName) `
                -Value (@('# manifest') + $RelativePaths) `
                -Encoding UTF8
}

function New-DeploySet {
    param([string[]] $Paths)
    $script:DeployedFiles = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($p in $Paths) { Register-DeployedFile $p }
}

try {
    # === the repository dropped two files since the last deployment ===========
    Reset-Lab
    Write-Manifest @(
        'Browsers\install_chrome-standalone.exe',
        'ventoy\theme\oldname\theme.txt',
        'update_logs.ps1')
    New-DeploySet @("$lab\Browsers\install_chrome-standalone.exe")
    Invoke-StalePrune -PartitionRoot $lab -Label 'test' | Out-Null

    Assert 'stale file from a renamed folder is removed' (-not (Test-Path "$lab\ventoy\theme\oldname\theme.txt"))
    Assert 'stale file from a deleted script is removed' (-not (Test-Path "$lab\update_logs.ps1"))
    Assert 'emptied directory is cleaned up'             (-not (Test-Path "$lab\ventoy\theme\oldname"))
    Assert 'still-deployed file is kept'                 (Test-Path "$lab\Browsers\install_chrome-standalone.exe")
    Assert 'VENDOR SETUP BINARY IS KEPT'                 (Test-Path "$lab\Browsers\chrome-standalone.exe")
    Assert 'USER FILE IS KEPT'                           (Test-Path "$lab\Browsers\my-notes.txt")
    Assert 'WINDOWS ISO IS KEPT'                         (Test-Path "$lab\Windows\win11.iso")
    Assert 'vendor binary content is untouched'          ((Get-Content "$lab\Browsers\chrome-standalone.exe") -eq 'VENDOR SETUP')

    $manifest = @(Get-Content -LiteralPath (Join-Path "$lab\" $manifestName) -Force |
                  Where-Object { -not $_.StartsWith('#') })
    Assert 'new manifest lists only this run''s files' ($manifest.Count -eq 1 -and $manifest[0] -like '*install_chrome-standalone.exe')

    # === a manifest naming something outside the partition ====================
    Reset-Lab
    $outside = Join-Path ([System.IO.Path]::GetTempPath()) 'autoinstaller-prunetest-outside.txt'
    Set-Content $outside 'must not be touched' -Encoding ascii
    # Both entries are absolute, which is the older manifest format: the one
    # outside the partition must never be touched, and the one inside is
    # ignored too rather than trusted on a possibly different disk.
    Set-Content -LiteralPath (Join-Path "$lab\" $manifestName) `
                -Value @('# manifest', [System.IO.Path]::GetFullPath($outside), [System.IO.Path]::GetFullPath("$lab\update_logs.ps1")) `
                -Encoding UTF8
    New-DeploySet @()
    Invoke-StalePrune -PartitionRoot $lab -Label 'test' | Out-Null

    Assert 'legacy manifest: outside path untouched' (Test-Path $outside)
    Assert 'legacy manifest: inside path untouched'  (Test-Path "$lab\update_logs.ps1")
    Remove-Item $outside -Force -ErrorAction SilentlyContinue

    # === dry run must not delete ==============================================
    Reset-Lab
    Write-Manifest @('update_logs.ps1')
    New-DeploySet @()
    $DryRun = $true
    Invoke-StalePrune -PartitionRoot $lab -Label 'test' | Out-Null
    Assert 'dry run deletes nothing' (Test-Path "$lab\update_logs.ps1")
    $DryRun = $false
}
finally {
    if (Test-Path -LiteralPath $lab) { Remove-Item -LiteralPath $lab -Recurse -Force -ErrorAction SilentlyContinue }
}

foreach ($r in $script:results) {
    $colour = if ($r.Result -eq 'PASS') { 'DarkGray' } else { 'Red' }
    Write-Host ("  [{0}] {1}" -f $r.Result.PadLeft(4), $r.Check) -ForegroundColor $colour
}

$failed = @($script:results | Where-Object { $_.Result -ne 'PASS' })
if ($failed.Count -gt 0) {
    Write-Host ""
    Write-Host ("{0} of {1} prune checks failed." -f $failed.Count, $script:results.Count) -ForegroundColor Red
    exit 1
}
Write-Host ""
Write-Host ("All {0} prune checks passed." -f $script:results.Count) -ForegroundColor Green
exit 0

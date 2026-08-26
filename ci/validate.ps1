<#
.SYNOPSIS
    Validates every source file in the repository that can be checked without a
    Windows install or a vendor binary.

.DESCRIPTION
    "Running" this project means reinstalling Windows, so almost nothing about it
    is testable in the usual sense. What is testable is that the files it ships
    are well-formed and internally consistent, which is where most of the bugs
    found so far actually lived: invalid JSON that Ventoy silently ignored,
    .gitignore rules that excluded more than half the repository, an unreachable
    error branch in fifteen installers.

    Checks performed:
      1. Unattend and Office XML answer files parse
      2. Ventoy example configs are valid JSON
      3. Every .ps1 parses
      4. Every .au3 is structurally sound (block/quote balance, resolvable calls)
      5. Every #include path resolves on disk
      6. The committed Unattend answer files still match their template
      7. The committed GRUB theme files still match their template
      8. extract.ps1 prunes only what it deployed, never the user's own files
      9. No tracked file is excluded by the .gitignore rules

    AutoIt cannot be installed on a CI runner, so check 4 stands in for the
    compiler. It is not a parser: it verifies block balance, quote balance, that
    every _Name() call and Call("_Name") dispatch resolves against the file or
    the library it includes, and that no Global is read before its declaration
    runs -- including through a function that startup code calls too early,
    which AutoIt accepts silently and which inverted a guard here once.

.PARAMETER Path
    Repository root. Defaults to the parent of this script's folder.

.EXAMPLE
    .\ci\validate.ps1
#>
[CmdletBinding()]
param(
    [string] $Path
)

$ErrorActionPreference = 'Stop'

# Windows PowerShell leaves $PSScriptRoot empty inside a param() default when the
# script both declares [CmdletBinding()] and is launched with -File, which is how
# CI runs it. Resolve the default here, where it is always populated.
if (-not $Path) {
    $here = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
    $Path = Split-Path -Parent $here
}
Set-Location -LiteralPath $Path

$script:Failures = [System.Collections.Generic.List[string]]::new()

function Write-Result {
    param([string] $Name, [bool] $Ok, [string] $Detail = '')
    $tag = if ($Ok) { '  ok  ' } else { ' FAIL ' }
    $colour = if ($Ok) { 'DarkGray' } else { 'Red' }
    Write-Host ("[{0}] {1}{2}" -f $tag, $Name, $(if ($Detail) { " -- $Detail" } else { '' })) -ForegroundColor $colour
    if (-not $Ok) { $script:Failures.Add("$Name -- $Detail") }
}

function Start-Section {
    param([string] $Title)
    Write-Host ""
    Write-Host "== $Title" -ForegroundColor Cyan
}

# ==============================================================================
#  AutoIt structural checker
# ==============================================================================

# Opening keyword -> the keyword that closes it.
$script:Au3Blocks = @{
    'func' = 'endfunc'; 'if' = 'endif'; 'while' = 'wend'; 'for' = 'next'
    'do' = 'until'; 'select' = 'endselect'; 'switch' = 'endswitch'; 'with' = 'endwith'
}

function Remove-Au3Noise {
    <# Strips quoted strings and a trailing comment; reports an unclosed quote. #>
    param([string] $Line)
    $sb = [System.Text.StringBuilder]::new()
    $quote = $null
    for ($i = 0; $i -lt $Line.Length; $i++) {
        $c = $Line[$i]
        if ($quote) {
            if ($c -eq $quote) {
                # a doubled quote inside a string is an escaped quote
                if ($i + 1 -lt $Line.Length -and $Line[$i + 1] -eq $quote) { $i++; continue }
                $quote = $null
            }
            continue
        }
        if ($c -eq '"' -or $c -eq "'") { $quote = $c; [void] $sb.Append(' '); continue }
        if ($c -eq ';') { break }
        [void] $sb.Append($c)
    }
    return [pscustomobject]@{ Text = $sb.ToString(); Unterminated = ($null -ne $quote) }
}

function Get-Au3LogicalLine {
    <# Joins AutoIt's " _" line continuations. #>
    param([string[]] $Lines)
    $out = [System.Collections.Generic.List[pscustomobject]]::new()
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        $start = $i + 1
        $buf = $Lines[$i]
        while ($buf -match '\s_\s*$' -and $i + 1 -lt $Lines.Count) {
            $buf = ($buf -replace '\s_\s*$', ' ') + $Lines[$i + 1]
            $i++
        }
        $out.Add([pscustomobject]@{ Line = $start; Source = $buf })
    }
    return $out
}

function Test-Au3File {
    param([string] $File, [System.Collections.Generic.HashSet[string]] $ExtraNames)

    $text = [System.IO.File]::ReadAllText($File, [System.Text.UTF8Encoding]::new($false))
    $lines = ($text -replace "`r`n", "`n") -split "`n"

    $problems = [System.Collections.Generic.List[string]]::new()
    $stack = [System.Collections.Generic.Stack[object]]::new()
    $defined = [System.Collections.Generic.HashSet[string]]::new()
    $called = [System.Collections.Generic.List[object]]::new()

    # AutoIt creates a variable on first use unless MustDeclareVars is on, so a
    # Global whose declaration sits below code that already reads it does not
    # fail -- the early read just sees an empty value, which silently inverts a
    # boolean guard. The read is usually not lexically above the Global either:
    # it is inside a function that script-scope code calls too early. So track
    # where each Global is declared, which functions read it, and where script
    # scope calls those functions.
    $globalDecl     = @{}   # $name -> line of its Global
    $scriptUse      = @{}   # $name -> first script-scope line that reads it
    $funcReads      = @{}   # func  -> set of $names it reads
    $funcLocals     = @{}   # func  -> set of $names it declares locally
    $scriptCalls    = [System.Collections.Generic.List[object]]::new()  # (line, func)
    $currentFunc    = $null

    foreach ($entry in (Get-Au3LogicalLine $lines)) {
        $clean = Remove-Au3Noise $entry.Source
        if ($clean.Unterminated) { $problems.Add("line $($entry.Line): unbalanced quote") }

        $s = $clean.Text.Trim()
        if (-not $s -or $s.StartsWith('#')) { continue }
        $low = $s.ToLowerInvariant()
        $head = if ($low -match '^([a-z]+)\b') { $Matches[1] } else { '' }

        if ($head -eq 'func') {
            if ($s -match '(?i)^func\s+([A-Za-z0-9_]+)') { [void] $defined.Add($Matches[1].ToLowerInvariant()) }
            $stack.Push(@('func', $entry.Line))
        }
        elseif ($head -eq 'if') {
            # a single-line "If ... Then <statement>" opens no block
            if (-not ($low -match '\bthen\b\s*\S')) { $stack.Push(@('if', $entry.Line)) }
        }
        elseif ('while', 'select', 'switch', 'with', 'do', 'for' -contains $head) {
            $stack.Push(@($head, $entry.Line))
        }
        elseif ($script:Au3Blocks.Values -contains $head) {
            if ($stack.Count -eq 0) {
                $problems.Add("line $($entry.Line): $head without a matching opener")
            } else {
                $open = $stack.Pop()
                if ($script:Au3Blocks[$open[0]] -ne $head) {
                    $problems.Add("line $($entry.Line): $head closes $($open[0]) opened at line $($open[1])")
                }
            }
        }
        elseif ($head -eq 'else' -or $head -eq 'elseif') {
            if ($stack.Count -eq 0 -or $stack.Peek()[0] -ne 'if') {
                $problems.Add("line $($entry.Line): $head outside an If block")
            }
        }

        # "Script scope" means "not inside a Func" -- not "not inside a block".
        # Startup code lives inside If blocks, and that is exactly where the
        # too-early call sits.
        if ($head -eq 'func' -and $s -match '(?i)^func\s+([A-Za-z0-9_]+)') {
            $currentFunc = $Matches[1].ToLowerInvariant()
            $funcReads[$currentFunc]  = [System.Collections.Generic.HashSet[string]]::new()
            $funcLocals[$currentFunc] = [System.Collections.Generic.HashSet[string]]::new()
            foreach ($m in [regex]::Matches($s, '(\$[A-Za-z0-9_]+)')) {
                [void] $funcLocals[$currentFunc].Add($m.Groups[1].Value.ToLowerInvariant())
            }
        }
        elseif ($head -eq 'endfunc') {
            $currentFunc = $null
        }
        elseif ($null -eq $currentFunc) {
            $declLine = $null
            if ($s -match '(?i)^global\s+(const\s+)?(\$[A-Za-z0-9_]+)') {
                $declared = $Matches[2].ToLowerInvariant()
                if (-not $globalDecl.ContainsKey($declared)) { $globalDecl[$declared] = $entry.Line }
                $declLine = $declared
            }
            foreach ($m in [regex]::Matches($s, '(\$[A-Za-z0-9_]+)')) {
                $name = $m.Groups[1].Value.ToLowerInvariant()
                if ($name -eq $declLine) { continue }
                if (-not $scriptUse.ContainsKey($name)) { $scriptUse[$name] = $entry.Line }
            }
            foreach ($m in [regex]::Matches($s, '(?<![A-Za-z0-9_$@.])(_[A-Za-z0-9_]+)\s*\(')) {
                $scriptCalls.Add(@($entry.Line, $m.Groups[1].Value.ToLowerInvariant()))
            }
        }
        elseif ($currentFunc) {
            if ($s -match '(?i)^\s*(local|const|dim)\s+(\$[A-Za-z0-9_]+)') {
                [void] $funcLocals[$currentFunc].Add($Matches[2].ToLowerInvariant())
            }
            foreach ($m in [regex]::Matches($s, '(\$[A-Za-z0-9_]+)')) {
                [void] $funcReads[$currentFunc].Add($m.Groups[1].Value.ToLowerInvariant())
            }
        }

        foreach ($m in [regex]::Matches($s, '(?<![A-Za-z0-9_$@.])(_[A-Za-z0-9_]+)\s*\(')) {
            $called.Add(@($entry.Line, $m.Groups[1].Value.ToLowerInvariant()))
        }
        foreach ($m in [regex]::Matches($entry.Source, '(?i)Call\(\s*"(_[A-Za-z0-9_]+)"')) {
            $called.Add(@($entry.Line, $m.Groups[1].Value.ToLowerInvariant()))
        }
    }

    foreach ($open in $stack) { $problems.Add("line $($open[1]): unclosed $($open[0]) block") }

    foreach ($name in $globalDecl.Keys) {
        $declaredAt = $globalDecl[$name]

        # read directly, above its own declaration
        if ($scriptUse.ContainsKey($name) -and $scriptUse[$name] -lt $declaredAt) {
            $problems.Add(("line {0}: {1} is read at script scope before its Global on line {2}" -f $scriptUse[$name], $name, $declaredAt))
            continue
        }

        # or read by a function that script scope calls before the declaration
        foreach ($call in $scriptCalls) {
            if ($call[0] -ge $declaredAt) { continue }
            $fn = $call[1]
            if (-not $funcReads.ContainsKey($fn)) { continue }
            if ($funcLocals[$fn].Contains($name)) { continue }   # shadowed locally
            if ($funcReads[$fn].Contains($name)) {
                $problems.Add(("line {0}: {1}() reads {2}, whose Global is only declared on line {3}" -f $call[0], $fn, $name, $declaredAt))
                break
            }
        }
    }

    $known = [System.Collections.Generic.HashSet[string]]::new($defined)
    if ($ExtraNames) { foreach ($n in $ExtraNames) { [void] $known.Add($n) } }
    foreach ($c in $called) {
        if (-not $known.Contains($c[1])) { $problems.Add("line $($c[0]): call to undefined function $($c[1])()") }
    }

    return [pscustomobject]@{ Problems = $problems; Defined = $defined }
}

# ==============================================================================
#  Checks
# ==============================================================================

Write-Host "AutoInstaller-Win -- repository validation" -ForegroundColor Cyan
Write-Host ("Root: {0}" -f (Get-Location).Path) -ForegroundColor DarkGray

# ---- 1. XML -------------------------------------------------------------
Start-Section 'XML answer files and Office configs'
foreach ($file in (Get-ChildItem -Path 'Unattend', 'Office' -Filter '*.xml' -Recurse -File)) {
    # The disk-*.xml fragments are spliced into the template, not documents in
    # their own right: they have no root element and use the wcm prefix declared
    # by their host. Wrap them so they still get checked for well-formedness.
    $isFragment = $file.DirectoryName.EndsWith('template') -and $file.Name.StartsWith('disk-')
    try {
        $doc = [xml]::new()
        if ($isFragment) {
            $body = Get-Content -LiteralPath $file.FullName -Raw
            if ([string]::IsNullOrWhiteSpace($body)) {
                Write-Result "$($file.Name) (fragment, empty)" $true
                continue
            }
            $doc.LoadXml('<fragment xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">' + $body + '</fragment>')
            Write-Result "$($file.Name) (fragment)" $true
        } else {
            $doc.Load($file.FullName)
            Write-Result $file.Name $true
        }
    } catch {
        Write-Result $file.Name $false $_.Exception.Message
    }
}

# ---- 2. JSON ------------------------------------------------------------
Start-Section 'Ventoy example configs'
foreach ($file in (Get-ChildItem -Path 'ventoy' -Filter '*.json.example' -File)) {
    try {
        $null = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
        Write-Result $file.Name $true
    } catch {
        Write-Result $file.Name $false $_.Exception.Message
    }
}

# ---- 3. PowerShell ------------------------------------------------------
Start-Section 'PowerShell scripts'
foreach ($file in (Get-ChildItem -Filter '*.ps1' -Recurse -File | Where-Object { $_.FullName -notmatch '\\\.git\\' })) {
    $errors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref] $null, [ref] $errors)
    if ($errors) {
        Write-Result $file.Name $false ("line {0}: {1}" -f $errors[0].Extent.StartLineNumber, $errors[0].Message)
    } else {
        Write-Result $file.Name $true
    }
}

# ---- 4. AutoIt ----------------------------------------------------------
Start-Section 'AutoIt scripts'
$libraryPath = Join-Path (Get-Location) '_installer_common.au3'
$libraryNames = $null
if (Test-Path -LiteralPath $libraryPath) {
    $libraryNames = (Test-Au3File -File $libraryPath -ExtraNames $null).Defined
}
foreach ($file in (Get-ChildItem -Filter '*.au3' -Recurse -File | Where-Object { $_.FullName -notmatch '\\\.git\\' })) {
    $text = Get-Content -LiteralPath $file.FullName -Raw
    $extra = if ($text -match '(?i)#include\s+"[^"]*_installer_common\.au3"') { $libraryNames } else { $null }
    $result = Test-Au3File -File $file.FullName -ExtraNames $extra
    if ($result.Problems.Count -gt 0) {
        Write-Result $file.Name $false ($result.Problems -join '; ')
    } else {
        Write-Result $file.Name $true
    }
}

# ---- 5. Includes --------------------------------------------------------
Start-Section 'Include paths'
$includeCount = 0
$includeBad = 0
foreach ($file in (Get-ChildItem -Filter '*.au3' -Recurse -File | Where-Object { $_.FullName -notmatch '\\\.git\\' })) {
    $text = Get-Content -LiteralPath $file.FullName -Raw
    foreach ($m in [regex]::Matches($text, '(?i)#include\s+"([^"]+)"')) {
        $includeCount++
        $target = Join-Path (Split-Path -Parent $file.FullName) $m.Groups[1].Value
        if (-not (Test-Path -LiteralPath $target)) {
            $includeBad++
            Write-Result "$($file.Name) -> $($m.Groups[1].Value)" $false 'not found'
        }
    }
}
Write-Result "$includeCount relative include(s) resolve" ($includeBad -eq 0)

# ---- 6. Unattend template drift ----------------------------------------
Start-Section 'Unattend answer files match their template'
$builder = Join-Path (Get-Location) 'Unattend\build-unattend.ps1'
if (Test-Path -LiteralPath $builder) {
    $output = & $builder -Check 2>&1
    $ok = ($LASTEXITCODE -eq 0)
    if (-not $ok) { $output | ForEach-Object { Write-Host "    $_" -ForegroundColor Red } }
    Write-Result 'build-unattend.ps1 -Check' $ok $(if ($ok) { '' } else { 'answer files are out of date' })
} else {
    Write-Result 'build-unattend.ps1' $false 'not found'
}

# ---- 7. GRUB theme drift ------------------------------------------------
Start-Section 'GRUB theme files match their template'
$themeBuilder = Join-Path (Get-Location) 'ventoy\theme\build-theme.ps1'
if (Test-Path -LiteralPath $themeBuilder) {
    $output = & $themeBuilder -Check 2>&1
    $ok = ($LASTEXITCODE -eq 0)
    if (-not $ok) { $output | ForEach-Object { Write-Host "    $_" -ForegroundColor Red } }
    Write-Result 'build-theme.ps1 -Check' $ok $(if ($ok) { '' } else { 'theme files are out of date' })
} else {
    Write-Result 'build-theme.ps1' $false 'not found'
}

# ---- 8. extract.ps1 stale-file pruning ----------------------------------
Start-Section 'extract.ps1 pruning keeps user-supplied files'
$pruneTest = Join-Path (Get-Location) 'ci\Test-ExtractPrune.ps1'
if (Test-Path -LiteralPath $pruneTest) {
    $output = & $pruneTest 2>&1
    $ok = ($LASTEXITCODE -eq 0)
    if (-not $ok) { $output | ForEach-Object { Write-Host "    $_" -ForegroundColor Red } }
    Write-Result 'Test-ExtractPrune.ps1' $ok $(if ($ok) { '' } else { 'pruning would remove files it does not own' })
} else {
    Write-Result 'Test-ExtractPrune.ps1' $false 'not found'
}

# ---- 9. .gitignore does not exclude tracked files -----------------------
Start-Section '.gitignore keeps every tracked file'
$tracked = @(& git ls-files)
if ($LASTEXITCODE -ne 0) {
    Write-Result 'git ls-files' $false 'not a git checkout'
} else {
    # Not --stdin: PowerShell terminates piped lines with CRLF, and the stray
    # CR becomes part of the path, so nothing matches its keep rule and every
    # file looks excluded. Passing the list as arguments avoids that entirely.
    $ignored = @(& git check-ignore --no-index -- @tracked 2>$null)
    if ($ignored.Count -gt 0) {
        Write-Result "$($tracked.Count) tracked file(s)" $false ("{0} excluded by .gitignore, e.g. {1}" -f $ignored.Count, $ignored[0])
    } else {
        Write-Result "$($tracked.Count) tracked file(s), none excluded" $true
    }
}

# ==============================================================================
Write-Host ""
if ($script:Failures.Count -gt 0) {
    Write-Host ("{0} check(s) failed:" -f $script:Failures.Count) -ForegroundColor Red
    $script:Failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}
Write-Host "All checks passed." -ForegroundColor Green
exit 0

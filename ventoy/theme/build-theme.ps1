<#
.SYNOPSIS
    Generates the eighteen GRUB2 theme files from one template.

.DESCRIPTION
    The theme ships eighteen .txt files, one per combination of:

      ratio      169 | 43 | 1610      decides the geometry
      style      dark | light         picks the background art
      artwork    fb | gh | htc        picks the background art

    Only the geometry actually varies between them; style and artwork change
    nothing but which background image is named. Editing a colour or a menu
    position by hand therefore meant eighteen identical edits.

    Everything the menu looks like other than the text, the icons and the
    selection pill is painted into the background JPEG -- the card, the sidebar,
    the bottom key hints. Changing the layout here without redrawing the art to
    match will put the text somewhere the card is not. See README.md.

.PARAMETER Check
    Compare against the files on disk instead of writing, and exit 1 on any
    difference. Used by ci/validate.ps1.

.EXAMPLE
    .\build-theme.ps1
#>
[CmdletBinding()]
param(
    [switch] $Check
)

$ErrorActionPreference = 'Stop'

# $PSScriptRoot is empty inside a param() default when a script declares
# [CmdletBinding()] and is launched with -File, so resolve paths here.
$here = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$templatePath = Join-Path $here 'template\theme.template.txt'
$outputDir    = Join-Path $here 'autoinstaller'

# ------------------------------------------------------------------------------
# Variant tables
# ------------------------------------------------------------------------------

# Geometry is the only thing that genuinely differs, and it depends on the aspect
# ratio alone. 4:3 gives the menu more width and a wider row because the screen
# is shorter; 16:10 keeps 16:9's terminal box but 4:3's row height.
$ratios = [ordered] @{
    '169'  = @{ Label = '16:9';  TerminalLeft = '15%'; TerminalTop = '16%'; TerminalWidth = '55%'
                MenuLeft = '18%'; MenuWidth = '50%'; IconSize = 76; LabelLeft = '30%'; LabelWidth = '36%' }
    '43'   = @{ Label = '4:3';   TerminalLeft = '6%';  TerminalTop = '18%'; TerminalWidth = '60%'
                MenuLeft = '8%';  MenuWidth = '65%'; IconSize = 84; LabelLeft = '24%'; LabelWidth = '43%' }
    '1610' = @{ Label = '16:10'; TerminalLeft = '15%'; TerminalTop = '16%'; TerminalWidth = '55%'
                MenuLeft = '16%'; MenuWidth = '52%'; IconSize = 84; LabelLeft = '28%'; LabelWidth = '32%' }
}

# The menu card is dark in both styles -- "light" only lightens the area around
# it -- so the text colours are shared. Redrawing the art with a light card is
# what would make these differ.
$styles = [ordered] @{
    'dark'  = @{ Label = 'Dark';  ItemColor = '#6C6E70'; SelectedItemColor = '#CDCDCD' }
    'light' = @{ Label = 'Light'; ItemColor = '#6C6E70'; SelectedItemColor = '#CDCDCD' }
}

$artworks = @('fb', 'gh', 'htc')

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------

# The theme files are UTF-8 without a BOM and use CRLF.
function Read-TextFile {
    param([string] $Path)
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        $bytes = $bytes[3..($bytes.Length - 1)]
    }
    return ([System.Text.Encoding]::UTF8.GetString($bytes)) -replace "`r`n", "`n"
}

function ConvertTo-FileBytes {
    param([string] $Text)
    return ([System.Text.UTF8Encoding]::new($false)).GetBytes(($Text -replace "`n", "`r`n"))
}

# ------------------------------------------------------------------------------
# Generate
# ------------------------------------------------------------------------------

if (-not (Test-Path -LiteralPath $templatePath)) { throw "Template not found: $templatePath" }
$template = Read-TextFile $templatePath

$stale = [System.Collections.Generic.List[string]]::new()
$written = 0

foreach ($styleName in $styles.Keys) {
    foreach ($ratioName in $ratios.Keys) {
        foreach ($art in $artworks) {
            $r = $ratios[$ratioName]
            $s = $styles[$styleName]

            $text = $template
            $text = $text.Replace('{{RATIO_LABEL}}', $r.Label)
            $text = $text.Replace('{{STYLE_LABEL}}', $s.Label)
            $text = $text.Replace('{{BACKGROUND}}', ("background_{0}{1}_{2}.jpg" -f $styleName, $ratioName, $art))
            $text = $text.Replace('{{TERMINAL_LEFT}}', $r.TerminalLeft)
            $text = $text.Replace('{{TERMINAL_TOP}}', $r.TerminalTop)
            $text = $text.Replace('{{TERMINAL_WIDTH}}', $r.TerminalWidth)
            $text = $text.Replace('{{MENU_LEFT}}', $r.MenuLeft)
            $text = $text.Replace('{{MENU_WIDTH}}', $r.MenuWidth)
            $text = $text.Replace('{{ICON_SIZE}}', $r.IconSize)
            $text = $text.Replace('{{LABEL_LEFT}}', $r.LabelLeft)
            $text = $text.Replace('{{LABEL_WIDTH}}', $r.LabelWidth)
            $text = $text.Replace('{{ITEM_COLOR}}', $s.ItemColor)
            $text = $text.Replace('{{SELECTED_ITEM_COLOR}}', $s.SelectedItemColor)

            $leftover = [regex]::Matches($text, '\{\{[A-Z_]+\}\}')
            if ($leftover.Count -gt 0) {
                throw "Unresolved placeholder(s): $(($leftover | ForEach-Object { $_.Value }) -join ', ')"
            }

            $name    = "theme_{0}{1}_{2}.txt" -f $styleName, $ratioName, $art
            $outPath = Join-Path $outputDir $name
            $bytes   = ConvertTo-FileBytes $text

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
                Write-Host ("  [write]  {0}" -f $name) -ForegroundColor Green
                $written++
            }
        }
    }
}

if ($Check) {
    if ($stale.Count -gt 0) {
        Write-Host ""
        Write-Host ("{0} theme file(s) do not match the template. Run build-theme.ps1 and commit the result." -f $stale.Count) -ForegroundColor Red
        exit 1
    }
    Write-Host ""
    Write-Host "All 18 theme files match the template." -ForegroundColor Green
    exit 0
}

Write-Host ""
Write-Host ("Generated {0} theme file(s)." -f $written) -ForegroundColor Cyan
exit 0

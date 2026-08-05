# Applies the whole stack on a fresh machine, in the order the pieces depend on
# each other. Run elevated: the Windhawk mod settings live under HKLM and the
# font is installed machine-wide.
#
#   .\install.ps1                 # font + taskbar + shell + zebar
#   .\install.ps1 -ApplyConfigs   # also overwrite the GlazeWM / Zebar configs
#   .\install.ps1 -SkipFont       # font already installed
param(
    [switch]$SkipFont,
    [switch]$ApplyConfigs
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

function Require($label, $test, $hint) {
    if (-not $test) { throw "$label não encontrado. $hint" }
    Write-Output "  ok  $label"
}

Write-Output 'checking prerequisites'
Require 'Windhawk'  (Test-Path 'HKLM:\SOFTWARE\Windhawk\Engine\Mods') 'https://windhawk.net'
Require 'Zebar'     (Test-Path (Join-Path $env:ProgramFiles 'glzr.io\Zebar\zebar.exe')) 'https://github.com/glzr-io/zebar'
Require 'GlazeWM'   (Test-Path (Join-Path $env:ProgramFiles 'glzr.io\GlazeWM\glazewm.exe')) 'https://github.com/glzr-io/glazewm'

# The stylers are what carry the theme; the metrics mods size the taskbar.
$mods = 'windows-11-taskbar-styler', 'windows-11-start-menu-styler',
        'windows-11-notification-center-styler', 'windows-11-file-explorer-styler',
        'taskbar-icon-size', 'taskbar-labels', 'taskbar-clock-customization'
$missing = $mods | Where-Object { -not (Test-Path "HKLM:\SOFTWARE\Windhawk\Engine\Mods\$_") }
if ($missing) {
    throw "mods do Windhawk faltando (instale pelo app, depois rode de novo): $($missing -join ', ')"
}
Write-Output "  ok  $($mods.Count) mods do Windhawk"

if (-not $SkipFont) {
    Write-Output 'installing Cascadia Mono'
    & "$root\scripts\install-font.ps1" -Name cascadia
}

if ($ApplyConfigs) {
    Write-Output 'copying GlazeWM / Zebar configs'
    $glzr = Join-Path $env:USERPROFILE '.glzr'
    New-Item "$glzr\glazewm", "$glzr\zebar" -ItemType Directory -Force | Out-Null
    Copy-Item "$root\config\glazewm\config.yaml" "$glzr\glazewm\" -Force
    Copy-Item "$root\config\zebar\*" "$glzr\zebar\" -Recurse -Force -Exclude 'marketplace'
}

Write-Output 'applying taskbar theme'
& "$root\scripts\windhawk-gruvvy-taskbar.ps1"

Write-Output 'applying start menu / notification center / explorer theme'
& "$root\scripts\windhawk-shell-style.ps1"

Write-Output 'patching the zebar pack'
& "$root\scripts\zebar-gruvvy-patch.ps1"

# The taskbar XAML caches the font collection at process start, so a freshly
# installed font only shows up after explorer is restarted.
Write-Output 'restarting explorer'
Stop-Process -Name explorer -Force
Write-Output 'done'

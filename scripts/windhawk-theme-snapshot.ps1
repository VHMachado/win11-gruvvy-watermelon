# Snapshot / restore the whole taskbar look (styler styles + the metrics that
# live in the sibling mods). Windhawk has no user theme slot - a real entry in
# the mod's theme dropdown means editing and recompiling the mod source, and it
# gets wiped on every mod update - so a named registry snapshot is the revert.
#
#   .\windhawk-theme-snapshot.ps1 -Name gruvvy-watermelon-v1
#   .\windhawk-theme-snapshot.ps1 -Name gruvvy-watermelon-v1 -Restore
param(
    [Parameter(Mandatory)][string]$Name,
    [switch]$Restore
)
$ErrorActionPreference = 'Stop'

$mods = 'windows-11-taskbar-styler', 'taskbar-icon-size', 'taskbar-labels',
        'taskbar-start-button-position', 'taskbar-clock-customization',
        'windows-11-start-menu-styler', 'windows-11-notification-center-styler',
        'windows-11-file-explorer-styler'
$dir  = Join-Path (Split-Path $PSScriptRoot -Parent) 'snapshots'
$file = Join-Path $dir "$Name.reg"

if ($Restore) {
    if (-not (Test-Path $file)) { throw "no snapshot named '$Name' in $dir" }
    # the mods keep settings as flat string values, so a plain import is enough;
    # values added after the snapshot are cleared first to avoid leftovers
    foreach ($mod in $mods) {
        Remove-Item "HKLM:\SOFTWARE\Windhawk\Engine\Mods\$mod\Settings" -Recurse -Force -ErrorAction SilentlyContinue
    }
    & reg.exe import $file 2>&1 | Out-Null
    foreach ($mod in $mods) {
        Set-ItemProperty "HKLM:\SOFTWARE\Windhawk\Engine\Mods\$mod" -Name 'SettingsChangeTime' -Value ([int][double]::Parse((Get-Date -UFormat %s)))
    }
    Write-Output "restored '$Name'"
} else {
    New-Item $dir -ItemType Directory -Force | Out-Null
    Remove-Item $file -ErrorAction SilentlyContinue
    foreach ($mod in $mods) {
        # a mod with default settings has no Settings key at all
        if (-not (Test-Path "HKLM:\SOFTWARE\Windhawk\Engine\Mods\$mod\Settings")) { continue }
        $tmp = "$file.$mod.tmp"
        & reg.exe export "HKLM\SOFTWARE\Windhawk\Engine\Mods\$mod\Settings" $tmp /y | Out-Null
        Get-Content $tmp | Where-Object { $_ -notmatch '^Windows Registry Editor' } | Add-Content $file
        Remove-Item $tmp
    }
    # reg import needs the header on the first line
    "Windows Registry Editor Version 5.00`r`n" + (Get-Content $file -Raw) | Set-Content $file
    Write-Output "saved '$Name' -> $file"
}

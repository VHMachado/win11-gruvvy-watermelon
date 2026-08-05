# Reverts windows-11-taskbar-styler to its previous state: theme "Matter", no custom styles.
$ErrorActionPreference = 'Stop'
$modKey = 'HKLM:\SOFTWARE\Windhawk\Engine\Mods\windows-11-taskbar-styler'
$setKey = "$modKey\Settings"

Remove-Item $setKey -Recurse -Force -ErrorAction SilentlyContinue
New-Item $setKey -Force | Out-Null

$defaults = @{
    'theme'                            = 'Matter'
    'controlStyles[0].target'          = ''
    'controlStyles[0].styles[0]'       = ''
    'styleConstants[0]'                = ''
    'resourceVariables[0].variableKey' = ''
    'resourceVariables[0].value'       = ''
    'themeResourceVariables[0]'        = ''
    'xamlDiagnosticsHandling'          = 'alert'
}
foreach ($k in $defaults.Keys) {
    New-ItemProperty $setKey -Name $k -Value $defaults[$k] -PropertyType String -Force | Out-Null
}

Set-ItemProperty $modKey -Name 'SettingsChangeTime' -Value ([int][double]::Parse((Get-Date -UFormat %s)))
Write-Output 'restored: theme = Matter'

# metrics the gruvvy script changed in the sibling mods, back to their originals
$metrics = @{
    'taskbar-icon-size' = @{ TaskbarHeight = 52; IconSize = 32; TaskbarButtonWidth = 44
                             TaskbarButtonWidthSmall = 32 }
    'taskbar-labels'    = @{ leftAndRightPaddingSize = 10; spaceBetweenIconAndLabel = 8
                             taskbarItemWidth = 140; maximumTaskbarItemWidth = 176 }
}
foreach ($mod in $metrics.Keys) {
    $k = "HKLM:\SOFTWARE\Windhawk\Engine\Mods\$mod"
    foreach ($name in $metrics[$mod].Keys) {
        Set-ItemProperty "$k\Settings" -Name $name -Value $metrics[$mod][$name]
    }
    Set-ItemProperty $k -Name 'SettingsChangeTime' -Value ([int][double]::Parse((Get-Date -UFormat %s)))
    Write-Output "restored metrics: $mod"
}

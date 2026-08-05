# Gruvvy-watermelon palette + CaskaydiaCove font for the rest of the shell:
# start menu, notification center, file explorer. Replaces the older
# windhawk-shell-font.ps1 - one script owns each mod's settings, otherwise the
# two would keep clobbering each other's controlStyles.
#
# Three different levers, because the three themes are built differently:
#
#   notification center (Matter)  - the theme's own style constants ($base,
#                                   $overlay, ...). User constants load after
#                                   the theme's and override by name, so
#                                   redefining five constants recolors ~30
#                                   rules for free.
#   file explorer (Matter)        - only has $accentColor/$accentColor2; the
#                                   rest of its surfaces come from system theme
#                                   resources, so those get overridden instead.
#   start menu (Everblush)        - literal hex all over its 32 rules and no
#                                   constants, so its rules are read straight
#                                   out of the mod source and re-emitted with
#                                   the hexes remapped onto our palette.
param(
    [string]$Font = 'Cascadia Mono',
    [switch]$Revert
)
$ErrorActionPreference = 'Stop'

# same values as the taskbar script
$base    = '273030'   # bar background
$overlay = '31413D'   # raised surface
$active  = '33564E'   # pressed / selected
$border  = '8EB5AA'
$accent  = '4FB094'   # watermelon
$mint    = '80E5B3'
$peach   = 'EEA48D'
$lav     = 'C7B2FF'
$text    = 'DFECE8'
$muted   = '5C7F76'

# Everblush hex -> ours, by role. Alpha prefixes are handled by matching the
# last six digits, so #d28ccf7e follows #8ccf7e.
$remap = [ordered]@{
    '141b1e' = $base; '232a2d' = $overlay; '8ccf7e' = $accent
    'b3b9b8' = $text; 'e5c76b' = $peach;   '6cbfbf' = $mint
    '67b0e8' = $lav
}

# Surfaces that come from system resources rather than from a theme constant.
# Overriding these recolors the acrylic tints, the selection accent and the
# default text color in one go.
$resources = @(
    "ContentControlThemeFontFamily=$Font"
    "XamlAutoFontFamily=$Font"
    "SystemAltLowColor=#$base"
    "SystemChromeLowColor=#$base"
    "SystemChromeMediumColor=#$overlay"
    "LayerFillColorDefault=#$overlay"
    "CardStrokeColorDefaultSolid=#$border"
    "SystemAccentColor=#$accent"
    "SystemAccentColorLight1=#$accent"
    "SystemAccentColorLight2=#$mint"
    "SystemAccentColorDark1=#$active"
    "TextFillColorPrimary=#$text"
    "TextFillColorSecondary=#$border"
    "TextOnAccentFillColorPrimary=#$base"
    "ControlStrokeColorDefault=#$border"
)

# Font rules, unchanged from windhawk-shell-font.ps1 and its two dead ends:
# root-frame inheritance does nothing (every template sets its own FontFamily),
# and a bare TextBlock rule needs the icon fonts handed back afterwards.
$fontRules = @(
    # comma list = fallback for codepoints the font has no glyph for
    @{ t = 'TextBlock';                             s = @("FontFamily=$Font, Segoe Fluent Icons") },
    @{ t = 'FontIcon > TextBlock';                  s = @('FontFamily=Segoe Fluent Icons') },
    @{ t = 'FontIcon > Grid > TextBlock';           s = @('FontFamily=Segoe Fluent Icons') },
    @{ t = 'SymbolIcon > TextBlock';                s = @('FontFamily=Segoe MDL2 Assets') },
    # calendar month arrows are plain TextBlocks carrying a glyph - with our
    # font they came out as random Nerd Font symbols, not as boxes
    @{ t = 'Button#PreviousButton > * > TextBlock'; s = @('FontFamily=Segoe Fluent Icons') },
    @{ t = 'Button#NextButton > * > TextBlock';     s = @('FontFamily=Segoe Fluent Icons') }
)

# The 2px #8EB5AA stroke the taskbar pills and the zebar bar carry, extended to
# the shell surfaces. Applied after the recolored theme rules so it wins over
# whatever border the theme set (Everblush draws a translucent one).
# Targets that don't exist on a given surface simply never match.
$borderRules = @(
    # AcrylicOverlay sits on top of AcrylicBorder and its background eats the
    # inner half of the stroke, so both carry it
    @{ t = 'Border#AcrylicBorder';        s = @("BorderBrush=#$border", 'BorderThickness=2', 'CornerRadius=20') },
    @{ t = 'Border#AcrylicOverlay';       s = @("BorderBrush=#$border", 'BorderThickness=2', 'CornerRadius=20') },
    @{ t = 'Grid#NotificationCenterGrid'; s = @("BorderBrush=#$border", 'BorderThickness=2') },
    @{ t = 'Grid#CalendarCenterGrid';     s = @("BorderBrush=#$border", 'BorderThickness=2') },
    @{ t = 'Grid#ControlCenterRegion';    s = @("BorderBrush=#$border", 'BorderThickness=2') },
    # context menus and flyouts, present in all three surfaces
    @{ t = 'MenuFlyoutPresenter';         s = @("BorderBrush=#$border", 'BorderThickness=2', 'CornerRadius=12') },
    @{ t = 'FlyoutPresenter';             s = @("BorderBrush=#$border", 'BorderThickness=2', 'CornerRadius=12') }
)

# Pull a theme's rules out of the mod source and recolor them. The mod applies
# its theme first and the user's controlStyles after, so these win.
function Get-RecoloredTheme($modName, $themeVar, $map) {
    $src = (Join-Path $env:ProgramData "Windhawk\ModsSource\$modName.wh.cpp")
    $text = [IO.File]::ReadAllText($src)
    $start = $text.IndexOf("const Theme $themeVar = {{")
    if ($start -lt 0) { throw "theme $themeVar not found in $modName" }
    # the struct closes with `}};`, and the next theme starts right after - stop
    # at that, or the parser swallows every theme below it
    $end = $text.IndexOf("`nconst Theme ", $start + 1)
    if ($end -lt 0) { $end = $text.Length }
    $block = $text.Substring($start, $end - $start)

    $rules = @()
    foreach ($m in [regex]::Matches($block, 'ThemeTargetStyles\{L"((?:[^"\\]|\\.)*)",\s*\{(.*?)\}\}', 'Singleline')) {
        $target = $m.Groups[1].Value -replace '\\"', '"'
        $styles = @()
        foreach ($s in [regex]::Matches($m.Groups[2].Value, 'L"((?:[^"\\]|\\.)*)"')) {
            $style = $s.Groups[1].Value -replace '\\"', '"'
            if ($style -notmatch '#[0-9a-fA-F]{6}') { continue }   # colors only, the theme keeps its geometry
            foreach ($k in $map.Keys) { $style = $style -replace "(?i)$k", $map[$k] }
            $styles += $style
        }
        if ($styles) { $rules += @{ t = $target; s = $styles } }
    }
    $rules
}

$plan = @{
    'windows-11-notification-center-styler' = @{
        constants = @(
            "base = <SolidColorBrush Color=`"#F2$base`"/>"
            "overlay = <SolidColorBrush Color=`"#FF$overlay`"/>"
            "overlay2 = <SolidColorBrush Color=`"#FF$active`"/>"
            "accentColor = <SolidColorBrush Color=`"#$accent`"/>"
            'r1 = 20', 'r2 = 14', 'r3 = 12'
        )
        rules = @()
    }
    'windows-11-file-explorer-styler' = @{
        constants = @(
            "accentColor = <SolidColorBrush Color=`"#$accent`"/>"
            "accentColor2 = <SolidColorBrush Color=`"#$accent`" Opacity=`"0.5`"/>"
        )
        # No surface rules here on purpose. The nav pane and the file list stay
        # at the system's own #16181D / #23262E: every surface target the mod's
        # themes use for them (Grid#DetailsViewControlRootGrid,
        # Grid#HomeViewRootGrid, Grid#GalleryRootGrid, Grid#CommandBarControlRootGrid,
        # Grid#NavigationBarControlGrid, Grid#FileExplorerAddressBarGrid) was
        # probed with a magenta background on this build and none of them
        # matched - the explorer tree changed underneath them. What does land
        # is the theme plus the resource overrides: title bar, breadcrumb,
        # toolbar, selection accent, font.
        rules = @()
    }
    'windows-11-start-menu-styler' = @{
        constants = @()
        rules = Get-RecoloredTheme 'windows-11-start-menu-styler' 'g_themeEverblush' $remap
    }
}

foreach ($mod in $plan.Keys) {
    $modKey = "HKLM:\SOFTWARE\Windhawk\Engine\Mods\$mod"
    $setKey = "$modKey\Settings"
    if (-not (Test-Path $setKey)) { Write-Output "skip $mod (not installed)"; continue }

    # the value names contain [ ], which -Name treats as a wildcard - without
    # escaping, the removal silently matches nothing and stale rules survive
    (Get-ItemProperty $setKey).PSObject.Properties |
        Where-Object { $_.Name -like 'controlStyles*' -or $_.Name -like 'themeResourceVariables*' -or $_.Name -like 'styleConstants*' } |
        ForEach-Object { Remove-ItemProperty $setKey -Name ([WildcardPattern]::Escape($_.Name)) }

    $rules = if ($Revert) { @() } else { $fontRules + $plan[$mod].rules + $borderRules }
    $consts = if ($Revert) { @() } else { $plan[$mod].constants }
    $vars   = if ($Revert) { @() } else { $resources }

    if ($rules.Count -eq 0) {
        New-ItemProperty $setKey -Name 'controlStyles[0].target' -Value '' -PropertyType String -Force | Out-Null
        New-ItemProperty $setKey -Name 'controlStyles[0].styles[0]' -Value '' -PropertyType String -Force | Out-Null
    }
    for ($i = 0; $i -lt $rules.Count; $i++) {
        New-ItemProperty $setKey -Name "controlStyles[$i].target" -Value $rules[$i].t -PropertyType String -Force | Out-Null
        $styles = $rules[$i].s
        for ($j = 0; $j -lt $styles.Count; $j++) {
            New-ItemProperty $setKey -Name "controlStyles[$i].styles[$j]" -Value $styles[$j] -PropertyType String -Force | Out-Null
        }
    }
    for ($i = 0; $i -lt $consts.Count; $i++) {
        New-ItemProperty $setKey -Name "styleConstants[$i]" -Value $consts[$i] -PropertyType String -Force | Out-Null
    }
    for ($i = 0; $i -lt $vars.Count; $i++) {
        New-ItemProperty $setKey -Name "themeResourceVariables[$i]" -Value $vars[$i] -PropertyType String -Force | Out-Null
    }

    Set-ItemProperty $modKey -Name 'SettingsChangeTime' -Value ([int][double]::Parse((Get-Date -UFormat %s)))
    Write-Output ("{0,-40} {1} rules, {2} constants, {3} resources" -f $mod, $rules.Count, $consts.Count, $vars.Count)
}

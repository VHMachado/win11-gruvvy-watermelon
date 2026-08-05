# Applies a "Gruvvy Watermelon" (Zebar-matching) theme to the
# Windhawk mod "windows-11-taskbar-styler" by writing its settings directly.
$ErrorActionPreference = 'Stop'

$modKey  = 'HKLM:\SOFTWARE\Windhawk\Engine\Mods\windows-11-taskbar-styler'
$setKey  = "$modKey\Settings"
$backup  = Join-Path $PSScriptRoot 'windhawk-taskbar-styler-backup.reg'

# --- backup (first run only, so re-runs never clobber the original) ------
if (-not (Test-Path $backup)) {
    & reg.exe export 'HKLM\SOFTWARE\Windhawk\Engine\Mods\windows-11-taskbar-styler' $backup /y | Out-Null
    Write-Output "backup -> $backup"
}

# --- start button icon ---------------------------------------------------
# The windows logo is an AnimatedVisualPlayer, not a glyph, so it gets
# collapsed and the chip is painted with this image instead: a square inside
# a square, in the bar's base color on the watermelon accent.
$runtimeDir = Join-Path $env:USERPROFILE '.glzr'
New-Item $runtimeDir -ItemType Directory -Force | Out-Null
$iconPath = Join-Path $runtimeDir 'start-icon.png'
Add-Type -AssemblyName System.Drawing
$png = New-Object System.Drawing.Bitmap(96, 96)
$gfx = [System.Drawing.Graphics]::FromImage($png)
$gfx.SmoothingMode = 'AntiAlias'
$gfx.Clear([System.Drawing.Color]::FromArgb(0xFF, 0x4F, 0xB0, 0x94))
$ink = [System.Drawing.Color]::FromArgb(0xFF, 0x27, 0x30, 0x30)
$pen = New-Object System.Drawing.Pen ($ink, 12)
$pen.LineJoin = 'Round'
$gfx.DrawRectangle($pen, 22, 22, 52, 52)          # outer square, outlined
$gfx.FillRectangle((New-Object System.Drawing.SolidBrush $ink), 38, 38, 20, 20)  # inner square, solid
$pen.Dispose()
$gfx.Dispose()
$png.Save($iconPath, [System.Drawing.Imaging.ImageFormat]::Png)
$png.Dispose()
$iconUri = 'file:///' + ($iconPath -replace '\\', '/')

# --- tray icon selector, split so the per-icon rules stay readable -------
$trayIcon = 'SystemTray.OmniButton#ControlCenterButton > Grid > ContentPresenter > ItemsPresenter > StackPanel > ContentPresenter'
$trayLeaf = ' > SystemTray.IconView > Grid > Grid > SystemTray.TextIconContent > Windows.UI.Xaml.Controls.Grid > SystemTray.AdaptiveTextBlock > Windows.UI.Xaml.Controls.TextBlock'

# how far the start chip travels right to sit in the middle of the bar
Add-Type -AssemblyName System.Windows.Forms
$startOffset = [math]::Round([System.Windows.Forms.SystemInformation]::PrimaryMonitorSize.Width / 2 + 12.5, 1)

# --- palette (zebar bar-gruvvy-watermelon) ------------------------------
$styleConstants = @(
    'radius = 20',
    'radiusSmall = 12',
    'transparent = <SolidColorBrush Color="Transparent"/>',
    'base = <SolidColorBrush Color="#F2273030"/>',
    'overlay = <SolidColorBrush Color="#FF31413D"/>',
    'active = <SolidColorBrush Color="#FF33564E"/>',
    'border = <SolidColorBrush Color="#8EB5AA"/>',
    'accent = <SolidColorBrush Color="#4FB094"/>',
    'cherry = <SolidColorBrush Color="#FF647D"/>'
)

# target -> list of styles
$controlStyles = @(
    @{ t = 'Taskbar.TaskbarFrame > Grid#RootGrid > Taskbar.TaskbarBackground > Grid > Rectangle#BackgroundFill'
       s = @('Fill:=$transparent') },

    @{ t = 'Rectangle#BackgroundStroke'
       s = @('Fill:=$transparent') },

    @{ t = 'Taskbar.TaskbarBackground#HoverFlyoutBackgroundControl > Grid > Rectangle#BackgroundFill'
       s = @('Fill:=$base') },

    # app buttons (taskbar-labels mod -> labeled panel)
    @{ t = 'Taskbar.TaskListLabeledButtonPanel@CommonStates > Border#BackgroundElement'
       s = @('CornerRadius=$radius',
             'BorderThickness=2',
             'BorderBrush:=$border',
             # margins here are relative to the panel above, which is already
             # the pill height - so only the horizontal gap is set here
             'Margin=3,9,3,9',
             # zebar's pills are 36 tall. MinHeight saturates at
             # TaskbarHeight-24 and the parent clips 2px past that, cutting the
             # bottom border stroke - so the bar is 62 to leave room for both.
             'MinHeight=36',
             'Background:=$base',
             'Background@InactiveNormal:=$base',
             'Background@InactivePointerOver:=$overlay',
             'Background@InactivePressed:=$overlay',
             'Background@ActiveNormal:=$active',
             'Background@ActivePointerOver:=$overlay',
             'Background@ActivePressed:=$overlay',
             'Background@RequestingAttention:=$base',
             'Background@RequestingAttentionMulti:=$base',
             'Background@MultiWindowNormal:=$base',
             'Background@MultiWindowActive:=$active',
             'Background@MultiWindowPointerOver:=$overlay',
             'Background@MultiWindowPressed:=$overlay') },

    # non-labeled buttons: start / task view / widgets. Their slot is ~36 wide,
    # so a pill radius on a 40-tall box reads as a vertical oval. Squared off to
    # ~30x30 with radius 10 instead - same shape as the zebar workspace chip.
    @{ t = 'Taskbar.TaskListButtonPanel@CommonStates > Border#BackgroundElement'
       s = @('CornerRadius=12',
             'BorderThickness=2',
             'BorderBrush:=$border',
             # measured to land on y13..48, the same rows as the app pills
             'Margin=3,9,3,9',
             'Background:=$base',
             'Background@InactiveNormal:=$base',
             'Background@InactivePointerOver:=$overlay',
             'Background@InactivePressed:=$overlay',
             'Background@ActiveNormal:=$active',
             'Background@ActivePointerOver:=$overlay',
             'Background@ActivePressed:=$overlay',
             'Background@Normal:=$base',
             'Background@PointerOver:=$overlay',
             'Background@Pressed:=$overlay',
             'Background@Checked:=$active',
             'Background@CheckedNormal:=$active',
             'Background@CheckedPointerOver:=$overlay',
             'Background@CheckedPressed:=$overlay') },

    # start button = filled watermelon chip (zebar workspace pill).
    # Width pinned to the pill height so radius 20 gives a circle, not an oval.
    @{ t = 'Taskbar.ExperienceToggleButton#LaunchListButton[AutomationProperties.AutomationId=StartButton] > Taskbar.TaskListButtonPanel#ExperienceToggleButtonRootPanel > Border#BackgroundElement'
       s = @("Background:=<ImageBrush Stretch=`"UniformToFill`" ImageSource=`"$iconUri`" />",
             'BorderBrush:=$accent',
             'CornerRadius=12') },

    # hide the windows logo itself
    @{ t = 'Taskbar.ExperienceToggleButton#LaunchListButton[AutomationProperties.AutomationId=StartButton] > Taskbar.TaskListButtonPanel > Microsoft.UI.Xaml.Controls.AnimatedVisualPlayer#Icon'
       s = @('Visibility=Collapsed') },

    # running indicator -> watermelon
    @{ t = 'Taskbar.TaskListLabeledButtonPanel@RunningIndicatorStates > Rectangle#RunningIndicator'
       s = @('Fill:=$border',
             'Fill@ActiveRunningIndicator:=$accent',
             'Height=3',
             'Width=12',
             'RadiusX=1.5',
             'RadiusY=1.5',
             'Width@ActiveRunningIndicator=20') },

    # window labels
    @{ t = 'Taskbar.TaskListLabeledButtonPanel > TextBlock#LabelControl'
       s = @('FontFamily=Cascadia Mono',
             'FontSize=13',          # zebar's bar is 13px too - at 12 the taskbar reads smaller
             'Foreground=#DFECE8',
             'Padding=4,0,10,0') },

    # system tray pill
    @{ t = 'Grid#SystemTrayFrameGrid'
       s = @('Background:=$base',
             'CornerRadius=$radius',
             'BorderThickness=2',
             'BorderBrush:=$border',
             'Margin=0,13,12,13',
             'Padding=12,0,8,0') },

    @{ t = 'Border#BackgroundBorder'
       s = @('CornerRadius=$radiusSmall',
             'BorderThickness=0',
             'Margin=2,4,2,4') },

    # tray glyph/text icons
    @{ t = 'SystemTray.TextIconContent > Grid#ContainerGrid > SystemTray.AdaptiveTextBlock#Base > TextBlock#InnerTextBlock'
       s = @('Foreground=#DFECE8',
             'FontSize=16') },      # zebar draws its indicator icons at 16px

    @{ t = 'SystemTray.TextIconContent > Grid#ContainerGrid'
       s = @('Padding=2') },

    @{ t = 'SystemTray.ChevronIconView'
       s = @('MinWidth=27') },

    # per-icon colors, zebar style. These come after the generic rule above so
    # they win; the generic one stays as the fallback for everything else.
    # Indexed rather than [Text=\uXXXX] on purpose: the wifi glyph changes with
    # signal strength and the volume glyph with the level, so a glyph selector
    # would come undone on its own.
    # Same color order as the zebar bar, item for item:
    #   zebar    cpu(raspberry) ram(watermelon) temp(peach) keyboard(lavender) clock(mint)
    #   taskbar  chevron        wifi            volume      download           upload
    # The zebar colors are read off its own source: the cpu icon is hardcoded
    # raspberry, ram watermelon, the temp icon is conditional and lands on peach
    # between 15 and 25 degrees, keyboard lavender, clock mint.
    @{ t = "$trayIcon[1]$trayLeaf"
       s = @('Foreground=#4FB094') },      # wifi <- ram

    @{ t = "$trayIcon[2]$trayLeaf"
       s = @('Foreground=#EEA48D') },      # volume <- temperature

    @{ t = 'SystemTray.ChevronIconView > Grid#ContainerGrid > ContentPresenter#ContentPresenter > Grid#ContentGrid > SystemTray.TextIconContent > Grid#ContainerGrid > SystemTray.AdaptiveTextBlock#Base > TextBlock#InnerTextBlock'
       s = @('Foreground=#DD5A8E') },      # chevron <- cpu

    # download and upload share one line, so one color for both
    @{ t = 'TextBlock#TimeInnerTextBlock'
       s = @('Foreground=#C7B2FF',
             'FontFamily=Cascadia Mono',
             'FontSize=13') },

    @{ t = 'TextBlock#DateInnerTextBlock'
       s = @('Foreground=#C7B2FF',
             'FontFamily=Cascadia Mono',
             'FontSize=13') },

    # overflow flyout + context menus
    @{ t = 'Grid#OverflowRootGrid > Border'
       s = @('Background:=$base',
             'BorderThickness=2',
             'BorderBrush:=$border',
             'CornerRadius=$radiusSmall',
             'Shadow:=') },

    @{ t = 'MenuFlyoutPresenter'
       s = @('Background:=$base',
             'CornerRadius=$radiusSmall',
             'Shadow:=') },

    # open windows on the left, start button alone in the middle.
    # Start and the app buttons share one ItemsRepeater, so the only way to
    # split them is to leave Start in the layout and move just its rendering.
    # ponytail: single monitor only - the offset is half the screen width plus
    # the gap measured on the pill, recomputed at apply time.
    @{ t = 'Microsoft.UI.Xaml.Controls.ItemsRepeater#TaskbarFrameRepeater'
       s = @('HorizontalAlignment=Left',
             'Margin=-34,0,0,0') },

    @{ t = 'Taskbar.ExperienceToggleButton#LaunchListButton[AutomationProperties.AutomationId=StartButton]'
       s = @("RenderTransform:=<TranslateTransform X=`"$startOffset`" />") },

    # notification badge -> cherry
    @{ t = 'Taskbar.Badge#BadgeControl'
       s = @('Background:=$cherry',
             'CornerRadius=20',
             'Height=14',
             'MinWidth=14') }
)

# --- write --------------------------------------------------------------
Remove-Item $setKey -Recurse -Force -ErrorAction SilentlyContinue
New-Item $setKey -Force | Out-Null

New-ItemProperty $setKey -Name 'theme' -Value '' -PropertyType String -Force | Out-Null
New-ItemProperty $setKey -Name 'xamlDiagnosticsHandling' -Value 'alert' -PropertyType String -Force | Out-Null
New-ItemProperty $setKey -Name 'resourceVariables[0].variableKey' -Value '' -PropertyType String -Force | Out-Null
New-ItemProperty $setKey -Name 'resourceVariables[0].value' -Value '' -PropertyType String -Force | Out-Null
New-ItemProperty $setKey -Name 'themeResourceVariables[0]' -Value '' -PropertyType String -Force | Out-Null

for ($i = 0; $i -lt $styleConstants.Count; $i++) {
    New-ItemProperty $setKey -Name "styleConstants[$i]" -Value $styleConstants[$i] -PropertyType String -Force | Out-Null
}

for ($i = 0; $i -lt $controlStyles.Count; $i++) {
    New-ItemProperty $setKey -Name "controlStyles[$i].target" -Value $controlStyles[$i].t -PropertyType String -Force | Out-Null
    $styles = $controlStyles[$i].s
    for ($j = 0; $j -lt $styles.Count; $j++) {
        New-ItemProperty $setKey -Name "controlStyles[$i].styles[$j]" -Value $styles[$j] -PropertyType String -Force | Out-Null
    }
}

# tell windhawk the settings changed -> mod reloads in explorer.exe
Set-ItemProperty $modKey -Name 'SettingsChangeTime' -Value ([int][double]::Parse((Get-Date -UFormat %s)))

Write-Output "wrote $($controlStyles.Count) control styles, $($styleConstants.Count) constants"

# --- metrics, in the sibling mods ---------------------------------------
# pill height = TaskbarHeight - (top + bottom margin above) = 58 - 18 = 40,
# which matches radius 20 -> a true pill, same proportion as the zebar bar
# (55px bar / 36px pill). Previous values: height 52, icon 32, padding 10.
$metrics = @{
    # TaskbarButtonWidthSmall is what sizes the start / task view slot (32 by
    # default) - at 32 the chip is too narrow to round without looking oval
    'taskbar-icon-size' = @{ TaskbarHeight = 62; IconSize = 24; TaskbarButtonWidth = 44
                             TaskbarButtonWidthSmall = 44 }
    # the start button is in the middle now, so let windows place the start
    # menu itself (TaskbarAl=1 -> centered). With this on, the mod pins the
    # menu to the left edge, where the button no longer is.
    'taskbar-start-button-position' = @{ startMenuOnTheLeft = 0 }

    # split onto two lines so each arrow can carry its own color above
    # Back to one line, so one color for both. The arrows are U+1F53D / U+1F53C,
    # which live only in Segoe UI Emoji - Consolas has no glyph for them, so the
    # fallback forces the color font. U+2B07/U+2B06 rendered monochrome even with
    # the VS16 selector, because Segoe UI Variable does have those.
    # TextSpacing was -17 (4294967279 unsigned) - kept at 0.
    'taskbar-clock-customization' = @{ TopLine = "$([char]::ConvertFromUtf32(0x1F53D)) %download_speed% | $([char]::ConvertFromUtf32(0x1F53C)) %upload_speed%"
                                       BottomLine = ''
                                       TextSpacing = 4294967279 }   # -17, your original: centers a single line

    # wider items so the extra padding does not eat into the label text
    'taskbar-labels'    = @{ leftAndRightPaddingSize = 16; spaceBetweenIconAndLabel = 16
                             taskbarItemWidth = 170; maximumTaskbarItemWidth = 200 }
}
foreach ($mod in $metrics.Keys) {
    $k = "HKLM:\SOFTWARE\Windhawk\Engine\Mods\$mod"
    foreach ($name in $metrics[$mod].Keys) {
        Set-ItemProperty "$k\Settings" -Name $name -Value $metrics[$mod][$name]
    }
    Set-ItemProperty $k -Name 'SettingsChangeTime' -Value ([int][double]::Parse((Get-Date -UFormat %s)))
    Write-Output "metrics -> $mod"
}

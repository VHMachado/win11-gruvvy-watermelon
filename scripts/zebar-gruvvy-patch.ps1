# Patches the compiled bar-gruvvy-watermelon pack in place:
#   1. weather provider dropped; the temperature slot reads the machine's ACPI
#      thermal zone through shellExec instead (see cpu-temp.ps1).
#   2. center pill (focused window title) uses the taskbar start-icon colors,
#      and polls GlazeWM because it has no title-changed event.
#   3. 24h clock, Cascadia Mono, fixed yellow temperature icon.
#
# Idempotent - re-run after a pack update, it re-applies whatever is missing.
param(

    [double]$PillStroke = 0.5, # px of -webkit-text-stroke on the center pill, fattens the text
    [int]$TempSeconds = 10,    # how often the thermal zone is polled
    [int]$TitleMs = 300,       # how often the focused window title is re-read
    [string]$TempColor = '#E5C76B',   # sun icon, fixed - no ramp
    [string]$BarFont = "'Cascadia Mono'",
    [switch]$Revert
)
$ErrorActionPreference = 'Stop'

$pack = Get-ChildItem "$env:APPDATA\zebar\downloads" -Directory -Filter 'zacccharv.bar-gruvvy-watermelon@*' |
        Sort-Object Name | Select-Object -Last 1
if (-not $pack) { throw 'pack not installed' }
$js   = Join-Path $pack.FullName 'dist\assets\bar.glazewm-a6zTGHRW.js'
$css  = Join-Path $pack.FullName 'dist\assets\bar-CzgcAVql.css'
$pkg  = Join-Path $pack.FullName 'zpack.json'

# The temperature slot reads the ACPI thermal zone instead of the weather now,
# which means the widget has to be allowed to run one specific command. The
# regex pins it to exactly this script - no other powershell invocation passes.
$tempScript = Join-Path $PSScriptRoot 'cpu-temp.ps1'
$tempArgs   = '"-NoProfile","-ExecutionPolicy","Bypass","-File","' + ($tempScript -replace '\\', '\\') + '"'
$tempRegex  = '^' + [regex]::Escape("-NoProfile -ExecutionPolicy Bypass -File $tempScript") + '$'

foreach ($f in $js, $css, $pkg) {
    if (-not (Test-Path "$f.orig")) { Copy-Item $f "$f.orig" }
    Copy-Item "$f.orig" $f -Force   # always patch a pristine bundle
}

if (-not $Revert) {
    $edits = @(
        # The weather provider is gone: that slot shows the machine's own
        # temperature now, so there is nothing left to fetch from open-meteo
        # (and no ipinfo lookup left to fail).
        @{ file = $js
           from = 'weather:{type:"weather"},'
           to   = '' },
        # temperature = ACPI thermal zone, polled through shellExec. Keeps the
        # last good reading, so a failed poll shows a stale number, never 0.
        @{ file = $js
           from = 'He(di(r.raw,Q(()=>t.weather?.celsiusTemp)))'
           to   = 'He(di(r.raw,(()=>{const[_ct,_sct]=ze(null);const _rd=async()=>{try{const _o=await ge.shellExec("powershell",[' +
                  $tempArgs + ']);const _v=parseFloat(String(_o?.stdout??"").trim());if(!isNaN(_v))_sct(_v)}catch(_e){}};_rd();' +
                  "setInterval(_rd,$($TempSeconds * 1000));return _ct})()))" },
        # drop the temperature color ramp entirely - it was built for weather
        # (topped out at 25C, so any machine reading sat on cherry) and the icon
        # is a fixed color now
        @{ file = $js
           from = '{"text-gruvvy-watermelon-mint":r.get()<=-20,"text-gruvvy-watermelon-watermelon":r.get()<=-10,"text-gruvvy-watermelon-lavender":r.get()<=5,"text-gruvvy-watermelon-raspberry":r.get()<=14,"text-gruvvy-watermelon-peach":r.get()<=25,"text-gruvvy-watermelon-cherry":r.get()>=25}'
           to   = '{"temp-icon":!0}' },
        # allow that one command, and nothing else
        @{ file = $pkg
           from = '"shellCommands": []'
           to   = '"shellCommands": [{ "program": "powershell", "argsRegex": "' + ($tempRegex -replace '\\', '\\' -replace '"', '\"') + '" }]' },
        # GlazeWM has no title-changed event (its event enum stops at
        # workspace_updated), so the center pill only refreshed on focus
        # changes - switching browser tabs left the old title sitting there.
        # Poll the workspace tree instead, and only emit when the tree actually
        # differs, so the workspace pills don't re-render every tick.
        @{ file = $js
           from = 'n.output(a),i??=await s.subscribe(Ge.ALL,o);'
           to   = 'n.output(a),i??=await s.subscribe(Ge.ALL,o),(()=>{let _prev="";setInterval(async()=>{try{const _d=await d();' +
                  'const _k=JSON.stringify(_d.focusedWorkspace??null);if(_k===_prev)return;_prev=_k;a={...a,..._d};n.output(a)}catch(_e){}},' +
                  "$TitleMs)})();" },
        # 24h clock (luxon "t" is locale time, i.e. 3:54 PM here)
        @{ file = $js
           from = 'date:{type:"date",formatting:"t"}'
           to   = 'date:{type:"date",formatting:"HH:mm"}' },
        # center pill: green fill + dark ink, like the taskbar start button
        @{ file = $js
           from = 'class:"justify-self-center"'
           to   = 'class:"justify-self-center pill-center bg-gruvvy-watermelon-watermelon text-gruvvy-watermelon-base border-gruvvy-watermelon-watermelon font-bold"' },
        # the pack asks for Hack Nerd Font Mono, which wasn't installed - the
        # whole bar was falling back to Consolas
        @{ file = $css
           from = 'font-family:Hack Nerd Font Mono,ui-monospace,monospace'
           to   = "font-family:$BarFont,ui-monospace,monospace" },
        # tailwind only emits utilities it sees at build time
        @{ file = $css
           from = ''
           to   = "`n.border-gruvvy-watermelon-watermelon{border-color:var(--color-gruvvy-watermelon-watermelon)}" +
                  "`n.pill-center{-webkit-text-stroke:${PillStroke}px currentColor}" +
                  # unlayered, so it beats the tailwind text-* utilities
                  "`n.temp-icon{color:$TempColor}" }
    )

    foreach ($e in $edits) {
        $text = [IO.File]::ReadAllText($e.file)
        if ($e.from -eq '') {
            [IO.File]::WriteAllText($e.file, $text + $e.to)
        } elseif ($text.Contains($e.from)) {
            [IO.File]::WriteAllText($e.file, $text.Replace($e.from, $e.to))
        } else {
            throw "anchor not found in $($e.file): $($e.from)"
        }
    }
}

# WebView2 caches the bundle for 7 days (zpack caching.defaultDuration), so the
# edit is invisible until its HTTP cache is dropped. Local Storage is left alone.
Stop-Process -Name zebar -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500
$profileDir = "$env:APPDATA\zebar\webview-cache\zacccharv.bar-gruvvy-watermelon\EBWebView\Default"
foreach ($c in 'Cache', 'Code Cache') {
    Remove-Item (Join-Path $profileDir $c) -Recurse -Force -ErrorAction SilentlyContinue
}
Start-Process (Join-Path $env:ProgramFiles 'glzr.io\Zebar\zebar.exe')
Write-Output ($(if ($Revert) { 'reverted' } else { 'patched' }) + ' - zebar restarted')

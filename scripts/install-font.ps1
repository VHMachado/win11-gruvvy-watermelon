# Installs a font family machine-wide (explorer's XAML resolves fonts through
# the DirectWrite system collection, so a per-user install is a dead end).
# Idempotent: re-run is a no-op once the faces are registered.
#
#   .\install-font.ps1 -Name cascadia
#   .\install-font.ps1 -Name hack -Uninstall
param(
    [ValidateSet('cascadia', 'hack')][string]$Name = 'cascadia',
    [switch]$Uninstall
)
$ErrorActionPreference = 'Stop'

# Cascadia Mono is Cascadia Code without the Nerd Font glyphs. That matters:
# CaskaydiaCove (the Nerd patch) fills the private use area with Devicons,
# which collide with Segoe Fluent Icons - the explorer's close-tab X came out
# as an Apple logo and the new-tab + as junk. A font with an empty PUA lets the
# fallback do its job.
$presets = @{
    cascadia = @{
        url   = 'https://github.com/microsoft/cascadia-code/releases/download/v2407.24/CascadiaCode-2407.24.zip'
        faces = [ordered]@{
            'CascadiaMono-Regular.ttf'    = 'Cascadia Mono Regular (TrueType)'
            'CascadiaMono-Bold.ttf'       = 'Cascadia Mono Bold (TrueType)'
            'CascadiaMono-Italic.ttf'     = 'Cascadia Mono Italic (TrueType)'
            'CascadiaMono-BoldItalic.ttf' = 'Cascadia Mono Bold Italic (TrueType)'
        }
    }
    hack = @{
        url   = 'https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/Hack.zip'
        faces = [ordered]@{
            'HackNerdFontMono-Regular.ttf'    = 'Hack Nerd Font Mono Regular (TrueType)'
            'HackNerdFontMono-Bold.ttf'       = 'Hack Nerd Font Mono Bold (TrueType)'
            'HackNerdFontMono-Italic.ttf'     = 'Hack Nerd Font Mono Italic (TrueType)'
            'HackNerdFontMono-BoldItalic.ttf' = 'Hack Nerd Font Mono Bold Italic (TrueType)'
            'HackNerdFont-Regular.ttf'        = 'Hack Nerd Font Regular (TrueType)'
            'HackNerdFont-Bold.ttf'           = 'Hack Nerd Font Bold (TrueType)'
            'HackNerdFont-Italic.ttf'         = 'Hack Nerd Font Italic (TrueType)'
            'HackNerdFont-BoldItalic.ttf'     = 'Hack Nerd Font Bold Italic (TrueType)'
        }
    }
}

$faces   = $presets[$Name].faces
$fontDir = "$env:WINDIR\Fonts"
$regKey  = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'

Add-Type -Namespace Win32 -Name Font -MemberDefinition @'
[DllImport("gdi32.dll", CharSet = CharSet.Auto)] public static extern int AddFontResource(string lpFileName);
[DllImport("gdi32.dll", CharSet = CharSet.Auto)] public static extern bool RemoveFontResource(string lpFileName);
[DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam, uint fuFlags, uint uTimeout, out IntPtr lpdwResult);
'@

function Broadcast-FontChange {
    $ignore = [IntPtr]::Zero
    # HWND_BROADCAST, WM_FONTCHANGE, SMTO_ABORTIFHUNG
    [Win32.Font]::SendMessageTimeout([IntPtr]0xffff, 0x001D, [IntPtr]::Zero, [IntPtr]::Zero, 0x0002, 1000, [ref]$ignore) | Out-Null
}

if ($Uninstall) {
    foreach ($f in $faces.GetEnumerator()) {
        $path = Join-Path $fontDir $f.Key
        [Win32.Font]::RemoveFontResource($path) | Out-Null
        Remove-ItemProperty $regKey -Name $f.Value -ErrorAction SilentlyContinue
        Remove-Item $path -Force -ErrorAction SilentlyContinue
    }
    Broadcast-FontChange
    Write-Output "$Name uninstalled - restart explorer to drop the cached font collection"
    return
}

$installed = (Get-ItemProperty $regKey).PSObject.Properties.Name
$missing = $faces.GetEnumerator() | Where-Object {
    $installed -notcontains $_.Value -or -not (Test-Path (Join-Path $fontDir $_.Key))
}
if (-not $missing) { Write-Output "$Name already installed"; return }

$work = Join-Path $env:TEMP "font-$Name"
$zip  = "$work\font.zip"
if (-not (Test-Path "$work\extract")) {
    New-Item $work -ItemType Directory -Force | Out-Null
    if (-not (Test-Path $zip)) { Invoke-WebRequest $presets[$Name].url -OutFile $zip }
    Expand-Archive $zip "$work\extract" -Force
}

foreach ($f in $missing) {
    $src = Get-ChildItem "$work\extract" -Recurse -Filter $f.Key | Select-Object -First 1
    if (-not $src) { throw "not in the archive: $($f.Key)" }
    Copy-Item $src.FullName (Join-Path $fontDir $f.Key) -Force
    [Win32.Font]::AddFontResource((Join-Path $fontDir $f.Key)) | Out-Null
    Set-ItemProperty $regKey -Name $f.Value -Value $f.Key   # system fonts register by filename
}
Broadcast-FontChange
Write-Output "installed $($missing.Count) face(s) of $Name"

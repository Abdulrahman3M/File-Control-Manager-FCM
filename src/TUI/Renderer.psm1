$script:FcmPlainOutput = $false

function Initialize-FcmRenderer {
    param([switch]$PlainOutput)
    $script:FcmPlainOutput = [bool]$PlainOutput
    try {
        [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
        [Console]::InputEncoding = New-Object System.Text.UTF8Encoding($false)
    }
    catch { }
}

function Get-FcmTerminalSize {
    $width = 80
    $height = 25
    try {
        $width = [int]$Host.UI.RawUI.WindowSize.Width
        $height = [int]$Host.UI.RawUI.WindowSize.Height
    }
    catch {
        try {
            $width = [Console]::WindowWidth
            $height = [Console]::WindowHeight
        }
        catch { }
    }
    return [pscustomobject]@{ Width = [Math]::Max(40,$width); Height = [Math]::Max(12,$height) }
}

function Add-FcmWrappedText {
    param([System.Collections.Generic.List[object]]$Output,[string]$Text,[string]$Role,[int]$Width)
    $safeWidth = [Math]::Max(20,$Width - 2)
    $remaining = $Text
    if ([string]::IsNullOrWhiteSpace($remaining)) {
        $Output.Add(@{ Text = ''; Role = $Role })
        return
    }
    while ($remaining.Length -gt $safeWidth) {
        $cut = $remaining.LastIndexOf(' ',$safeWidth)
        if ($cut -lt 1) { $cut = $safeWidth }
        $Output.Add(@{ Text = $remaining.Substring(0,$cut); Role = $Role })
        $remaining = $remaining.Substring($cut).TrimStart()
    }
    $Output.Add(@{ Text = $remaining; Role = $Role })
}

function Write-FcmScreen {
    param([Parameter(Mandatory = $true)][object[]]$Line)
    $size = Get-FcmTerminalSize
    if (-not $script:FcmPlainOutput) {
        try { Clear-Host } catch { }
    }
    $expanded = New-Object 'System.Collections.Generic.List[object]'
    foreach ($item in $Line) {
        Add-FcmWrappedText -Output $expanded -Text ([string]$item.Text) -Role ([string]$item.Role) -Width $size.Width
    }
    $maxLines = $size.Height - 1
    $start = 0
    if ($expanded.Count -gt $maxLines) { $start = $expanded.Count - $maxLines }
    for ($index = $start; $index -lt $expanded.Count; $index++) {
        $item = $expanded[$index]
        $style = Get-FcmStyle -Role $item.Role
        if ($style.Foreground) {
            if ($style.Background) {
                Write-Host ([string]$item.Text) -ForegroundColor $style.Foreground -BackgroundColor $style.Background
            }
            else {
                Write-Host ([string]$item.Text) -ForegroundColor $style.Foreground
            }
        }
        else {
            Write-Host ([string]$item.Text)
        }
    }
}

Export-ModuleMember -Function Initialize-FcmRenderer,Get-FcmTerminalSize,Write-FcmScreen

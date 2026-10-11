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
    param([System.Collections.Generic.List[object]]$Output,[object]$Line,[int]$Width)
    $Text = [string]$Line.Text
    $Role = [string]$Line.Role
    $IconName = [string]$Line.IconName
    $Icon = ''
    if ($IconName) { $Icon = Get-FcmIcon $IconName }
    $Suffix = [string]$Line.Suffix
    $completeText = $Text + $Icon + $Suffix
    $iconStart = $Text.Length
    $iconEnd = $iconStart + $Icon.Length
    $safeWidth = [Math]::Max(20,$Width - 2)
    if ([string]::IsNullOrWhiteSpace($completeText)) {
        $Output.Add(@{ Text = ''; Role = $Role; IconName = ''; Suffix = '' })
        return
    }
    $offset = 0
    while (($completeText.Length - $offset) -gt $safeWidth) {
        $cut = $completeText.LastIndexOf(' ',$offset + $safeWidth - 1,$safeWidth)
        $length = $cut - $offset
        if ($length -lt 1) { $length = $safeWidth }
        $part = $completeText.Substring($offset,$length)
        if ($Icon -and $iconStart -ge $offset -and $iconEnd -le ($offset + $length)) {
            $beforeIcon = $completeText.Substring($offset,$iconStart - $offset)
            $afterIcon = $completeText.Substring($iconEnd,($offset + $length) - $iconEnd)
            $Output.Add(@{ Text = $beforeIcon; Role = $Role; IconName = $IconName; Suffix = $afterIcon })
        }
        else { $Output.Add(@{ Text = $part; Role = $Role; IconName = ''; Suffix = '' }) }
        $offset += $length
        while ($offset -lt $completeText.Length -and $completeText[$offset] -eq ' ') { $offset++ }
    }
    $part = $completeText.Substring($offset)
    if ($Icon -and $iconStart -ge $offset -and $iconEnd -le $completeText.Length) {
        $beforeIcon = $completeText.Substring($offset,$iconStart - $offset)
        $afterIcon = $completeText.Substring($iconEnd)
        $Output.Add(@{ Text = $beforeIcon; Role = $Role; IconName = $IconName; Suffix = $afterIcon })
    }
    else { $Output.Add(@{ Text = $part; Role = $Role; IconName = ''; Suffix = '' }) }
}

function Write-FcmSegment {
    param([string]$Text,[string]$Foreground,[string]$Background)
    if ($Foreground -and $Background) { Write-Host $Text -NoNewline -ForegroundColor $Foreground -BackgroundColor $Background }
    elseif ($Foreground) { Write-Host $Text -NoNewline -ForegroundColor $Foreground }
    else { Write-Host $Text -NoNewline }
}

function Write-FcmScreen {
    param([Parameter(Mandatory = $true)][object[]]$Line)
    $size = Get-FcmTerminalSize
    if (-not $script:FcmPlainOutput) {
        try { Clear-Host } catch { }
    }
    $expanded = New-Object 'System.Collections.Generic.List[object]'
    foreach ($item in $Line) {
        Add-FcmWrappedText -Output $expanded -Line $item -Width $size.Width
    }
    $maxLines = $size.Height - 1
    $start = 0
    if ($expanded.Count -gt $maxLines) { $start = $expanded.Count - $maxLines }
    for ($index = $start; $index -lt $expanded.Count; $index++) {
        $item = $expanded[$index]
        $style = Get-FcmStyle -Role $item.Role
        $iconName = [string]$item.IconName
        $icon = ''
        if ($iconName) { $icon = Get-FcmIcon $iconName }
        $iconStyle = Get-FcmStyle 'Accent'
        $iconColor = $null
        if ($icon -and $iconStyle.Foreground) { $iconColor = Get-FcmIconColor $iconName }
        Write-FcmSegment -Text ([string]$item.Text) -Foreground $style.Foreground -Background $style.Background
        if ($icon) {
            Write-FcmSegment -Text $icon -Foreground $iconColor -Background $style.Background
            Write-FcmSegment -Text ([string]$item.Suffix) -Foreground $style.Foreground -Background $style.Background
        }
        Write-Host
    }
}

Export-ModuleMember -Function Initialize-FcmRenderer,Get-FcmTerminalSize,Write-FcmScreen

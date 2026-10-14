$script:FcmPlainOutput = $false
$script:FcmLastFrame = @()
$script:FcmLastStyleKeys = @()
$script:FcmLastWidth = 0
$script:FcmLastHeight = 0
$script:FcmAnsi = $false
$script:FcmSynchronizedOutput = $false
$script:FcmSyncUpdateActive = $false
$script:FcmFullRedraw = $true
$script:FcmCursorHidden = $false

function Initialize-FcmRenderer {
    param([switch]$PlainOutput)
    $script:FcmPlainOutput = [bool]$PlainOutput
    $script:FcmLastFrame = @()
    $script:FcmLastStyleKeys = @()
    $script:FcmLastWidth = 0
    $script:FcmLastHeight = 0
    $script:FcmAnsi = $false
    $script:FcmSynchronizedOutput = $false
    $script:FcmSyncUpdateActive = $false
    $script:FcmFullRedraw = $true
    $script:FcmCursorHidden = $false
    if (-not $script:FcmPlainOutput) {
        try {
            if (-not [Console]::IsOutputRedirected) {
                $script:FcmAnsi = [bool]($env:WT_SESSION -or $env:TERM_PROGRAM -or $env:ConEmuANSI -eq 'ON' -or $Host.UI.SupportsVirtualTerminal)
            }
        } catch { $script:FcmAnsi = $false }
    }
    $script:FcmSynchronizedOutput = $script:FcmAnsi -and [bool]$env:WT_SESSION
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

function Restore-FcmScreen {
    # Return the terminal to its original cursor state on application shutdown.
    if ($script:FcmSyncUpdateActive) {
        if ($script:FcmAnsi) {
            try {
                [Console]::Out.Write(([string][char]27) + '[?2026l')
                [Console]::Out.Flush()
            }
            catch { }
        }
        $script:FcmSyncUpdateActive = $false
    }
    if ($script:FcmCursorHidden) {
        if ($script:FcmAnsi) {
            try { [Console]::Out.Write(([string][char]27) + '[?25h') } catch { }
        }
        try { [Console]::CursorVisible = $true } catch { }
        $script:FcmCursorHidden = $false
    }
    $script:FcmLastFrame = @()
    $script:FcmLastStyleKeys = @()
    $script:FcmLastWidth = 0
    $script:FcmLastHeight = 0
    $script:FcmFullRedraw = $true
}

function Get-FcmRenderedLine {
    param([object]$Line)
    $icon = ''
    if ([string]$Line.IconName) { $icon = Get-FcmIcon ([string]$Line.IconName) }
    return ([string]$Line.Text + $icon + [string]$Line.Suffix)
}

function Write-FcmStyledLine {
    param([object]$Item)
    $style = Get-FcmStyle -Role $Item.Role
    $iconName = [string]$Item.IconName
    $icon = ''
    if ($iconName) { $icon = Get-FcmIcon $iconName }
    $iconColor = $null
    if ($icon -and $style.Foreground) { $iconColor = Get-FcmIconColor $iconName }
    Write-FcmSegment -Text ([string]$Item.Text) -Foreground $style.Foreground -Background $style.Background
    if ($icon) {
        Write-FcmSegment -Text $icon -Foreground $iconColor -Background $style.Background
        Write-FcmSegment -Text ([string]$Item.Suffix) -Foreground $style.Foreground -Background $style.Background
    }
}

function Get-FcmAnsiColorCode {
    param([string]$Color,[switch]$Background)
    $foregroundCodes = @{
        Black = 30; DarkRed = 31; DarkGreen = 32; DarkYellow = 33; DarkBlue = 34; DarkMagenta = 35; DarkCyan = 36; Gray = 37
        DarkGray = 90; Red = 91; Green = 92; Yellow = 93; Blue = 94; Magenta = 95; Cyan = 96; White = 97
    }
    if (-not $Color -or -not $foregroundCodes.ContainsKey($Color)) { return $null }
    $code = [int]$foregroundCodes[$Color]
    if ($Background) { return ($code + 10) }
    return $code
}

function Get-FcmAnsiStyleSequence {
    param([string]$Foreground,[string]$Background)
    $codes = New-Object 'System.Collections.Generic.List[int]'
    $foregroundCode = Get-FcmAnsiColorCode -Color $Foreground
    $backgroundCode = Get-FcmAnsiColorCode -Color $Background -Background
    if ($null -ne $foregroundCode) { $codes.Add([int]$foregroundCode) }
    if ($null -ne $backgroundCode) { $codes.Add([int]$backgroundCode) }
    if ($codes.Count -eq 0) { return ([string][char]27 + '[0m') }
    return ([string][char]27 + '[' + ($codes -join ';') + 'm')
}

function New-FcmSynchronizedFrame {
    param([Parameter(Mandatory = $true)][object[]]$Line,[switch]$ClearScreen)
    $escape = [string][char]27
    $builder = New-Object System.Text.StringBuilder
    [void]$builder.Append($escape + '[?2026h')
    [void]$builder.Append($escape + '[?25l')
    if ($ClearScreen) { [void]$builder.Append($escape + '[2J') }
    for ($row = 0; $row -lt $Line.Count; $row++) {
        $item = $Line[$row]
        $roleStyle = Get-FcmStyle -Role ([string]$item.Role)
        $text = [string]$item.Text
        $iconName = [string]$item.IconName
        $icon = ''
        if ($iconName) { $icon = Get-FcmIcon $iconName }
        $suffix = [string]$item.Suffix
        $iconForeground = $null
        if ($icon -and $roleStyle.Foreground) { $iconForeground = Get-FcmIconColor $iconName }

        [void]$builder.Append($escape + '[' + ($row + 1) + ';1H')
        [void]$builder.Append((Get-FcmAnsiStyleSequence -Foreground $roleStyle.Foreground -Background $roleStyle.Background))
        [void]$builder.Append($text).Append($escape + '[0m')
        if ($icon) {
            [void]$builder.Append((Get-FcmAnsiStyleSequence -Foreground $iconForeground -Background $roleStyle.Background))
            [void]$builder.Append($icon).Append($escape + '[0m')
        }
        [void]$builder.Append((Get-FcmAnsiStyleSequence -Foreground $roleStyle.Foreground -Background $roleStyle.Background))
        [void]$builder.Append($suffix).Append($escape + '[0m')
        [void]$builder.Append($escape + '[K')
    }
    [void]$builder.Append($escape + '[?2026l')
    return $builder.ToString()
}

function Write-FcmSynchronizedFrame {
    param(
        [Parameter(Mandatory = $true)][object[]]$Line,
        [switch]$ClearScreen,
        [System.IO.TextWriter]$OutputWriter = $null
    )
    if ($null -eq $OutputWriter) { $OutputWriter = [Console]::Out }
    $isConsoleWriter = [object]::ReferenceEquals($OutputWriter,[Console]::Out)
    $frame = New-FcmSynchronizedFrame -Line $Line -ClearScreen:$ClearScreen
    if ($isConsoleWriter) {
        $script:FcmCursorHidden = $true
        $script:FcmSyncUpdateActive = $true
    }
    $OutputWriter.Write($frame)
    $OutputWriter.Flush()
    if ($isConsoleWriter) { $script:FcmSyncUpdateActive = $false }
}

function Write-FcmScreen {
    param([Parameter(Mandatory = $true)][object[]]$Line)
    $size = Get-FcmTerminalSize
    $expanded = New-Object 'System.Collections.Generic.List[object]'
    foreach ($item in $Line) {
        Add-FcmWrappedText -Output $expanded -Line $item -Width $size.Width
    }
    $maxLines = $size.Height - 1
    $start = 0
    if ($expanded.Count -gt $maxLines) { $start = $expanded.Count - $maxLines }
    $visible = @()
    for ($index = $start; $index -lt $expanded.Count; $index++) {
        $visible += ,$expanded[$index]
    }

    if ($script:FcmPlainOutput) {
        foreach ($item in $visible) {
            Write-FcmStyledLine -Item $item
            Write-Host
        }
        return
    }

    # Paint only changed rows. Cache includes text and semantic/icon style keys.
    # ANSI controls are emitted only to verified interactive VT-capable terminals.
    try {
        if (-not $script:FcmCursorHidden) {
            try { [Console]::CursorVisible = $false; $script:FcmCursorHidden = $true } catch { }
        }
        $current = @($visible | ForEach-Object { Get-FcmRenderedLine -Line $_ })
        $styles = @($visible | ForEach-Object { ([string]$_.Role + '|' + [string]$_.IconName) })
        if ($script:FcmLastWidth -ne $size.Width -or $script:FcmLastHeight -ne $size.Height) {
            $script:FcmLastFrame = @()
            $script:FcmLastStyleKeys = @()
            $script:FcmFullRedraw = $true
        }
        if ($script:FcmFullRedraw) {
            if ($script:FcmSynchronizedOutput) {
                Write-FcmSynchronizedFrame -Line $visible -ClearScreen
                $script:FcmFullRedraw = $false
                $script:FcmLastFrame = $current
                $script:FcmLastStyleKeys = $styles
                $script:FcmLastWidth = $size.Width
                $script:FcmLastHeight = $size.Height
                return
            }
            # Initial layout and resize only; NEVER clear on ordinary arrow navigation.
            if ($script:FcmAnsi) {
                [Console]::Out.Write(([string][char]27) + '[H' + ([string][char]27) + '[J')
            } else {
                try { Clear-Host } catch { }
            }
            $script:FcmFullRedraw = $false
        }
        $rows = [Math]::Max($current.Count, $script:FcmLastFrame.Count)
        for ($row = 0; $row -lt $rows; $row++) {
            $newText = if ($row -lt $current.Count) { [string]$current[$row] } else { '' }
            $oldText = if ($row -lt $script:FcmLastFrame.Count) { [string]$script:FcmLastFrame[$row] } else { $null }
            $oldStyle = if ($row -lt $script:FcmLastStyleKeys.Count) { [string]$script:FcmLastStyleKeys[$row] } else { $null }
            $newStyle = if ($row -lt $styles.Count) { [string]$styles[$row] } else { '' }
            if ($null -ne $oldText -and $newText -ceq $oldText -and $newStyle -ceq $oldStyle) { continue }
            if ($row -ge $size.Height - 1) { continue }
            if ($script:FcmAnsi) {
                $escape = [string][char]27
                [Console]::Out.Write($escape + '[' + ($row + 1) + ';1H')
            } else {
                [Console]::SetCursorPosition(0,$row)
            }
            if ($row -lt $visible.Count) { Write-FcmStyledLine -Item $visible[$row] }
            if ($script:FcmAnsi) {
                # ANSI CSI K clears the old, longer row without blanking the frame.
                [Console]::Out.Write(([string][char]27) + '[K')
            } else {
                # Legacy conhost has no VT erasure; pad to the last safe column.
                $remaining = [Math]::Max(0, [Console]::WindowWidth - 1 - [Console]::CursorLeft)
                if ($remaining -gt 0) { [Console]::Out.Write(' ' * $remaining) }
            }
        }
        $script:FcmLastFrame = $current
        $script:FcmLastStyleKeys = $styles
        $script:FcmLastWidth = $size.Width
        $script:FcmLastHeight = $size.Height
    }
    catch {
        if ($script:FcmSyncUpdateActive) {
            try {
                [Console]::Out.Write(([string][char]27) + '[?2026l')
                [Console]::Out.Flush()
            }
            catch { }
            $script:FcmSyncUpdateActive = $false
        }
        # Older hosts may reject cursor positioning: safely return to the original renderer.
        $script:FcmLastFrame = @()
        $script:FcmLastStyleKeys = @()
        $script:FcmLastWidth = 0
        $script:FcmLastHeight = 0
        $script:FcmFullRedraw = $true
        try { Clear-Host } catch { }
        foreach ($item in $visible) {
            Write-FcmStyledLine -Item $item
            Write-Host
        }
    }
}

Export-ModuleMember -Function Initialize-FcmRenderer,Get-FcmTerminalSize,Write-FcmScreen,Restore-FcmScreen

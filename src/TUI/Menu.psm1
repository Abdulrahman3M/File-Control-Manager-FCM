function New-FcmMenuLine {
    param([string]$Text,[string]$Role = 'Normal',[string]$IconName = '',[string]$Suffix = '')
    return @{ Text = $Text; Role = $Role; IconName = $IconName; Suffix = $Suffix }
}

function Show-FcmMenu {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [string]$Context = '',
        [Parameter(Mandatory = $true)][object[]]$Items,
        [int]$SelectedIndex = 0,
        [string]$Status = '',
        [string]$AppVersion = '3.2.2',
        [string]$ModeLabel = 'Administrator Session',
        [string]$Target = '(not selected)',
        [switch]$Static
    )
    if ($Items.Count -lt 1) { return 'Exit' }
    if ($SelectedIndex -lt 0 -or $SelectedIndex -ge $Items.Count) { $SelectedIndex = 0 }
    $numberBuffer = ''
    $message = ''
    while ($true) {
        $size = Get-FcmTerminalSize
        $lines = New-Object 'System.Collections.Generic.List[object]'
        $lines.Add((New-FcmMenuLine '  ' 'Title' 'App' ('  File Control Manager  (v' + $AppVersion + ')')))
        $lines.Add((New-FcmMenuLine ('  ' + $Title + '  |  ' + $Context) 'Dim'))
        $lines.Add((New-FcmMenuLine '  ' 'Info' 'Admin' ('  ' + $ModeLabel)))
        $lines.Add((New-FcmMenuLine ('  Target  ' + $Target) 'Normal'))
        $lines.Add((New-FcmMenuLine ('  ' + ('-' * [Math]::Min(72,$size.Width - 4))) 'Border'))
        $lines.Add((New-FcmMenuLine '  Actions' 'Heading'))

        $rowBudget = [Math]::Max(3,$size.Height - 12)
        $first = 0
        if ($Items.Count -gt $rowBudget) {
            $first = [Math]::Max(0,$SelectedIndex - [Math]::Floor($rowBudget / 2))
            $first = [Math]::Min($first,$Items.Count - $rowBudget)
            if ($first -gt 0) { $lines.Add((New-FcmMenuLine '  ... more actions above ...' 'Dim')) }
        }
        $last = [Math]::Min($Items.Count - 1,$first + $rowBudget - 1)
        for ($index = $first; $index -le $last; $index++) {
            $item = $Items[$index]
            $number = '{0:D2}' -f ($index + 1)
            $marker = '  '
            $role = 'Normal'
            if ($index -eq $SelectedIndex) { $marker = '> '; $role = 'Selected' }
            if ($item.Disabled) { $role = 'Dim' }
            $prefix = ('  {0}{1}  ' -f $marker,$number)
            $lines.Add((New-FcmMenuLine $prefix $role ([string]$item.Icon) ('  ' + [string]$item.Label)))
        }
        if ($last -lt $Items.Count - 1) { $lines.Add((New-FcmMenuLine '  ... more actions below ...' 'Dim')) }
        $lines.Add((New-FcmMenuLine ('  ' + ('-' * [Math]::Min(72,$size.Width - 4))) 'Border'))
        if ($message) {
            $lines.Add((New-FcmMenuLine ('  ' + $message) 'Warning'))
        }
        elseif ($Status) {
            $lines.Add((New-FcmMenuLine ('  ' + $Status) 'Info'))
        }
        if ($SelectedIndex -ge 0 -and $SelectedIndex -lt $Items.Count) {
            $lines.Add((New-FcmMenuLine ('  ' + [string]$Items[$SelectedIndex].Description) 'Dim'))
        }
        $lines.Add((New-FcmMenuLine '  Up/Down move   Enter select   01-11 quick select   Esc back   Ctrl+C exit' 'Dim'))
        if ($numberBuffer) { $lines.Add((New-FcmMenuLine ('  Select: ' + $numberBuffer) 'Accent')) }
        Write-FcmScreen -Line $lines.ToArray()
        if ($Static) { return 'Static' }

        $key = Read-FcmKey
        switch ($key.Key) {
            'Up' { $SelectedIndex = ($SelectedIndex - 1 + $Items.Count) % $Items.Count; $numberBuffer = ''; $message = ''; continue }
            'Down' { $SelectedIndex = ($SelectedIndex + 1) % $Items.Count; $numberBuffer = ''; $message = ''; continue }
            'Escape' { return 'Back' }
            'Cancel' { return 'Exit' }
            'Backspace' {
                if ($numberBuffer.Length -gt 0) { $numberBuffer = $numberBuffer.Substring(0,$numberBuffer.Length - 1) }
                $message = ''
                continue
            }
            'Enter' {
                if ($numberBuffer) {
                    $chosenNumber = 0
                    [void][int]::TryParse($numberBuffer,[ref]$chosenNumber)
                    if ($chosenNumber -ge 1 -and $chosenNumber -le $Items.Count) { return [string]$Items[$chosenNumber - 1].Id }
                    $message = 'That action number is not available.'
                    $numberBuffer = ''
                    continue
                }
                return [string]$Items[$SelectedIndex].Id
            }
            'Digit' {
                $numberBuffer += [string]$key.Character
                $chosenNumber = 0
                [void][int]::TryParse($numberBuffer,[ref]$chosenNumber)
                $exact = $chosenNumber -ge 1 -and $chosenNumber -le $Items.Count
                $hasLonger = $false
                foreach ($itemIndex in 1..$Items.Count) {
                    $itemNumber = [string]$itemIndex
                    if ($itemNumber.Length -gt $numberBuffer.Length -and $itemNumber.StartsWith($numberBuffer)) { $hasLonger = $true }
                    $paddedNumber = '{0:D2}' -f $itemIndex
                    if ($paddedNumber.Length -gt $numberBuffer.Length -and $paddedNumber.StartsWith($numberBuffer)) { $hasLonger = $true }
                }
                if ($exact -and $numberBuffer.Length -ge 2) { return [string]$Items[$chosenNumber - 1].Id }
                if ($exact -and -not $hasLonger) { return [string]$Items[$chosenNumber - 1].Id }
                $validPrefix = $false
                for ($itemIndex = 1; $itemIndex -le $Items.Count; $itemIndex++) {
                    if (([string]$itemIndex).StartsWith($numberBuffer) -or ('{0:D2}' -f $itemIndex).StartsWith($numberBuffer)) { $validPrefix = $true }
                }
                if (-not $validPrefix) { $message = 'That action number is not available.'; $numberBuffer = '' }
                else { $message = '' }
                continue
            }
            default { $numberBuffer = ''; $message = '' }
        }
    }
}

Export-ModuleMember -Function Show-FcmMenu

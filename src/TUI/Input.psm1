$script:FcmInputQueue = New-Object System.Collections.Generic.Queue[string]

function Set-FcmScriptedInput {
    param([string[]]$Token)
    $script:FcmInputQueue = New-Object System.Collections.Generic.Queue[string]
    foreach ($item in $Token) {
        $value = ([string]$item).Trim()
        if ($value -match '^\d+$' -and $value.Length -gt 1) {
            foreach ($digit in $value.ToCharArray()) { $script:FcmInputQueue.Enqueue([string]$digit) }
        }
        else {
            $script:FcmInputQueue.Enqueue($value.ToUpperInvariant())
        }
    }
}

function Read-FcmKey {
    if ($script:FcmInputQueue.Count -gt 0) {
        $token = $script:FcmInputQueue.Dequeue()
        if ($token.StartsWith('TEXT:')) {
            return @{ Key = 'Character'; Character = $token.Substring(5) }
        }
        if ($token.Length -eq 1 -and $token -match '^\d$') {
            return @{ Key = 'Digit'; Character = $token }
        }
        if ($token.Length -eq 1 -and $token -match '^[A-Z]$') {
            return @{ Key = 'Character'; Character = $token }
        }
        $map = @{
            ENTER = 'Enter'; ESC = 'Escape'; ESCAPE = 'Escape'; UP = 'Up'; DOWN = 'Down'
            LEFT = 'Left'; RIGHT = 'Right'; BACKSPACE = 'Backspace'; DELETE = 'Delete'
            HOME = 'Home'; END = 'End'; 'CTRL+C' = 'Cancel'; 'CTRL+U' = 'Clear'
        }
        if ($map.ContainsKey($token)) { return @{ Key = $map[$token]; Character = '' } }
        return @{ Key = 'Character'; Character = $token }
    }
    $key = [Console]::ReadKey($true)
    if ($key.Key -eq [ConsoleKey]::UpArrow) { return @{ Key = 'Up'; Character = '' } }
    if ($key.Key -eq [ConsoleKey]::DownArrow) { return @{ Key = 'Down'; Character = '' } }
    if ($key.Key -eq [ConsoleKey]::LeftArrow) { return @{ Key = 'Left'; Character = '' } }
    if ($key.Key -eq [ConsoleKey]::RightArrow) { return @{ Key = 'Right'; Character = '' } }
    if ($key.Key -eq [ConsoleKey]::Enter) { return @{ Key = 'Enter'; Character = '' } }
    if ($key.Key -eq [ConsoleKey]::Escape) { return @{ Key = 'Escape'; Character = '' } }
    if ($key.Key -eq [ConsoleKey]::Backspace) { return @{ Key = 'Backspace'; Character = '' } }
    if ($key.Key -eq [ConsoleKey]::Delete) { return @{ Key = 'Delete'; Character = '' } }
    if ($key.Key -eq [ConsoleKey]::Home) { return @{ Key = 'Home'; Character = '' } }
    if ($key.Key -eq [ConsoleKey]::End) { return @{ Key = 'End'; Character = '' } }
    if ($key.Key -eq [ConsoleKey]::U -and $key.Modifiers -band [ConsoleModifiers]::Control) {
        return @{ Key = 'Clear'; Character = '' }
    }
    if ($key.KeyChar -eq [char]3) { return @{ Key = 'Cancel'; Character = '' } }
    if ($key.KeyChar -match '^\d$') { return @{ Key = 'Digit'; Character = [string]$key.KeyChar } }
    if (-not [char]::IsControl($key.KeyChar)) { return @{ Key = 'Character'; Character = [string]$key.KeyChar } }
    return @{ Key = 'Other'; Character = '' }
}

function Test-FcmScriptedInputAvailable {
    return ($script:FcmInputQueue.Count -gt 0)
}

Export-ModuleMember -Function Set-FcmScriptedInput,Read-FcmKey,Test-FcmScriptedInputAvailable

$script:FcmIconMode = 'Auto'
$script:FcmColorEnabled = $true
$script:FcmPlatform = 'Windows'
$script:FcmIconTable = @{
    App = @{ Emoji = [char]::ConvertFromUtf32(0x1F5C2); Symbol = [string][char]0x25A0; Ascii = '[FCM]' }
    Folder = @{ Emoji = [char]::ConvertFromUtf32(0x1F4C1); Symbol = [string][char]0x25A0; Ascii = '[DIR]' }
    Search = @{ Emoji = [char]::ConvertFromUtf32(0x1F50E); Symbol = [string][char]0x25CF; Ascii = '[?]' }
    Rename = @{ Emoji = [char]::ConvertFromUtf32(0x1F58A); Symbol = [string][char]0x25BA; Ascii = '[~]' }
    Copy = @{ Emoji = [char]::ConvertFromUtf32(0x1F4CB); Symbol = [string][char]0x25A0; Ascii = '[+]' }
    Move = @{ Emoji = [char]::ConvertFromUtf32(0x1F4E6); Symbol = [string][char]0x25BA; Ascii = '[>]' }
    Delete = @{ Emoji = [char]::ConvertFromUtf32(0x1F5D1); Symbol = [string][char]0x00D7; Ascii = '[X]' }
    Key = @{ Emoji = [char]::ConvertFromUtf32(0x1F511); Symbol = [string][char]0x2666; Ascii = '[*]' }
    Shield = @{ Emoji = [char]::ConvertFromUtf32(0x1F6E1); Symbol = [string][char]0x221A; Ascii = '[+]' }
    Admin = @{ Emoji = [char]::ConvertFromUtf32(0x1F6E1); Symbol = [string][char]0x25B2; Ascii = '[^]' }
    Logs = @{ Emoji = [char]::ConvertFromUtf32(0x1F4DC); Symbol = [string][char]0x25A0; Ascii = '[#]' }
    Exit = @{ Emoji = [char]::ConvertFromUtf32(0x1F6AA); Symbol = [string][char]0x25C4; Ascii = '[<]' }
    Success = @{ Emoji = [char]::ConvertFromUtf32(0x2705); Symbol = [string][char]0x221A; Ascii = '[+]' }
    Warning = @{ Emoji = [char]::ConvertFromUtf32(0x1F536); Symbol = [string][char]0x25B2; Ascii = '[!]' }
    Error = @{ Emoji = [char]::ConvertFromUtf32(0x274C); Symbol = [string][char]0x00D7; Ascii = '[X]' }
    Info = @{ Emoji = [char]::ConvertFromUtf32(0x1F6C8); Symbol = [string][char]0x263A; Ascii = '[i]' }
}
$script:FcmPalette = @{
    Title = @{ Foreground = 'Cyan'; Background = $null }
    Heading = @{ Foreground = 'White'; Background = $null }
    Normal = @{ Foreground = 'Gray'; Background = $null }
    Dim = @{ Foreground = 'DarkGray'; Background = $null }
    Selected = @{ Foreground = 'White'; Background = 'DarkBlue' }
    Accent = @{ Foreground = 'Cyan'; Background = $null }
    Success = @{ Foreground = 'Green'; Background = $null }
    Warning = @{ Foreground = 'Yellow'; Background = $null }
    Error = @{ Foreground = 'Red'; Background = $null }
    Info = @{ Foreground = 'Blue'; Background = $null }
    Border = @{ Foreground = 'DarkCyan'; Background = $null }
}

function Initialize-FcmTheme {
    param([string]$IconMode = 'Auto',[string]$Platform = 'Windows',[switch]$NoColor)
    $script:FcmIconMode = $IconMode
    $script:FcmPlatform = $Platform
    $script:FcmColorEnabled = (-not $NoColor) -and (-not $env:NO_COLOR)
}

function Get-FcmIconTier {
    $override = [string]$script:FcmIconMode
    if ($override -eq 'Auto') { $override = [string]$env:FCM_ICONS }
    if ($override -in @('emoji','symbol','ascii')) {
        if ($override -eq 'emoji') { return 'Emoji' }
        if ($override -eq 'symbol') { return 'Symbol' }
        return 'Ascii'
    }
    if ([Console]::IsOutputRedirected) { return 'Ascii' }
    if ($env:WT_SESSION -or $env:TERM_PROGRAM -or $env:ConEmuANSI -eq 'ON') { return 'Emoji' }
    if ($script:FcmPlatform -eq 'Windows') { return 'Symbol' }
    if ($env:LANG -match 'UTF-?8' -or $env:LC_ALL -match 'UTF-?8') { return 'Emoji' }
    return 'Ascii'
}

function Get-FcmIcon {
    param([Parameter(Mandatory = $true)][string]$Name)
    if (-not $script:FcmIconTable.ContainsKey($Name)) { return '[?]' }
    $tier = Get-FcmIconTier
    if ($tier -eq 'Emoji') { return [string]$script:FcmIconTable[$Name].Emoji }
    if ($tier -eq 'Symbol') { return [string]$script:FcmIconTable[$Name].Symbol }
    return [string]$script:FcmIconTable[$Name].Ascii
}

function Get-FcmStyle {
    param([Parameter(Mandatory = $true)][string]$Role)
    if (-not $script:FcmColorEnabled -or -not $script:FcmPalette.ContainsKey($Role)) {
        return @{ Foreground = $null; Background = $null }
    }
    return $script:FcmPalette[$Role]
}

Export-ModuleMember -Function Initialize-FcmTheme,Get-FcmIconTier,Get-FcmIcon,Get-FcmStyle

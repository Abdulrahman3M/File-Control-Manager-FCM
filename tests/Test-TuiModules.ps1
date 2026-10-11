$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'src/Import-Modules.ps1')

function Assert-FcmTest {
    param([bool]$Condition,[string]$Message)
    if (-not $Condition) { throw ('FAIL: ' + $Message) }
    Write-Output ('PASS: ' + $Message)
}

Initialize-FcmTheme -IconMode 'Auto' -Platform 'Windows' -NoColor
Initialize-FcmRenderer -PlainOutput
$sourceFiles = @((Join-Path $root 'FCM.ps1')) + @(Get-ChildItem -LiteralPath (Join-Path $root 'src') -Recurse -File | Where-Object { $_.Extension -in '.ps1','.psm1' } | ForEach-Object { $_.FullName })
foreach ($sourceFile in $sourceFiles) {
    $bytes = [IO.File]::ReadAllBytes($sourceFile)
    if ($bytes | Where-Object { $_ -gt 127 } | Select-Object -First 1) {
        throw ('FAIL: PowerShell source is not ASCII-only: ' + $sourceFile)
    }
    $tokens = $null
    $parseErrors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($sourceFile,[ref]$tokens,[ref]$parseErrors) | Out-Null
    if ($parseErrors) { throw ('FAIL: PowerShell syntax error in ' + $sourceFile + ': ' + ($parseErrors -join '; ')) }
}
Assert-FcmTest $true 'PowerShell source is ASCII-only and parses'

$oldIconMode = $env:FCM_ICONS
try {
    $env:FCM_ICONS = 'ascii'
    $icon = Get-FcmIcon 'Folder'
    Assert-FcmTest ($icon -eq '[DIR]') 'ASCII icon override selects readable fallback'
    $allIconsAreAscii = $true
    foreach ($iconName in @('App','Folder','Search','Rename','Copy','Move','Delete','Key','Shield','Admin','Logs','Exit','Success','Warning','Error','Info')) {
        if ((Get-FcmIcon $iconName) -match '[^\x00-\x7F]') { $allIconsAreAscii = $false }
    }
    Assert-FcmTest $allIconsAreAscii 'Every icon has an ASCII-only fallback'

$env:FCM_ICONS = 'emoji'
$emojiIcon = Get-FcmIcon 'Folder'
Assert-FcmTest ((Get-FcmIconTier) -eq 'Emoji' -and $emojiIcon.Length -gt 0 -and $emojiIcon -match '[^\x00-\x7F]') 'Explicit Emoji mode returns a Unicode folder glyph'
$env:FCM_ICONS = 'symbol'
Assert-FcmTest ((Get-FcmIconTier) -eq 'Symbol' -and (Get-FcmIcon 'Folder') -match '[^\x00-\x7F]') 'Windows symbol mode returns a Unicode fallback glyph'
$oldNoColor = $env:NO_COLOR
Remove-Item Env:NO_COLOR -ErrorAction SilentlyContinue
Initialize-FcmTheme -IconMode Auto -Platform Windows
$titleStyle = Get-FcmStyle 'Title'
$successStyle = Get-FcmStyle 'Success'
$warningStyle = Get-FcmStyle 'Warning'
if ($null -ne $oldNoColor) { $env:NO_COLOR = $oldNoColor }
Initialize-FcmTheme -IconMode Auto -Platform Windows -NoColor:([bool]$env:NO_COLOR)
Assert-FcmTest ($titleStyle.Foreground -eq 'Cyan' -and $successStyle.Foreground -eq 'Green' -and $warningStyle.Foreground -eq 'Yellow') 'Semantic title, success, and warning colors are configured'
Assert-FcmTest ((Get-FcmIconColor 'Folder') -eq 'Yellow' -and (Get-FcmIconColor 'Delete') -eq 'Red' -and (Get-FcmIconColor 'Success') -eq 'Green') 'Action and status icons have distinct semantic colors'
}
finally {
    $env:FCM_ICONS = $oldIconMode
}

$items = @(
    @{ Id = 'first'; Label = 'First action'; Icon = 'Folder'; Description = 'First description.'; Disabled = $false },
    @{ Id = 'second'; Label = 'Second action'; Icon = 'Search'; Description = 'Second description.'; Disabled = $false }
)
Set-FcmScriptedInput -Token @('01')
$choice = Show-FcmMenu -Title 'Test' -Items $items -Status 'Ready' -AppVersion '3.1.0' -ModeLabel 'ADMINISTRATOR SESSION'
Assert-FcmTest ($choice -eq 'first') 'Zero-padded numeric shortcut selects the intended row'

Set-FcmScriptedInput -Token @('1','ENTER')
$choice = Show-FcmMenu -Title 'Test' -Items $items -Status 'Ready'
Assert-FcmTest ($choice -eq 'first') 'Single-digit shortcut commits when Enter resolves a longer-number prefix'

Set-FcmScriptedInput -Token @('DOWN','ENTER')
$choice = Show-FcmMenu -Title 'Test' -Items $items -Status 'Ready'
Assert-FcmTest ($choice -eq 'second') 'Arrow navigation and Enter select the highlighted row'

$manyItems = @()
for ($index = 1; $index -le 11; $index++) {
    $manyItems += @{ Id = ('item' + $index); Label = ('Action ' + $index); Icon = 'Info'; Description = 'Test action.'; Disabled = $false }
}
Set-FcmScriptedInput -Token @('11')
$choice = Show-FcmMenu -Title 'Test' -Items $manyItems -Status 'Ready'
Assert-FcmTest ($choice -eq 'item11') 'Two-digit shortcut selects the eleventh action'

Set-FcmScriptedInput -Token @('01','TEXT:DELETE','ENTER')
$confirmed = Show-FcmConfirm -Title 'Delete test' -Message 'Permanent action' -Destructive -RequireText 'DELETE'
Assert-FcmTest ([bool]$confirmed) 'Permanent-action dialog requires the exact typed confirmation'

Set-FcmScriptedInput -Token @('02')
$confirmed = Show-FcmConfirm -Title 'Cancel test' -Message 'No action'
Assert-FcmTest (-not $confirmed) 'Cancel returns without confirming an action'

$numericPath = 'C:\Test\05 Info Bank\02 User Data Layer\.pytest_cache'
$numericTokens = @('TEXT:C:\Test\','0','5','TEXT: Info Bank\','0','2','TEXT: User Data Layer\.pytest_cache','ENTER')
Set-FcmScriptedInput -Token $numericTokens
$acceptedNumericPath = Read-FcmValidatedInput -Title 'Path test' -Prompt 'Target path' -Validator {
    param($value)
    if ($value -ieq $numericPath) { return $null }
    return 'Path characters were changed.'
}
Assert-FcmTest ($acceptedNumericPath.ToUpperInvariant() -eq $numericPath.ToUpperInvariant()) 'Path editor preserves every numeric character in numbered folder segments'

Write-Output 'All PowerShell TUI module checks passed.'

# Compatibility entry point: the former Windows Forms interface has been retired.
# All actions now use the PowerShell TUI and native PowerShell/Windows operations.
[CmdletBinding()]
param(
    [switch]$Version,
    [string]$InitialPath = '',
    [switch]$SelfTest,
    [switch]$SmokeTest,
    [ValidateSet('ownership','grant')][string]$StartAction = '',
    [switch]$AdminSession,
    [string]$ScriptedInput = ''
)
$entry = Join-Path $PSScriptRoot 'FCM.ps1'
if (-not (Test-Path -LiteralPath $entry -PathType Leaf)) {
    throw 'FCM.ps1 is missing. Restore the complete File Control Manager folder.'
}
& $entry @PSBoundParameters


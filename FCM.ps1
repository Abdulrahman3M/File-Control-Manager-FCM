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

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
$root = Split-Path -Parent $PSCommandPath
$appVersion = (Get-Content -LiteralPath (Join-Path $root 'VERSION') -Raw).Trim()
if ($Version) {
    Write-Output ('File Control Manager v' + $appVersion)
    exit 0
}

function Write-FcmStartupMessage {
    param([string]$Title,[string[]]$Message,[string]$Role = 'Error')
    if (Get-Command -Name Write-FcmScreen -ErrorAction SilentlyContinue) {
        $lines = New-Object 'System.Collections.Generic.List[object]'
        $lines.Add(@{ Text = '  '; Role = 'Title'; IconName = 'App'; Suffix = '  File Control Manager (v' + $appVersion + ')' })
        $lines.Add(@{ Text = ('  ' + $Title); Role = $Role })
        foreach ($line in $Message) { $lines.Add(@{ Text = ('  ' + $line); Role = $Role }) }
        Write-FcmScreen -Line $lines.ToArray()
    }
    else {
        foreach ($line in $Message) { Write-Error $line }
    }
}

try {
    . (Join-Path $root 'src/Import-Modules.ps1')
}
catch {
    Write-Error ('FCM could not load its PowerShell modules. Restore the complete FCM folder. Details: ' + $_.Exception.Message)
    exit 2
}

$environment = Get-FcmEnvironment
Initialize-FcmTheme -IconMode 'Auto' -Platform $environment.Platform -NoColor:([bool]$env:NO_COLOR -or $environment.OutputRedirected)
Initialize-FcmRenderer -PlainOutput:($environment.OutputRedirected -or $SmokeTest -or [bool]$ScriptedInput)
# Register terminal restoration for abnormal exits as well as normal shutdown.
$global:FCMRendererCleanupRegistered = $true

$preflightFailures = @(Get-FcmPreflightFailures -Root $root)
if ($preflightFailures.Count -gt 0) {
    Write-FcmStartupMessage -Title 'Startup checks found a problem' -Message ($preflightFailures + @('Install or restore the item listed above, then start FCM again.'))
    exit 2
}

if ($SelfTest) {
    Write-Output ('FCM startup check passed | v' + $appVersion + ' | PowerShell ' + $environment.PowerShell + ' | PowerShell-only')
    exit 0
}

$diagnosticMode = [bool]($SmokeTest -or $ScriptedInput)
if (-not $diagnosticMode -and ($environment.OutputRedirected -or $environment.InputRedirected)) {
    Write-FcmStartupMessage -Title 'Interactive terminal required' -Message @('Open Windows Terminal or a PowerShell console and run FCM.ps1 again. Use -SmokeTest for an automated dashboard check.')
    exit 2
}

$disposition = Get-FcmStartupDisposition -IsAdministrator $environment.IsAdministrator -DiagnosticMode $diagnosticMode
if ($disposition -eq 'Elevate') {
    Write-FcmStartupMessage -Title 'Administrator approval required' -Message @('Windows will display its standard UAC prompt. If approval is canceled, FCM closes without opening the menu.') -Role 'Warning'
    $elevation = Start-FcmStartupElevation -ScriptPath $PSCommandPath -InitialPath $InitialPath
    if ($elevation.Status -eq 'Started') { exit 0 }
    if ($elevation.Status -eq 'Canceled') {
        Write-FcmStartupMessage -Title 'FCM is closing' -Message @($elevation.Message) -Role 'Warning'
        exit 5
    }
    Write-FcmStartupMessage -Title 'Administrator startup failed' -Message @($elevation.Message)
    exit 6
}

if (($AdminSession -or $StartAction) -and -not $environment.IsAdministrator) {
    Write-FcmStartupMessage -Title 'Administrator access was not granted' -Message @('FCM did not run the requested action. Start the elevated FCM session again and approve the Windows prompt.')
    exit 4
}

$scriptedTokens = @()
if ($ScriptedInput) { $scriptedTokens = @($ScriptedInput -split ',') }
$previousControlC = $false
$controlCChanged = $false
try {
    if (-not $diagnosticMode) {
        try {
            $previousControlC = [Console]::TreatControlCAsInput
            [Console]::TreatControlCAsInput = $true
            $controlCChanged = $true
        }
        catch { }
    }
    Start-FcmApp -InitialPath $InitialPath -ScriptPath $PSCommandPath -StartAction $StartAction -AdminSession:$AdminSession -SmokeTest:$SmokeTest -ScriptedInput $scriptedTokens
}
catch [OperationCanceledException] {
    exit 0
}
catch {
    Write-FcmStartupMessage -Title 'FCM could not continue' -Message @($_.Exception.Message)
    exit 3
}
finally {
    if ($controlCChanged) {
        try { [Console]::TreatControlCAsInput = $previousControlC } catch { }
    }
}
exit 0

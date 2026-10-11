function Test-FcmAdministrator {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        return $false
    }
}

function Test-FcmWindows {
    if ($env:OS -eq 'Windows_NT') { return $true }
    if ($PSVersionTable.PSVersion.Major -lt 6) { return $true }
    $isWindows = Get-Variable -Name IsWindows -ValueOnly -ErrorAction SilentlyContinue
    return [bool]$isWindows
}

function Get-FcmEnvironment {
    $width = 80
    $height = 25
    $outputRedirected = $false
    $inputRedirected = $false
    try {
        $width = [Console]::WindowWidth
        $height = [Console]::WindowHeight
        $outputRedirected = [Console]::IsOutputRedirected
        $inputRedirected = [Console]::IsInputRedirected
    }
    catch {
        $outputRedirected = $true
        $inputRedirected = $true
    }
    try {
        if ($Host.UI.RawUI.WindowSize.Width -gt 0) { $width = $Host.UI.RawUI.WindowSize.Width }
        if ($Host.UI.RawUI.WindowSize.Height -gt 0) { $height = $Host.UI.RawUI.WindowSize.Height }
    }
    catch { }
    $edition = 'Desktop'
    if ($PSVersionTable.ContainsKey('PSEdition')) {
        $edition = [string]$PSVersionTable.PSEdition
    }
    $terminal = 'Console'
    if ($env:WT_SESSION) { $terminal = 'WindowsTerminal' }
    elseif ($env:TERM_PROGRAM) { $terminal = [string]$env:TERM_PROGRAM }
    return [pscustomobject]@{
        Platform = $(if (Test-FcmWindows) { 'Windows' } else { 'Other' })
        PowerShell = [string]$PSVersionTable.PSVersion
        Edition = $edition
        Width = [Math]::Max(40, [int]$width)
        Height = [Math]::Max(12, [int]$height)
        OutputRedirected = [bool]$outputRedirected
        InputRedirected = [bool]$inputRedirected
        Terminal = $terminal
        IsAdministrator = (Test-FcmAdministrator)
    }
}

function Get-FcmPreflightFailures {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$Root)
    $failures = New-Object 'System.Collections.Generic.List[string]'
    if (-not (Test-FcmWindows)) { $failures.Add('FCM requires Windows. Run it in Windows PowerShell or PowerShell 7 on Windows.') }
    $version = $PSVersionTable.PSVersion
    if ($version.Major -lt 5 -or ($version.Major -eq 5 -and $version.Minor -lt 1)) {
        $failures.Add(('PowerShell 5.1 or later is required. Current version: ' + $version + '. Install Windows PowerShell 5.1 or PowerShell 7.'))
    }
    foreach ($requiredFile in @('VERSION','FCM.ps1','src/Import-Modules.ps1')) {
        if (-not (Test-Path -LiteralPath (Join-Path $Root $requiredFile) -PathType Leaf)) {
            $failures.Add(('Required FCM file is missing: ' + $requiredFile + '. Restore the complete FCM folder.'))
        }
    }
    foreach ($failure in @(Get-FcmOperationPrerequisites)) { $failures.Add($failure) }
    return $failures.ToArray()
}

function Get-FcmStartupDisposition {
    param([bool]$IsAdministrator,[bool]$DiagnosticMode)
    if ($DiagnosticMode) { return 'Diagnostic' }
    if ($IsAdministrator) { return 'Continue' }
    return 'Elevate'
}

function Get-FcmPowerShellExecutable {
    $process = Get-Process -Id $PID -ErrorAction Stop
    if (-not [string]::IsNullOrWhiteSpace($process.Path)) {
        return $process.Path
    }
    $command = Get-Command -Name pwsh,powershell -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($command) { return $command.Source }
    throw 'The current PowerShell executable could not be located.'
}

Export-ModuleMember -Function Test-FcmWindows,Test-FcmAdministrator,Get-FcmEnvironment,Get-FcmPreflightFailures,Get-FcmStartupDisposition,Get-FcmPowerShellExecutable

# Windows launcher integration checks, to be run under PowerShell 5.1 and 7.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$entry = Join-Path $root 'FCM.ps1'
$version = (Get-Content -LiteralPath (Join-Path $root 'VERSION') -Raw).Trim()
$exe = (Get-Process -Id $PID).Path

function Assert-Fcm([bool]$condition, [string]$description) {
    if (-not $condition) { throw "FAIL: $description" }
    Write-Host "PASS: $description"
}

$versionResult = & $exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $entry -Version 2>&1 | Out-String
Assert-Fcm ($LASTEXITCODE -eq 0) 'Version switch exits successfully (regression for case-insensitive $Version)'
Assert-Fcm ($versionResult.Trim() -eq "File Control Manager v$version") 'Version output matches VERSION file'

$selfTest = & $exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $entry -SelfTest 2>&1 | Out-String
Assert-Fcm ($LASTEXITCODE -eq 0) 'PowerShell prerequisite check succeeds'
Assert-Fcm ($selfTest -match [regex]::Escape("v$version")) 'Prerequisite check reports the correct app version'
Assert-Fcm ($selfTest -notmatch 'Python') 'SelfTest output has no Python runtime dependency'

. (Join-Path $root 'src/Import-Modules.ps1')
$adminDisposition = Get-FcmStartupDisposition -IsAdministrator $true -DiagnosticMode $false
$userDisposition = Get-FcmStartupDisposition -IsAdministrator $false -DiagnosticMode $false
$diagnosticDisposition = Get-FcmStartupDisposition -IsAdministrator $false -DiagnosticMode $true
Assert-Fcm ($adminDisposition -eq 'Continue') 'An elevated session proceeds to preflight and the TUI'
Assert-Fcm ($userDisposition -eq 'Elevate') 'A normal interactive startup must request administrator approval'
Assert-Fcm ($diagnosticDisposition -eq 'Diagnostic') 'SelfTest and SmokeTest stay non-elevating'
$quotedArguments = ConvertTo-FcmWindowsArgumentLine -Argument @('-File','C:\Program Files\FCM\FCM.ps1','-InitialPath','D:\Data Folder\05 File.txt')
Assert-Fcm ($quotedArguments -eq '"-File" "C:\Program Files\FCM\FCM.ps1" "-InitialPath" "D:\Data Folder\05 File.txt"') 'UAC relaunch arguments preserve spaces and numbered paths'
$terminalArguments = Get-FcmWindowsTerminalLaunchArguments -PowerShellPath 'C:\Program Files\PowerShell\7\pwsh.exe' -ScriptPath 'C:\Program Files\FCM\FCM.ps1' -InitialPath 'D:\Data Folder\05 File.txt'
Assert-Fcm ($terminalArguments.Contains('"--window" "new"') -and $terminalArguments.Contains('"new-tab"') -and $terminalArguments.Contains('"--title"') -and $terminalArguments.Contains('"C:\Program Files\PowerShell\7\pwsh.exe"') -and $terminalArguments.Contains('"D:\Data Folder\05 File.txt"')) 'Elevated launch opens a dedicated Windows Terminal window with quoted PowerShell and target paths'
$actionTerminalArguments = Get-FcmWindowsTerminalLaunchArguments -PowerShellPath 'pwsh.exe' -ScriptPath 'C:\Program Files\FCM\FCM.ps1' -StartAction 'ownership'
Assert-Fcm ($actionTerminalArguments.Contains('"-StartAction" "ownership"')) 'Elevated security actions retain their selected operation in Windows Terminal'
$uacCanceled = New-Object System.ComponentModel.Win32Exception(1223)
Assert-Fcm ((Get-FcmStartupElevationStatus -Exception $uacCanceled) -eq 'Canceled') 'Windows UAC cancellation is recognized and closes the launcher'
$preflightFailures = @(Get-FcmPreflightFailures -Root $root)
Assert-Fcm ($preflightFailures.Count -eq 0) 'Preflight recognizes the installed PowerShell modules and Windows utilities'

$nativeSource = @((Get-Content (Join-Path $root 'FCM.ps1')) + (Get-Content (Join-Path $root 'FCM.bat')) + (Get-ChildItem (Join-Path $root 'src') -Recurse -File -Include *.ps1,*.psm1 | ForEach-Object { Get-Content $_.FullName })) -join "`n"
Assert-Fcm ($nativeSource -notmatch 'fcm\.py|python\.exe|Get-FcmPythonRuntime') 'Application source does not invoke Python'

# End-to-end launcher smoke run without reliance on PowerShell pipeline input.
# The application renders the real menu once and exits (no user input required).
$previousErrorAction = $ErrorActionPreference
try {
    $ErrorActionPreference = 'Continue'
    $menuOutput = & $exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $entry -SmokeTest 2>&1 | Out-String
    $menuExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorAction
}
if ($menuExitCode -ne 0) { Write-Host ('FCM dashboard smoke output: ' + $menuOutput) }
Assert-Fcm ($menuExitCode -eq 0) 'PowerShell renders the native dashboard without hanging'
Assert-Fcm ($menuOutput -match 'FILE CONTROL MANAGER') 'The terminal interface renders its dashboard'
Assert-Fcm ($menuOutput -match 'DIAGNOSTIC') 'SmokeTest identifies its non-elevated diagnostic mode'
foreach ($label in @('Choose file or folder','Inspect metadata, ACL and EFS status','Rename','Copy','Move','Permanently delete','Take ownership','Grant Administrators Full Control','Open Administrator session','View activity logs','Exit')) {
    Assert-Fcm ($menuOutput -match [regex]::Escape($label)) ('The dashboard keeps the "' + $label + '" action')
}

$scriptedExit = & $exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $entry -ScriptedInput '11' 2>&1 | Out-String
Assert-Fcm ($LASTEXITCODE -eq 0) 'Scripted menu exit completes without reading piped console input'
Assert-Fcm ($scriptedExit -match 'Exit') 'Scripted navigation renders the Exit action'

# Exercise the actual double-click entry file (CMD/BAT), not just FCM.ps1.
Push-Location $root
try {
    $batVersion = & $env:ComSpec /d /c 'FCM.bat -Version' 2>&1 | Out-String
    $batVersionExit = $LASTEXITCODE
    Assert-Fcm ($batVersionExit -eq 0) 'FCM.bat version launch exits successfully'
    Assert-Fcm ($batVersion.Trim() -eq "File Control Manager v$version") 'FCM.bat resolves the correct version'

    $legacyLauncherVersion = & $env:ComSpec /d /c 'Launch-FCM.cmd -Version' 2>&1 | Out-String
    $legacyLauncherExit = $LASTEXITCODE
    Assert-Fcm ($legacyLauncherExit -eq 0) 'Launch-FCM.cmd forwards to the current PowerShell launcher'
    Assert-Fcm ($legacyLauncherVersion.Trim() -eq "File Control Manager v$version") 'Legacy launcher reports the current version'

    $batDashboard = & $env:ComSpec /d /c 'FCM.bat -SmokeTest' 2>&1 | Out-String
    $batDashboardExit = $LASTEXITCODE
    if ($batDashboardExit -ne 0) { Write-Host ('FCM.bat smoke output: ' + $batDashboard) }
    Assert-Fcm ($batDashboardExit -eq 0) 'FCM.bat renders the dashboard and exits'
    Assert-Fcm ($batDashboard -match 'FILE CONTROL MANAGER') 'FCM.bat launches the PowerShell dashboard'
}
finally {
    Pop-Location
}

Write-Host 'All FCM launcher checks passed.'


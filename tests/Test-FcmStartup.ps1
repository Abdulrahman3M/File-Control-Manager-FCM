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
Assert-Fcm ($LASTEXITCODE -eq 0) 'Python runtime detection succeeds without prompting for elevation'
Assert-Fcm ($selfTest -match [regex]::Escape("v$version")) 'Runtime check reports the correct app version'

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
Assert-Fcm ($menuExitCode -eq 0) 'PowerShell can launch Python and render the menu without hanging'
Assert-Fcm ($menuOutput -match 'FILE CONTROL MANAGER') 'The terminal interface renders its dashboard'

# Exercise the actual double-click entry file (CMD/BAT), not just FCM.ps1.
Push-Location $root
try {
    $batVersion = & $env:ComSpec /d /c 'FCM.bat -Version' 2>&1 | Out-String
    $batVersionExit = $LASTEXITCODE
    Assert-Fcm ($batVersionExit -eq 0) 'FCM.bat version launch exits successfully'
    Assert-Fcm ($batVersion.Trim() -eq "File Control Manager v$version") 'FCM.bat resolves the correct version'

    $batDashboard = & $env:ComSpec /d /c 'FCM.bat -SmokeTest' 2>&1 | Out-String
    $batDashboardExit = $LASTEXITCODE
    if ($batDashboardExit -ne 0) { Write-Host ('FCM.bat smoke output: ' + $batDashboard) }
    Assert-Fcm ($batDashboardExit -eq 0) 'FCM.bat renders the dashboard and exits'
    Assert-Fcm ($batDashboard -match 'FILE CONTROL MANAGER') 'FCM.bat launches the Python dashboard'
}
finally {
    Pop-Location
}

Write-Host 'All FCM launcher checks passed.'

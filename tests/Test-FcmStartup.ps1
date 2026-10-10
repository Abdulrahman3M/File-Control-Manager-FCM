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

# End-to-end smoke run: force standard mode, pipe a numbered menu exit selection
# and assert that the Python UI actually launched rather than crashing.
$menuOutput = '11' | & $exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $entry -SkipAdminPrompt 2>&1 | Out-String
if ($LASTEXITCODE -ne 0) { Write-Host ('FCM dashboard smoke output: ' + $menuOutput) }
Assert-Fcm ($LASTEXITCODE -eq 0) 'PowerShell can launch Python and exit cleanly'
Assert-Fcm ($menuOutput -match 'FILE CONTROL MANAGER') 'The terminal interface renders its dashboard'

Write-Host 'All FCM launcher checks passed.'

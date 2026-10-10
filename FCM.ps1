[CmdletBinding()]
param(
    [switch]$Version,
    [string]$InitialPath = '',
    [switch]$SkipAdminPrompt,
    [switch]$SelfTest
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSCommandPath

# PowerShell variable names are case-insensitive. Do not assign to $version,
# which is the same variable as the [switch] $Version parameter.
$appVersion = (Get-Content -LiteralPath (Join-Path $root 'VERSION') -Raw).Trim()
if ($Version) {
    Write-Output "File Control Manager v$appVersion"
    exit 0
}

if ($env:OS -ne 'Windows_NT') {
    Write-Error 'FCM requires Windows.'
    exit 1
}

function Resolve-FcmPython {
    # Only py.exe supports the "-3" launcher flag; python.exe must NOT receive it.
    $candidates = @(
        @{ Name = 'py.exe'; Prefix = @('-3') },
        @{ Name = 'python.exe'; Prefix = @() }
    )

    foreach ($candidate in $candidates) {
        $application = Get-Command -Name $candidate.Name -CommandType Application -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if (-not $application) { continue }

        $exe = $application.Source
        $prefix = @($candidate.Prefix)
        try {
            $checkArgs = @($prefix) + @('--version')
            $output = (& $exe @checkArgs 2>&1 | Out-String).Trim()
            if ($LASTEXITCODE -ne 0) { continue }
            if ($output -notmatch 'Python\s+(\d+)\.(\d+)') { continue }
            $major = [int]$Matches[1]
            $minor = [int]$Matches[2]
            if ($major -gt 3 -or ($major -eq 3 -and $minor -ge 9)) {
                return [pscustomobject]@{
                    Executable = $exe
                    Prefix = $prefix
                    Version = $output
                }
            }
        }
        catch {
            # Broken Windows Store app aliases and missing Python installations
            # should not prevent trying the next Python executable.
            continue
        }
    }

    throw 'Python 3.9+ was not found. Install Python, reopen the terminal, and restart FCM.'
}

try {
    $pythonRuntime = Resolve-FcmPython
}
catch {
    Write-Host ('FCM startup error: ' + $_.Exception.Message) -ForegroundColor Red
    exit 2
}

if ($SelfTest) {
    Write-Output "FCM startup check passed | v$appVersion | $($pythonRuntime.Version)"
    exit 0
}

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin -and -not $SkipAdminPrompt) {
    Write-Host ''
    Write-Host '  FILE CONTROL MANAGER | Permission Request' -ForegroundColor Cyan
    Write-Host '  Ordinary file management can run without administrator access.' -ForegroundColor Gray
    Write-Host '  Ownership recovery and ACL changes require administrator permission.' -ForegroundColor Yellow
    Write-Host '  Windows will show its standard User Account Control confirmation.' -ForegroundColor Gray
    Write-Host ''
    Write-Host '  01  Request Administrator Access' -ForegroundColor Cyan
    Write-Host '  02  Continue Without Elevation' -ForegroundColor Green
    Write-Host '  03  Exit' -ForegroundColor Gray

    $choice = Read-Host '  Select [01-03]'
    if ($choice -eq '01' -or $choice -eq '1') {
        $exe = (Get-Process -Id $PID).Path
        $quotedScript = '"' + $PSCommandPath.Replace('"', '') + '"'
        $arguments = '-NoLogo -NoProfile -ExecutionPolicy Bypass -File ' + $quotedScript
        if ($InitialPath) {
            $arguments += ' -InitialPath "' + $InitialPath.Replace('"', '') + '"'
        }
        try {
            Start-Process -FilePath $exe -Verb RunAs -ArgumentList $arguments -ErrorAction Stop
        }
        catch {
            Write-Warning 'Administrator approval was not granted. No security settings were changed.'
            exit 1
        }
        exit 0
    }
    if ($choice -ne '02' -and $choice -ne '2') { exit 0 }
}

$pythonExecutable = $pythonRuntime.Executable
$pythonArguments = @($pythonRuntime.Prefix) + @((Join-Path $root 'fcm.py'))
if ($InitialPath) { $pythonArguments += @('--path', $InitialPath) }

try {
    & $pythonExecutable @pythonArguments
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
catch {
    Write-Host ('FCM could not start: ' + $_.Exception.Message) -ForegroundColor Red
    exit 3
}

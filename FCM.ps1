[CmdletBinding()]
param([switch]$Version,[string]$InitialPath='')
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $MyInvocation.MyCommand.Path
$version=(Get-Content -LiteralPath (Join-Path $root 'VERSION') -Raw).Trim()
if($Version){Write-Output "File Control Manager v$version";exit 0}
if($env:OS -ne 'Windows_NT'){throw 'FCM requires Windows'}
$identity=[Security.Principal.WindowsIdentity]::GetCurrent()
$principal=New-Object Security.Principal.WindowsPrincipal($identity)
$isAdmin=$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if(-not $isAdmin){
    Write-Host ''
    Write-Host '  FILE CONTROL MANAGER | Permission Request' -ForegroundColor Cyan
    Write-Host '  File inspection, copying and ordinary operations can run normally.' -ForegroundColor Gray
    Write-Host '  Ownership recovery and ACL changes require Administrator approval.' -ForegroundColor Yellow
    Write-Host '  Windows will show its standard User Account Control confirmation.' -ForegroundColor Gray
    Write-Host ''
    Write-Host '  01  Request Administrator Access' -ForegroundColor Cyan
    Write-Host '  02  Continue Without Elevation' -ForegroundColor Green
    Write-Host '  03  Exit' -ForegroundColor Gray
    $choice=Read-Host '  Select [01-03]'
    if($choice -eq '01' -or $choice -eq '1'){
        $exe=(Get-Process -Id $PID).Path
        $quotedScript='"'+$MyInvocation.MyCommand.Path.Replace('"','')+'"'
        $arguments='-NoLogo -NoProfile -File '+$quotedScript
        if($InitialPath){$arguments+=' -InitialPath "'+$InitialPath.Replace('"','')+'"'}
        try { Start-Process -FilePath $exe -Verb RunAs -ArgumentList $arguments -ErrorAction Stop }
        catch { Write-Warning 'Administrator access was not granted. No security settings were changed.'; exit 1 }
        exit 0
    }
    if($choice -ne '02' -and $choice -ne '2'){exit 0}
}
$python=Get-Command py -ErrorAction SilentlyContinue
if(-not $python){$python=Get-Command python -ErrorAction SilentlyContinue}
if(-not $python){throw 'Install Python 3.9+ to use FCM.'}
$callArgs=@()
if($python.Name -like 'py*'){$callArgs+= '-3'}
$callArgs+= (Join-Path $root 'fcm.py')
if($InitialPath){$callArgs+= @('--path',$InitialPath)}
& $python.Source @callArgs
if($LASTEXITCODE -ne 0){exit $LASTEXITCODE}

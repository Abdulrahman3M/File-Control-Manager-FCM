[CmdletBinding()]
param([switch]$Version,[string]$InitialPath='')
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $MyInvocation.MyCommand.Path
$version=(Get-Content -LiteralPath (Join-Path $root 'VERSION') -Raw).Trim()
if($Version){Write-Output "File Control Manager v$version";exit 0}
if($env:OS -ne 'Windows_NT'){throw 'FCM requires Windows'}
$python=Get-Command py -ErrorAction SilentlyContinue
if(-not $python){$python=Get-Command python -ErrorAction SilentlyContinue}
if(-not $python){throw 'Install Python 3.9+ to use FCM.'}
$callArgs=@()
if($python.Name -like 'py*'){$callArgs+= '-3'}
$callArgs+= (Join-Path $root 'fcm.py')
if($InitialPath){$callArgs+= @('--path',$InitialPath)}
& $python.Source @callArgs
if($LASTEXITCODE -ne 0){exit $LASTEXITCODE}

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path $root 'src/Core/Operations.psm1'
if (-not (Test-Path -LiteralPath $modulePath -PathType Leaf)) { throw 'Expected the PowerShell operation module.' }
Import-Module $modulePath -Force

function Assert-FcmOperationTest {
    param([bool]$Condition,[string]$Message)
    if (-not $Condition) { throw ('FAIL: ' + $Message) }
    Write-Output ('PASS: ' + $Message)
}

$testRoot = Join-Path $root 'work/native-ops'
$safeRoot = [IO.Path]::GetFullPath((Join-Path $root 'work')).TrimEnd('\') + '\'
$resolvedTestRoot = [IO.Path]::GetFullPath($testRoot)
if (-not $resolvedTestRoot.StartsWith($safeRoot,[StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe test path.' }
$oldDataDir = $env:FCM_DATA_DIR
try {
    if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
    New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
    $env:FCM_DATA_DIR = Join-Path $testRoot 'data'
    $source = Join-Path $testRoot '05 source.txt'
    $destination = Join-Path $testRoot 'destination'
    $moveDestination = Join-Path $testRoot 'move destination'
    [IO.File]::WriteAllText($source,'FCM PowerShell operation test',(New-Object Text.UTF8Encoding($false)))
    New-Item -ItemType Directory -Path $destination | Out-Null
    New-Item -ItemType Directory -Path $moveDestination | Out-Null

    $inspect = Invoke-FcmOperation -Operation inspect -Path $source
    Assert-FcmOperationTest ($inspect.ok -and $inspect.details -match 'Type: File') 'Inspect returns file metadata and diagnostics'

    $rename = Invoke-FcmOperation -Operation rename -Path $source -NewName '05 renamed.txt'
    $renamed = Join-Path $testRoot '05 renamed.txt'
    Assert-FcmOperationTest ($rename.ok -and (Test-Path -LiteralPath $renamed)) 'Rename preserves numbered names'

    $copy = Invoke-FcmOperation -Operation copy -Path $renamed -Destination $destination
    $copied = Join-Path $destination '05 renamed.txt'
    Assert-FcmOperationTest ($copy.ok -and (Test-Path -LiteralPath $copied)) 'Copy writes into the selected destination'
    $collision = Invoke-FcmOperation -Operation copy -Path $renamed -Destination $destination
    Assert-FcmOperationTest ((-not $collision.ok) -and (Test-Path -LiteralPath $copied)) 'Copy refuses to overwrite an existing item'

    $move = Invoke-FcmOperation -Operation move -Path $renamed -Destination $moveDestination
    $moved = Join-Path $moveDestination '05 renamed.txt'
    Assert-FcmOperationTest ($move.ok -and (-not (Test-Path -LiteralPath $renamed)) -and (Test-Path -LiteralPath $moved)) 'Move relocates the selected item'

    $unconfirmed = Invoke-FcmOperation -Operation delete -Path $copied
    Assert-FcmOperationTest ((-not $unconfirmed.ok) -and (Test-Path -LiteralPath $copied)) 'Delete refuses to run without explicit confirmation'
    $deleted = Invoke-FcmOperation -Operation delete -Path $copied -Confirmed
    Assert-FcmOperationTest ($deleted.ok -and (-not (Test-Path -LiteralPath $copied))) 'Confirmed delete removes the selected item'

    $unsafe = Invoke-FcmOperation -Operation ownership -Path $source -Confirmed:$false
    Assert-FcmOperationTest (-not $unsafe.ok) 'Ownership operation requires explicit confirmation'
    $logs = Invoke-FcmOperation -Operation logs
    Assert-FcmOperationTest ($logs.ok -and (Test-Path -LiteralPath (Join-Path $env:FCM_DATA_DIR 'activity.jsonl'))) 'Operations produce an activity log'
}
finally {
    $env:FCM_DATA_DIR = $oldDataDir
    if ((Test-Path -LiteralPath $testRoot) -and $resolvedTestRoot.StartsWith($safeRoot,[StringComparison]::OrdinalIgnoreCase)) {
        Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
    }
}

Write-Output 'All PowerShell operation tests passed.'

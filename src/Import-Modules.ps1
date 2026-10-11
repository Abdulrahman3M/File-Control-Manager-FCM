$ErrorActionPreference = 'Stop'
$moduleRoot = $PSScriptRoot
$moduleFiles = @(
    (Join-Path $moduleRoot 'Core/Platform.psm1'),
    (Join-Path $moduleRoot 'Core/Process.psm1'),
    (Join-Path $moduleRoot 'Core/Operations.psm1'),
    (Join-Path $moduleRoot 'TUI/Theme.psm1'),
    (Join-Path $moduleRoot 'TUI/Renderer.psm1'),
    (Join-Path $moduleRoot 'TUI/Input.psm1'),
    (Join-Path $moduleRoot 'TUI/Menu.psm1'),
    (Join-Path $moduleRoot 'TUI/Dialog.psm1'),
    (Join-Path $moduleRoot 'TUI/Prompt.psm1'),
    (Join-Path $moduleRoot 'Core/App.psm1')
)
foreach ($moduleFile in $moduleFiles) {
    if (-not (Test-Path -LiteralPath $moduleFile -PathType Leaf)) {
        throw ('Required FCM module was not found: ' + $moduleFile)
    }
    Import-Module -Name $moduleFile -Global -Force -ErrorAction Stop
}

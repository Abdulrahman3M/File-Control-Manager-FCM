function Read-FcmValidatedInput {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][string]$Prompt,
        [string]$Help = '',
        [string]$Example = '',
        [string]$InitialValue = '',
        [Parameter(Mandatory = $true)][scriptblock]$Validator
    )
    $buffer = [string]$InitialValue
    $cursor = $buffer.Length
    $errorText = ''
    while ($true) {
        $lines = @(
            @{ Text = '  '; Role = 'Title'; IconName = 'App'; Suffix = '  File Control Manager' },
            @{ Text = ('  ' + $Title); Role = 'Heading' },
            @{ Text = ('  ' + $Prompt); Role = 'Normal' },
            @{ Text = ('  ' + $Help); Role = 'Dim' }
        )
        if ($Example) { $lines += @{ Text = ('  Example: ' + $Example); Role = 'Dim' } }
        if ($errorText) { $lines += @{ Text = ('  ' + $errorText); Role = 'Error' } }
        $lines += @{ Text = ('  > ' + $buffer); Role = 'Accent' }
        $lines += @{ Text = '  Type text   Enter accept   Esc back   Ctrl+U clear'; Role = 'Dim' }
        Write-FcmScreen -Line $lines
        if (-not (Test-FcmScriptedInputAvailable) -and ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected)) {
            return 'Back'
        }
        $key = Read-FcmKey
        switch ($key.Key) {
            'Enter' {
                $validation = & $Validator $buffer
                if ($null -eq $validation -or [string]::IsNullOrEmpty([string]$validation)) { return $buffer }
                $errorText = [string]$validation
            }
            'Escape' { return 'Back' }
            'Cancel' { return 'Back' }
            'Backspace' {
                if ($cursor -gt 0) { $buffer = $buffer.Remove($cursor - 1,1); $cursor-- }
                $errorText = ''
            }
            'Delete' {
                if ($cursor -lt $buffer.Length) { $buffer = $buffer.Remove($cursor,1) }
                $errorText = ''
            }
            'Left' { if ($cursor -gt 0) { $cursor-- } }
            'Right' { if ($cursor -lt $buffer.Length) { $cursor++ } }
            'Home' { $cursor = 0 }
            'End' { $cursor = $buffer.Length }
            'Clear' { $buffer = ''; $cursor = 0; $errorText = '' }
            { $_ -in @('Character','Digit') } {
                $buffer = $buffer.Insert($cursor,[string]$key.Character)
                $cursor += ([string]$key.Character).Length
                $errorText = ''
            }
            default { }
        }
    }
}

Export-ModuleMember -Function Read-FcmValidatedInput

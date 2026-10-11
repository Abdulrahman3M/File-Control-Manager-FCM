function Show-FcmConfirm {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][string]$Message,
        [switch]$Destructive,
        [string]$RequireText = ''
    )
    $items = @(
        @{ Id = 'yes'; Label = 'Continue'; Icon = 'Success'; Description = 'Proceed with the action shown above.'; Disabled = $false },
        @{ Id = 'no'; Label = 'Cancel'; Icon = 'Exit'; Description = 'Return without changing the target.'; Disabled = $false }
    )
    $selected = Show-FcmMenu -Title $Title -Context 'Confirm action' -Items $items -Status $Message
    if ($selected -ne 'yes') { return $false }
    if ($RequireText) {
        $validator = {
            param($candidate)
            if ($candidate -cne $RequireText) { return ('Type ' + $RequireText + ' exactly to continue.') }
            return $null
        }.GetNewClosure()
        $value = Read-FcmValidatedInput -Title $Title -Prompt ('Type ' + $RequireText + ' to confirm') -Help 'This permanent action cannot be undone.' -Example $RequireText -InitialValue '' -Validator $validator
        if ($value -cne $RequireText) { return $false }
    }
    return $true
}

function Show-FcmNotice {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][string]$Message,
        [string]$Details = '',
        [ValidateSet('Info','Success','Warning','Error')][string]$Kind = 'Info'
    )
    $icon = Get-FcmIcon $Kind
    $lines = New-Object 'System.Collections.Generic.List[object]'
    $lines.Add(@{ Text = '  '; Role = 'Title'; IconName = 'App'; Suffix = '  File Control Manager' })
    $lines.Add(@{ Text = ('  ' + $Title); Role = 'Heading' })
    $lines.Add(@{ Text = '  '; Role = 'Normal' })
    $lines.Add(@{ Text = '  '; Role = $Kind; IconName = $Kind; Suffix = '  ' + $Message })
    if ($Details) {
        $lines.Add(@{ Text = '  '; Role = 'Normal' })
        foreach ($detailLine in ($Details -split ([string][char]10))) {
            $lines.Add(@{ Text = ('  ' + $detailLine); Role = 'Normal' })
        }
    }
    $lines.Add(@{ Text = '  '; Role = 'Normal' })
    $lines.Add(@{ Text = '  Press Enter to return.'; Role = 'Dim' })
    Write-FcmScreen -Line $lines.ToArray()
    $null = Read-FcmKey
}

Export-ModuleMember -Function Show-FcmConfirm,Show-FcmNotice

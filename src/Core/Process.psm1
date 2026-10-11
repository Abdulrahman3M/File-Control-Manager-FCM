function ConvertTo-FcmWindowsArgumentLine {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string[]]$Argument)

    $quotedArguments = New-Object System.Collections.Generic.List[string]
    foreach ($value in $Argument) {
        $builder = New-Object System.Text.StringBuilder
        [void]$builder.Append('"')
        $slashes = 0
        foreach ($character in $value.ToCharArray()) {
            if ($character -eq [char]92) {
                $slashes++
                continue
            }
            if ($character -eq [char]34) {
                if ($slashes -gt 0) {
                    [void]$builder.Append(('\' * (2 * $slashes)))
                }
                [void]$builder.Append('\')
                [void]$builder.Append('"')
                $slashes = 0
                continue
            }
            if ($slashes -gt 0) {
                [void]$builder.Append(('\' * $slashes))
                $slashes = 0
            }
            [void]$builder.Append($character)
        }
        if ($slashes -gt 0) {
            [void]$builder.Append(('\' * (2 * $slashes)))
        }
        [void]$builder.Append('"')
        $quotedArguments.Add($builder.ToString())
    }
    return ($quotedArguments -join ' ')
}

function Get-FcmStartupElevationStatus {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][System.Exception]$Exception)
    $current = $Exception
    while ($null -ne $current) {
        if ($current -is [System.ComponentModel.Win32Exception] -and $current.NativeErrorCode -eq 1223) { return 'Canceled' }
        if (($current.HResult -band 0xFFFF) -eq 1223) { return 'Canceled' }
        $current = $current.InnerException
    }
    return 'Failed'
}

function Start-FcmStartupElevation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$ScriptPath,
        [string]$InitialPath = ''
    )
    try {
        $executable = Get-FcmPowerShellExecutable
        $arguments = @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',$ScriptPath,'-AdminSession')
        if ($InitialPath) { $arguments += @('-InitialPath',$InitialPath) }
        $argumentLine = ConvertTo-FcmWindowsArgumentLine -Argument $arguments
        $null = Start-Process -FilePath $executable -Verb RunAs -ArgumentList $argumentLine -PassThru -ErrorAction Stop
        return [pscustomobject]@{ Status = 'Started'; Message = 'Administrator approval was granted. FCM is opening in the elevated PowerShell session.' }
    }
    catch {
        if ((Get-FcmStartupElevationStatus -Exception $_.Exception) -eq 'Canceled') {
            return [pscustomobject]@{ Status = 'Canceled'; Message = 'Administrator approval was canceled. FCM is closing without starting.' }
        }
        return [pscustomobject]@{ Status = 'Failed'; Message = ('FCM could not request administrator access: ' + $_.Exception.Message + ' Close PowerShell and try again, or check your Windows UAC policy.') }
    }
}

Export-ModuleMember -Function ConvertTo-FcmWindowsArgumentLine,Get-FcmStartupElevationStatus,Start-FcmStartupElevation

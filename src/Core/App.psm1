function New-FcmMenuItems {
    return @(
        @{ Id = 'choose'; Label = 'Choose file or folder'; Icon = 'Folder'; Description = 'Set the file or folder that later actions will use.'; Disabled = $false },
        @{ Id = 'inspect'; Label = 'Inspect metadata, ACL and EFS status'; Icon = 'Search'; Description = 'Review file details, Windows permissions, and EFS status.'; Disabled = $false },
        @{ Id = 'rename'; Label = 'Rename'; Icon = 'Rename'; Description = 'Rename the selected item without overwriting an existing name.'; Disabled = $false },
        @{ Id = 'copy'; Label = 'Copy'; Icon = 'Copy'; Description = 'Copy the selected file or folder into an existing destination folder.'; Disabled = $false },
        @{ Id = 'move'; Label = 'Move'; Icon = 'Move'; Description = 'Move the selected file or folder into an existing destination folder.'; Disabled = $false },
        @{ Id = 'delete'; Label = 'Permanently delete'; Icon = 'Delete'; Description = 'Permanently remove the selected item after two explicit confirmations.'; Disabled = $false },
        @{ Id = 'ownership'; Label = 'Take ownership'; Icon = 'Key'; Description = 'Run Windows ownership recovery after reviewing the target and confirming.'; Disabled = $false },
        @{ Id = 'grant'; Label = 'Grant Administrators Full Control'; Icon = 'Shield'; Description = 'Change the target ACL after reviewing the target and confirming.'; Disabled = $false },
        @{ Id = 'admin-session'; Label = 'Open Administrator session'; Icon = 'Admin'; Description = 'Start another elevated FCM PowerShell session.'; Disabled = $false },
        @{ Id = 'logs'; Label = 'View activity logs'; Icon = 'Logs'; Description = 'Review the most recent actions recorded by FCM.'; Disabled = $false },
        @{ Id = 'exit'; Label = 'Exit'; Icon = 'Exit'; Description = 'Close File Control Manager.'; Disabled = $false }
    )
}

function Read-FcmTarget {
    param([string]$InitialValue = '')
    $validator = {
        param($value)
        if ([string]::IsNullOrWhiteSpace($value)) { return 'Enter a file or folder path.' }
        if (-not (Test-Path -LiteralPath $value)) { return 'That path does not exist or is not accessible.' }
        return $null
    }
    $value = Read-FcmValidatedInput -Title 'Choose a target' -Prompt 'File or folder path' -Help 'Paste or type the complete path. Quotes around a path are optional.' -Example 'C:\Users\You\Documents\notes.txt' -InitialValue $InitialValue -Validator $validator
    if ($value -eq 'Back') { return '' }
    try { return (Get-Item -LiteralPath $value -Force -ErrorAction Stop).FullName }
    catch { return '' }
}

function Invoke-FcmBackendResult {
    param([string]$Operation,[string]$Path = '',[string]$Destination = '',[string]$NewName = '',[switch]$Confirmed)
    $result = Invoke-FcmOperation -Operation $Operation -Path $Path -Destination $Destination -NewName $NewName -Confirmed:$Confirmed
    $kind = 'Success'
    if (-not $result.ok) { $kind = 'Error' }
    Show-FcmNotice -Title 'Operation result' -Message ([string]$result.message) -Details ([string]$result.details) -Kind $kind
    return [bool]$result.ok
}

function Start-FcmElevatedSession {
    param([string]$ScriptPath,[string]$InitialPath = '',[string]$StartAction = '',[switch]$AdminSession)
    try {
        $executable = Get-FcmPowerShellExecutable
        $arguments = @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',$ScriptPath)
        if ($InitialPath) { $arguments += @('-InitialPath',$InitialPath) }
        if ($StartAction) { $arguments += @('-StartAction',$StartAction) }
        if ($AdminSession) { $arguments += '-AdminSession' }
        $terminal = Get-FcmWindowsTerminalExecutable
        if ($terminal) {
            $argumentLine = Get-FcmWindowsTerminalLaunchArguments -PowerShellPath $executable -ScriptPath $ScriptPath -InitialPath $InitialPath -StartAction $StartAction
            $null = Start-Process -FilePath $terminal -Verb RunAs -ArgumentList $argumentLine -PassThru -ErrorAction Stop
            return [pscustomobject]@{ ok = $true; message = 'An elevated FCM session has opened in Windows Terminal.'; details = 'Continue in the new elevated window.'; path = $InitialPath }
        }
        $argumentLine = ConvertTo-FcmWindowsArgumentLine -Argument $arguments
        $process = Start-Process -FilePath $executable -Verb RunAs -ArgumentList $argumentLine -Wait -PassThru -ErrorAction Stop
        if ($process.ExitCode -ne 0) {
            return [pscustomobject]@{ ok = $false; message = 'The elevated PowerShell session ended with an error.'; details = ''; path = $InitialPath }
        }
        return [pscustomobject]@{ ok = $true; message = 'The elevated PowerShell session has closed.'; details = 'Review the result shown in that session.'; path = $InitialPath }
    }
    catch {
        return [pscustomobject]@{ ok = $false; message = 'Administrator approval was not granted. No operation was started.'; details = ''; path = $InitialPath }
    }
}

function Invoke-FcmAdminAction {
    param([string]$Action,[string]$Path,[string]$ScriptPath,[switch]$FromElevatedLaunch)
    if (-not $Path) {
        Show-FcmNotice -Title 'Target required' -Message 'Choose a file or folder before using this action.' -Kind 'Warning'
        return
    }
    if (-not (Test-FcmAdministrator)) {
        if ($FromElevatedLaunch) {
            Show-FcmNotice -Title 'Administrator access required' -Message 'This PowerShell session is not elevated. The action was not run.' -Kind 'Error'
            return
        }
        $actionName = 'Take ownership'
        $operation = 'ownership'
        if ($Action -eq 'grant') { $actionName = 'Grant Administrators Full Control'; $operation = 'grant' }
        $consent = Show-FcmConfirm -Title 'Administrator permission required' -Message ($actionName + ' changes Windows security settings. Request UAC permission to continue?')
        if (-not $consent) { return }
        $elevated = Start-FcmElevatedSession -ScriptPath $ScriptPath -InitialPath $Path -StartAction $operation
        $kind = 'Success'
        if (-not $elevated.ok) { $kind = 'Warning' }
        Show-FcmNotice -Title 'Administrator session' -Message $elevated.message -Details $elevated.details -Kind $kind
        return
    }
    $description = 'This changes the security owner of the target and may affect child items.'
    $operation = 'ownership'
    if ($Action -eq 'grant') {
        $description = 'This grants the local Administrators group Full Control and may affect child items.'
        $operation = 'grant'
    }
    if (-not (Show-FcmConfirm -Title 'Confirm security change' -Message ($description + ' Target: ' + $Path) -Destructive)) { return }
    $null = Invoke-FcmBackendResult -Operation $operation -Path $Path -Confirmed
}

function Invoke-FcmMenuAction {
    param([string]$Action,[string]$Path,[string]$ScriptPath)
    if ($Action -eq 'choose') {
        $chosen = Read-FcmTarget -InitialValue $Path
        if ($chosen) { $script:FcmTarget = $chosen }
        return
    }
    if ($Action -eq 'logs') {
        $null = Invoke-FcmBackendResult -Operation 'logs'
        return
    }
    if ($Action -eq 'admin-session') {
        if (Test-FcmAdministrator) {
            Show-FcmNotice -Title 'Administrator session' -Message 'This PowerShell session already has administrator access.' -Kind 'Info'
            return
        }
        if (-not (Show-FcmConfirm -Title 'Open Administrator session' -Message 'Windows will show its standard UAC approval. The new terminal will start with administrator access.')) { return }
        $session = Start-FcmElevatedSession -ScriptPath $ScriptPath -InitialPath $Path -AdminSession
        $kind = 'Success'
        if (-not $session.ok) { $kind = 'Warning' }
        Show-FcmNotice -Title 'Administrator session' -Message $session.message -Details $session.details -Kind $kind
        return
    }
    if ($Action -in @('ownership','grant')) {
        Invoke-FcmAdminAction -Action $Action -Path $Path -ScriptPath $ScriptPath
        return
    }
    if (-not $Path) {
        Show-FcmNotice -Title 'Target required' -Message 'Choose a file or folder before using this action.' -Kind 'Warning'
        return
    }

    switch ($Action) {
        'inspect' { $null = Invoke-FcmBackendResult -Operation 'inspect' -Path $Path; return }
        'rename' {
            $script:FcmRenamePath = $Path
            $validator = {
                param($value)
                if ([string]::IsNullOrWhiteSpace($value) -or $value -in @('.','..')) { return 'Enter a valid Windows file name.' }
                if ($value -match '[<>:"/\\|?*]' -or $value.EndsWith('.') -or $value.EndsWith(' ')) { return 'That name contains characters or endings Windows does not allow.' }
                $parent = Split-Path -Parent $script:FcmRenamePath
                if (Test-Path -LiteralPath (Join-Path $parent $value)) { return 'An item with that name already exists.' }
                return $null
            }.GetNewClosure()
            $name = Read-FcmValidatedInput -Title 'Rename target' -Prompt 'New file or folder name' -Help 'Enter a name only, not a full path.' -Example 'archive-2026.zip' -Validator $validator
            if ($name -eq 'Back') { return }
            if (-not (Show-FcmConfirm -Title 'Confirm rename' -Message ('Rename ' + $Path + ' to ' + $name + '?'))) { return }
            $null = Invoke-FcmBackendResult -Operation 'rename' -Path $Path -NewName $name
            if (-not (Test-Path -LiteralPath $Path) -and (Test-Path -LiteralPath (Join-Path (Split-Path -Parent $Path) $name))) {
                $script:FcmTarget = Join-Path (Split-Path -Parent $Path) $name
            }
            return
        }
        { $_ -in @('copy','move') } {
            $validator = {
                param($value)
                if (-not (Test-Path -LiteralPath $value -PathType Container)) { return 'Enter an existing destination folder.' }
                return $null
            }
            $destination = Read-FcmValidatedInput -Title 'Choose destination' -Prompt 'Existing destination folder' -Help 'FCM will keep the original item name and will not overwrite.' -Example 'C:\Users\You\Desktop' -Validator $validator
            if ($destination -eq 'Back') { return }
            $verb = 'Copy'
            if ($Action -eq 'move') { $verb = 'Move' }
            if (-not (Show-FcmConfirm -Title ('Confirm ' + $verb.ToLowerInvariant()) -Message ($verb + ' ' + $Path + ' to ' + $destination + '?'))) { return }
            $completed = Invoke-FcmBackendResult -Operation $Action -Path $Path -Destination $destination
            if ($completed -and $Action -eq 'move') {
                $script:FcmTarget = Join-Path $destination (Split-Path -Leaf $Path)
            }
            return
        }
        'delete' {
            $confirmed = Show-FcmConfirm -Title 'Permanent deletion' -Message ('Permanently delete ' + $Path + '? This does not use the Recycle Bin.') -Destructive -RequireText 'DELETE'
            if ($confirmed) {
                $null = Invoke-FcmBackendResult -Operation 'delete' -Path $Path -Confirmed
                if (-not (Test-Path -LiteralPath $Path)) { $script:FcmTarget = '' }
            }
            return
        }
        default {
            Show-FcmNotice -Title 'Unavailable action' -Message 'This action is not available.' -Kind 'Warning'
        }
    }
}

function Start-FcmApp {
    [CmdletBinding()]
    param(
        [string]$InitialPath = '',
        [string]$ScriptPath = '',
        [string]$StartAction = '',
        [switch]$AdminSession,
        [switch]$SmokeTest,
        [string[]]$ScriptedInput = @()
    )
    $script:FcmAppVersion = (Get-Content -LiteralPath (Join-Path (Split-Path -Parent $ScriptPath) 'VERSION') -Raw).Trim()
    $script:FcmTarget = $InitialPath
    $environment = Get-FcmEnvironment
    if ($environment.IsAdministrator) { $modeLabel = 'ADMINISTRATOR SESSION' }
    else { $modeLabel = 'STANDARD USER' }
    $script:FcmModeLabel = $modeLabel
    Initialize-FcmTheme -IconMode 'Auto' -Platform $environment.Platform -NoColor:([bool]$env:NO_COLOR -or $environment.OutputRedirected)
    Initialize-FcmRenderer -PlainOutput:($SmokeTest -or $ScriptedInput.Count -gt 0 -or $environment.OutputRedirected)
    if ($ScriptedInput.Count -gt 0) { Set-FcmScriptedInput -Token $ScriptedInput }
    $items = New-FcmMenuItems

    if ($StartAction) {
        Invoke-FcmAdminAction -Action $StartAction -Path $InitialPath -ScriptPath $ScriptPath -FromElevatedLaunch
        return
    }
    if ($SmokeTest) {
        $null = Show-FcmMenu -Title 'Files, folders and security' -Context 'DIAGNOSTIC MODE' -Items $items -Status 'Preflight passed. This diagnostic mode does not require administrator access.' -AppVersion $script:FcmAppVersion -ModeLabel $modeLabel -Target $(if ($script:FcmTarget) { $script:FcmTarget } else { '(not selected)' }) -Static
        return
    }

    while ($true) {
        $context = 'Files | folders | security'
        if ($AdminSession) { $context = 'Administrator session' }
        $selected = Show-FcmMenu -Title $context -Context 'Main menu' -Items $items -Status 'Administrator session active. Review each permanent or security change before confirming.' -AppVersion $script:FcmAppVersion -ModeLabel $modeLabel -Target $(if ($script:FcmTarget) { $script:FcmTarget } else { '(not selected)' })
        if ($selected -eq 'Exit' -or $selected -eq 'exit') { return }
        if ($selected -eq 'Back') { continue }
        Invoke-FcmMenuAction -Action $selected -Path $script:FcmTarget -ScriptPath $ScriptPath
    }
}

Export-ModuleMember -Function Start-FcmApp,New-FcmMenuItems

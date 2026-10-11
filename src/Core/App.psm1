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
            if (-not (Show-FcmConfirm -Title ('Confirm ' + $verb.ToLowerInvariant()) -Message ($verb + ' ' + $Path + ' to ' + $destination + '?')))Îç<∂âûÀk∫wµÁQ¡’–ÄµçπΩ—µÖ—ç†Äù%1Å=9QI=0Å59IÒ5%9%MQIQ=HÅMMM%=9ÒMQ9IÅUMIÒ%9=MQ%Å5=ÄÅQIPÅÄÅQ%=9Lú§ÄùQ°îÅëÖÕ°âΩÖ…êÅçΩπ—Ö•πÃÅπºÅ±ïùÖç‰ÅÖ±∞µ’¡¡ï…çÖÕîÅë•Õ¡±Ö‰Å°ïÖë•πùÃú)ôΩ…ïÖç†Ä†ë±Öâï∞Å•∏Å †ù°ΩΩÕîÅô•±îÅΩ»ÅôΩ±ëï»ú∞ù%πÕ¡ïç–Åµï—ÖëÖ—Ñ∞Å0ÅÖπêÅLÅÕ—Ö—’Ãú∞ùIïπÖµîú∞ùΩ¡‰ú∞ù5ΩŸîú∞ùAï…µÖπïπ—±‰Åëï±ï—îú∞ùQÖ≠îÅΩ›πï…Õ°•¿ú∞ù…Öπ–Åëµ•π•Õ—…Ö—Ω…ÃÅ’±∞ÅΩπ—…Ω∞ú∞ù=¡ï∏Åëµ•π•Õ—…Ö—Ω»ÅÕïÕÕ•Ω∏ú∞ùY•ï‹ÅÖç—•Ÿ•—‰Å±ΩùÃú∞ù·•–ú§§ÅÏ(ÄÄÄÅÕÕï…–µç¥Ä†ëµïπ’=’—¡’–ÄµµÖ—ç†Åm…ïùï·tËÈÕçÖ¡î†ë±Öâï∞§§Ä†ùQ°îÅëÖÕ°âΩÖ…êÅ≠ïï¡ÃÅ—°îÄàúÄ¨Äë±Öâï∞Ä¨ÄúàÅÖç—•Ω∏ú§)Ù((ëÕç…•¡—ïë·•–ÄÙÄòÄëï·îÄµ9Ω1ΩùºÄµ9ΩA…Ωô•±îÄµ·ïç’—•ΩπAΩ±•ç‰Å	Â¡ÖÕÃÄµ•±îÄëïπ—…‰ÄµMç…•¡—ïë%π¡’–ÄúƒƒúÄ»¯òƒÅÅ=’–µM—…•πú)ÕÕï…–µç¥Ä†ë1MQa%Q=ÄµïƒÄ¿§ÄùMç…•¡—ïêÅµïπ‘Åï·•–ÅçΩµ¡±ï—ïÃÅ›•—°Ω’–Å…ïÖë•πúÅ¡•¡ïêÅçΩπÕΩ±îÅ•π¡’–ú)ÕÕï…–µç¥Ä†ëÕç…•¡—ïë·•–ÄµµÖ—ç†Äù·•–ú§ÄùMç…•¡—ïêÅπÖŸ•ùÖ—•Ω∏Å…ïπëï…ÃÅ—°îÅ·•–ÅÖç—•Ω∏ú((åÅ·ï…ç•ÕîÅ—°îÅÖç—’Ö∞ÅëΩ’â±îµç±•ç¨Åïπ—…‰Åô•±îÄ°5Ω	P§∞ÅπΩ–Å©’Õ–Å4π¡Ãƒ∏)A’Õ†µ1ΩçÖ—•Ω∏Äë…ΩΩ–)—…‰ÅÏ(ÄÄÄÄëâÖ—Yï…Õ•Ω∏ÄÙÄòÄëïπÿÈΩµM¡ïåÄΩêÄΩåÄù4πâÖ–ÄµYï…Õ•Ω∏úÄ»¯òƒÅÅ=’–µM—…•πú(ÄÄÄÄëâÖ—Yï…Õ•Ωπ·•–ÄÙÄë1MQa%Q=(ÄÄÄÅÕÕï…–µç¥Ä†ëâÖ—Yï…Õ•Ωπ·•–ÄµïƒÄ¿§Äù4πâÖ–ÅŸï…Õ•Ω∏Å±Ö’πç†Åï·•—ÃÅÕ’ççïÕÕô’±±‰ú(ÄÄÄÅÕÕï…–µç¥Ä†ëâÖ—Yï…Õ•Ω∏πQ…•¥†§ÄµïƒÄâ•±îÅΩπ—…Ω∞Å5ÖπÖùï»ÅÿëŸï…Õ•Ω∏à§Äù4πâÖ–Å…ïÕΩ±ŸïÃÅ—°îÅçΩ……ïç–ÅŸï…Õ•Ω∏ú((ÄÄÄÄë±ïùÖçÂ1Ö’πç°ï…Yï…Õ•Ω∏ÄÙÄòÄëïπÿÈΩµM¡ïåÄΩêÄΩåÄù1Ö’πç†µ4πçµêÄµYï…Õ•Ω∏úÄ»¯òƒÅÅ=’–µM—…•πú(ÄÄÄÄë±ïùÖçÂ1Ö’πç°ï…·•–ÄÙÄë1MQa%Q=(ÄÄÄÅÕÕï…–µç¥Ä†ë±ïùÖçÂ1Ö’πç°ï…·•–ÄµïƒÄ¿§Äù1Ö’πç†µ4πçµêÅôΩ…›Ö…ëÃÅ—ºÅ—°îÅç’……ïπ–ÅAΩ›ï…M°ï±∞Å±Ö’πç°ï»ú(ÄÄÄÅÕÕï…–µç¥Ä†ë±ïùÖçÂ1Ö’πç°ï…Yï…Õ•Ω∏πQ…•¥†§ÄµïƒÄâ•±îÅΩπ—…Ω∞Å5ÖπÖùï»ÅÿëŸï…Õ•Ω∏à§Äù1ïùÖç‰Å±Ö’πç°ï»Å…ï¡Ω…—ÃÅ—°îÅç’……ïπ–ÅŸï…Õ•Ω∏ú((ÄÄÄÄëâÖ—ÖÕ°âΩÖ…êÄÙÄòÄëïπÿÈΩµM¡ïåÄΩêÄΩåÄù4πâÖ–ÄµMµΩ≠ïQïÕ–úÄ»¯òƒÅÅ=’–µM—…•πú(ÄÄÄÄëâÖ—ÖÕ°âΩÖ…ë·•–ÄÙÄë1MQa%Q=(ÄÄÄÅ•òÄ†ëâÖ—ÖÕ°âΩÖ…ë·•–ÄµπîÄ¿§ÅÏÅ]…•—îµ!ΩÕ–Ä†ù4πâÖ–ÅÕµΩ≠îÅΩ’—¡’–ËÄúÄ¨ÄëâÖ—ÖÕ°âΩÖ…ê§ÅÙ(ÄÄÄÅÕÕï…–µç¥Ä†ëâÖ—ÖÕ°âΩÖ…ë·•–ÄµïƒÄ¿§Äù4πâÖ–Å…ïπëï…ÃÅ—°îÅëÖÕ°âΩÖ…êÅÖπêÅï·•—Ãú)ÕÕï…–µç¥Ä†ëâÖ—ÖÕ°âΩÖ…êÄµçµÖ—ç†Äù•±îÅΩπ—…Ω∞Å5ÖπÖùï»ú§Äù4πâÖ–Å±Ö’πç°ïÃÅ—°îÅAΩ›ï…M°ï±∞ÅëÖÕ°âΩÖ…êú)Ù)ô•πÖ±±‰ÅÏ(ÄÄÄÅAΩ¿µ1ΩçÖ—•Ω∏)Ù()]…•—îµ!ΩÕ–Äù±∞Å4Å±Ö’πç°ï»Åç°ïç≠ÃÅ¡ÖÕÕïê∏ú(
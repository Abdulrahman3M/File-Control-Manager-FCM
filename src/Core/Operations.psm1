$script:FcmProjectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))

function Get-FcmOperationsDataDirectory {
    if (-not [string]::IsNullOrWhiteSpace($env:FCM_DATA_DIR)) { return [IO.Path]::GetFullPath($env:FCM_DATA_DIR) }
    if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        return Join-Path $env:LOCALAPPDATA 'FileControlManager'
    }
    return Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'FileControlManager'
}

function Write-FcmOperationLog {
    param([string]$Action,[string]$Path,[bool]$Success = $true,[string]$Detail = '')
    $directory = Get-FcmOperationsDataDirectory
    if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
        New-Item -ItemType Directory -Path $directory -Force -ErrorAction Stop | Out-Null
    }
    $entry = [ordered]@{
        time = [DateTimeOffset]::Now.ToString('o')
        action = $Action
        path = $Path
        success = $Success
        detail = $Detail
    }
    $line = ConvertTo-Json -InputObject $entry -Compress -Depth 4
    Add-Content -LiteralPath (Join-Path $directory 'activity.jsonl') -Value $line -Encoding UTF8 -ErrorAction Stop
}

function New-FcmOperationResult {
    param([bool]$Ok,[string]$Message,[string]$Details = '',[string]$Path = '')
    return [pscustomobject]@{ ok = $Ok; message = $Message; details = $Details; path = $Path }
}

function Get-FcmSafeItem {
    param([string]$Path,[switch]$AllowProtectedRoot)
    if ([string]::IsNullOrWhiteSpace($Path)) { throw 'Specify a file or folder.' }
    $cleanPath = $Path.Trim().Trim('"')
    try {
        $item = Get-Item -LiteralPath $cleanPath -Force -ErrorAction Stop
    }
    catch {
        throw ('The file or folder could not be found or accessed: ' + $cleanPath)
    }
    if (-not $AllowProtectedRoot) {
        $protectedRoots = @(
            [IO.Path]::GetPathRoot($item.FullName),
            $env:WINDIR,
            $env:ProgramFiles,
            ${env:ProgramFiles(x86)},
            $env:ProgramData,
            [Environment]::GetFolderPath('UserProfile'),
            $script:FcmProjectRoot
        )
        foreach ($protectedRoot in $protectedRoots) {
            if ([string]::IsNullOrWhiteSpace([string]$protectedRoot)) { continue }
            try { $resolvedProtected = [IO.Path]::GetFullPath([string]$protectedRoot).TrimEnd('\') }
            catch { continue }
            if ($item.FullName.TrimEnd('\').Equals($resolvedProtected,[StringComparison]::OrdinalIgnoreCase)) {
                throw 'This protected system, user, drive, or application root cannot be changed.'
            }
        }
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw 'Reparse points and symbolic links require manual review and are not modified.'
        }
    }
    return $item
}

function Test-FcmOperationsAdministrator {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch { return $false }
}

function Invoke-FcmNativeUtility {
    param([Parameter(Mandatory = $true)][string]$Name,[Parameter(Mandatory = $true)][string[]]$Argument)
    $candidate = Join-Path $env:WINDIR ('System32\' + $Name + '.exe')
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { throw ('Required Windows utility is missing: ' + $Name + '.exe') }
    try {
        $output = @(& $candidate @Argument 2>&1)
        $exitCode = $LASTEXITCODE
        $text = (@($output | ForEach-Object { [string]$_ }) -join [Environment]::NewLine).Trim()
        if ($exitCode -ne 0) { throw (($text + ' (exit code ' + $exitCode + ')').Trim()) }
        return $text
    }
    catch {
        throw ($Name + '.exe failed: ' + $_.Exception.Message)
    }
}

function Get-FcmItemDiagnostics {
    param([Parameter(Mandatory = $true)][System.IO.FileSystemInfo]$Item)
    $details = New-Object 'System.Collections.Generic.List[string]'
    $kind = 'File'
    if ($Item.PSIsContainer) { $kind = 'Folder' }
    $details.Add(('Type: ' + $kind))
    if (-not $Item.PSIsContainer) { $details.Add(('Size: ' + $Item.Length + ' bytes')) }
    $details.Add(('Modified: ' + $Item.LastWriteTime.ToString('o')))
    $details.Add(('Attributes: ' + [string]$Item.Attributes))

    try {
        $acl = Get-Acl -LiteralPath $Item.FullName -ErrorAction Stop
        $details.Add(('Owner: ' + $acl.Owner))
        $rules = @($acl.Access | Select-Object -First 10)
        foreach ($rule in $rules) {
            $details.Add(('ACL: ' + $rule.IdentityReference + ' | ' + $rule.AccessControlType + ' | ' + $rule.FileSystemRights + ' | ' + $rule.InheritanceFlags))
        }
        if ($acl.Access.Count -gt $rules.Count) { $details.Add(('ACL: ' + ($acl.Access.Count - $rules.Count) + ' additional rules omitted')) }
    }
    catch { $details.Add(('ACL diagnostic unavailable: ' + $_.Exception.Message)) }

    try {
        $cipher = Invoke-FcmNativeUtility -Name 'cipher' -Argument @('/C',$Item.FullName)
        if ($cipher) { $details.Add(('EFS: ' + $cipher)) }
    }
    catch { $details.Add(('EFS diagnostic unavailable: ' + $_.Exception.Message)) }

    return ($details -join [Environment]::NewLine)
}

function Get-FcmDestinationDirectory {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { throw 'Choose an existing destination folder.' }
    try { $folder = Get-Item -LiteralPath $Path.Trim().Trim('"') -Force -ErrorAction Stop }
    catch { throw ('The destination folder could not be found or accessed: ' + $Path) }
    if (-not $folder.PSIsContainer) { throw 'The destination must be an existing folder.' }
    return $folder
}

function Invoke-FcmOperation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][ValidateSet('inspect','rename','copy','move','delete','ownership','grant','logs')][string]$Operation,
        [string]$Path = '',
        [string]$Destination = '',
        [string]$NewName = '',
        [switch]$Confirmed
    )
    try {
        if ($Operation -eq 'logs') {
            $logPath = Join-Path (Get-FcmOperationsDataDirectory) 'activity.jsonl'
            if (-not (Test-Path -LiteralPath $logPath -PathType Leaf)) {
                return New-FcmOperationResult -Ok $true -Message 'No activity has been recorded.' -Details ('Log file: ' + $logPath) -Path $logPath
            }
            $lines = @(Get-Content -LiteralPath $logPath -Encoding UTF8 -Tail 15 -ErrorAction Stop)
            return New-FcmOperationResult -Ok $true -Message 'Recent activity.' -Details ($lines -join [Environment]::NewLine) -Path $logPath
        }
        if ($Operation -in @('delete','ownership','grant') -and -not $Confirmed) {
            throw 'This security-sensitive operation requires explicit confirmation.'
        }
        $item = Get-FcmSafeItem -Path $Path -AllowProtectedRoot:($Operation -eq 'inspect')
        if ($Operation -eq 'inspect') {
            return New-FcmOperationResult -Ok $true -Message 'Item inspected.' -Details (Get-FcmItemDiagnostics -Item $item) -Path $item.FullName
        }
        if ($Operation -in @('ownership','grant')) {
            if (-not (Test-FcmOperationsAdministrator)) { throw 'Administrator privileges are required for this operation.' }
            if ($Operation -eq 'ownership') {
                $arguments = @('/F',$item.FullName)
                if ($item.PSIsContainer) { $arguments += @('/R','/D','Y') }
                $output = Invoke-FcmNativeUtility -Name 'takeown' -Argument $arguments
                Write-FcmOperationLog -Action 'ownership' -Path $item.FullName -Detail $output
                return New-FcmOperationResult -Ok $true -Message 'Ownership recovery completed.' -Details $output -Path $item.FullName
            }
            $permission = '*S-1-5-32-544:F'
            if ($item.PSIsContainer) { $permission = '*S-1-5-32-544:(OI)(CI)F' }
            $arguments = @($item.FullName,'/grant',$permission)
            if ($item.PSIsContainer) { $arguments += '/T' }
            $output = Invoke-FcmNativeUtility -Name 'icacls' -Argument $arguments
            Write-FcmOperationLog -Action 'grant' -Path $item.FullName -Detail $output
            return New-FcmOperationResult -Ok $true -Message 'Administrators Full Control granted.' -Details $output -Path $item.FullName
        }
        if ($Operation -eq 'rename') {
            $name = $NewName.Trim()
            if ([string]::IsNullOrWhiteSpace($name) -or $name -in @('.','..') -or $name -match '[<>:"/\\|?*]' -or $name.EndsWith('.') -or $name.EndsWith(' ')) {
                throw 'Enter a valid Windows file or folder name.'
            }
            $target = Join-Path (Split-Path -Parent $item.FullName) $name
            if (Test-Path -LiteralPath $target) { throw ('The destination already exists: ' + $target) }
            Move-Item -LiteralPath $item.FullName -Destination $target -ErrorAction Stop
            Write-FcmOperationLog -Action 'rename' -Path $item.FullName -Detail $target
            return New-FcmOperationResult -Ok $true -Message 'Renamed.' -Details ('New path: ' + $target) -Path $target
        }
        if ($Operation -in @('copy','move')) {
            $folder = Get-FcmDestinationDirectory -Path $Destination
            $target = Join-Path $folder.FullName $item.Name
            if (Test-Path -LiteralPath $target) { throw ('The destination already exists: ' + $target) }
            if ($item.PSIsContainer -and ($item.FullName -eq $folder.FullName -or $item.FullName.StartsWith($folder.FullName.TrimEnd('\') + '\',[StringComparison]::OrdinalIgnoreCase))) {
                throw 'A folder cannot be copied or moved into itself or one of its child folders.'
            }
            if ($Operation -eq 'copy') {
                Copy-Item -LiteralPath $item.FullName -Destination $target -Recurse -ErrorAction Stop
                $message = 'Copied.'
            }
            else {
                Move-Item -LiteralPath $item.FullName -Destination $target -ErrorAction Stop
                $message = 'Moved.'
            }
            Write-FcmOperationLog -Action $Operation -Path $item.FullName -Detail $target
            $resultPath = $item.FullName
            if ($Operation -eq 'move') { $resultPath = $target }
            return New-FcmOperationResult -Ok $true -Message $message -Details ('Destination: ' + $target) -Path $resultPath
        }
        if ($Operation -eq 'delete') {
            Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction Stop
            Write-FcmOperationLog -Action 'delete' -Path $item.FullName
            return New-FcmOperationResult -Ok $true -Message 'Permanently deleted.' -Details $item.FullName -Path ''
        }
        throw 'The requested operation is not available.'
    }
    catch {
        try { Write-FcmOperationLog -Action 'error' -Path $Path -Success $false -Detail $_.Exception.Message }
        catch { }
        return New-FcmOperationResult -Ok $false -Message $_.Exception.Message -Details '' -Path $Path
    }
}

function Get-FcmOperationPrerequisites {
    $failures = New-Object 'System.Collections.Generic.List[string]'
    foreach ($tool in @('icacls.exe','cipher.exe','takeown.exe')) {
        $path = Join-Path $env:WINDIR ('System32\' + $tool)
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { $failures.Add(('Missing Windows utility: ' + $tool)) }
    }
    return $failures.ToArray()
}

Export-ModuleMember -Function Invoke-FcmOperation,Get-FcmOperationPrerequisites

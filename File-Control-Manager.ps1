# File Control Manager - Windows PowerShell 5.1 / PowerShell 6+ / 7+
# Windows Forms GUI. No external dependencies. MIT License.
# ACLs control access; they are not encryption. EFS/BitLocker are not bypassed.
param([string]$InitialPath = '')
if ($env:OS -ne 'Windows_NT') { Write-Error 'Windows only.'; exit 1 }
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
$script:logFile = Join-Path $env:LOCALAPPDATA 'FileControlManager\actions.log'
New-Item -ItemType Directory -Path (Split-Path $script:logFile) -Force | Out-Null
$script:bg = [Drawing.Color]::FromArgb(21,27,39)
$script:panel = [Drawing.Color]::FromArgb(32,41,57)
$script:fg = [Drawing.Color]::FromArgb(237,243,250)
$script:accent = [Drawing.Color]::FromArgb(69,178,226)
$form = New-Object Windows.Forms.Form
$form.Text = 'File Control Manager | FCM 1.0.0'
$form.Size = New-Object Drawing.Size(960,740)
$form.MinimumSize = New-Object Drawing.Size(820,650)
$form.StartPosition = 'CenterScreen'
$form.BackColor = $script:bg
$form.ForeColor = $script:fg
$form.Font = New-Object Drawing.Font('Segoe UI',10)
$layout = New-Object Windows.Forms.TableLayoutPanel
$layout.Dock='Fill'; $layout.Padding=New-Object Windows.Forms.Padding(18)
$layout.ColumnCount=1; $layout.RowCount=7
[void]$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle('Absolute',65)))
[void]$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle('Absolute',85)))
[void]$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle('Absolute',62)))
[void]$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle('Absolute',76)))
[void]$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle('Absolute',55)))
[void]$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle('Percent',100)))
[void]$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle('Absolute',40)))
$form.Controls.Add($layout)
function New-Label($txt,$size) { $l=New-Object Windows.Forms.Label; $l.Text=$txt; $l.ForeColor=$script:fg; $l.Dock='Fill'; $l.TextAlign='MiddleLeft'; $l.Font=New-Object Drawing.Font('Segoe UI',$size); return $l }
function New-Button($txt,$color) { $b=New-Object Windows.Forms.Button; $b.Text=$txt; $b.FlatStyle='Flat'; $b.FlatAppearance.BorderSize=0; $b.BackColor=$color; $b.ForeColor=[Drawing.Color]::White; $b.Font=New-Object Drawing.Font('Segoe UI',10,[Drawing.FontStyle]::Bold); $b.Margin=New-Object Windows.Forms.Padding(4); return $b }
$header=New-Label '▣  FILE CONTROL MANAGER     •     Windows file & ACL toolkit' 16
$layout.Controls.Add($header,0,0)
$pathPanel=New-Object Windows.Forms.TableLayoutPanel
$pathPanel.Dock='Fill'; $pathPanel.ColumnCount=2; $pathPanel.RowCount=2
[void]$pathPanel.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('Percent',80)))
[void]$pathPanel.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('Percent',20)))
[void]$pathPanel.RowStyles.Add((New-Object Windows.Forms.RowStyle('Absolute',28)))
[void]$pathPanel.RowStyles.Add((New-Object Windows.Forms.RowStyle('Percent',100)))
$pathLabel=New-Label 'TARGET FILE OR FOLDER  •  exact path' 9
$pathPanel.Controls.Add($pathLabel,0,0); $pathPanel.SetColumnSpan($pathLabel,2)
$pathBox=New-Object Windows.Forms.TextBox; $pathBox.Dock='Fill'; $pathBox.Font=New-Object Drawing.Font('Consolas',11); $pathBox.Text=$InitialPath
$pathPanel.Controls.Add($pathBox,0,1)
$browse=New-Button '📂  Browse' $script:panel
$pathPanel.Controls.Add($browse,1,1)
$layout.Controls.Add($pathPanel,0,1)
$ops=New-Object Windows.Forms.TableLayoutPanel; $ops.Dock='Fill'; $ops.ColumnCount=5
1..5 | ForEach-Object { [void]$ops.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('Percent',20))) }
$inspect=New-Button '🔎  Inspect' $script:panel
$rename=New-Button '✎  Rename' $script:panel
$move=New-Button '➜  Move' $script:panel
$delete=New-Button '✕  Delete' ([Drawing.Color]::FromArgb(148,52,68))
$refresh=New-Button '↻  Refresh' $script:panel
@($inspect,$rename,$move,$delete,$refresh) | ForEach-Object { $ops.Controls.Add($_) }
$layout.Controls.Add($ops,0,2)
$aclOps=New-Object Windows.Forms.TableLayoutPanel; $aclOps.Dock='Fill'; $aclOps.ColumnCount=3
1..3 | ForEach-Object { [void]$aclOps.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('Percent',33.333))) }
$owner=New-Button '🔑  Take Ownership' ([Drawing.Color]::FromArgb(37,100,145))
$grant=New-Button '🛡  Grant Admins Full Control' ([Drawing.Color]::FromArgb(37,100,145))
$admin=New-Button '↑  Relaunch as Admin' ([Drawing.Color]::FromArgb(83,86,146))
@($owner,$grant,$admin) | ForEach-Object { $aclOps.Controls.Add($_) }
$layout.Controls.Add($aclOps,0,3)
$info=New-Label 'Select a target, then Inspect. Ownership and permissions are separate operations.' 9
$layout.Controls.Add($info,0,4)
$output=New-Object Windows.Forms.RichTextBox; $output.Dock='Fill'; $output.ReadOnly=$true; $output.BackColor=$script:panel; $output.ForeColor=$script:fg; $output.Font=New-Object Drawing.Font('Consolas',10); $output.BorderStyle='None'; $output.WordWrap=$false
$layout.Controls.Add($output,0,5)
$status=New-Label 'Ready  •  Changes are never made automatically.' 9
$layout.Controls.Add($status,0,6)
function Log($message) {
 $stamp=(Get-Date).ToString('yyyy-MM-dd HH:mm:ss'); $line="[$stamp] $message"
 $output.AppendText("$line`r`n"); $output.ScrollToCaret(); $status.Text=$message
 try { Add-Content -LiteralPath $script:logFile -Value $line -Encoding UTF8 } catch {}
}
function Target {
 $p=$pathBox.Text.Trim().Trim('"'); if ([string]::IsNullOrWhiteSpace($p)) { throw 'Choose a file or folder.' }
 if (-not (Test-Path -LiteralPath $p)) { throw "Target does not exist: $p" }
 return (Get-Item -LiteralPath $p -Force -ErrorAction Stop).FullName
}
function SafeTarget($p) {
 $full=[IO.Path]::GetFullPath($p).TrimEnd('\')
 $root=[IO.Path]::GetPathRoot($full).TrimEnd('\')
 if ($full -ieq $root) { throw 'Refusing to modify a drive root.' }
 $win=$env:WINDIR.TrimEnd('\')
 $system=@($win, (Join-Path $win 'System32'),$env:ProgramFiles,${env:ProgramFiles(x86)},$env:ProgramData,($env:SystemDrive+'\Users'))
 foreach($s in $system) { if ($s -and ($full -ieq $s.TrimEnd('\'))) { throw 'Protected system-level directory. Operation refused.' } }
 return $full
}
function Confirm($msg) { return ([Windows.Forms.MessageBox]::Show($msg,'FCM - Confirm',[Windows.Forms.MessageBoxButtons]::YesNo,[Windows.Forms.MessageBoxIcon]::Warning) -eq [Windows.Forms.DialogResult]::Yes) }
function Execute($name,[scriptblock]$action) { try { & $action } catch { Log "ERROR [$name]: $($_.Exception.Message)"; [Windows.Forms.MessageBox]::Show($_.Exception.Message,'FCM Error','OK','Error') | Out-Null } }
function Inspect {
 Execute 'Inspect' {
  $p=Target; $i=Get-Item -LiteralPath $p -Force; $a=Get-Acl -LiteralPath $p -ErrorAction Stop
  Log "TARGET: $p"; Log "TYPE: $(if($i.PSIsContainer){'Directory'}else{'File'}) | ATTRIBUTES: $($i.Attributes)"; Log "OWNER: $($a.Owner)"
  foreach($rule in $a.Access) { Log "ACL: $($rule.IdentityReference) | $($rule.AccessControlType) | $($rule.FileSystemRights) | inherited=$($rule.IsInherited)" }
 }
}
$browse.Add_Click({
 $choice=[Windows.Forms.MessageBox]::Show('Select a folder? Choose No to select a file.','Browse target','YesNoCancel','Question')
 if($choice -eq 'Cancel'){return}
 if($choice -eq 'Yes'){$d=New-Object Windows.Forms.FolderBrowserDialog; if($d.ShowDialog() -eq 'OK'){$pathBox.Text=$d.SelectedPath}}
 else {$d=New-Object Windows.Forms.OpenFileDialog; $d.CheckFileExists=$true; if($d.ShowDialog() -eq 'OK'){$pathBox.Text=$d.FileName}}
})
$inspect.Add_Click({Inspect}); $refresh.Add_Click({Inspect})
$rename.Add_Click({ Execute 'Rename' {
 $p=SafeTarget (Target)
 $new=[Microsoft.VisualBasic.Interaction]::InputBox('Enter new name (not a path):','Rename',(Split-Path $p -Leaf))
 if([string]::IsNullOrWhiteSpace($new)){return}
 if($new -match '[\\/:*?"<>|]' -or $new -in @('.','..')){throw 'Invalid name.'}
 $dest=Join-Path (Split-Path $p -Parent) $new
 if(Test-Path -LiteralPath $dest){throw 'Destination already exists.'}
 if(-not (Confirm "Rename?`n$p`nTO`n$dest")){return}
 Rename-Item -LiteralPath $p -NewName $new -ErrorAction Stop; $pathBox.Text=$dest; Log "RENAMED: $p -> $dest"
}})
$move.Add_Click({ Execute 'Move' {
 $p=SafeTarget (Target)
 $folder=New-Object Windows.Forms.FolderBrowserDialog; $folder.Description='Choose destination folder'
 if($folder.ShowDialog() -ne 'OK'){return}
 $dest=Join-Path $folder.SelectedPath (Split-Path $p -Leaf)
 if(Test-Path -LiteralPath $dest){throw 'Destination already exists. Overwriting is disabled.'}
 if($folder.SelectedPath.TrimEnd('\').StartsWith(($p.TrimEnd('\')+'\'),[StringComparison]::OrdinalIgnoreCase)){throw 'Cannot move a directory into itself.'}
 if(-not (Confirm "Move?`n$p`nTO`n$dest")){return}
 Move-Item -LiteralPath $p -Destination $dest -ErrorAction Stop; $pathBox.Text=$dest; Log "MOVED: $p -> $dest"
}})
$delete.Add_Click({ Execute 'Delete' {
 $p=SafeTarget (Target)
 $item=Get-Item -LiteralPath $p -Force
 if(-not (Confirm "PERMANENT DELETE (no Recycle Bin):`n$p`n`nThis can delete ALL contents recursively.")){return}
 $typed=[Microsoft.VisualBasic.Interaction]::InputBox("Type DELETE to permanently remove:`n$p",'Final confirmation','')
 if($typed -cne 'DELETE'){Log 'Delete cancelled: confirmation not matched.';return}
 Remove-Item -LiteralPath $p -Force -Recurse -ErrorAction Stop; Log "DELETED: $p"
}})
function Run-Native($exe,[string[]]$arguments) {
 $res=& $exe @arguments 2>&1 | Out-String
 if($res){Log $res.Trim()}
 if($LASTEXITCODE -ne 0){throw "$exe failed with exit code $LASTEXITCODE"}
}
$owner.Add_Click({ Execute 'Ownership' {
 $p=SafeTarget (Target)
 if(-not (Confirm "Take ownership of this target and all children?`n$p`n`nThis changes security metadata.")){return}
 Run-Native 'takeown.exe' @('/F',$p,'/R','/D','Y'); Log "OWNERSHIP COMMAND COMPLETED: $p"
}})
$grant.Add_Click({ Execute 'Grant ACL' {
 $p=SafeTarget (Target)
 if(-not (Confirm "Grant local Administrators FULL CONTROL recursively?`n$p`n`nThis is a security-sensitive permission change.")){return}
 Run-Native 'icacls.exe' @($p,'/grant','*S-1-5-32-544:(OI)(CI)F','/T','/C'); Log "ACL GRANT COMMAND COMPLETED: $p"
}})
$admin.Add_Click({ Execute 'Elevate' {
 $exe=(Get-Process -Id $PID).Path
 $scriptPath=$PSCommandPath
 $args='-NoProfile -ExecutionPolicy Bypass -File "'+$scriptPath+'" -InitialPath "'+$pathBox.Text.Replace('"','')+'"'
 Start-Process -FilePath $exe -ArgumentList $args -Verb RunAs -ErrorAction Stop
 Log 'Requested administrator relaunch.'
}})
Add-Type -AssemblyName Microsoft.VisualBasic
Log 'FCM ready. Inspect before changing permissions. Windows only.'
[void]$form.ShowDialog()

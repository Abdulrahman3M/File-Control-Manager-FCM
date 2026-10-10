# File Control Manager (FCM) 1.0.0

A free, source-available Windows Forms PowerShell utility for Windows PowerShell 5.1, PowerShell 6, and PowerShell 7 on **Windows**.

## Quick start

1. Extract the ZIP to a normal writable directory.
2. Double-click `Launch-FCM.cmd` (prefers `pwsh`, otherwise Windows PowerShell).
3. Browse for a file or folder and select **Inspect**.
4. Use Rename, Move, or Delete; each operation asks for confirmation. Permanent deletion requires typing `DELETE`.
5. If permissions block a legitimate operation, use **Relaunch as Admin**, then **Take Ownership** and/or **Grant Admins Full Control** as appropriate.

## Features

- Dark graphical UI with Unicode symbol icons, no external modules.
- File/folder inspect: owner, attributes, access rules.
- Rename and move (no destination overwriting).
- Permanent recursive delete with two confirmations.
- Explicit take ownership and ACL grant via Windows `takeown.exe` and `icacls.exe`.
- Log stored in `%LOCALAPPDATA%\FileControlManager\actions.log`.
- Basic protection against modifying drive roots and some major system directories.

## Important limitations

- ACL is **not encryption**. This tool does not decrypt EFS, unlock BitLocker, bypass antivirus, or bypass TrustedInstaller / Windows protected resources.
- Administrative elevation is subject to UAC and Windows security policy.
- Locked files can still fail; close processes holding file handles first (e.g. PowerToys File Locksmith).
- Permission changes may fail due to explicit deny ACEs, inheritance, policies, or file-system errors.
- Do not run on system files or files you do not have permission to manage.
- `takeown /D Y` uses the English `Y` response; behavior can vary on localized Windows installations.
- This is a first release; it has not been runtime-tested on all three PowerShell versions in a Windows GUI environment.

## Security design

All changes are manual and target a single selected path. No automatic ACL modifications. No background services, network calls, downloads, or telemetry. Inspect source before executing elevated code.

## License

MIT; see LICENSE.

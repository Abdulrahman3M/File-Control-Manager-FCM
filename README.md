# File Control Manager (FCM) v2.1.1

Terminal-based file and folder manager for Windows, inspired by the FFmpeg User Manager terminal layout.

**Requirements:** Windows 10/11, Python 3.9+, PowerShell 5.1 / 6 / 7.

**Start:** double-click `FCM.bat`, or run `./FCM.ps1` in PowerShell.

Features: a colored terminal dashboard, file metadata and `icacls` ACL inspection, `cipher` EFS status checks, copying, moving, renaming, confirmed permanent deletion, ownership recovery, administrator ACL grants, elevation, and JSONL audit logs in LocalAppData.

ACLs are access permissions, not encryption. FCM does not decrypt EFS or BitLocker, bypass Windows security controls, or forcibly unlock active process handles. Ownership and ACL changes always require confirmation.

Tests: `python -m unittest discover -s tests -v`. Windows launcher checks: `./tests/Test-FcmStartup.ps1` (requires Python 3.9+). A Windows GitHub Actions workflow runs startup checks under PowerShell 5.1 and PowerShell 7. PowerShell 6 compatibility is not verified.

`VERSION` is the authoritative version file, to be synchronized with README and CHANGELOG.


### Administrator permissions and security warnings
FCM displays a consent menu before requesting administrator privileges. Windows UAC remains active. Windows SmartScreen or downloaded-file warnings are separate and cannot be removed by the app; signing and trusted distribution are recommended. The TUI supports ANSI colors when the terminal allows them and emoji/symbol/ASCII glyph fallback. Check the Windows Actions workflow for the latest runtime verification status.


### Startup troubleshooting (v2.1.1)
- The error `Cannot convert value "System.String" to type "System.Management.Automation.SwitchParameter"` occurred because PowerShell treated `$Version` and `$version` as the same variable. The version string now uses `$appVersion`.
- The Python launcher `py.exe` accepts `-3`; `python.exe` does not. FCM detects the runtime and validates Python 3.9+ before opening the interface.
- To verify startup without opening the UI: `./FCM.ps1 -Version` and `./FCM.ps1 -SelfTest`.
- To run without the initial administrator prompt (e.g. in automated smoke tests): `./FCM.ps1 -SkipAdminPrompt`. ACL modification commands still require administrator privileges.
- Windows PowerShell 5.1 / PowerShell 7 startup is exercised in GitHub Actions; PowerShell 6 remains UNVERIFIED unless separately tested.

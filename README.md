# File Control Manager (FCM) v2.1.0

Terminal-based file and folder manager for Windows, inspired by the FFmpeg User Manager terminal layout.

**Requirements:** Windows 10/11, Python 3.9+, PowerShell 5.1 / 6 / 7.

**Start:** double-click `FCM.bat`, or run `./FCM.ps1` in PowerShell.

Features: a colored terminal dashboard, file metadata and `icacls` ACL inspection, `cipher` EFS status checks, copying, moving, renaming, confirmed permanent deletion, ownership recovery, administrator ACL grants, elevation, and JSONL audit logs in LocalAppData.

ACLs are access permissions, not encryption. FCM does not decrypt EFS or BitLocker, bypass Windows security controls, or forcibly unlock active process handles. Ownership and ACL changes always require confirmation.

Tests: `python -m unittest discover -s tests -v`. **Windows and PowerShell 5.1/6/7 runtime integration tests have not yet been performed.**

`VERSION` is the authoritative version file, to be synchronized with README and CHANGELOG.


### Administrator permissions and security warnings
FCM displays a consent menu before requesting administrator privileges. Windows UAC remains active. Windows SmartScreen or downloaded-file warnings are separate and cannot be removed by the app; signing and trusted distribution are recommended. The TUI supports ANSI colors when the terminal allows them and emoji/symbol/ASCII glyph fallback. Windows runtime tests are pending.

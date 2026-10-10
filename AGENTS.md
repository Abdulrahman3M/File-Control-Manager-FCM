# Project Rules
- Console UI only; no Windows Forms.
- Maintain PowerShell 5.1, 6 and 7 launch compatibility.
- VERSION is authoritative; synchronize README and CHANGELOG.
- Explicit confirmation before modifying ACL, ownership or deleting files.
- Never imply NTFS ACL is encryption or that EFS/BitLocker can be bypassed.
- Do not claim runtime verification on Windows until it has been performed.

- Never reuse a switch-parameter name (case-insensitively) as a local variable; PowerShell variable names are case-insensitive.
- Run `FCM.ps1 -Version` and `FCM.ps1 -SelfTest` as pre-merge launcher regression tests.
- Keep separate Python invocation logic for `py.exe` (supports `-3`) and `python.exe` (does not).
- Test both `01` and `1` when the TUI displays two-digit numbered options.
- Require GitHub Actions Windows startup checks for PowerShell 5.1 and 7 before describing the fix as verified; list PowerShell 6 separately.

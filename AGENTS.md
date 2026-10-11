# Project Rules
- Console UI only; no Windows Forms.
- Maintain PowerShell 5.1, 6 and 7 launch compatibility.
- VERSION is authoritative; synchronize README and CHANGELOG.
- Explicit confirmation before modifying ACL, ownership or deleting files.
- Never imply NTFS ACL is encryption or that EFS/BitLocker can be bypassed.
- Do not claim runtime verification on Windows until it has been performed.

- Never reuse a switch-parameter name (case-insensitively) as a local variable; PowerShell variable names are case-insensitive.
- Run `FCM.ps1 -Version` and `FCM.ps1 -SelfTest` as pre-merge launcher regression tests.
- Keep the runtime PowerShell-only; do not add Python launchers, packages, tests, or runtime dependencies.
- Test both `01` and `1` when the TUI displays two-digit numbered options.
- Require GitHub Actions Windows startup checks for PowerShell 5.1 and 7 before describing the fix as verified; list PowerShell 6 separately.

- Automated TUI checks must use `FCM.ps1 -SmokeTest` rather than piping interactive input through nested Windows PowerShell 5.1 processes.
- Keep redirected output UTF-8-capable and provide ASCII fallback for terminal glyphs.


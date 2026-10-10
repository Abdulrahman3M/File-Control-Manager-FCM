# Changelog

## 2.1.1 — 2026-10-10
- Fixed fatal startup crash caused by case-insensitive PowerShell variable collision between `$Version` (switch) and `$version` (string).
- Corrected Python runtime detection and prevented passing the `py.exe`-specific `-3` flag to `python.exe`.
- Allowed zero-padded menu selections, matching displayed entries (`01`, `02`, etc.).
- Added `-SelfTest` and `-SkipAdminPrompt` launch options for smoke testing.
- Added Windows PowerShell 5.1 and PowerShell 7 GitHub Actions startup test matrix.
- Windows runtime status depends on CI results; PowerShell 6 remains unverified.


## 2.1.0 — 2026-10-10
- Colorized terminal dashboard and selectable icon tiers with symbol/ASCII fallback.
- Added explicit administrator consent screen before Windows UAC elevation.
- Preserved Windows security warnings; no security bypasses or automatic policy changes.
- Windows runtime validation pending.

## 2.0.0 — 2026-10-10
- Replaced Windows Forms GUI with a Python-backed PowerShell terminal dashboard.
- Added FCM.bat launcher and FCM.ps1 PowerShell entry point.
- Added file inspection, copy, rename, move, confirmed deletion, ACL inspection and repair.
- Added EFS status diagnostics, structured activity logs, VERSION and unit tests.
- Windows runtime compatibility remains to be validated.

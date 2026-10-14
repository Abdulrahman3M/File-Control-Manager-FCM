# Changelog

## 3.2.1 — 2026-10-14
- Replaced per-key Clear-Host screen refresh with changed-row in-place rendering to reduce menu flicker.
- Preserved semantic icon colors, Emoji/Symbol/ASCII fallbacks, muted help text, and the existing menu layout.
- Kept plain/redirected diagnostic output compatible with existing smoke tests.


## 3.2.0 — 2026-10-11
- Changed all-uppercase dashboard headings and session labels to readable Title Case, including the application name, target, actions, and diagnostic mode.
- Updated startup regression checks to prevent all-uppercase display headings from returning.

## 3.1.1 — 2026-10-11
- Fixed a PowerShell 5.1 parameter-binding failure when rendering lines without an icon while colors are enabled.
- Added a regression check for colored rendering of ordinary text lines.

## 3.1.0 — 2026-10-11
- Elevated startup now opens a dedicated Windows Terminal window running the same PowerShell executable and FCM command; the classic console remains available when Windows Terminal is missing.
- Elevated follow-up actions also open in Windows Terminal, with their selected target and operation preserved.
- Added semantic colors for action and status icons, with terminal-aware Emoji, symbol, and ASCII fallback behavior.
- Updated the startup checks and usage documentation for the elevated Windows Terminal flow.

## 3.0.0 — 2026-10-10
- Replaced the Python operation backend with native PowerShell file operations and Windows security tools; removed Python runtime and test dependencies.
- Added startup preflight diagnostics for Windows, PowerShell, required project files, and Windows utilities.
- Normal interactive startup now requests standard Windows UAC elevation after preflight; canceling closes FCM without starting an operation.
- Replaced the legacy Windows Forms entry point with a compatibility forwarder to the PowerShell TUI.
- Updated the dashboard header, administrator status, and action guidance to match elevated startup behavior.
- Preserved explicit confirmation for permanent deletion and security changes, plus protected-root and destination-collision checks.

## 2.2.1 — 2026-10-10
- Fixed path entry dropping numeric characters because the keyboard layer classified digits separately from ordinary text.
- Added a regression check for paths with numbered folders and digit-containing names.

## 2.2.0 — 2026-10-10
- Rebuilt the terminal interface as focused PowerShell TUI modules with arrow/Enter navigation and retained numeric shortcuts.
- Added semantic color roles, terminal-aware Emoji/Symbol/ASCII icon fallback, responsive menu rendering, contextual help, and editable prompts.
- Used a separate Python JSON backend before the PowerShell-only 3.0.0 migration.

## 2.1.1 — 2026-10-10
- Fixed startup variable collision, Python runtime detection, numeric shortcut parsing, and redirected-output handling.
- Added `-SelfTest`, `-SmokeTest`, and Windows PowerShell 5.1 / PowerShell 7 startup checks.

## 2.1.0 — 2026-10-10
- Added a colorized terminal dashboard and selectable icon tiers with symbol/ASCII fallback.
- Added explicit administrator consent before Windows UAC elevation.

## 2.0.0 — 2026-10-10
- Replaced the original Windows Forms GUI with a Python-backed PowerShell terminal dashboard.
- Added file inspection, copy, rename, move, confirmed deletion, ACL inspection and repair, EFS diagnostics, structured activity logs, and launcher.

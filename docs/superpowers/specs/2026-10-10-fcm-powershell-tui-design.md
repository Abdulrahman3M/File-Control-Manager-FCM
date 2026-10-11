# File Control Manager PowerShell-Only TUI

## Goal

Deliver FCM as a Windows PowerShell terminal application with no Python runtime or Windows Forms dependency. Preserve file-management and ACL/EFS diagnostics, improve the Codex-inspired console presentation, check prerequisites at startup, and require an administrator session before showing the operational menu.

## Current state

- FCM 2.2.1 has a keyboard-first PowerShell TUI and Python file-operation backend.
- The local base directory contains FCM 1.0.0 with a Windows Forms GUI and its own PowerShell file operations.
- The delivered PowerShell TUI already provides the full 11-action workflow, confirmation dialogs, semantic colors, icon fallbacks, and terminal-aware rendering.

## Design

### Application and visual interface

Keep the existing modular TUI boundaries: Platform owns environment facts, Theme owns color and icon choices, Renderer is the only screen writer, Input is the only key reader, and App owns workflow state. Use a compact Codex-style command header, a clear title/version line, selected-target context, keyboard-highlighted actions, contextual status, and a stable shortcut footer. Preserve Emoji, WGL4-symbol, and ASCII fallbacks, `NO_COLOR`, keyboard navigation, resize-aware layout, and PowerShell 5.1 compatibility.

### PowerShell-only operation backend

Move all domain behavior into `src/Core/Operations.psm1`. Use PowerShell filesystem APIs for inspect, rename, copy, move, delete, target normalization, and JSONL audit logs. Use `Get-Acl` plus `icacls.exe`/`cipher.exe` for Windows ACL and EFS diagnostics, and `takeown.exe`/`icacls.exe` for explicitly confirmed ownership and ACL changes. Keep process invocation argument-safe; never use `Invoke-Expression` or interpolated shell command strings. No Python executable, script, package, or CI setup is required.

Retain protected-root and reparse-point checks, collision refusal, action logs, exact typed `DELETE` confirmation, and explicit consent before security changes. ACL changes do not decrypt EFS or BitLocker and do not bypass Windows policy, protected system resources, or file locks.

### Startup and elevation

Before opening the dashboard, check Windows, supported PowerShell version, required FCM modules, an interactive terminal (except explicit diagnostic modes), and required Windows utilities. If a prerequisite is missing, print a concise explanation and recovery step. Normal launch requests UAC immediately when the current token is not elevated. If approval succeeds, the elevated FCM process repeats preflight and opens the TUI; if the user cancels, FCM exits without starting the operational UI. Diagnostic `-SelfTest` and `-SmokeTest` modes remain non-elevating for automation.

Use Windows' standard UAC process boundary; the elevated process may open a separate console window because Windows does not permit silently raising the token of an existing non-elevated PowerShell process. Do not change execution policy or hide the elevated console.

### Compatibility and diagnostics

Support Windows PowerShell 5.1 and PowerShell 7; retain PowerShell 6 as best-effort pending an installed runtime. Prefer Windows Terminal but support the classic console. Use no Python dependency. The launcher starts the FCM PowerShell entry point, reports startup failures clearly, and closes after UAC cancellation.

## Acceptance criteria

1. Operations execute in PowerShell without discovering or invoking Python.
2. All current actions remain available with safe path validation, no-overwrite behavior, audit logs, and explicit destructive/security confirmations.
3. Normal startup runs preflight and requests UAC when needed; cancellation starts no operation and exits FCM.
4. `-SelfTest` and `-SmokeTest` verify prerequisites/dashboard without triggering UAC.
5. Codex-style header, clear selected-row treatment, semantic colors, icon fallbacks, keyboard navigation, and narrow-terminal behavior remain available.
6. PowerShell 5.1 and PowerShell 7 tests cover operations, launcher/preflight, and navigation.
7. Documentation states elevation behavior and Windows encryption/security limitations.

## Out of scope

- Decrypting EFS or BitLocker, bypassing ACLs, TrustedInstaller, antivirus, Windows policy, or active file locks.
- Linux and macOS support.
- Publishing a GitHub release or changing remote repositories.

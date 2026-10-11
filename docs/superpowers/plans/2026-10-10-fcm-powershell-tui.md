# FCM PowerShell-Only TUI Implementation Plan

> **For agentic workers:** Use TDD for each behavior change. Keep every step independently verifiable.

**Goal:** Convert FCM to a PowerShell-only TUI and operations engine, with startup preflight and UAC before the operational menu.

**Architecture:** PowerShell modules own platform checks, safe native process calls, filesystem/security operations, and TUI rendering/input. `FCM.ps1` performs preflight and launches an elevated FCM process when needed. Diagnostic switches remain available without UAC.

**Tech Stack:** Windows PowerShell 5.1+, PowerShell 7, Windows inbox tools (`icacls.exe`, `cipher.exe`, `takeown.exe`); no Python.

**Spec:** `docs/superpowers/specs/2026-10-10-fcm-powershell-tui-design.md`

## Global Constraints

- No Python, Windows Forms, external PowerShell modules, network access, or execution-policy mutation.
- Protect drive/system/app roots and reparse points; do not overwrite destinations.
- Delete and security changes require visible confirmation; EFS/BitLocker are never bypassed or decrypted.
- Only Renderer writes TUI output, Input reads key events, Theme owns glyphs/colors, and Platform owns environment facts.
- Windows PowerShell 5.1 and PowerShell 7 are the primary test targets.

## Review Focus

- Numeric keystrokes must remain text in path prompts while remaining numeric shortcuts in menus.
- Unicode paths with spaces and supplementary characters must survive target entry and file operations.
- UAC cancellation must launch no elevated operation and must let the non-elevated launcher exit cleanly.
- Native utility failures/localized output must be reported without shell injection or false success.
- EFS, BitLocker, reparse points, protected roots, and destination collisions must fail safely.

---

### Task 1: Port operations and establish regression tests

**Files:** Create `src/Core/Operations.psm1`; create `tests/Test-Operations.ps1`; modify `tests/Test-TuiModules.ps1`.

- [x] Write tests for inspect metadata/ACL/EFS response, copy, move, rename, delete confirmations, collision refusal, log output, and admin-only operation gating.
- [x] Run the operation suite to observe expected missing-module failures.
- [x] Implement PowerShell-native structured operation results and JSONL logs.
- [x] Run operation tests in PowerShell 5.1 and 7.

### Task 2: Preflight, UAC startup, and launcher behavior

**Files:** Modify `src/Core/Platform.psm1`, `src/Core/Process.psm1`, `src/Core/App.psm1`, `FCM.ps1`, `FCM.bat`; modify `tests/Test-FcmStartup.ps1`.

- [x] Add tests for Windows/PowerShell/module/native-tool preflight and diagnostic modes that do not elevate.
- [x] Add a controllable test seam for startup elevation decision and cancellation status.
- [x] Implement startup UAC relaunch, clean cancel exit, and elevated child preflight.
- [x] Confirm normal operations do not invoke Python and startup messages explain missing prerequisites.
- [x] Run launcher tests in PowerShell 5.1 and 7.

### Task 3: Integrate PowerShell operations and refine Codex-style presentation

**Files:** Modify `src/Core/App.psm1`, TUI theme/renderer/menu modules, and `tests/Test-TuiModules.ps1`.

- [x] Test module ownership boundaries, header composition, all 11 actions, color/icon fallback, keyboard navigation, and responsive menu behavior.
- [x] Wire each workflow directly to `Invoke-FcmOperation`; preserve target updates, confirmation layers, and actionable failures.
- [x] Tune title/header spacing and icons to match the supplied Codex CLI reference while preserving Unicode/ASCII fallback.
- [x] Run PowerShell launcher, operation, and scripted menu checks.

### Task 4: Remove Python dependency and update base folder package

**Files:** Remove `fcm.py` and `tests/test_fcm.py`; modify README, CHANGELOG, VERSION, `.github/workflows/windows-startup.yml`, and compatibility launch scripts.

- [x] Remove Python setup and test steps from CI; use the PowerShell operation suite in both shells.
- [x] Replace the old Windows Forms entry script with a PowerShell TUI forwarder.
- [x] Document startup UAC, cancellation, preflight, supported versions, and encryption limitations.
- [x] Run all suites in Windows PowerShell 5.1 and PowerShell 7, scan runtime source for Python/Windows Forms execution references, and smoke-test an extracted package.
- [x] Synchronize the verified package to `D:\Test\02 │ Assistance Projects\File Control Manager (FCM)\FCM` and pass installed `-SelfTest` / `-SmokeTest` checks.

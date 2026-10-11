# File Control Manager (FCM) v3.2.0

FCM is a PowerShell-only, keyboard-first terminal file and folder manager. It runs inside PowerShell or Windows Terminal and uses native PowerShell file operations plus Windows security utilities. It has no Python or third-party runtime dependency.

## Requirements and startup

- Windows 10 or 11
- Windows PowerShell 5.1 or PowerShell 7 (PowerShell 6 is supported by the code but is not in the automated test matrix)
- Windows utilities `icacls.exe`, `cipher.exe`, and `takeown.exe`
- Windows Terminal is recommended and is used for elevated sessions when installed; the classic PowerShell console remains a fallback

Start `FCM.bat` or run `./FCM.ps1` from PowerShell. FCM checks Windows, PowerShell, required files, and utilities before showing the normal interface. If checks pass and the current session is not elevated, Windows presents its standard UAC prompt. When Windows Terminal is installed, approval opens a new Windows Terminal window with an elevated PowerShell tab; Windows Terminal does not mix administrator and non-administrator tabs in one window. If Windows Terminal is unavailable, FCM falls back to the elevated PowerShell console. Canceling UAC closes FCM without running an action. FCM does not change system execution policy.

```powershell
./FCM.ps1 -Version
./FCM.ps1 -SelfTest
./FCM.ps1 -SmokeTest
```

`-SelfTest` and `-SmokeTest` are non-elevating diagnostics. `-SmokeTest` renders the real dashboard once and exits. Normal interactive use requires a terminal.

## Interface

The dashboard displays the application version, administrator mode, selected target, available actions, contextual help, and status. Use Up/Down and Enter, or type an action number such as `01` or `11`. Esc backs out; Ctrl+C exits. Path and filename prompts support typing, paste, navigation keys, Backspace, Delete, and Ctrl+U.

FCM colors each action and status icon by meaning (for example, yellow for folders, green for copy/success, and red for deletion/errors). Windows Terminal uses Emoji icons when its terminal session is detected; PowerShell and older consoles receive symbol or ASCII fallbacks. Set `FCM_ICONS=emoji`, `FCM_ICONS=symbol`, or `FCM_ICONS=ascii` to choose explicitly. Set `NO_COLOR` to disable colors. Redirected output uses readable ASCII icons.

## Actions

1. Choose a file or folder.
2. Inspect metadata, Windows ACLs, and EFS status.
3. Rename without overwriting.
4. Copy to an existing destination folder.
5. Move to an existing destination folder.
6. Permanently delete after confirmation and typing `DELETE`.
7. Take ownership.
8. Grant the local Administrators group Full Control.
9. Open another Administrator FCM session.
10. View recent activity logs.
11. Exit.

Copy, move, and rename refuse existing destination names. Activity is recorded as JSON Lines under the current user's LocalAppData folder. Security changes require a second explicit confirmation after UAC. ACLs control access; they are not encryption. FCM does not decrypt EFS or BitLocker, bypass Windows security controls, or forcibly unlock active file handles.

## Checks

Run these from PowerShell 5.1 or 7:

```powershell
./tests/Test-TuiModules.ps1
./tests/Test-Operations.ps1
./tests/Test-FcmStartup.ps1
```

GitHub Actions runs the same checks on Windows PowerShell 5.1 and PowerShell 7. Automated checks cannot approve/cancel a real UAC prompt or guarantee a particular font's Emoji rendering; PowerShell 6 also remains outside the CI matrix.

## Version and license

`VERSION` is authoritative. See `CHANGELOG.md` for user-facing changes. FCM is provided under `LICENSE`.

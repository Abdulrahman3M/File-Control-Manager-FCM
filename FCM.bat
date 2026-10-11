@echo off
setlocal EnableExtensions DisableDelayedExpansion
set "ROOT=%~dp0"
set "PWSH="
for %%P in (pwsh.exe) do set "PWSH=%%~$PATH:P"
if not defined PWSH for %%P in (powershell.exe) do set "PWSH=%%~$PATH:P"
if not defined PWSH set "PWSH=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "FCM_CODEPAGE="
for /f "tokens=2 delims=:" %%A in ('chcp') do set "FCM_CODEPAGE=%%A"
set "FCM_CODEPAGE=%FCM_CODEPAGE: =%"
chcp 65001 >nul
"%PWSH%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%ROOT%FCM.ps1" %*
set "FCM_EXIT=%ERRORLEVEL%"
if defined FCM_CODEPAGE chcp %FCM_CODEPAGE% >nul
if not "%FCM_EXIT%"=="0" if not "%FCM_EXIT%"=="5" pause
exit /b %FCM_EXIT%

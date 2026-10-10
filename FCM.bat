@echo off
setlocal EnableExtensions DisableDelayedExpansion
set "ROOT=%~dp0"
set "PWSH="
for %%P in (pwsh.exe) do set "PWSH=%%~$PATH:P"
if not defined PWSH for %%P in (powershell.exe) do set "PWSH=%%~$PATH:P"
if not defined PWSH set "PWSH=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
"%PWSH%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%ROOT%FCM.ps1" %*
if errorlevel 1 pause

@echo off
setlocal EnableExtensions DisableDelayedExpansion
call "%~dp0FCM.bat" %*
exit /b %ERRORLEVEL%

@echo off
rem Run the same checks as CI. Double-click or run from a terminal.
rem All arguments are passed through to scripts\check.ps1
rem   check.cmd              format check, lint, import, test
rem   check.cmd -Fix         run gdformat first, then all checks
rem   check.cmd -Only test   run one step only (format / lint / import / test)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\check.ps1" %*
if errorlevel 1 pause

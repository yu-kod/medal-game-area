@echo off
rem Launch the medal game. Double-click or run from a terminal.
rem All arguments are passed through to arcade\run.ps1
rem   play.cmd              play by hand (no auto-insert, no on-screen readout)
rem   play.cmd -Debug       show the dev readout in the top-left corner
rem   play.cmd -Demo        run the auto-insert demo
rem   play.cmd -Import      re-import after adding a new class_name
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0arcade\run.ps1" %*
if errorlevel 1 pause

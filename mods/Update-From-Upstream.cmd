@echo off
rem Double-click: put this fork's mods on top of the newest official Sefirah (new branch, master untouched).
pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0update-from-upstream.ps1" %*
pause

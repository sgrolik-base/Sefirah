@echo off
rem Double-click: build the current branch and install it over the running Sefirah (keeps pairing/data).
pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0build-install.ps1" %*
pause

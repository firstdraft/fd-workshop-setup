@echo off
rem Fallback if Claude is not available: double-click to run the same setup steps in a window.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\setup-without-claude.ps1"

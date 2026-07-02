@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\productivity-audit.ps1" %*

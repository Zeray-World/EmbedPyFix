@echo off
setlocal
cd /d "%~dp0"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0fix_embedded_python.ps1" %*

echo.
echo Press any key to exit...
pause >nul
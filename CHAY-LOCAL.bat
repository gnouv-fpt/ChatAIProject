@echo off
chcp 65001 >nul
cd /d "%~dp0"
title Chay he thong Lo trinh

rem --- Tim PowerShell 7 (phai chay duoc that su, khong chi co trong PATH) ---
set "PWSH="
for /f "delims=" %%P in ('where pwsh 2^>nul') do (
  if not defined PWSH (
    "%%P" -NoProfile -Command "exit 0" >nul 2>nul && set "PWSH=%%P"
  )
)
if not defined PWSH if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" set "PWSH=%ProgramFiles%\PowerShell\7\pwsh.exe"
if not defined PWSH if exist "%LOCALAPPDATA%\Microsoft\powershell\pwsh.exe" set "PWSH=%LOCALAPPDATA%\Microsoft\powershell\pwsh.exe"

if not defined PWSH (
  echo Chua co PowerShell 7. Dang cai bang winget, hay doi...
  winget install --id Microsoft.PowerShell -e --accept-package-agreements --accept-source-agreements
  if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" set "PWSH=%ProgramFiles%\PowerShell\7\pwsh.exe"
)
if not defined PWSH (
  echo.
  echo Khong cai duoc PowerShell 7. Hay tai va cai tu https://aka.ms/powershell roi bam dup file nay lai.
  pause
  exit /b 1
)

echo Dung PowerShell: %PWSH%
"%PWSH%" -NoProfile -ExecutionPolicy Bypass -File "scripts\run-local.ps1" %*
echo.
if errorlevel 1 (echo === CO LOI, xem thong bao o tren ===) else (echo === HOAN TAT ===)
pause

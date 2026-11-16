@echo off
rem ===========================================================================
rem  Printer Sharing Toolkit - Launcher menu interaktif
rem
rem  Cukup klik dua kali file ini (atau jalankan "Menu.cmd" dari Command Prompt).
rem  File ini otomatis meminta hak Administrator, lalu membuka Menu.ps1
rem  sehingga pengguna hanya perlu memilih nomor menu.
rem ===========================================================================
setlocal EnableExtensions
title Printer Sharing Toolkit

rem Pindah ke folder tempat file ini berada (penting setelah elevasi UAC,
rem karena working directory berubah ke C:\Windows\System32).
pushd "%~dp0"

rem --- Cek apakah sudah berjalan sebagai Administrator ---
net session >nul 2>&1
if not errorlevel 1 goto :run

echo.
echo  ============================================================
echo    Printer Sharing Toolkit
echo  ============================================================
echo    Membutuhkan hak Administrator. Meminta izin UAC...
echo    (Jika muncul jendela "User Account Control", pilih Yes.)
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
popd
endlocal
exit /b

:run
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Menu.ps1"

echo.
echo  Tekan tombol apa saja untuk menutup jendela ini...
pause >nul
popd
endlocal

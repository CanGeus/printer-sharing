@echo off
setlocal EnableExtensions
chcp 437 >nul 2>&1

rem ===========================================================================
rem  KLIEN Windows 7 - connect printer lewat batch (tanpa PowerShell)
rem
rem  Pemakaian:
rem   02-Connect-Win7.cmd <HOST> <SHARE> [USER] [PASSWORD] [test] [repair]
rem
rem  Contoh:
rem   02-Connect-Win7.cmd PC-HOST EPSON-L120
rem   02-Connect-Win7.cmd PC-HOST EPSON-L120 printer P@ssw0rd
rem   02-Connect-Win7.cmd PC-HOST EPSON-L120 - - test
rem   02-Connect-Win7.cmd PC-HOST EPSON-L120 - - - repair
rem
rem  CATATAN: ini hanya untuk Windows 7 64-bit.
rem  Windows 7 32-bit butuh driver x86 lokal - pakai 02-Connect-Win7.ps1
rem  dengan -Mode LocalPort.
rem ===========================================================================

set "SERVER=%~1"
set "SHARE=%~2"
set "PUSER=%~3"
set "PPASS=%~4"
set "DOTEST=%~5"
set "DOREPAIR=%~6"

if "%SERVER%"=="" goto :usage
if "%SHARE%"=="" goto :usage

set "UNC=\\%SERVER%\%SHARE%"

echo.
echo === KLIEN Windows 7 -^> %UNC% ===
echo.

echo [1/4] Cek host %SERVER% ...
ping -n 1 -w 1500 %SERVER% >nul
if errorlevel 1 (
    echo       [WARN] Ping gagal. Host mungkin memblokir ICMP, lanjut saja.
) else (
    echo       [OK]   Host merespons
)

echo [2/4] Cek share ...
net view \\%SERVER% >nul 2>&1
if errorlevel 1 (
    echo       [WARN] Tidak bisa enumerate share ^(normal bila browsing SMB dibatasi^)
) else (
    echo       [OK]   Share host bisa dibaca
)

if not "%PUSER%"=="" if not "%PUSER%"=="-" if not "%PPASS%"=="" (
    net use \\%SERVER%\IPC$ /user:%PUSER% %PPASS% >nul 2>&1
    if errorlevel 1 (
        echo       [WARN] Autentikasi gagal. Periksa user/password.
    ) else (
        echo       [OK]   Autentikasi berhasil
    )
)

if /i "%DOREPAIR%"=="repair" (
    echo [3/4] Hapus koneksi lama ...
    rundll32 printui.dll,PrintUIEntry /dn /n "%UNC%"
    timeout /t 2 /nobreak >nul
    echo       [OK]   Koneksi lama dihapus
) else (
    echo [3/4] Lewati hapus koneksi lama
)

echo [4/4] Menambahkan printer ...
rundll32 printui.dll,PrintUIEntry /in /n "%UNC%"
timeout /t 3 /nobreak >nul

wmic printer get name 2>nul | findstr /i /c:"%SHARE%" >nul
if errorlevel 1 (
    echo.
    echo       [FAIL] Printer tidak terdaftar.
    echo.
    echo       Saran:
    echo         - Di HOST jalankan 01-Sharing-*.ps1 dengan -AllowLegacyWin7
    echo         - Pastikan SHARE sama persis dengan output script host
    echo         - Windows 7 32-bit: pakai 02-Connect-Win7.ps1 -Mode LocalPort
    echo         - Diagnosa: tools\03-Test-PrinterShare.ps1 -Server %SERVER% -ShareName %SHARE%
    echo.
    goto :end
)

echo       [OK]   Terpasang: %UNC%
rundll32 printui.dll,PrintUIEntry /y /n "%UNC%"
echo       [OK]   Dijadikan printer default

if /i "%DOTEST%"=="test" (
    echo       Mengirim test page ...
    rundll32 printui.dll,PrintUIEntry /k /n "%UNC%"
)

echo.
echo Selesai.
echo.
goto :end

:usage
echo.
echo Pemakaian:
echo   02-Connect-Win7.cmd ^<HOST^> ^<SHARE^> [USER] [PASSWORD] [test] [repair]
echo.
echo Contoh:
echo   02-Connect-Win7.cmd PC-HOST EPSON-L120
echo   02-Connect-Win7.cmd PC-HOST EPSON-L120 printer P@ssw0rd test
echo.
echo Windows 7 32-bit: jalankan 02-Connect-Win7.ps1 -Mode LocalPort
echo.

:end
endlocal

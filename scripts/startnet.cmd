@echo off
rem ============================================================
rem  WDS Deployment Kit - WinPE startnet.cmd
rem  Basqa sirket: 172.16.50.10 (server IP), Deploy (share), DEPLOYSRV\svc_imaging ve SIFRE_BURAYA deyisir
rem  Yer: boot.wim icinde  Windows\System32\startnet.cmd
rem  WinPE acilan kimi AVTOMATIK isleyir
rem  DIQQET: SIFRE_BURAYA -> svc_imaging-un sifresi ile evez et
rem ============================================================

wpeinit
echo.
echo Sebeke gozlenilir...
wpeutil WaitForNetwork >nul 2>&1

rem --- Server qovluguna qosul (10 cehd) ---
set /a n=0
:retry
net use Z: \\172.16.50.10\Deploy /user:DEPLOYSRV\svc_imaging SIFRE_BURAYA >nul 2>&1
if not errorlevel 1 goto connected
set /a n+=1
if %n% geq 10 goto fail
echo Servere qosulmaq olmadi, yeniden cehd %n%/10 ...
ping -n 4 127.0.0.1 >nul
goto retry

:connected
powershell.exe -NoProfile -ExecutionPolicy Bypass -File Z:\Scripts\Deploy.ps1
goto :eof

:fail
echo.
echo XETA: \\172.16.50.10\Deploy qovluguna qosulmaq olmadi.
echo Kabeli, WDS serverini ve svc_imaging sifresini yoxlayin.
echo.

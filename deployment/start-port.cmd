@echo off
cd /d C:\ProgramData\Port\app
echo [%date% %time%] Starting Port host>>C:\ProgramData\Port\host.log
WindowPort.Host.exe --urls http://0.0.0.0:47821 >>C:\ProgramData\Port\host.log 2>&1

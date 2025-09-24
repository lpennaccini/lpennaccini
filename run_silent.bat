@echo off
REM Script batch per esecuzione completamente nascosta
REM Questo file può essere distribuito via GPO o copiato sui client

REM Parametri di configurazione
set NETWORK_SHARE=\\server\shared\client_data
set SCRIPT_NAME=collect_client_info_silent.ps1
set LOG_PATH=%TEMP%\MonitorIT_Collection.log

REM Crea directory nascosta se non esiste
if not exist "%WINDIR%\Temp\.monitorit" (
    mkdir "%WINDIR%\Temp\.monitorit"
    attrib +h "%WINDIR%\Temp\.monitorit"
)

REM Esegui PowerShell in modalità completamente nascosta
powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -NoProfile -Command "& '%~dp0%SCRIPT_NAME%' -DatabasePath '%NETWORK_SHARE%' -OutputFormat 'CSV' -LogPath '%LOG_PATH%'"

REM Exit code per monitoraggio
exit /b %errorlevel%
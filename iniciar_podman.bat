@echo off
title Iniciar Podman y Servicios CDI - ASIC Guanipa
echo ==============================================
echo   Iniciando Stack CDI con Podman
echo ==============================================

echo [1/2] Levantando contenedores (PostgreSQL y API Server)...
wsl -d podman-machine-default -u root -- podman start proyecto-uptjaa-cdi-db-postgres-1 proyecto-uptjaa-cdi-api-server-1 >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    wsl -d podman-machine-default -u root -- podman start db-postgres api-server >nul 2>&1
)

echo.
echo ==============================================
echo   ¡Stack CDI en Podman Funcionando!
echo ==============================================
for /f "tokens=*" %%i in ('wsl -d podman-machine-default -u root -- ip -4 addr show eth0 ^| findstr "inet"') do (
    echo   - Red WSL / Contenedores: %%i
)
echo   - URL de la Aplicacion:  http://172.30.172.154:3000
echo   - Base de Datos (PG):    172.30.172.154:5434
echo ==============================================
echo.
pause

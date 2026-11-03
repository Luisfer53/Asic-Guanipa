@echo off
title Iniciar Podman y Servicios CDI - ASIC Guanipa
echo ==============================================
echo   Iniciando Stack CDI con Podman
echo ==============================================

echo [1/3] Verificando maquina Podman...
podman machine start >nul 2>&1

echo [2/3] Levantando contenedores (PostgreSQL y API Server)...
podman start proyecto-uptjaa-cdi-db-postgres-1 proyecto-uptjaa-cdi-api-server-1 >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    wsl -d podman-machine-default -u root -- podman start proyecto-uptjaa-cdi-db-postgres-1 proyecto-uptjaa-cdi-api-server-1 >nul 2>&1
)

echo [3/3] Configurando red y enlaces de acceso...
set "WSL_IP=localhost"
for /f "tokens=3" %%a in ('wsl -d podman-machine-default -u root -- ip -4 -br addr show eth0 2^>nul') do (
    for /f "delims=/" %%b in ("%%a") do set "WSL_IP=%%b"
)

:: Redireccionar puertos hacia la maquina de Podman para habilitar localhost
netsh interface portproxy delete v4tov4 listenport=3000 listenaddress=0.0.0.0 >nul 2>&1
netsh interface portproxy add v4tov4 listenport=3000 listenaddress=0.0.0.0 connectport=3000 connectaddress=%WSL_IP% >nul 2>&1
netsh interface portproxy delete v4tov4 listenport=5434 listenaddress=0.0.0.0 >nul 2>&1
netsh interface portproxy add v4tov4 listenport=5434 listenaddress=0.0.0.0 connectport=5434 connectaddress=%WSL_IP% >nul 2>&1

echo.
echo ==============================================
echo   Stack CDI en Podman Funcionando Exitosamente
echo ==============================================
echo   - Acceso Localhost:      http://localhost:3000
echo   - Acceso IP WSL:         http://%WSL_IP%:3000
echo   - Base de Datos (PG):    Puerto 5434
echo ==============================================
echo.
pause
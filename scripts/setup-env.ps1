# =============================================================================
# setup-env.ps1 - Configuracion completa del entorno del proyecto CDI
# Ejecutar: powershell -ExecutionPolicy Bypass -File .\scripts\setup-env.ps1
# =============================================================================

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  CDI - Configuracion del Entorno" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

$ErrorActionPreference = "Continue"
$projectRoot = "d:\Farmapro\Proyecto-Uptjaa-CDI"

function Check-Tool($name, $cmd) {
    $result = & cmd /c "$cmd 2>&1"
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] $name : $($result | Select-Object -First 1)" -ForegroundColor Green
    } else {
        Write-Host "  [NO] $name : NO encontrado" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "[1/6] Herramientas base:" -ForegroundColor Yellow
Check-Tool "Node.js" "node --version"
Check-Tool "npm"     "npm --version"
Check-Tool "Git"     "git --version"
Check-Tool "Docker"  "docker --version"

Write-Host ""
Write-Host "[2/6] Dependencias npm..." -ForegroundColor Yellow
Set-Location $projectRoot
npm install 2>&1 | Select-Object -Last 3

Write-Host ""
Write-Host "[3/6] Verificando .env..." -ForegroundColor Yellow
if (-not (Test-Path "$projectRoot\.env")) {
    Copy-Item "$projectRoot\.env.example" "$projectRoot\.env"
    Write-Host "  .env creado desde .env.example" -ForegroundColor Yellow
} else {
    Write-Host "  .env ya existe" -ForegroundColor Green
}

Write-Host ""
Write-Host "[4/6] Levantando Docker Compose..." -ForegroundColor Yellow
cmd /c "docker compose -f d:\Farmapro\Proyecto-Uptjaa-CDI\docker-compose.yml up -d --build 2>&1"
Write-Host "  Resultado: $LASTEXITCODE"

Write-Host ""
Write-Host "[5/6] Esperando PostgreSQL..." -ForegroundColor Yellow
Start-Sleep -Seconds 15
cmd /c "docker compose -f d:\Farmapro\Proyecto-Uptjaa-CDI\docker-compose.yml exec db-postgres pg_isready -U postgres 2>&1"

Write-Host ""
Write-Host "[6/6] Migraciones Sequelize..." -ForegroundColor Yellow
Set-Location $projectRoot
cmd /c "npx sequelize-cli db:migrate 2>&1"

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Backend: http://localhost:3000"
Write-Host "Swagger: http://localhost:3000/api-docs"
Write-Host "PG:      localhost:5434"
Write-Host "=========================================" -ForegroundColor Cyan

#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════
#  📱 ASIC GUANIPA — Deploy APK + Cloudflare Tunnel
#
#  Hace TODO automáticamente:
#    1. Compila la APK de Flutter
#    2. Copia la APK a /downloads para descarga vía túnel
#    3. Levanta el backend Node.js
#    4. Inicia el túnel Cloudflare
#    5. Espera la URL pública
#    6. Actualiza .env con la nueva URL del backend
#    7. Actualiza la URL de la APK y del API en el script/archivos
#    8. Muestra el link de descarga del APK
#
#  Uso:  ./deploy-apk.sh
#  Para detener todo:  Ctrl+C
# ═══════════════════════════════════════════════════════════════════════

set -e
set -o pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
FRONTEND_DIR="$DIR/frontend"
API_SERVICE="$FRONTEND_DIR/lib/services/api_service.dart"
APK_OUTPUT="$FRONTEND_DIR/build/app/outputs/flutter-apk/app-release.apk"
WEB_OUTPUT="$FRONTEND_DIR/build/web/index.html"
DOWNLOADS_DIR="$DIR/downloads"
APK_URL_FILE="$DOWNLOADS_DIR/latest-apk-url.txt"
CLOUDFLARED="$DIR/cloudflared"
PORT=${PORT:-3000}
TUNNEL_LOG="$DIR/tunnel.log"
BACKEND_LOG="$DIR/backend.log"
FORCE_BUILD=false

if [ "${DEBUG_DEPLOY_APK:-false}" = "true" ]; then
    echo "DEBUG: PWD=$(pwd)"
    echo "DEBUG: SHELL=${SHELL:-unknown}"
    echo "DEBUG: PATH=$PATH"
    for cmd in sh node flutter python3 "$CLOUDFLARED"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            echo "DEBUG: found $cmd -> $(command -v "$cmd")"
        else
            echo "DEBUG: missing $cmd"
        fi
    done
    echo "DEBUG: deploy-apk.sh exists? $(test -f "$DIR/deploy-apk.sh" && echo yes || echo no)"
    echo "DEBUG: deploy-apk.sh executable? $(test -x "$DIR/deploy-apk.sh" && echo yes || echo no)"
fi

for arg in "$@"; do
    case "$arg" in
        --force-build)
            FORCE_BUILD=true
            ;;
        --help|-h)
            echo "Uso: ./deploy-apk.sh [--force-build]"
            exit 0
            ;;
    esac
done

# PIDs para limpieza
BACKEND_PID=""
TUNNEL_PID=""

# ─── Colores ───────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ─── Limpieza al salir ────────────────────────────────────────────────
cleanup() {
    echo ""
    echo -e "${YELLOW}⚠️  Deteniendo servicios...${NC}"
    [ -n "$BACKEND_PID" ] && kill "$BACKEND_PID" 2>/dev/null && echo "   ✅ Backend detenido (PID $BACKEND_PID)"
    [ -n "$TUNNEL_PID" ] && kill "$TUNNEL_PID" 2>/dev/null && echo "   ✅ Túnel detenido (PID $TUNNEL_PID)"
    pkill -f "cloudflared tunnel" 2>/dev/null || true
    echo -e "${GREEN}👋 ¡Hasta la próxima!${NC}"
    exit 0
}
trap cleanup SIGINT SIGTERM EXIT

# ─── Banner ────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     ${BOLD}📱 ASIC GUANIPA — Deploy APK Automático${NC}${CYAN}            ║${NC}"
echo -e "${CYAN}║     Backend + Túnel + APK + URL Pública                ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# ─── Verificaciones ───────────────────────────────────────────────────
echo -e "${BOLD}🔍 Verificando requisitos...${NC}"

if ! command -v node &>/dev/null; then
    echo -e "${RED}❌ Node.js no encontrado. Instálalo primero.${NC}"
    exit 1
fi
echo "   ✅ Node.js $(node --version)"

if ! command -v flutter &>/dev/null; then
    echo -e "${RED}❌ Flutter no encontrado. Instálalo primero.${NC}"
    exit 1
fi
echo "   ✅ Flutter $(flutter --version 2>&1 | head -1 | awk '{print $2}')"

if ! command -v python3 &>/dev/null; then
    echo -e "${RED}❌ Python3 no encontrado. Instálalo primero.${NC}"
    exit 1
fi
echo "   ✅ Python3 $(python3 --version 2>&1 | head -1)"

if [ ! -x "$CLOUDFLARED" ]; then
    echo -e "${RED}❌ cloudflared no encontrado en $CLOUDFLARED${NC}"
    exit 1
fi
echo "   ✅ cloudflared encontrado"

if [ ! -f "$API_SERVICE" ]; then
    echo -e "${RED}❌ api_service.dart no encontrado en $API_SERVICE${NC}"
    exit 1
fi
echo "   ✅ api_service.dart encontrado"
echo ""

# ═══════════════════════════════════════════════════════════════════════
# PASO 1: Compilar APK y frontend web
# ═══════════════════════════════════════════════════════════════════════
echo -e "${BOLD}[1/4] 🔨 Preparando APK y frontend web...${NC}"
cd "$FRONTEND_DIR"

SHOULD_BUILD=true
if [ "$FORCE_BUILD" = false ] && [ -f "$APK_OUTPUT" ]; then
    if ! find "$FRONTEND_DIR" -path "$FRONTEND_DIR/build" -prune -o -type f \( -name '*.dart' -o -name '*.yaml' -o -name '*.yml' -o -name '*.kt' -o -name '*.gradle' -o -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.json' \) -newer "$APK_OUTPUT" 2>/dev/null | grep -q .; then
        SHOULD_BUILD=false
    fi
fi

if [ "$SHOULD_BUILD" = false ]; then
    echo -e "   ${YELLOW}⚡ APK ya existe y no ha cambiado desde la última compilación. Reutilizando...${NC}"
else
    flutter pub get > /dev/null 2>&1
    echo "   ✅ Dependencias listas"

    echo "   ⏳ Compilando APK..."
    flutter build apk --release

    if [ ! -f "$APK_OUTPUT" ]; then
        echo -e "${RED}❌ Error: No se generó el APK. Revisa los errores arriba.${NC}"
        exit 1
    fi

    APK_SIZE=$(du -h "$APK_OUTPUT" | awk '{print $1}')
    echo -e "   ${GREEN}✅ APK compilada exitosamente ($APK_SIZE)${NC}"
fi

echo "   ⏳ Compilando frontend web..."
if [ "$FORCE_BUILD" = false ] && [ -f "$WEB_OUTPUT" ]; then
    if ! find "$FRONTEND_DIR/lib" "$FRONTEND_DIR/web" "$FRONTEND_DIR/pubspec.yaml" "$FRONTEND_DIR/pubspec.lock" -type f -newer "$WEB_OUTPUT" 2>/dev/null | grep -q .; then
        echo -e "   ${YELLOW}⚡ Frontend web ya existe y no ha cambiado. Reutilizando...${NC}"
    else
        flutter build web --release --base-href /app/
    fi
else
    flutter build web --release --base-href /app/
fi

if [ ! -f "$WEB_OUTPUT" ]; then
    echo -e "${RED}❌ Error: No se generó el frontend web. Revisa los errores arriba.${NC}"
    exit 1
fi

echo -e "   ${GREEN}✅ Frontend web listo en $FRONTEND_DIR/build/web${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════════════
# PASO 2: Preparar carpeta de descargas
# ═══════════════════════════════════════════════════════════════════════
echo -e "${BOLD}[2/4] 📦 Preparando carpeta de descargas...${NC}"
mkdir -p "$DOWNLOADS_DIR"
echo -e "   ${GREEN}✅ Carpeta $DOWNLOADS_DIR lista${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════════════
# PASO 3: Levantar backend y túnel Cloudflare
# ═══════════════════════════════════════════════════════════════════════
echo -e "${BOLD}[3/4] 🔧 Levantando backend en puerto $PORT...${NC}"
cd "$DIR"
node server.js > "$BACKEND_LOG" 2>&1 &
BACKEND_PID=$!
sleep 3

if ! kill -0 "$BACKEND_PID" 2>/dev/null; then
    echo -e "${RED}❌ El backend no pudo arrancar. Revisa $BACKEND_LOG.${NC}"
    exit 1
fi
echo -e "   ${GREEN}✅ Backend listo (PID $BACKEND_PID) → http://localhost:$PORT${NC}"
echo ""

echo -e "${BOLD}[4/4] 🌐 Iniciando túnel Cloudflare...${NC}"
echo "   ⏳ Esperando URL pública (puede tardar 10-20 segundos)..."

"$CLOUDFLARED" tunnel --no-autoupdate --url "http://localhost:$PORT" > "$TUNNEL_LOG" 2>&1 &
TUNNEL_PID=$!

TUNNEL_URL=""
WAIT_COUNT=0
MAX_WAIT=60

while [ -z "$TUNNEL_URL" ] && [ $WAIT_COUNT -lt $MAX_WAIT ]; do
    sleep 1
    WAIT_COUNT=$((WAIT_COUNT + 1))
    TUNNEL_URL=$(grep -oE "https://[a-z0-9-]+\.trycloudflare\.com" "$TUNNEL_LOG" 2>/dev/null | head -1 || true)
    if [ $((WAIT_COUNT % 5)) -eq 0 ] && [ -z "$TUNNEL_URL" ]; then
        echo "   ⏳ Esperando... ($WAIT_COUNT segundos)"
    fi
done

if [ -z "$TUNNEL_URL" ]; then
    echo -e "${RED}❌ No se pudo obtener la URL del túnel después de $MAX_WAIT segundos.${NC}"
    echo "   Revisa: cat $TUNNEL_LOG"
    exit 1
fi

echo -e "   ${GREEN}✅ Túnel activo → ${BOLD}$TUNNEL_URL${NC}"
echo ""

# Actualizar .env
if [ -f "$DIR/.env" ]; then
    if grep -q '^SERVER_URL=' "$DIR/.env"; then
        sed -i "s|^SERVER_URL=.*|SERVER_URL=$TUNNEL_URL/api|" "$DIR/.env"
    else
        echo "SERVER_URL=$TUNNEL_URL/api" >> "$DIR/.env"
    fi

    if grep -q '^APK_DOWNLOAD_URL=' "$DIR/.env"; then
        sed -i "s|^APK_DOWNLOAD_URL=.*|APK_DOWNLOAD_URL=$TUNNEL_URL/downloads/asic-guanipa.apk|" "$DIR/.env"
    else
        echo "APK_DOWNLOAD_URL=$TUNNEL_URL/downloads/asic-guanipa.apk" >> "$DIR/.env"
    fi
else
    echo "SERVER_URL=$TUNNEL_URL/api" > "$DIR/.env"
    echo "APK_DOWNLOAD_URL=$TUNNEL_URL/downloads/asic-guanipa.apk" >> "$DIR/.env"
fi

echo "   ✅ .env actualizado con la URL pública"

# Actualizar api_service.dart con la nueva URL del API
python3 - "$API_SERVICE" "$TUNNEL_URL/api" <<'PY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
url = sys.argv[2]
text = path.read_text()
pattern = re.compile(
    r"static const String _tunnelUrl = String\.fromEnvironment\(\s*'SERVER_URL',\s*defaultValue:\s*'[^']*'\s*\);",
    re.DOTALL,
)
replacement = f"static const String _tunnelUrl = String.fromEnvironment('SERVER_URL', defaultValue: '{url}');"
new_text, count = pattern.subn(replacement, text, count=1)
if count == 0:
    raise SystemExit(1)
path.write_text(new_text)
PY

if grep -q "$TUNNEL_URL/api" "$API_SERVICE"; then
    echo -e "   ${GREEN}✅ api_service.dart actualizado con: $TUNNEL_URL/api${NC}"
else
    echo -e "${YELLOW}⚠️  No se pudo actualizar automáticamente. Revisa api_service.dart manualmente.${NC}"
fi

echo -e "${BOLD}[3/4] 🔨 Recompilando APK y web con la URL pública...${NC}"
cd "$FRONTEND_DIR"
flutter build apk --release --dart-define=SERVER_URL="$TUNNEL_URL/api" > /dev/null 2>&1
flutter build web --release --base-href /app/ --dart-define=SERVER_URL="$TUNNEL_URL/api" > /dev/null 2>&1

echo -e "   ${GREEN}✅ APK y web recompiladas con la URL pública del túnel${NC}"
echo ""

# Guardar la URL del APK en un archivo accesible desde la carpeta downloads
printf '%s\n' "$TUNNEL_URL/downloads/asic-guanipa.apk" > "$APK_URL_FILE"
echo "   ✅ URL del APK guardada en $APK_URL_FILE"
echo ""

# ──────────────── Resumen final ────────────────────────────────────────
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                                                              ║${NC}"
echo -e "${CYAN}║   ${GREEN}${BOLD}✅  ¡TODO LISTO! ASIC GUANIPA EN LÍNEA${NC}${CYAN}                     ║${NC}"
echo -e "${CYAN}║                                                              ║${NC}"
printf "${CYAN}║${NC}   🌐  Portal Web:    ${BOLD}%-39s${NC}${CYAN}║${NC}\n" "$TUNNEL_URL"
printf "${CYAN}║${NC}   📡  API Backend:   ${BOLD}%-39s${NC}${CYAN}║${NC}\n" "$TUNNEL_URL/api"
printf "${CYAN}║${NC}   📱  Descargar APK: ${BOLD}%-39s${NC}${CYAN}║${NC}\n" "$TUNNEL_URL/downloads/asic-guanipa.apk"
echo -e "${CYAN}║                                                              ║${NC}"
echo -e "${CYAN}║   ${YELLOW}📲 Abre este link desde tu teléfono para${NC}${CYAN}                  ║${NC}"
echo -e "${CYAN}║   ${YELLOW}   descargar e instalar el APK${NC}${CYAN}                            ║${NC}"
echo -e "${CYAN}║                                                              ║${NC}"
echo -e "${CYAN}║   ${RED}Presiona Ctrl+C para detener todo${NC}${CYAN}                         ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}💡 El túnel sigue activo. Mientras veas este mensaje, tu teléfono puede acceder.${NC}"
echo ""

tail -f "$TUNNEL_LOG" 2>/dev/null || wait "$TUNNEL_PID"

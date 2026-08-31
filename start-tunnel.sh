./start-tunnel.sh#!/bin/bash

# ═══════════════════════════════════════════════════════════════
#  🌐 ASIC GUANIPA — Cloudflare Quick Tunnel
#  Accesible desde cualquier IP sin configuración adicional
# ═══════════════════════════════════════════════════════════════

CLOUDFLARED="$(dirname "$0")/cloudflared"
PORT=${PORT:-3000}
DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="$DIR/tunnel.log"
FRONTEND_DIR="$DIR/frontend"
APK_OUTPUT="$FRONTEND_DIR/build/app/outputs/flutter-apk/app-release.apk"
DOWNLOADS_DIR="$DIR/downloads"
APK_FILE="$DOWNLOADS_DIR/asic-guanipa.apk"
LATEST_URL_FILE="$DOWNLOADS_DIR/latest-apk-url.txt"
BACKEND_PID=""
FLUTTER_AVAILABLE=0

# Detectar si Flutter está disponible en el sistema
if command -v flutter >/dev/null 2>&1; then
    FLUTTER_AVAILABLE=1
fi

# Por defecto recompilar APK automáticamente si Flutter está disponible
if [ "$FLUTTER_AVAILABLE" -eq 1 ]; then
    BUILD_APK=true
else
    BUILD_APK=false
fi

for arg in "$@"; do
    case "$arg" in
        --build-apk|-b)
            BUILD_APK=true
            ;;
        --help|-h)
            echo "Uso: ./start-tunnel.sh [--build-apk|-b]"
            exit 0
            ;;
    esac
done
echo ""
echo "═══════════════════════════════════════════════════════"
echo "🚀 Iniciando Cloudflare Tunnel para ASIC GUANIPA..."
echo "   Servidor backend: http://localhost:$PORT"
echo "═══════════════════════════════════════════════════════"
echo ""

echo "🔎 Verificando base de datos PostgreSQL..."
if ! bash -c "</dev/tcp/127.0.0.1/5436" >/dev/null 2>&1; then
    echo "   ⚠️ Base de datos no responde en el puerto 5436. Levantando contenedor Docker..."
    if command -v docker >/dev/null 2>&1; then
        docker compose up -d db-postgres >/dev/null 2>&1 || true
        sleep 2
    fi
fi
if bash -c "</dev/tcp/127.0.0.1/5436" >/dev/null 2>&1; then
    echo "   ✅ Base de datos activa en puerto 5436"
else
    echo "   ⚠️ Advertencia: La base de datos en puerto 5436 no responde. Revisa docker compose."
fi

echo ""
echo "🔎 Verificando si el backend ya está activo..."
if ! bash -c "</dev/tcp/localhost/$PORT" >/dev/null 2>&1; then
    echo "   ⚠️  Backend no está activo. Iniciando servidor Node.js..."
    cd "$DIR"
    node server.js > "$DIR/backend.log" 2>&1 &
    BACKEND_PID=$!
    sleep 3
    if ! kill -0 "$BACKEND_PID" 2>/dev/null; then
        echo "❌ No se pudo iniciar el backend. Revisa $DIR/backend.log"
        exit 1
    fi
    echo "   ✅ Backend iniciado en http://localhost:$PORT (PID $BACKEND_PID)"
else
    echo "   ✅ Backend ya está activo en http://localhost:$PORT"
fi

echo ""
echo "⏳ Generando URL pública... (puede tardar unos segundos)"
echo ""

# Lanzar cloudflared en modo quick-tunnel (no requiere cuenta)
# El túnel expone el puerto local al mundo mediante Cloudflare
"$CLOUDFLARED" tunnel --no-autoupdate --url "http://localhost:$PORT" 2>&1 | tee "$LOG_FILE" | while IFS= read -r line; do
    echo "$line"
    # Detectar la URL pública y mostrarla de forma destacada
    if echo "$line" | grep -qE "https://[a-z0-9-]+\.trycloudflare\.com"; then
        URL=$(echo "$line" | grep -oE "https://[a-z0-9-]+\.trycloudflare\.com")
        ENV_FILE="$(dirname "$0")/.env"
        DOWNLOAD_URL="$URL/downloads/asic-guanipa.apk"
        API_SERVICE="$FRONTEND_DIR/lib/services/api_service.dart"

        echo ""
        echo "╔══════════════════════════════════════════════════════════════════╗"
        echo "║  ✅  TÚNEL ACTIVO — ACCESIBLE DESDE CUALQUIER RED               ║"
        echo "║                                                                  ║"
        echo "║  🌐  Web App (Navegador):  $URL                                  ║"
        echo "║  📡  API Backend (Móvil):  $URL/api                              ║"
        echo "║  📥  Descargar APK:        $DOWNLOAD_URL                         ║"
        echo "║                                                                  ║"
        echo "║  📱  ¿YA TIENES LA APK INSTALADA EN TU TELÉFONO?                 ║"
        echo "║     ¡No necesitas volver a compilar ni descargar!                ║"
        echo "║     Abre la app -> Toca '⚙️ Configurar Servidor' y pega:        ║"
        echo "║     $URL/api                                                     ║"
        echo "║                                                                  ║"
        echo "║  ⚠️  MANTÉN ESTA TERMINAL ABIERA PARA QUE EL TÚNEL FUNCIONE.    ║"
        echo "║     Si cierras esta terminal o ejecutas Ctrl+C, el túnel        ║"
        echo "║     se apagará y Cloudflare mostrará Error 1033.                ║"
        echo "╚══════════════════════════════════════════════════════════════════╝"
        echo ""

        # Actualizar el .env con la URL del túnel
        if grep -q '^SERVER_URL=' "$ENV_FILE"; then
            sed -i "s|^SERVER_URL=.*|SERVER_URL=$URL/api|" "$ENV_FILE"
        else
            echo "SERVER_URL=$URL/api" >> "$ENV_FILE"
        fi

        if grep -q '^APK_DOWNLOAD_URL=' "$ENV_FILE"; then
            sed -i "s|^APK_DOWNLOAD_URL=.*|APK_DOWNLOAD_URL=$DOWNLOAD_URL|" "$ENV_FILE"
        else
            echo "APK_DOWNLOAD_URL=$DOWNLOAD_URL" >> "$ENV_FILE"
        fi

        # Actualizar la URL por defecto en api_service.dart
        if [ -f "$API_SERVICE" ] && command -v python3 >/dev/null 2>&1; then
            python3 - "$API_SERVICE" "$URL/api" <<'PY'
import pathlib, re, sys
path = pathlib.Path(sys.argv[1])
url = sys.argv[2]
text = path.read_text()
pattern = re.compile(
    r"static const String _tunnelUrl = String\.fromEnvironment\(\s*'SERVER_URL',\s*defaultValue:\s*'[^']*'\s*\);",
    re.DOTALL,
)
replacement = f"static const String _tunnelUrl = String.fromEnvironment('SERVER_URL', defaultValue: '{url}');"
new_text, count = pattern.subn(replacement, text, count=1)
if count > 0:
    path.write_text(new_text)
PY
            echo "✅  api_service.dart actualizado con la nueva URL por defecto: $URL/api"
        fi

        mkdir -p "$DOWNLOADS_DIR"
        printf '%s\n' "$DOWNLOAD_URL" > "$LATEST_URL_FILE"

        if [ "$BUILD_APK" = true ]; then
            if [ "$FLUTTER_AVAILABLE" -eq 1 ]; then
                echo "⏳ Recompilando APK con la nueva URL (--dart-define=SERVER_URL=$URL/api)..."
                (cd "$FRONTEND_DIR" && flutter build apk --release --dart-define=SERVER_URL="$URL/api" >/dev/null 2>&1)
                if [ -f "$APK_OUTPUT" ]; then
                    cp "$APK_OUTPUT" "$APK_FILE"
                    echo "✅  APK compilada y guardada en $APK_FILE"
                fi
            else
                echo "⚠️  Flutter no disponible para compilar APK."
            fi
        elif [ "$FLUTTER_AVAILABLE" -eq 1 ] && [ -f "$APK_OUTPUT" ]; then
            cp "$APK_OUTPUT" "$APK_FILE"
            echo "✅  APK existente copiada a $APK_FILE"
        fi

        echo "✅  SERVER_URL actualizado en .env: $URL/api"
        echo "✅  APK_DOWNLOAD_URL actualizado en .env: $DOWNLOAD_URL"
        echo "✅  Link de APK guardado en $LATEST_URL_FILE"
        echo ""
    fi
done

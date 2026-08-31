#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════
#  🚀 ASIC GUANIPA — Inicio completo: Backend + Cloudflare Tunnel
#  Levanta el servidor Node.js y expone al mundo con Cloudflare
# ═══════════════════════════════════════════════════════════════════════

DIR="$(cd "$(dirname "$0")" && pwd)"
PORT=${PORT:-3000}

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║         🏥  ASIC GUANIPA — Sistema de Salud             ║"
echo "║              Inicio de Servicios Completos               ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# 1) Iniciar el backend en segundo plano
echo "🔧 Iniciando servidor backend en puerto $PORT..."
cd "$DIR"
node server.js &
BACKEND_PID=$!
echo "   PID del backend: $BACKEND_PID"

# Esperar a que el backend esté listo
sleep 2
echo "   ✅ Backend listo en http://localhost:$PORT"
echo ""

# 2) Iniciar el túnel Cloudflare
echo "🌐 Iniciando túnel Cloudflare..."
"$DIR/cloudflared" tunnel --no-autoupdate --url "http://localhost:$PORT" 2>&1 | while IFS= read -r line; do
    echo "$line"
    if echo "$line" | grep -qE "https://[a-z0-9-]+\.trycloudflare\.com"; then
        URL=$(echo "$line" | grep -oE "https://[a-z0-9-]+\.trycloudflare\.com")
        echo ""
        echo "╔══════════════════════════════════════════════════════════╗"
        echo "║  ✅  SISTEMA ASIC GUANIPA — EN LÍNEA                     ║"
        echo "║                                                          ║"
        printf "║  🌐  Portal Web:  %-39s║\n" "$URL"
        printf "║  📡  API:         %-39s║\n" "$URL/api"
        printf "║  📥  APK Android: %-39s║\n" "$URL/downloads/asic-guanipa.apk"
        printf "║  📚  Docs Swagger:%-39s║\n" "$URL/api-docs"
        echo "║                                                          ║"
        echo "║  Accesible desde CUALQUIER IP en el mundo 🌍            ║"
        echo "╚══════════════════════════════════════════════════════════╝"
        echo ""
        # Actualizar .env con la URL del túnel
        sed -i "s|^SERVER_URL=.*|SERVER_URL=$URL/api|" "$DIR/.env"
        echo "✅  .env actualizado: SERVER_URL=$URL/api"
    fi
done

# Si el túnel se cierra, matar el backend
echo "⚠️  Túnel cerrado. Deteniendo backend..."
kill $BACKEND_PID 2>/dev/null

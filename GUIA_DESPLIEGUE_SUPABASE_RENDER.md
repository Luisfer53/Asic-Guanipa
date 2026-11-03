# 🚀 Guía Oficial de Despliegue: Supabase & Render + Android APK
### Sistema Epidemiológico y Asistencial — CDI Dr. Pedro Urbina / ASIC San José de Guanipa

Esta guía detalla los pasos exactos para poner en producción el sistema completo utilizando la arquitectura moderna en la nube:
* **Base de Datos:** [Supabase](https://supabase.com/) (PostgreSQL administrado con réplica y SSL).
* **Backend y Frontend Web:** [Render](https://render.com/) (API REST Express + Flutter Web compilado).
* **Aplicación Móvil:** Android APK versión `1.1.0+2` (con soporte para servidor dinámico en la nube y Constancia Médica con QR).

---

## 1. Configuración de la Base de Datos en Supabase

### Paso 1.1: Crear el Proyecto
1. Ingresa a [supabase.com](https://supabase.com/) e inicia sesión (o regístrate con GitHub).
2. Haz clic en **"New Project"**.
3. Completa los campos:
   * **Name:** `cdi-pedro-urbina` (o el nombre de tu preferencia).
   * **Database Password:** Define una contraseña segura y **anótala**, la necesitarás en Render.
   * **Region:** Selecciona `East US (North Virginia)` u `Oregon (US West)` (preferiblemente la misma región que elijas en Render).
   * **Pricing Plan:** Free tier.
4. Haz clic en **"Create new project"** y espera ~2 minutos mientras se aprovisiona.

### Paso 1.2: Obtener la Cadena de Conexión (`DATABASE_URL`)
1. En el panel de Supabase, ve al menú lateral: **Project Settings** (ícono de engranaje abajo a la izquierda) > **Database**.
2. Desplázate hasta la sección **Connection string**.
3. Selecciona la pestaña **URI** o **Connection pooling**:
   * Si usas el **Pooler** (Recomendado para servidores serverless/Render):
     ```text
     postgresql://postgres.[PROJECT_REF]:[TU_CONTRASEÑA]@aws-0-[REGION].pooler.supabase.com:6543/postgres?sslmode=require
     ```
   * Si usas conexión **Directa**:
     ```text
     postgresql://postgres:[TU_CONTRASEÑA]@db.[PROJECT_REF].supabase.co:5432/postgres?sslmode=require
     ```
4. Reemplaza `[TU_CONTRASEÑA]` con la contraseña real que definiste en el paso 1.1.

---

## 2. Despliegue del Backend y Web en Render

El proyecto ya incluye el archivo `render.yaml` para despliegue automatizado con Blueprint, o puedes configurarlo manualmente.

### Método A: Despliegue Automático (Blueprint `render.yaml`)
1. Sube tus cambios a tu repositorio de GitHub:
   ```bash
   git add .
   git commit -m "feat: preparado para supabase, render y actualizacion apk"
   git push origin main
   ```
2. Ve a [dashboard.render.com](https://dashboard.render.com/) y haz clic en **New +** > **Blueprint**.
3. Conecta tu repositorio de GitHub.
4. Render detectará automáticamente el archivo `render.yaml`.
5. En la variable `DATABASE_URL`, pega la cadena de conexión de Supabase obtenida en el Paso 1.2.
6. Haz clic en **Apply**.

### Método B: Despliegue Manual (Web Service)
Si prefieres crearlo manualmente:
1. En Render Dashboard, haz clic en **New +** > **Web Service**.
2. Conecta tu repositorio de GitHub.
3. Configura los siguientes parámetros:
   * **Name:** `cdi-pedro-urbina-backend`
   * **Region:** `Oregon (US West)`
   * **Branch:** `main`
   * **Runtime:** `Node`
   * **Build Command:** `npm run render-build`
   * **Start Command:** `npm start`
   * **Plan:** `Free`
4. En la sección **Environment Variables**, añade:

| Variable | Valor | Descripción |
|---|---|---|
| `NODE_ENV` | `production` | Modo de producción optimizado |
| `DATABASE_URL` | `postgresql://...` | URI de Supabase con `?sslmode=require` |
| `DB_SSL` | `true` | Conexión SSL obligatoria para Supabase |
| `JWT_SECRET` | *(Generar valor aleatorio o escribir clave secreta)* | Clave para tokens de sesión |
| `JWT_EXPIRE` | `24h` | Duración del token de sesión |
| `ENCRYPTION_KEY` | *(Clave hexadecimal de 64 caracteres)* | Cifrado AES-256 de pacientes |
| `ALLOWED_ORIGINS` | `https://api.asic-guanipa.online,http://localhost:3000` | Dominios autorizados |

5. Haz clic en **Deploy Web Service**.
6. Durante el build, Render ejecutará automáticamente:
   * `npm install`
   * `npx sequelize-cli db:migrate` (crea todas las tablas en Supabase)
   * `npx sequelize-cli db:seed:all` (crea los roles y el usuario administrador inicial)
7. Al finalizar, tu sistema estará activo en:
   `https://tu-servicio.onrender.com`

---

## 3. Actualización de la Versión Android (APK)

### 3.1 Dónde encontrar el APK Compilado
Una vez completada la compilación en este entorno, el archivo APK actualizado se ubica en:
* En el proyecto: `frontend/build/app/outputs/flutter-apk/app-release.apk`
* En descargas del backend: `downloads/asic-guanipa.apk`

### 3.2 Descarga Directa desde la Web
Cualquier médico, enfermero o usuario puede descargar el APK desde cualquier navegador ingresando a:
```text
https://tu-servicio.onrender.com/downloads/asic-guanipa.apk
```

### 3.3 Conexión de la App Móvil con Render
La app móvil incluye detección de servidor en tiempo de ejecución:
1. Al abrir la app en el dispositivo Android, si no detecta el servidor local, pulsa el ícono de **Configuración de Servidor** (o el botón en pantalla).
2. Pega la URL de tu backend en Render:
   `https://tu-servicio.onrender.com`
3. Presiona **Guardar y Conectar**. La app recordará esta dirección para siempre y funcionará desde cualquier red WiFi o datos móviles LTE/5G.

---

## 4. Verificación de Funcionamiento

* **Frontend Web:** Abre en el navegador `https://tu-servicio.onrender.com/` para acceder al sistema clínico y nominal.
* **Documentación API:** Abre `https://tu-servicio.onrender.com/api-docs` para ver Swagger.
* **Verificación de Constancia Médica (QR):** Escanear el QR de cualquier constancia abrirá la página oficial de verificación pública en `https://tu-servicio.onrender.com/verificar-constancia?codigo=...&ci=...`.


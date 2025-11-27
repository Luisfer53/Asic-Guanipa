# 🧪 Guía Rápida de Prueba

Esta es una guía rápida para probar el backend antes de iniciar la base de datos completa.

## ⚠️ IMPORTANTE: Configuración de Base de Datos

Antes de iniciar el servidor, debes:

### 1. Instalar PostgreSQL (si no lo tienes)

Descarga e instala PostgreSQL desde: https://www.postgresql.org/download/windows/

### 2. Crear la Base de Datos

Opción A - Usando pgAdmin:
1. Abre pgAdmin
2. Crea una nueva base de datos llamada `auth_system`
3. Abre Query Tool
4. Copia y pega el contenido de `database.sql`
5. Ejecuta

Opción B - Usando línea de comandos:
```bash
# Entrar a PostgreSQL
psql -U postgres

# Crear la base de datos
CREATE DATABASE auth_system;

# Conectar a la base de datos
\c auth_system

# Ejecutar el script
\i "c:/Users/Luis/Documents/Proyecto cdi/database.sql"
```

### 3. Configurar Variables de Entorno

Edita el archivo `.env` y actualiza:

```env
DB_PASSWORD=tu_contraseña_de_postgresql
```

Cambia solo esta línea con la contraseña que pusiste al instalar PostgreSQL.

### 4. Iniciar el Servidor

```bash
npm start
```

Si todo está bien, verás:

```
✅ Conectado a PostgreSQL
══════════════════════════════════════════════════
🚀 Servidor corriendo en http://localhost:3000
══════════════════════════════════════════════════
```

## 🚀 Prueba Rápida con PowerShell

Una vez que el servidor esté corriendo, abre OTRA terminal y prueba:

### 1. Verificar que el servidor responde

```powershell
Invoke-RestMethod -Uri "http://localhost:3000" -Method Get
```

### 2. Registrar un usuario

```powershell
$body = @{
    username = "testuser"
    email = "test@example.com"
    password = "Test123"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:3000/api/auth/register" -Method Post -Body $body -ContentType "application/json"
```

### 3. Hacer login

```powershell
$body = @{
    email = "test@example.com"
    password = "Test123"
} | ConvertTo-Json

$response = Invoke-RestMethod -Uri "http://localhost:3000/api/auth/login" -Method Post -Body $body -ContentType "application/json"
$token = $response.data.token
Write-Host "Token: $token"
```

### 4. Obtener perfil (ruta protegida)

```powershell
$headers = @{
    Authorization = "Bearer $token"
}

Invoke-RestMethod -Uri "http://localhost:3000/api/auth/profile" -Method Get -Headers $headers
```

### 5. Recuperar contraseña

```powershell
$body = @{
    email = "test@example.com"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:3000/api/auth/forgot-password" -Method Post -Body $body -ContentType "application/json"
```

Mira en la consola del servidor para ver el token de recuperación.

## 🐛 Errores Comunes

### "Cannot connect to PostgreSQL"

- ✅ Verifica que PostgreSQL esté corriendo
- ✅ Revisa la contraseña en `.env`
- ✅ Asegúrate de que la base de datos `auth_system` exista

### "listen EADDRINUSE"

- ✅ El puerto 3000 está en uso
- ✅ Cambia `PORT=3001` en `.env`

### "User already exists"

- ✅ Usa otro email o username
- ✅ O elimina el usuario de la base de datos:

```sql
DELETE FROM users WHERE email = 'test@example.com';
```

## ✅ Siguiente Paso

Lee el archivo [README.md](./README.md) para documentación completa.

Para subir a GitHub, lee [GITHUB_INSTRUCTIONS.md](./GITHUB_INSTRUCTIONS.md).

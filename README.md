# Backend de Autenticación - Node.js + PostgreSQL

Sistema completo de autenticación backend con Node.js, Express y PostgreSQL que incluye:
- ✅ Registro de usuarios
- ✅ Login con contraseñas encriptadas (bcrypt)
- ✅ Autenticación con JWT
- ✅ Recuperación de contraseña
- ✅ Validación de datos
- ✅ Rutas protegidas

## 📋 Requisitos Previos

- **Node.js** (v14 o superior) - [Descargar aquí](https://nodejs.org/)
- **PostgreSQL** (v12 o superior) - [Descargar aquí](https://www.postgresql.org/download/)
- **npm** (viene con Node.js)

## 🚀 Instalación

### 1. Clonar o descargar el proyecto

```bash
cd "c:\Users\Luis\Documents\Proyecto cdi"
```

### 2. Instalar dependencias

```bash
npm install
```

### 3. Configurar la base de datos PostgreSQL

#### Opción A: Usando pgAdmin o línea de comandos

1. Abre PostgreSQL y crea una nueva base de datos:

```sql
CREATE DATABASE auth_system;
```

2. Ejecuta el script de base de datos:

```bash
psql -U postgres -d auth_system -f database.sql
```

O copia y pega el contenido de `database.sql` en pgAdmin.

#### Opción B: Desde la terminal de PostgreSQL

```bash
psql -U postgres
CREATE DATABASE auth_system;
\c auth_system
\i database.sql
```

### 4. Configurar variables de entorno

1. Copia el archivo de ejemplo:

```bash
copy .env.example .env
```

2. Edita el archivo `.env` con tus datos:

```env
# Server Configuration
PORT=3000
NODE_ENV=development

# Database Configuration
DB_HOST=localhost
DB_PORT=5432
DB_NAME=auth_system
DB_USER=postgres
DB_PASSWORD=tu_contraseña_de_postgresql

# JWT Configuration
JWT_SECRET=cambia_esto_por_algo_super_secreto_y_aleatorio
JWT_EXPIRE=24h

# Email Configuration (opcional)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=tu_email@gmail.com
SMTP_PASSWORD=tu_contraseña_de_app
EMAIL_FROM=noreply@tuapp.com

# Frontend URL
FRONTEND_URL=http://localhost:3000
```

> **Nota importante sobre JWT_SECRET**: Genera un string aleatorio seguro. Puedes usar:
> ```bash
> node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
> ```

### 5. Iniciar el servidor

```bash
npm start
```

Para desarrollo con auto-reinicio:

```bash
npm run dev
```

Deberías ver:

```
══════════════════════════════════════════════════
🚀 Servidor corriendo en http://localhost:3000
══════════════════════════════════════════════════
```

## 📡 API Endpoints

### 1. Registro de Usuario

**POST** `/api/auth/register`

```json
{
  "username": "usuario123",
  "email": "usuario@example.com",
  "password": "Password123"
}
```

**Respuesta exitosa (201):**

```json
{
  "success": true,
  "message": "Usuario registrado exitosamente",
  "data": {
    "user": {
      "id": 1,
      "username": "usuario123",
      "email": "usuario@example.com",
      "created_at": "2024-01-01T00:00:00.000Z"
    },
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }
}
```

### 2. Login

**POST** `/api/auth/login`

```json
{
  "email": "usuario@example.com",
  "password": "Password123"
}
```

**Respuesta exitosa (200):**

```json
{
  "success": true,
  "message": "Login exitoso",
  "data": {
    "user": {
      "id": 1,
      "username": "usuario123",
      "email": "usuario@example.com"
    },
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }
}
```

### 3. Recuperar Contraseña (Solicitud)

**POST** `/api/auth/forgot-password`

```json
{
  "email": "usuario@example.com"
}
```

**Respuesta exitosa (200):**

```json
{
  "success": true,
  "message": "Si el email existe, recibirás un enlace de recuperación"
}
```

> **Nota**: El token de recuperación se mostrará en la consola del servidor si no tienes configurado SMTP.

### 4. Restablecer Contraseña

**POST** `/api/auth/reset-password`

```json
{
  "token": "token_recibido_por_email",
  "newPassword": "NuevaPassword123"
}
```

**Respuesta exitosa (200):**

```json
{
  "success": true,
  "message": "Contraseña restablecida exitosamente"
}
```

### 5. Obtener Perfil (Ruta Protegida)

**GET** `/api/auth/profile`

**Headers:**

```
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Respuesta exitosa (200):**

```json
{
  "success": true,
  "data": {
    "id": 1,
    "username": "usuario123",
    "email": "usuario@example.com",
    "created_at": "2024-01-01T00:00:00.000Z",
    "updated_at": "2024-01-01T00:00:00.000Z"
  }
}
```

## 🔒 Seguridad

- ✅ **Contraseñas encriptadas**: Usando bcrypt con salt rounds = 10
- ✅ **JWT para autenticación**: Tokens seguros con expiración configurable
- ✅ **Validación de datos**: Express-validator para validar todas las entradas
- ✅ **Tokens de recuperación**: SHA-256 hash para tokens de recuperación
- ✅ **Variables de entorno**: Credenciales sensibles en archivos .env
- ✅ **CORS habilitado**: Para permitir peticiones desde otros dominios

## 🧪 Probando la API

### Usando cURL

**Registro:**

```bash
curl -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"testuser\",\"email\":\"test@example.com\",\"password\":\"Test123\"}"
```

**Login:**

```bash
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"test@example.com\",\"password\":\"Test123\"}"
```

### Usando Postman

1. Importa la colección o crea requests manualmente
2. Para rutas protegidas, agrega el header:
   - Key: `Authorization`
   - Value: `Bearer TU_TOKEN_AQUI`

## 📁 Estructura del Proyecto

```
Proyecto cdi/
├── src/
│   ├── config/
│   │   └── database.js          # Configuración de PostgreSQL
│   ├── controllers/
│   │   └── authController.js    # Lógica de autenticación
│   ├── middleware/
│   │   ├── auth.js              # Middleware JWT
│   │   └── validator.js         # Validaciones
│   └── routes/
│       └── authRoutes.js        # Rutas de la API
├── database.sql                  # Script de base de datos
├── server.js                     # Servidor principal
├── package.json                  # Dependencias
├── .env                          # Variables de entorno (NO subir a Git)
├── .env.example                  # Plantilla de variables
└── .gitignore                    # Archivos ignorados por Git
```

## ⚠️ Solución de Problemas

### Error de conexión a PostgreSQL

```
❌ Error en la conexión a PostgreSQL
```

**Solución:**
- Verifica que PostgreSQL esté ejecutándose
- Revisa las credenciales en `.env`
- Asegúrate de que la base de datos `auth_system` exista

### Error: "listen EADDRINUSE"

**Solución:**
- El puerto 3000 está en uso
- Cambia el `PORT` en `.env`
- O mata el proceso: `taskkill /F /IM node.exe` (Windows)

### Errores de validación

**Solución:**
- Revisa que los datos cumplan con los requisitos:
  - Username: 3-50 caracteres, solo letras, números y _
  - Email: formato válido
  - Password: mínimo 6 caracteres, incluye mayúscula, minúscula y número

## 📧 Configuración de Email (Opcional)

Para habilitar el envío real de emails de recuperación:

### Gmail

1. Habilita "Verificación en 2 pasos" en tu cuenta
2. Genera una "Contraseña de aplicación"
3. Usa esas credenciales en `.env`:

```env
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=tu_email@gmail.com
SMTP_PASSWORD=tu_contraseña_de_app_de_16_digitos
```

## 📝 Notas Adicionales

- Las contraseñas **nunca** se almacenan en texto plano
- Los tokens JWT expiran según `JWT_EXPIRE` (por defecto 24h)
- Los tokens de recuperación expiran en 1 hora
- En desarrollo, los tokens de recuperación se muestran en la consola

## 🤝 Contribuir

Si encuentras bugs o quieres agregar features, ¡siéntete libre de hacerlo!

## 📄 Licencia

ISC

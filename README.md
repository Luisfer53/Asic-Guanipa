# Sistema de Gestión Clínica y Epidemiológica - ASIC Guanipa

Sistema integral para la gestión asistencial, control nominal de vacunación, registro de atenciones diarias e inventario clínico del Área de Salud Integral Comunitaria (ASIC) San José de Guanipa.

La plataforma está compuesta por una aplicación cliente desarrollada en Flutter (Web y Android) y un servicio backend modular implementado en Node.js, Express y PostgreSQL con Sequelize ORM.

---

## 1. Módulos del Sistema

- **Control de Acceso y Seguridad**: Autenticación mediante JSON Web Tokens (JWT), contraseñas cifradas con bcrypt y control de accesos basado en roles clínicos (Médico, Inmunizador, Inventario, Epidemiólogo, Admin y Básico).
- **Registro Nominal de Pacientes**: Módulo de historia clínica digital, soporte para adultos y menores de edad (con vinculación a representantes legales), validación de identificación oficial venezolana (V/E) y estandarización de datos en mayúsculas.
- **Jornadas Diarias de Salud**: Registro rápido de inmunizaciones, triaje básico, captura de signos vitales (temperatura, peso, talla) y emisión de constancias de atención con código QR.
- **Carnet Digital de Vacunación**: Generación y visualización del carnet oficial nominal (anverso y reverso) adaptado para dispositivos móviles e impresión.
- **Gestión de Inventario y Cadena de Frío**: Control de lotes de insumos y biológicos, fechas de vencimiento, stock disponible, kardex de movimientos y reportes de descartes para trazabilidad sanitaria.
- **Sala Situacional y Vigilancia Epidemiológica**: Consolidación de estadísticas periódicas y exportación de reportes de morbilidad y cobertura de vacunación.

---

## 2. Arquitectura y Tecnologías

### Backend
- **Entorno de ejecución**: Node.js (v18 o superior)
- **Framework web**: Express.js
- **Base de datos**: PostgreSQL
- **ORM**: Sequelize con soporte para migraciones y seeders
- **Seguridad**: JWT (jsonwebtoken), bcryptjs, express-validator, helmet, cors
- **Generación de documentos**: PDFKit, QRCode

### Frontend
- **Framework**: Flutter (soporte multiplataforma: Web y Android APK)
- **Gestión de estado**: Provider
- **Diseño**: Material Design con componentes adaptados para dispositivos móviles y escritorio

---

## 3. Requisitos Previos

- **Node.js** v18.x o superior
- **npm** v9.x o superior
- **PostgreSQL** v14.x o superior
- **Flutter SDK** v3.24 o superior (únicamente para compilación del cliente)

---

## 4. Instalación y Configuración Local

### Paso 1: Clonar el repositorio

```bash
git clone https://github.com/Luisfer53/Asic-Guanipa.git
cd Asic-Guanipa
```

### Paso 2: Instalar dependencias del backend

```bash
npm install
```

### Paso 3: Configurar variables de entorno

Copie el archivo de plantilla `.env.example` y configure sus credenciales de base de datos y entorno:

```bash
cp .env.example .env
```

Parámetros principales del archivo `.env`:

```env
PORT=3000
NODE_ENV=development

# Configuración de PostgreSQL
DB_HOST=localhost
DB_PORT=5432
DB_NAME=asic_guanipa
DB_USER=postgres
DB_PASSWORD=su_contraseña

# Configuración de JWT
JWT_SECRET=clave_secreta_para_firmar_tokens
JWT_EXPIRE=24h

# URL base del backend
SERVER_URL=http://localhost:3000/api
```

### Paso 4: Ejecutar migraciones de base de datos

```bash
npx sequelize-cli db:migrate
npx sequelize-cli db:seed:all
```

### Paso 5: Iniciar el servidor

Modo producción:
```bash
npm start
```

Modo desarrollo (con recarga automática):
```bash
npm run dev
```

---

## 5. Endpoints Principales de la API

### Autenticación y Usuarios
- `POST /api/auth/login` - Autenticación de usuarios y entrega de token JWT.
- `POST /api/auth/register` - Registro de nuevos usuarios asistenciales (requiere rol Admin).
- `GET /api/auth/profile` - Consulta del perfil y permisos del usuario en sesión.
- `GET /api/auth/users` - Listado y administración de cuentas activas.

### Gestión de Pacientes
- `GET /api/pacientes` - Consulta paginada y búsqueda nominal por cédula o nombre.
- `POST /api/pacientes` - Registro exhaustivo de expediente clínico.
- `POST /api/pacientes/rapido` - Alta inmediata al vuelo desde módulos de atención.
- `PUT /api/pacientes/datos/:id` - Actualización de datos demográficos y clínicos.

### Atenciones e Inmunización
- `POST /api/atenciones` - Registro de atención médica y triaje.
- `POST /api/atenciones/operativos` - Planificación y control de jornadas extramurales.
- `GET /api/atenciones/operativos` - Consulta de operativos activos y participantes.

### Inventario y Lotes
- `GET /api/articulos` - Catálogo de artículos médicos y vacunas.
- `POST /api/articulos` - Registro de nuevos insumos en catálogo.
- `GET /api/` - Consulta general de inventario por lotes y stock disponible.
- `POST /api/lotes` - Registro de nuevo lote con fecha de caducidad.
- `GET /api/movimientos` - Historial de movimientos de kardex (entradas y salidas).

---

## 6. Estructura del Proyecto

```
├── config/                  # Configuración de conexión y parámetros de base de datos
├── database/
│   ├── migrations/          # Migraciones de base de datos con Sequelize
│   └── seeders/             # Semillas de roles y datos base del sistema
├── frontend/                # Código fuente de la aplicación Flutter
│   ├── lib/                 # Vistas, controladores de estado y modelos cliente
│   └── web/                 # Configuración del contenedor web
├── public/                  # Archivos estáticos y distribución compilada de Flutter Web
│   └── downloads/           # Instaladores generados (APK para Android)
├── src/
│   ├── controllers/         # Lógica de negocio y controladores de endpoints
│   ├── middleware/          # Middlewares de autenticación, roles y validación
│   ├── models/              # Definición de entidades Sequelize
│   ├── routes/              # Declaración de rutas de la API REST
│   └── utils/               # Utilidades de auditoría y formateo
├── server.js                # Punto de entrada de la aplicación Express
├── package.json             # Manifiesto de dependencias y scripts de ejecución
└── README.md                # Documentación técnica del proyecto
```

---

## 7. Licencia

Proyecto desarrollado para fines académicos y asistenciales en el marco del convenio UPTJAA y ASIC San José de Guanipa.

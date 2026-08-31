const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
require('dotenv').config();

const authRoutes = require('./src/routes/authRoutes');
const patientRoutes = require('./src/routes/patientRoutes');
const atencionesRoutes = require('./src/routes/atencionesRoutes');
const inventarioRoutes = require('./src/routes/inventarioRoutes');
const reportRoutes = require('./src/routes/reportRoutes');
const swaggerUi = require('swagger-ui-express');
const YAML = require('yamljs');
const path = require('path');
const fs = require('fs');
const swaggerDocument = YAML.load(path.join(__dirname, 'swagger.yaml'));

const prodUrl = process.env.SERVER_URL || (process.env.RENDER_EXTERNAL_URL ? `${process.env.RENDER_EXTERNAL_URL}/api` : 'https://api.asic-guanipa.online/api');
const devUrl = `http://localhost:${process.env.PORT || 3000}/api`;

swaggerDocument.servers = [{
    url: process.env.NODE_ENV === 'production' ? prodUrl : (process.env.SERVER_URL || devUrl),
    description: process.env.NODE_ENV === 'production' ? 'Servidor de Producción' : 'Servidor de Desarrollo'
}];

const app = express();
app.set('trust proxy', 1);

// ─── 🛡️ SEGURIDAD: Encabezados HTTP (Helmet) ───────────────────────────
app.use(helmet({ contentSecurityPolicy: false }));

// ─── 🛡️ SEGURIDAD: Configuración de CORS ────────────────────────────────
const allowedOrigins = process.env.ALLOWED_ORIGINS
    ? process.env.ALLOWED_ORIGINS.split(',')
    : ['http://localhost:3000', 'http://localhost:8080', 'https://api.asic-guanipa.online'];

app.use(cors({
    origin: (origin, callback) => {
        if (!origin || process.env.NODE_ENV !== 'production' || allowedOrigins.includes(origin)) {
            callback(null, true);
        } else {
            callback(new Error('Acceso no permitido por la directiva CORS'));
        }
    },
    credentials: true
}));

// ─── 🛡️ SEGURIDAD: Limite de peticiones (Rate Limiting) ───────────────
const authLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutos
    max: 15, // máximo 15 intentos por IP en 15 min
    standardHeaders: true,
    legacyHeaders: false,
    message: {
        success: false,
        message: 'Demasiados intentos desde esta dirección IP. Intente de nuevo en 15 minutos.'
    }
});

const apiLimiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 500, // máximo 500 peticiones globales por IP en 15 min
    standardHeaders: true,
    legacyHeaders: false
});

app.use('/api/', apiLimiter);
app.use('/api/auth/login', authLimiter);
app.use('/api/auth/forgot-password', authLimiter);

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Servir archivos de descarga de aplicaciones (APKs, instaladores, etc.)
app.use('/downloads', express.static(path.join(__dirname, 'downloads')));

// Servir archivos estáticos de la carpeta public (como logo.png)
app.use(express.static(path.join(__dirname, 'public')));

// ─── 🌐 FRONTEND WEB (Flutter Web Build) ─────────────────────────────────────
// Sirve la app Flutter web compilada en /app
// Cualquier ruta desconocida dentro de /app devuelve index.html (SPA fallback)
const flutterWebPath = path.join(__dirname, 'frontend', 'build', 'web');
app.use('/app', express.static(flutterWebPath, { index: 'index.html' }));
app.get('/app', (req, res) => {
    res.sendFile(path.join(flutterWebPath, 'index.html'));
});
app.get('/app/*', (req, res) => {
    res.sendFile(path.join(flutterWebPath, 'index.html'));
});

// La raíz redirige al frontend web
app.get('/', (req, res) => {
    res.redirect('/app/');
});

app.use('/api/auth', authRoutes);
app.use('/api', patientRoutes);
app.use('/api', atencionesRoutes);
app.use('/api', reportRoutes);
app.use('/api/inventario', inventarioRoutes);
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerDocument));

// Endpoint público para obtener configuración en tiempo de ejecución
app.get('/config', (req, res) => {
    const serverUrl = process.env.SERVER_URL || (process.env.NODE_ENV === 'production' ? prodUrl : devUrl);
    const downloadsBase = serverUrl.replace(/\/api$/, '');
    let apkDownload = null;
    try {
        const latestFile = path.join(__dirname, 'downloads', 'latest-apk-url.txt');
        if (fs.existsSync(latestFile)) {
            apkDownload = fs.readFileSync(latestFile, 'utf8').trim();
        } else {
            apkDownload = `${downloadsBase}/downloads/asic-guanipa.apk`;
        }
    } catch (e) {
        apkDownload = `${downloadsBase}/downloads/asic-guanipa.apk`;
    }

    res.json({
        server_url: serverUrl,
        apk_download_url: apkDownload,
    });
});

app.use((err, req, res, next) => {
    console.error('Error:', err);
    res.status(err.status || 500).json({
        success: false,
        message: err.message || 'Error interno del servidor',
        error: process.env.NODE_ENV === 'development' ? err : {}
    });
});

app.use((req, res) => {
    res.status(404).json({
        success: false,
        message: 'Endpoint no encontrado'
    });
});

const PORT = process.env.PORT || 3000;
const HOST = '0.0.0.0';

if (require.main === module) {
    app.listen(PORT, HOST, () => {
        const currentUrl = process.env.SERVER_URL || (process.env.NODE_ENV === 'production' ? prodUrl : `http://localhost:${PORT}/api`);
        const displayUrl = currentUrl.replace(/\/api$/, '');

        console.log('\n' + '═'.repeat(50));
        console.log(`🚀 Servidor corriendo en ${displayUrl}`);
        console.log('═'.repeat(50));
        console.log('📝 Endpoints disponibles:');
        console.log(`   POST   ${currentUrl}/auth/register`);
        console.log(`   POST   ${currentUrl}/auth/login`);
        console.log(`   POST   ${currentUrl}/auth/forgot-password`);
        console.log(`   POST   ${currentUrl}/auth/reset-password`);
        console.log(`   GET    ${currentUrl}/auth/profile`);
        console.log('═'.repeat(50) + '\n');
    });
}

module.exports = app;

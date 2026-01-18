const express = require('express');
const cors = require('cors');
require('dotenv').config();

const authRoutes = require('./src/routes/authRoutes');
const patientRoutes = require('./src/routes/patientRoutes');
const swaggerUi = require('swagger-ui-express');
const YAML = require('yamljs');
const path = require('path');
const swaggerDocument = YAML.load(path.join(__dirname, 'swagger.yaml'));

const prodUrl = 'https://api.asic-guanipa.online/api';
const devUrl = 'http://localhost:3000/api';

swaggerDocument.servers = [{
    url: process.env.SERVER_URL || (process.env.NODE_ENV === 'production' ? prodUrl : devUrl),
    description: process.env.NODE_ENV === 'production' ? 'Servidor de Producción' : 'Servidor de Desarrollo'
}];

const app = express();

app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.get('/', (req, res) => {
    res.json({
        success: true,
        message: 'API de Autenticación - Servidor funcionando',
        version: '1.0.0',
        endpoints: {
            register: 'POST /api/auth/register',
            login: 'POST /api/auth/login',
            forgotPassword: 'POST /api/auth/forgot-password',
            resetPassword: 'POST /api/auth/reset-password',
            profile: 'GET /api/auth/profile (requiere token)',
            pacientes: 'GET /api/pacientes',
            reportes: 'GET /api/reportes'
        }
    });
});

app.use('/api/auth', authRoutes);
app.use('/api', patientRoutes);
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerDocument));

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

if (require.main === module) {
    app.listen(PORT, () => {
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

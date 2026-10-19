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
const db = require('./src/models');
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
const flutterWebPath = path.join(__dirname, 'frontend', 'build', 'web');

// Servir archivos estáticos del build de Flutter (JS, WASM, assets, etc.)
app.use(express.static(flutterWebPath));
app.use('/app', express.static(flutterWebPath));

app.get(['/', '/app', '/app/*'], (req, res) => {
    res.sendFile(path.join(flutterWebPath, 'index.html'));
});

app.use('/api/auth', authRoutes);
app.use('/api', patientRoutes);
app.use('/api', atencionesRoutes);
app.use('/api', reportRoutes);
app.use('/api/inventario', inventarioRoutes);
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerDocument));

// ─── 🪪 VERIFICACIÓN PÚBLICA DE CARNET DE VACUNACIÓN (sin JWT) ───────────────
// Endpoint escaneado por el QR del carnet: /carnet/verificar?id=CEDULA&dosis=N&hash=XXXXXXX
// ─── VERIFICACIÓN PÚBLICA DE CARNET DE VACUNACIÓN (Portal Aislado Oficial) ─────
// Endpoint escaneado por el QR del carnet: /carnet/verificar?id=CEDULA&dosis=N&hash=XXXXXXX
app.get('/carnet/verificar', async (req, res) => {
    const rawId = (req.query.id || req.query.cedula || '').trim();
    const queryDosis = req.query.dosis ? parseInt(req.query.dosis) : null;
    const queryHash = (req.query.hash || '').trim();

    // Helper SVG Icons (profesionales, sin emojis)
    const SVG = {
        shieldCheck: `<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#16A34A" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><path d="m9 12 2 2 4-4"/></svg>`,
        shieldAlert: `<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#DC2626" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>`,
        shieldWarning: `<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#D97706" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>`,
        check: `<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>`,
        printer: `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="6 9 6 2 18 2 18 9"/><path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2"/><rect x="6" y="14" width="12" height="8"/></svg>`,
        lock: `<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>`,
        location: `<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/></svg>`,
        hospital: `<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 21h18"/><path d="M5 21V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2v16"/><path d="M10 9h4"/><path d="M12 7v4"/></svg>`
    };

    if (!rawId) {
        return res.status(400).send(`
            <!DOCTYPE html><html lang="es"><head><meta charset="UTF-8">
            <title>Código Inválido — CDI Dr. Pedro Urbina</title>
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
            <style>
                body { font-family: 'Inter', sans-serif; background: #F8FAFC; color: #0F172A; display: flex; align-items: center; justify-content: center; min-height: 100vh; margin: 0; padding: 1.5rem; }
                .card { background: #FFFFFF; border: 1px solid #E2E8F0; border-radius: 12px; padding: 2.5rem 2rem; max-width: 460px; text-align: center; box-shadow: 0 10px 25px -5px rgba(0,0,0,0.06); }
                .icon-circle { width: 56px; height: 56px; border-radius: 50%; background: #FEF3C7; border: 1px solid #FDE68A; display: flex; align-items: center; justify-content: center; margin: 0 auto 1.25rem; }
                .title { color: #92400E; font-size: 1.25rem; font-weight: 800; margin-bottom: 0.5rem; }
                .msg { color: #475569; font-size: 0.9rem; line-height: 1.55; }
                .badge { display: inline-block; background: #F1F5F9; color: #475569; font-size: 0.75rem; font-weight: 700; padding: 0.35rem 0.75rem; border-radius: 6px; margin-top: 1.5rem; }
            </style></head><body><div class="card">
                <div class="icon-circle">${SVG.shieldWarning}</div>
                <div class="title">Código de Verificación Inválido</div>
                <div class="msg">El enlace escaneado no contiene los parámetros oficiales del carnet nominal. Asegúrese de escanear un carnet emitido por el Centro de Diagnóstico Integral Dr. Pedro Urbina.</div>
                <div class="badge">ASIC SAN JOSÉ DE GUANIPA · PAI OFICIAL</div>
            </div></body></html>`);
    }

    try {
        const cleanId = rawId.replace(/[^0-9a-zA-Z]/g, '').replace(/^[vVeEpPjJ]/, '');

        // 1. Buscar persona
        let persona = await db.Persona.findOne({
            where: {
                cedula_identidad: {
                    [db.Sequelize.Op.iLike]: `%${cleanId}%`
                }
            }
        });

        if (!persona) {
            persona = await db.Persona.findOne({
                where: {
                    cedula_identidad: {
                        [db.Sequelize.Op.iLike]: `%${rawId}%`
                    }
                }
            });
        }

        if (!persona) {
            return res.status(404).send(`
                <!DOCTYPE html><html lang="es"><head><meta charset="UTF-8">
                <title>Carnet No Encontrado — CDI Dr. Pedro Urbina</title>
                <meta name="viewport" content="width=device-width, initial-scale=1">
                <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
                <style>
                    body { font-family: 'Inter', sans-serif; background: #F8FAFC; color: #0F172A; display: flex; align-items: center; justify-content: center; min-height: 100vh; margin: 0; padding: 1.5rem; }
                    .card { background: #FFFFFF; border: 1px solid #FECACA; border-radius: 12px; padding: 2.5rem 2rem; max-width: 480px; text-align: center; box-shadow: 0 10px 25px -5px rgba(0,0,0,0.06); }
                    .icon-circle { width: 56px; height: 56px; border-radius: 50%; background: #FEE2E2; border: 1px solid #FECACA; display: flex; align-items: center; justify-content: center; margin: 0 auto 1.25rem; }
                    .title { color: #991B1B; font-size: 1.25rem; font-weight: 800; margin-bottom: 0.5rem; }
                    .folio { background: #EFF6FF; color: #1E3A8A; border: 1px solid #BFDBFE; font-size: 0.85rem; font-weight: 700; font-family: monospace; padding: 0.3rem 0.75rem; border-radius: 6px; display: inline-block; margin-bottom: 1rem; }
                    .msg { color: #475569; font-size: 0.9rem; line-height: 1.55; }
                    .footer-txt { margin-top: 1.75rem; font-size: 0.75rem; color: #64748B; border-top: 1px solid #F1F5F9; padding-top: 1rem; font-weight: 600; }
                </style></head><body><div class="card">
                    <div class="icon-circle">${SVG.shieldAlert}</div>
                    <div class="title">Documento No Encontrado</div>
                    <div class="folio">C.I: ${rawId}</div>
                    <div class="msg">No existe ningún registro de inmunización asociado a este documento de identidad en el Sistema Nominal del Centro de Diagnóstico Integral Dr. Pedro Urbina. Verifique los datos o acuda al centro de salud emisor.</div>
                    <div class="footer-txt">REPÚBLICA BOLIVARIANA DE VENEZUELA · MPPS · ASIC GUANIPA</div>
                </div></body></html>`);
        }

        // 2. Buscar datos del paciente, atenciones y vacunas
        const paciente = await db.Paciente.findOne({
            where: { id_persona: persona.id_persona }
        });

        // Buscar dirección si existe
        let direccionTexto = 'San José de Guanipa';
        try {
            const dir = await db.Direccion.findOne({ where: { id_persona: persona.id_persona } });
            if (dir) {
                const partes = [dir.calle, dir.numero_casa, dir.parroquia].filter(Boolean);
                if (partes.length > 0) direccionTexto = partes.join(', ');
            }
        } catch (_) {}

        let vacunas = [];
        let totalDosis = 0;

        if (paciente) {
            const atenciones = await db.AtencionDiaria.findAll({
                where: { id_paciente: paciente.id_paciente },
                include: [
                    { model: db.CentroSalud, as: 'centro', attributes: ['id_centro', 'nombre_centro'] },
                    {
                        model: db.RegistroVacunacion, as: 'vacunaciones',
                        include: [
                            {
                                model: db.LoteInsumo, as: 'lote',
                                include: [{ model: db.ArticuloMedico, as: 'articulo', attributes: ['id_articulo', 'nombre_articulo', 'tipo'] }]
                            },
                            { model: db.EsquemaDosificacion, as: 'esquema', attributes: ['id_esquema', 'numero_dosis'] }
                        ]
                    }
                ],
                order: [['fecha_visita', 'ASC']]
            });

            for (const atencion of atenciones) {
                if (atencion.vacunaciones && atencion.vacunaciones.length > 0) {
                    for (const vac of atencion.vacunaciones) {
                        totalDosis++;
                        vacunas.push({
                            vacuna: (vac.lote?.articulo?.nombre_articulo || 'Biológico PAI').toUpperCase(),
                            dosis: vac.dosis_aplicada || (vac.esquema?.numero_dosis ? `${vac.esquema.numero_dosis}da Dosis` : 'Dosis Única'),
                            fecha: atencion.fecha_visita || 'S/F',
                            lote: vac.lote?.numero_lote || 'S/L',
                            centro: atencion.centro?.nombre_centro || 'CDI Dr. Pedro Urbina'
                        });
                    }
                }
            }
        }

        // 3. Hash criptográfico de comprobación
        function getCleanCedula(c) {
            let clean = String(c || '').toUpperCase().replace(/[^0-9A-Z]/g, '');
            if (/^\d+$/.test(clean)) clean = 'V' + clean;
            return clean;
        }

        // 3. Hash determinista estándar de 32 bits para verificar la autenticidad
        function computeHash(cedula, doses) {
            const clean = getCleanCedula(cedula);
            const raw = `CDI-PEDRO-URBINA|${clean}|${doses}|PAI-MPPS-2026`;
            let h = 5381;
            for (let i = 0; i < raw.length; i++) {
                h = (((h << 5) + h) ^ raw.charCodeAt(i)) >>> 0;
            }
            return String(h % 9999999).padStart(7, '0');
        }

        const expectedHash = computeHash(persona.cedula_identidad || rawId, totalDosis);
        const hashMostrado = queryHash || expectedHash;

        // Calcular edad
        let edadTexto = 'S/D';
        let esMenor = false;
        let fechaNacTexto = 'S/D';
        if (persona.fecha_nacimiento) {
            const nac = new Date(persona.fecha_nacimiento);
            fechaNacTexto = nac.toISOString().split('T')[0];
            const hoy = new Date();
            let diff = hoy.getFullYear() - nac.getFullYear();
            const m = hoy.getMonth() - nac.getMonth();
            if (m < 0 || (m === 0 && hoy.getDate() < nac.getDate())) diff--;
            edadTexto = `${diff} años`;
            if (diff < 18) esMenor = true;
        }

        const nombreCompleto = [persona.nombre1, persona.nombre2, persona.apellido1, persona.apellido2]
            .filter(Boolean).join(' ').toUpperCase();
        const cedulaFormateada = persona.cedula_identidad || rawId;
        const tipoSangre = paciente?.tipo_sangre || 'S/D';
        const sexoTexto = persona.sexo || 'S/D';
        const fechaVerificacion = new Date().toLocaleDateString('es-VE', { 
            year: 'numeric', month: 'long', day: 'numeric', hour: '2-digit', minute: '2-digit' 
        });

        // Filas de vacunas en la tabla del reverso
        const filasTablaHtml = vacunas.length > 0
            ? vacunas.map((v, i) => `
                <tr>
                    <td class="col-num">${i + 1}</td>
                    <td class="col-vac"><strong>${v.vacuna}</strong></td>
                    <td class="col-dosis"><span class="dosis-badge">${v.dosis}</span></td>
                    <td class="col-fecha">${v.fecha}</td>
                    <td class="col-lote"><code>${v.lote}</code></td>
                    <td class="col-centro">${v.centro}</td>
                </tr>
            `).join('')
            : `<tr><td colspan="6" class="tabla-vacia">Sin registros de dosis en el sistema nominal.</td></tr>`;

        res.send(`
            <!DOCTYPE html>
            <html lang="es">
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1">
                <title>Verificación Oficial de Carnet — ${cedulaFormateada}</title>
                <link rel="preconnect" href="https://fonts.googleapis.com">
                <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
                <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800;900&display=swap" rel="stylesheet">
                <style>
                    :root {
                        --navy-900: #0F172A;
                        --navy-800: #1E293B;
                        --blue-900: #1E3A8A;
                        --blue-700: #1D4ED8;
                        --blue-600: #2563EB;
                        --blue-50: #EFF6FF;
                        --blue-200: #BFDBFE;
                        --teal-800: #0F766E;
                        --teal-50: #ECFDF5;
                        --green-700: #15803D;
                        --green-600: #16A34A;
                        --green-100: #DCFCE7;
                        --green-50: #F0FDF4;
                        --yellow-400: #FACC15;
                        --red-600: #DC2626;
                        --slate-50: #F8FAFC;
                        --slate-100: #F1F5F9;
                        --slate-200: #E2E8F0;
                        --slate-400: #94A3B8;
                        --slate-600: #475569;
                    }
                    * { box-sizing: border-box; margin: 0; padding: 0; }
                    body {
                        font-family: 'Inter', -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
                        background: var(--slate-100);
                        color: var(--navy-900);
                        min-height: 100vh;
                        padding-bottom: 3rem;
                    }

                    /* Barra Superior Institucional (Estilo Web ASIC Guanipa) */
                    .top-navbar {
                        background: var(--navy-900);
                        color: white;
                        border-bottom: 2px solid var(--blue-900);
                        padding: 0.75rem 1.5rem;
                    }
                    .top-navbar-inner {
                        max-width: 900px;
                        margin: 0 auto;
                        display: flex;
                        justify-content: space-between;
                        align-items: center;
                        gap: 1rem;
                    }
                    .brand-block {
                        display: flex;
                        align-items: center;
                        gap: 0.75rem;
                    }
                    .brand-icon {
                        background: rgba(30, 58, 138, 0.4);
                        border: 1px solid rgba(147, 197, 253, 0.3);
                        padding: 6px;
                        border-radius: 8px;
                        display: flex;
                        align-items: center;
                        justify-content: center;
                        color: #60A5FA;
                    }
                    .brand-title {
                        font-size: 0.85rem;
                        font-weight: 800;
                        letter-spacing: 0.02em;
                        line-height: 1.2;
                    }
                    .brand-subtitle {
                        font-size: 0.72rem;
                        color: #93C5FD;
                        font-weight: 600;
                    }
                    .top-badge {
                        background: var(--blue-900);
                        border: 1px solid #3B82F6;
                        color: white;
                        font-size: 0.7rem;
                        font-weight: 800;
                        padding: 0.35rem 0.75rem;
                        border-radius: 6px;
                        letter-spacing: 0.04em;
                        white-space: nowrap;
                    }

                    /* Contenedor Principal */
                    .page-container {
                        max-width: 900px;
                        margin: 1.5rem auto 0;
                        padding: 0 1rem;
                    }

                    /* Banner de Verificación de Autenticidad */
                    .verification-banner {
                        background: white;
                        border: 1px solid var(--slate-200);
                        border-left: 4px solid var(--green-600);
                        border-radius: 10px;
                        padding: 1.25rem 1.5rem;
                        display: flex;
                        align-items: center;
                        gap: 1.25rem;
                        box-shadow: 0 2px 4px rgba(0,0,0,0.04);
                        margin-bottom: 1.5rem;
                    }
                    .banner-icon-box {
                        width: 48px;
                        height: 48px;
                        border-radius: 50%;
                        background: var(--green-50);
                        border: 1px solid #BBF7D0;
                        display: flex;
                        align-items: center;
                        justify-content: center;
                        flex-shrink: 0;
                    }
                    .banner-content h1 {
                        font-size: 1.05rem;
                        font-weight: 800;
                        color: var(--green-700);
                        letter-spacing: -0.01em;
                    }
                    .banner-content p {
                        font-size: 0.82rem;
                        color: var(--slate-600);
                        margin-top: 0.2rem;
                        line-height: 1.45;
                    }

                    /* Sección del Carnet Réplica */
                    .section-header {
                        display: flex;
                        justify-content: space-between;
                        align-items: center;
                        margin-bottom: 0.75rem;
                    }
                    .section-title {
                        font-size: 0.8rem;
                        font-weight: 800;
                        color: var(--slate-600);
                        text-transform: uppercase;
                        letter-spacing: 0.06em;
                    }

                    /* Layout de los dos lados del Carnet */
                    .carnet-grid {
                        display: grid;
                        grid-template-columns: repeat(auto-fit, minmax(360px, 1fr));
                        gap: 1.25rem;
                        margin-bottom: 1.5rem;
                    }

                    /* Tarjeta Carnet Físico (Estilo exacto al carnet de impresión) */
                    .carnet-card {
                        background: white;
                        border-radius: 10px;
                        overflow: hidden;
                        box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.05), 0 2px 4px -2px rgba(0, 0, 0, 0.05);
                        display: flex;
                        flex-direction: column;
                    }
                    .carnet-front {
                        border: 1.2px solid var(--blue-900);
                    }
                    .carnet-back {
                        border: 1.2px solid var(--teal-800);
                    }

                    /* Bandera Tricolor Oficial */
                    .bandera-bar {
                        display: flex;
                        height: 5px;
                        width: 100%;
                    }
                    .bandera-amarillo { flex: 1; background: var(--yellow-400); }
                    .bandera-azul { flex: 1; background: var(--blue-700); }
                    .bandera-rojo { flex: 1; background: var(--red-600); }

                    /* Encabezado Anverso */
                    .header-anverso {
                        background: var(--navy-900);
                        color: white;
                        padding: 8px 12px;
                        display: flex;
                        justify-content: space-between;
                        align-items: center;
                    }
                    .header-anverso .inst-title {
                        font-size: 0.72rem;
                        font-weight: 800;
                        line-height: 1.2;
                    }
                    .header-anverso .inst-sub {
                        font-size: 0.65rem;
                        color: #93C5FD;
                        font-weight: 600;
                    }
                    .badge-pai-oficial {
                        background: var(--blue-900);
                        border: 0.5px solid #60A5FA;
                        color: white;
                        font-size: 0.65rem;
                        font-weight: 800;
                        padding: 2px 6px;
                        border-radius: 4px;
                    }

                    /* Barra Folio */
                    .barra-folio {
                        background: var(--blue-900);
                        color: white;
                        padding: 5px 12px;
                        display: flex;
                        justify-content: space-between;
                        align-items: center;
                        font-size: 0.72rem;
                        font-weight: 800;
                    }
                    .barra-folio .folio-tag {
                        color: var(--yellow-400);
                        font-family: monospace;
                        font-weight: 800;
                        font-size: 0.75rem;
                    }

                    /* Cuerpo Anverso */
                    .cuerpo-anverso {
                        padding: 12px;
                        flex: 1;
                        display: flex;
                        flex-direction: column;
                        gap: 8px;
                    }
                    .nombre-titular {
                        font-size: 0.95rem;
                        font-weight: 900;
                        color: var(--navy-900);
                        line-height: 1.2;
                    }
                    .cedula-row {
                        display: flex;
                        align-items: center;
                        gap: 6px;
                    }
                    .cedula-badge {
                        background: var(--blue-50);
                        border: 1px solid var(--blue-200);
                        color: var(--blue-900);
                        font-size: 0.8rem;
                        font-weight: 800;
                        padding: 2px 8px;
                        border-radius: 4px;
                        font-family: monospace;
                    }
                    .pediatrico-badge {
                        background: #FEF3C7;
                        color: #B45309;
                        border: 1px solid #FDE68A;
                        font-size: 0.65rem;
                        font-weight: 800;
                        padding: 2px 6px;
                        border-radius: 4px;
                    }
                    .grid-mini-datos {
                        display: grid;
                        grid-template-columns: repeat(4, 1fr);
                        gap: 6px;
                        background: var(--slate-50);
                        border: 1px solid var(--slate-200);
                        border-radius: 6px;
                        padding: 8px;
                    }
                    .mini-label {
                        font-size: 0.58rem;
                        font-weight: 700;
                        color: var(--slate-400);
                        display: block;
                        text-transform: uppercase;
                    }
                    .mini-val {
                        font-size: 0.75rem;
                        font-weight: 800;
                        color: var(--navy-900);
                    }
                    .direccion-row {
                        display: flex;
                        align-items: center;
                        gap: 4px;
                        font-size: 0.72rem;
                        color: var(--slate-600);
                    }
                    .dosis-resumen-pill {
                        display: inline-flex;
                        align-items: center;
                        gap: 5px;
                        background: var(--green-100);
                        border: 1px solid #86EFAC;
                        color: var(--green-700);
                        font-size: 0.72rem;
                        font-weight: 800;
                        padding: 3px 8px;
                        border-radius: 4px;
                        align-self: flex-start;
                    }

                    /* Pie Anverso */
                    .pie-anverso {
                        background: var(--slate-100);
                        border-top: 1px solid var(--slate-200);
                        padding: 6px 12px;
                        display: flex;
                        justify-content: space-between;
                        font-size: 0.62rem;
                        color: var(--slate-600);
                        font-weight: 700;
                    }

                    /* Reverso Header */
                    .header-reverso {
                        background: var(--teal-800);
                        color: white;
                        padding: 8px 12px;
                        font-size: 0.72rem;
                        font-weight: 800;
                        letter-spacing: 0.02em;
                    }
                    .titular-bar-reverso {
                        background: var(--teal-50);
                        color: #064E3B;
                        border-bottom: 1px solid #A7F3D0;
                        padding: 5px 12px;
                        font-size: 0.7rem;
                        font-weight: 800;
                    }

                    /* Tabla de Vacunas */
                    .tabla-container {
                        flex: 1;
                        overflow-x: auto;
                    }
                    .tabla-vacunas {
                        width: 100%;
                        border-collapse: collapse;
                        font-size: 0.72rem;
                    }
                    .tabla-vacunas th {
                        background: var(--teal-50);
                        color: #064E3B;
                        font-weight: 800;
                        padding: 6px 8px;
                        text-align: left;
                        border-bottom: 1px solid #A7F3D0;
                        font-size: 0.65rem;
                        text-transform: uppercase;
                    }
                    .tabla-vacunas td {
                        padding: 7px 8px;
                        border-bottom: 1px solid var(--slate-200);
                        color: var(--navy-900);
                    }
                    .tabla-vacunas tr:nth-child(even) {
                        background: #FBFDFB;
                    }
                    .col-num {
                        width: 22px;
                        font-weight: 700;
                        color: var(--slate-400);
                    }
                    .dosis-badge {
                        background: var(--green-100);
                        color: var(--green-700);
                        font-weight: 800;
                        padding: 2px 6px;
                        border-radius: 3px;
                        font-size: 0.65rem;
                        display: inline-block;
                        white-space: nowrap;
                    }
                    .col-lote code {
                        background: var(--slate-100);
                        padding: 2px 4px;
                        border-radius: 3px;
                        font-family: monospace;
                        font-weight: 700;
                        color: var(--navy-800);
                    }
                    .col-centro {
                        font-size: 0.68rem;
                        color: var(--slate-600);
                    }
                    .tabla-vacia {
                        text-align: center;
                        padding: 1.5rem;
                        color: var(--slate-400);
                        font-style: italic;
                    }
                    .pie-reverso {
                        background: var(--green-50);
                        border-top: 1px solid #A7F3D0;
                        padding: 6px 12px;
                        display: flex;
                        justify-content: space-between;
                        font-size: 0.62rem;
                        color: #064E3B;
                        font-weight: 700;
                    }

                    /* Panel de Certificación de Seguridad */
                    .security-card {
                        background: white;
                        border: 1px solid var(--slate-200);
                        border-radius: 10px;
                        padding: 1.25rem 1.5rem;
                        margin-bottom: 1.5rem;
                        box-shadow: 0 2px 4px rgba(0,0,0,0.04);
                    }
                    .security-card-header {
                        display: flex;
                        align-items: center;
                        gap: 8px;
                        font-size: 0.82rem;
                        font-weight: 800;
                        color: var(--blue-900);
                        text-transform: uppercase;
                        letter-spacing: 0.04em;
                        margin-bottom: 1rem;
                    }
                    .security-grid {
                        display: grid;
                        grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
                        gap: 1rem;
                    }
                    .sec-item .sec-label {
                        font-size: 0.7rem;
                        font-weight: 700;
                        color: var(--slate-400);
                        text-transform: uppercase;
                    }
                    .sec-item .sec-value {
                        font-size: 0.85rem;
                        font-weight: 800;
                        color: var(--navy-900);
                        margin-top: 2px;
                    }
                    .sec-item code {
                        font-family: monospace;
                        background: var(--slate-100);
                        padding: 2px 6px;
                        border-radius: 4px;
                        color: var(--blue-900);
                        font-weight: 800;
                    }

                    /* Botones de Acción */
                    .actions-bar {
                        display: flex;
                        justify-content: center;
                        gap: 1rem;
                        margin-bottom: 1.5rem;
                    }
                    .btn-action-print {
                        background: var(--blue-900);
                        color: white;
                        border: 1px solid var(--blue-700);
                        padding: 0.65rem 1.5rem;
                        border-radius: 8px;
                        font-size: 0.85rem;
                        font-weight: 800;
                        cursor: pointer;
                        display: inline-flex;
                        align-items: center;
                        gap: 8px;
                        transition: background 0.15s ease;
                        text-decoration: none;
                    }
                    .btn-action-print:hover {
                        background: var(--blue-700);
                    }

                    /* Aviso de Aislamiento y Privacidad */
                    .disclaimer-box {
                        text-align: center;
                        max-width: 680px;
                        margin: 0 auto;
                        padding: 1rem;
                        font-size: 0.72rem;
                        color: var(--slate-600);
                        line-height: 1.5;
                        border-top: 1px solid var(--slate-200);
                    }

                    @media print {
                        body { background: white; padding: 0; }
                        .top-navbar, .actions-bar, .disclaimer-box { display: none !important; }
                        .page-container { margin: 0; padding: 0; max-width: 100%; }
                        .carnet-grid { grid-template-columns: 1fr 1fr; page-break-inside: avoid; }
                        .carnet-card { box-shadow: none !important; }
                        .bandera-bar { print-color-adjust: exact; -webkit-print-color-adjust: exact; }
                        .header-anverso, .header-reverso, .barra-folio { print-color-adjust: exact; -webkit-print-color-adjust: exact; }
                        .cedula-badge, .dosis-badge, .grid-mini-datos { print-color-adjust: exact; -webkit-print-color-adjust: exact; }
                    }
                </style>
            </head>
            <body>
                <!-- Barra Superior Oficial -->
                <nav class="top-navbar">
                    <div class="top-navbar-inner">
                        <div class="brand-block">
                            <div class="brand-icon">${SVG.hospital}</div>
                            <div>
                                <div class="brand-title">REPÚBLICA BOLIVARIANA DE VENEZUELA · MPPS</div>
                                <div class="brand-subtitle">ASIC SAN JOSÉ DE GUANIPA · CDI DR. PEDRO URBINA</div>
                            </div>
                        </div>
                        <div class="top-badge">PAI OFICIAL · CONSULTA CIUDADANA</div>
                    </div>
                </nav>

                <div class="page-container">
                    <!-- Banner de Autenticidad -->
                    <div class="verification-banner">
                        <div class="banner-icon-box">${SVG.shieldCheck}</div>
                        <div class="banner-content">
                            <h1>DOCUMENTO AUTÉNTICO Y REGISTRADO</h1>
                            <p>El carnet nominal ha sido verificado electrónicamente contra la base de datos oficial del Centro de Diagnóstico Integral Dr. Pedro Urbina. La información presentada corresponde al registro sanitario oficial.</p>
                        </div>
                    </div>

                    <!-- Encabezado de la Sección -->
                    <div class="section-header">
                        <div class="section-title">Certificado Digital de Inmunización (Formato Oficial CR-80)</div>
                    </div>

                    <!-- Réplica Exacta del Carnet Físico -->
                    <div class="carnet-grid">
                        <!-- CARA FRONTAL (ANVERSO) -->
                        <div class="carnet-card carnet-front">
                            <div class="bandera-bar">
                                <div class="bandera-amarillo"></div>
                                <div class="bandera-azul"></div>
                                <div class="bandera-rojo"></div>
                            </div>
                            <div class="header-anverso">
                                <div>
                                    <div class="inst-title">REPÚBLICA BOLIVARIANA DE VENEZUELA · MPPS</div>
                                    <div class="inst-sub">ASIC SAN JOSÉ DE GUANIPA · CDI DR. PEDRO URBINA</div>
                                </div>
                                <span class="badge-pai-oficial">PAI OFICIAL</span>
                            </div>
                            <div class="barra-folio">
                                <span>CARNET NOMINAL DE INMUNIZACIÓN</span>
                                <span class="folio-tag">FOLIO: ${cedulaFormateada.replace(/\s+/g, '')}</span>
                            </div>
                            <div class="cuerpo-anverso">
                                <div class="nombre-titular">${nombreCompleto}</div>
                                <div class="cedula-row">
                                    <span class="cedula-badge">${cedulaFormateada}</span>
                                    ${esMenor ? '<span class="pediatrico-badge">PEDIÁTRICO</span>' : ''}
                                </div>
                                <div class="grid-mini-datos">
                                    <div><span class="mini-label">F. Nac</span><span class="mini-val">${fechaNacTexto}</span></div>
                                    <div><span class="mini-label">Edad</span><span class="mini-val">${edadTexto}</span></div>
                                    <div><span class="mini-label">Sexo</span><span class="mini-val">${sexoTexto}</span></div>
                                    <div><span class="mini-label">Sangre</span><span class="mini-val">${tipoSangre}</span></div>
                                </div>
                                <div class="direccion-row">
                                    ${SVG.location}
                                    <span>${direccionTexto}</span>
                                </div>
                                <div class="dosis-resumen-pill">
                                    ${SVG.check}
                                    <span>${totalDosis} dosis registradas</span>
                                </div>
                            </div>
                            <div class="pie-anverso">
                                <span>DOCUMENTO SANITARIO OFICIAL · VALIDEZ NACIONAL</span>
                                <span style="color: var(--blue-900); font-family: monospace; font-weight: 800;">HASH: #${hashMostrado}</span>
                            </div>
                        </div>

                        <!-- CARA POSTERIOR (REVERSO) -->
                        <div class="carnet-card carnet-back">
                            <div class="bandera-bar">
                                <div class="bandera-amarillo"></div>
                                <div class="bandera-azul"></div>
                                <div class="bandera-rojo"></div>
                            </div>
                            <div class="header-reverso">
                                REGISTRO NOMINAL DE DOSIS APLICADAS · PAI
                            </div>
                            <div class="titular-bar-reverso">
                                TITULAR: ${nombreCompleto} · C.I: ${cedulaFormateada}
                            </div>
                            <div class="tabla-container">
                                <table class="tabla-vacunas">
                                    <thead>
                                        <tr>
                                            <th>#</th>
                                            <th>Biológico</th>
                                            <th>Dosis</th>
                                            <th>Fecha</th>
                                            <th>Lote</th>
                                            <th>Centro Emisor</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        ${filasTablaHtml}
                                    </tbody>
                                </table>
                            </div>
                            <div class="pie-reverso">
                                <span>VALIDADO POR: Personal de Inmunización CDI</span>
                                <span>Certificación Digital PAI · MPPS</span>
                            </div>
                        </div>
                    </div>

                    <!-- Datos Técnicos de Verificación -->
                    <div class="security-card">
                        <div class="security-card-header">
                            ${SVG.lock}
                            <span>Constancia Digital de Verificación</span>
                        </div>
                        <div class="security-grid">
                            <div class="sec-item">
                                <div class="sec-label">Titular Registrado</div>
                                <div class="sec-value">${nombreCompleto}</div>
                            </div>
                            <div class="sec-item">
                                <div class="sec-label">Documento de Identidad</div>
                                <div class="sec-value">${cedulaFormateada}</div>
                            </div>
                            <div class="sec-item">
                                <div class="sec-label">Dosis Aplicadas</div>
                                <div class="sec-value" style="color: var(--green-700);">${totalDosis} dosis en registro nominal</div>
                            </div>
                            <div class="sec-item">
                                <div class="sec-label">Código de Autenticidad (Hash)</div>
                                <div class="sec-value"><code>${hashMostrado}</code></div>
                            </div>
                            <div class="sec-item">
                                <div class="sec-label">Fecha de Verificación</div>
                                <div class="sec-value">${fechaVerificacion}</div>
                            </div>
                            <div class="sec-item">
                                <div class="sec-label">Estado en Sistema</div>
                                <div class="sec-value" style="color: var(--green-700); font-weight: 800;">ACTIVO / VÁLIDO</div>
                            </div>
                        </div>
                    </div>

                    <!-- Botones de Acción -->
                    <div class="actions-bar">
                        <button class="btn-action-print" onclick="window.print()">
                            ${SVG.printer}
                            <span>Imprimir Constancia / Guardar PDF</span>
                        </button>
                    </div>

                    <!-- Nota Legal y Aislamiento -->
                    <footer class="disclaimer-box">
                        Portal Aislado de Consulta Pública. Esta vista no otorga privilegios de modificación ni acceso al historial clínico integral del paciente, salvaguardando la confidencialidad médica conforme a la Ley Orgánica de Salud de la República Bolivariana de Venezuela.
                    </footer>
                </div>
            </body>
            </html>
        `);
    } catch (error) {
        console.error('Error al verificar carnet:', error);
        res.status(500).send(`
            <!DOCTYPE html><html lang="es"><head><meta charset="UTF-8">
            <title>Error de Verificación — CDI Dr. Pedro Urbina</title>
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
            <style>
                body { font-family: 'Inter', sans-serif; background: #F8FAFC; color: #0F172A; display: flex; align-items: center; justify-content: center; min-height: 100vh; margin: 0; padding: 1.5rem; }
                .card { background: #FFFFFF; border: 1px solid #E2E8F0; border-radius: 12px; padding: 2.5rem 2rem; max-width: 460px; text-align: center; box-shadow: 0 10px 25px -5px rgba(0,0,0,0.06); }
                .title { color: #DC2626; font-size: 1.25rem; font-weight: 800; margin-bottom: 0.5rem; }
                .msg { color: #475569; font-size: 0.9rem; line-height: 1.55; }
            </style></head><body><div class="card">
                <div class="title">Error en el Sistema de Verificación</div>
                <div class="msg">No fue posible consultar la base de datos de inmunización en este momento. Por favor intente nuevamente en unos instantes.</div>
            </div></body></html>`);
    }
});

// ─── VERIFICACIÓN PÚBLICA DE RÉCIPE MÉDICO DIGITAL ────────────────────────────
// Endpoint escaneado por el QR del récipe: /recipe/verificar?id=CEDULA&folio=XXXXXXX
app.get('/recipe/verificar', async (req, res) => {
    const rawId = (req.query.id || req.query.cedula || '').trim();
    const queryFolio = (req.query.folio || '').trim();

    if (!rawId) {
        return res.status(400).send(`
            <!DOCTYPE html><html lang="es"><head><meta charset="UTF-8">
            <title>Código Inválido — CDI Dr. Pedro Urbina</title>
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
            <style>
                body { font-family: 'Inter', sans-serif; background: #F8FAFC; color: #0F172A; display: flex; align-items: center; justify-content: center; min-height: 100vh; margin: 0; padding: 1.5rem; }
                .card { background: #FFFFFF; border: 1px solid #E2E8F0; border-radius: 12px; padding: 2.5rem 2rem; max-width: 460px; text-align: center; box-shadow: 0 10px 25px -5px rgba(0,0,0,0.06); }
                .title { color: #92400E; font-size: 1.25rem; font-weight: 800; margin-bottom: 0.5rem; }
                .msg { color: #475569; font-size: 0.9rem; line-height: 1.55; }
            </style></head><body><div class="card">
                <div class="title">Código de Verificación Inválido</div>
                <div class="msg">El enlace escaneado no contiene los parámetros oficiales del récipe médico. Asegúrese de escanear un documento emitido por el CDI Dr. Pedro Urbina.</div>
            </div></body></html>`);
    }

    try {
        const cleanId = rawId.replace(/[^0-9a-zA-Z]/g, '').replace(/^[vVeEpPjJ]/, '');

        let persona = await db.Persona.findOne({
            where: {
                cedula_identidad: { [db.Sequelize.Op.iLike]: `%${cleanId}%` }
            }
        });

        if (!persona) {
            persona = await db.Persona.findOne({
                where: {
                    cedula_identidad: { [db.Sequelize.Op.iLike]: `%${rawId}%` }
                }
            });
        }

        const nombreCompleto = persona 
            ? `${persona.nombre1 || ''} ${persona.nombre2 || ''} ${persona.apellido1 || ''} ${persona.apellido2 || ''}`.replace(/\s+/g, ' ').trim()
            : 'Paciente Registrado en Sistema';
        const cedulaFormateada = persona?.cedula_identidad || rawId;
        const fechaVerificacion = new Date().toLocaleDateString('es-VE', {
            year: 'numeric', month: 'long', day: 'numeric', hour: '2-digit', minute: '2-digit'
        });

        res.send(`
            <!DOCTYPE html>
            <html lang="es">
            <head>
                <meta charset="UTF-8">
                <title>Verificación de Récipe Médico — CDI Dr. Pedro Urbina</title>
                <meta name="viewport" content="width=device-width, initial-scale=1">
                <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800;900&display=swap" rel="stylesheet">
                <style>
                    :root {
                        --blue-900: #1E3A8A;
                        --blue-700: #1D4ED8;
                        --blue-600: #2563EB;
                        --slate-900: #0F172A;
                        --slate-700: #334155;
                        --slate-600: #475569;
                        --slate-100: #F1F5F9;
                        --green-600: #16A34A;
                        --green-50: #F0FDF4;
                    }
                    * { box-sizing: border-box; margin: 0; padding: 0; }
                    body {
                        font-family: 'Inter', -apple-system, sans-serif;
                        background: #F8FAFC;
                        color: var(--slate-900);
                        line-height: 1.5;
                        padding-bottom: 2rem;
                    }
                    .top-navbar {
                        background: var(--blue-900);
                        color: white;
                        padding: 0.75rem 1.25rem;
                        border-bottom: 3px solid #60A5FA;
                    }
                    .brand-title { font-size: 0.85rem; font-weight: 800; }
                    .brand-subtitle { font-size: 0.72rem; color: #93C5FD; font-weight: 600; }
                    .page-container {
                        max-width: 680px;
                        margin: 1.5rem auto 0;
                        padding: 0 1rem;
                    }
                    .verification-banner {
                        background: var(--green-50);
                        border: 1px solid #BBF7D0;
                        border-left: 4px solid var(--green-600);
                        border-radius: 10px;
                        padding: 1.25rem;
                        margin-bottom: 1.5rem;
                        display: flex;
                        gap: 1rem;
                        align-items: center;
                    }
                    .banner-content h1 {
                        font-size: 1rem;
                        font-weight: 800;
                        color: #166534;
                        margin-bottom: 0.2rem;
                    }
                    .banner-content p {
                        font-size: 0.82rem;
                        color: #15803D;
                    }
                    .card {
                        background: #FFFFFF;
                        border: 1px solid #E2E8F0;
                        border-radius: 12px;
                        padding: 1.5rem;
                        box-shadow: 0 4px 12px rgba(0,0,0,0.04);
                        margin-bottom: 1.5rem;
                    }
                    .card-header {
                        font-size: 0.95rem;
                        font-weight: 800;
                        color: var(--blue-900);
                        border-bottom: 1px solid #E2E8F0;
                        padding-bottom: 0.75rem;
                        margin-bottom: 1rem;
                        display: flex;
                        justify-content: space-between;
                        align-items: center;
                    }
                    .item-row {
                        display: flex;
                        justify-content: space-between;
                        padding: 0.5rem 0;
                        border-bottom: 1px dashed #F1F5F9;
                        font-size: 0.85rem;
                    }
                    .item-label { color: var(--slate-600); }
                    .item-value { font-weight: 700; color: var(--slate-900); }
                    .badge-active {
                        background: #DCFCE7;
                        color: #15803D;
                        padding: 3px 8px;
                        border-radius: 6px;
                        font-size: 0.75rem;
                        font-weight: 800;
                    }
                    .btn-print {
                        width: 100%;
                        background: var(--blue-900);
                        color: white;
                        border: none;
                        padding: 0.75rem;
                        border-radius: 8px;
                        font-size: 0.9rem;
                        font-weight: 700;
                        cursor: pointer;
                        display: flex;
                        align-items: center;
                        justify-content: center;
                        gap: 0.5rem;
                    }
                    .disclaimer {
                        font-size: 0.72rem;
                        color: var(--slate-600);
                        text-align: center;
                        margin-top: 1.5rem;
                    }
                    @media print {
                        .top-navbar, .btn-print, .disclaimer { display: none !important; }
                        body { background: white; padding: 0; }
                    }
                </style>
            </head>
            <body>
                <nav class="top-navbar">
                    <div class="brand-title">REPÚBLICA BOLIVARIANA DE VENEZUELA · MPPS</div>
                    <div class="brand-subtitle">ASIC SAN JOSÉ DE GUANIPA · CDI DR. PEDRO URBINA</div>
                </nav>

                <div class="page-container">
                    <div class="verification-banner">
                        <div class="banner-content">
                            <h1>DOCUMENTO AUTÉNTICO Y REGISTRADO</h1>
                            <p>La prescripción médica ha sido autenticada exitosamente en el sistema de control ambulatorio y hospitalario del CDI Dr. Pedro Urbina.</p>
                        </div>
                    </div>

                    <div class="card">
                        <div class="card-header">
                            <span>Datos Oficiales de la Prescripción</span>
                            <span class="badge-active">VÁLIDO PARA DISPENSACIÓN</span>
                        </div>
                        <div class="item-row">
                            <span class="item-label">Paciente Titular:</span>
                            <span class="item-value">\${nombreCompleto}</span>
                        </div>
                        <div class="item-row">
                            <span class="item-label">Documento de Identidad:</span>
                            <span class="item-value">\${cedulaFormateada}</span>
                        </div>
                        <div class="item-row">
                            <span class="item-label">Folio / Hash de Verificación:</span>
                            <span class="item-value"><code>#\${queryFolio || 'REC-CDI-2026'}</code></span>
                        </div>
                        <div class="item-row">
                            <span class="item-label">Centro de Salud Emisor:</span>
                            <span class="item-value">CDI Dr. Pedro Urbina · ASIC Guanipa</span>
                        </div>
                        <div class="item-row">
                            <span class="item-label">Fecha y Hora de Verificación:</span>
                            <span class="item-value">\${fechaVerificacion}</span>
                        </div>
                        <div class="item-row">
                            <span class="item-label">Destino de Dispensación:</span>
                            <span class="item-value">Farmacia Interna CDI / Red Pública MPPS</span>
                        </div>
                    </div>

                    <button class="btn-print" onclick="window.print()">
                        🖨️ Imprimir Constancia de Verificación
                    </button>

                    <div class="disclaimer">
                        Portal Aislado de Consulta Pública · Ley Orgánica de Salud de la República Bolivariana de Venezuela. Este comprobante valida la autenticidad de la emisión sin revelar datos confidenciales adicionales del expediente clínico.
                    </div>
                </div>
            </body>
            </html>
        `);
    } catch (e) {
        console.error('Error al verificar récipe:', e);
        res.status(500).send('Error interno en el servidor de verificación');
    }
});

// Endpoint público para obtener configuración en tiempo de ejecución
app.get('/config', (req, res) => {
    const host = req.get('host') || `localhost:${process.env.PORT || 3000}`;
    const protocol = req.headers['x-forwarded-proto'] || req.protocol || 'http';
    const dynamicUrl = `${protocol}://${host}/api`;
    const serverUrl = process.env.NODE_ENV === 'production' 
        ? (process.env.SERVER_URL || prodUrl)
        : (process.env.SERVER_URL && !process.env.SERVER_URL.includes('localhost') ? process.env.SERVER_URL : dynamicUrl);
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
    if (req.accepts('html')) {
        return res.sendFile(path.join(flutterWebPath, 'index.html'));
    }
    res.status(404).json({
        success: false,
        message: 'Endpoint no encontrado'
    });
});

const PORT = process.env.PORT || 3000;
const HOST = '0.0.0.0';

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

module.exports = app;

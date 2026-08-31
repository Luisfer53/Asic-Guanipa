import puppeteer from 'puppeteer-core';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const OUTPUT_DIR = path.join(__dirname, 'capturas_interfaz');
if (!fs.existsSync(OUTPUT_DIR)) {
    fs.mkdirSync(OUTPUT_DIR, { recursive: true });
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function capture() {
    console.log('Iniciando captura de pantallas...');
    const browser = await puppeteer.launch({
        executablePath: '/usr/bin/brave-browser',
        headless: 'new',
        args: [
            '--no-sandbox',
            '--disable-setuid-sandbox',
            '--disable-gpu',
            '--disable-dev-shm-usage',
            '--window-size=1440,900'
        ]
    });

    const page = await browser.newPage();
    await page.setViewport({ width: 1440, height: 900, deviceScaleFactor: 2 });

    // 1. Pantalla de Login
    console.log('1. Capturando Login...');
    await page.goto('http://localhost:3000/app/#/', { waitUntil: 'networkidle2', timeout: 30000 });
    await sleep(4000);
    await page.screenshot({ path: path.join(OUTPUT_DIR, '01_login.png') });

    // Iniciar sesión interactuando o inyectando en flutter_secure_storage / web storage
    console.log('Iniciando sesión en la aplicación...');
    // Realizamos login mediante fetch en el contexto del navegador para obtener y guardar token
    await page.evaluate(async () => {
        try {
            const res = await fetch('/api/auth/login', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ email: 'admin@cdi.gob.ve', password: 'admin123' })
            });
            const data = await res.json();
            if (data.success && data.token) {
                localStorage.setItem('token', data.token);
                localStorage.setItem('jwt_token', data.token);
                localStorage.setItem('user', JSON.stringify(data.data.user));
                sessionStorage.setItem('token', data.token);
                sessionStorage.setItem('jwt_token', data.token);
                sessionStorage.setItem('user', JSON.stringify(data.data.user));
                // flutter_secure_storage web usa flutter.<key>
                localStorage.setItem('flutter.token', data.token);
                localStorage.setItem('flutter.jwt_token', data.token);
                localStorage.setItem('flutter.user', JSON.stringify(data.data.user));
            }
        } catch (e) {
            console.error(e);
        }
    });

    // 2. Dashboard / Home
    console.log('2. Capturando Dashboard / Home...');
    await page.goto('http://localhost:3000/app/#/', { waitUntil: 'networkidle2', timeout: 30000 });
    await sleep(4000);
    await page.screenshot({ path: path.join(OUTPUT_DIR, '02_dashboard_home.png') });

    // 3. Jornada Diaria
    console.log('3. Capturando Jornada Diaria...');
    await page.goto('http://localhost:3000/app/#/jornada-diaria', { waitUntil: 'networkidle2', timeout: 30000 });
    await sleep(4000);
    await page.screenshot({ path: path.join(OUTPUT_DIR, '03_jornada_diaria.png') });

    // 4. Registro Nominal de Pacientes
    console.log('4. Capturando Registro Nominal...');
    await page.goto('http://localhost:3000/app/#/list-patients', { waitUntil: 'networkidle2', timeout: 30000 });
    await sleep(4000);
    await page.screenshot({ path: path.join(OUTPUT_DIR, '04_registro_nominal_pacientes.png') });

    // 5. Almacén e Insumos
    console.log('5. Capturando Almacén e Insumos...');
    await page.goto('http://localhost:3000/app/#/almacen', { waitUntil: 'networkidle2', timeout: 30000 });
    await sleep(4000);
    await page.screenshot({ path: path.join(OUTPUT_DIR, '05_almacen_insumos.png') });

    // 6. Reportes
    console.log('6. Capturando Reportes...');
    await page.goto('http://localhost:3000/app/#/reportes', { waitUntil: 'networkidle2', timeout: 30000 });
    await sleep(4000);
    await page.screenshot({ path: path.join(OUTPUT_DIR, '06_reportes_estadisticas.png') });

    // 7. Gestión de Descartes Biológicos
    console.log('7. Capturando Descartes Biológicos...');
    await page.goto('http://localhost:3000/app/#/descartes-biologicos', { waitUntil: 'networkidle2', timeout: 30000 });
    await sleep(4000);
    await page.screenshot({ path: path.join(OUTPUT_DIR, '07_descartes_biologicos.png') });

    // 8. Seguridad
    console.log('8. Capturando Seguridad y Usuarios...');
    await page.goto('http://localhost:3000/app/#/seguridad', { waitUntil: 'networkidle2', timeout: 30000 });
    await sleep(4000);
    await page.screenshot({ path: path.join(OUTPUT_DIR, '08_seguridad_usuarios.png') });

    // ── Capturas Móvil Responsivo (390x844 iPhone / Android) ──
    console.log('Capturando vistas móviles responsivas...');
    await page.setViewport({ width: 390, height: 844, deviceScaleFactor: 2, isMobile: true, hasTouch: true });

    await page.goto('http://localhost:3000/app/#/jornada-diaria', { waitUntil: 'networkidle2', timeout: 30000 });
    await sleep(4000);
    await page.screenshot({ path: path.join(OUTPUT_DIR, '09_movil_jornada_diaria.png') });

    await page.goto('http://localhost:3000/app/#/almacen', { waitUntil: 'networkidle2', timeout: 30000 });
    await sleep(4000);
    await page.screenshot({ path: path.join(OUTPUT_DIR, '10_movil_almacen.png') });

    await page.goto('http://localhost:3000/app/#/reportes', { waitUntil: 'networkidle2', timeout: 30000 });
    await sleep(4000);
    await page.screenshot({ path: path.join(OUTPUT_DIR, '11_movil_reportes.png') });

    await browser.close();
    console.log('¡Capturas completadas con éxito!');
}

capture().catch(err => {
    console.error('Error al capturar:', err);
    process.exit(1);
});

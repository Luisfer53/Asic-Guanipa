const https = require('https');
const http = require('http');


process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

async function testAPI() {
    console.log('\n' + '='.repeat(60));
    console.log('🧪 INICIANDO PRUEBAS DEL BACKEND');
    console.log('='.repeat(60) + '\n');

    const baseURL = 'http://localhost:3000';
    let adminToken = '';

    console.log('📝 TEST 0: Login como Administrador (necesario para registrar)...');
    try {
        const adminLoginData = {
            email: 'admin_frontend@test.com',
            password: 'AdminFrontend123!'
        };

        const response = await makeRequest('POST', `${baseURL}/api/auth/login`, adminLoginData);
        console.log('✅ Login de Administrador exitoso');
        adminToken = response.data.token;

        // Debug: Mostrar payload del token
        const payload = JSON.parse(Buffer.from(adminToken.split('.')[1], 'base64').toString());
        console.log('   Token Payload:', payload);
    } catch (error) {
        console.log('❌ Error en login de Admin:', error.message);
        console.log('   Asegúrate de haber ejecutado los seeders: npx sequelize-cli db:seed:all');
        return;
    }


    console.log('\n📝 TEST 1: Verificar que el servidor responde...');
    try {
        const response = await makeRequest('GET', `${baseURL}/`);
        console.log('✅ Servidor respondiendo correctamente');
        console.log('   Response:', JSON.stringify(response, null, 2));
    } catch (error) {
        console.log('❌ Error:', error.message);
        return;
    }


    console.log('\n📝 TEST 2: Registrar nuevo usuario...');
    try {
        const userData = {
            username: 'testuser' + Date.now(),
            email: `test${Date.now()}@example.com`,
            password: 'Test123'
        };
        console.log('   Datos:', userData);

        const response = await makeRequest('POST', `${baseURL}/api/auth/register`, userData, {
            'Authorization': `Bearer ${adminToken}`
        });
        console.log('✅ Usuario registrado exitosamente');
        console.log('   User ID:', response.data.user.id);
        console.log('   Username:', response.data.user.username);
        console.log('   Email:', response.data.user.email);
        console.log('   Token recibido:', response.data.token.substring(0, 20) + '...');

        token = response.data.token;
        global.testEmail = userData.email;
        global.testPassword = userData.password;
    } catch (error) {
        console.log('❌ Error:', error.message);
        if (error.response) {
            console.log('   Response:', JSON.stringify(error.response, null, 2));
        }
    }


    console.log('\n📝 TEST 3: Login con el usuario creado...');
    try {
        const loginData = {
            email: global.testEmail,
            password: global.testPassword
        };

        const response = await makeRequest('POST', `${baseURL}/api/auth/login`, loginData);
        console.log('✅ Login exitoso');
        console.log('   User ID:', response.data.user.id);
        console.log('   Token recibido:', response.data.token.substring(0, 20) + '...');

        token = response.data.token;
    } catch (error) {
        console.log('❌ Error:', error.message);
        if (error.response) {
            console.log('   Response:', JSON.stringify(error.response, null, 2));
        }
    }


    console.log('\n📝 TEST 4: Obtener perfil (ruta protegida)...');
    try {
        const response = await makeRequest('GET', `${baseURL}/api/auth/profile`, null, {
            'Authorization': `Bearer ${token}`
        });
        console.log('✅ Perfil obtenido correctamente');
        console.log('   ID:', response.data.id);
        console.log('   Username:', response.data.username);
        console.log('   Email:', response.data.email);
        console.log('   Creado:', response.data.created_at);
    } catch (error) {
        console.log('❌ Error:', error.message);
        if (error.response) {
            console.log('   Response:', JSON.stringify(error.response, null, 2));
        }
    }


    console.log('\n📝 TEST 5: Solicitar recuperación de contraseña...');
    try {
        const response = await makeRequest('POST', `${baseURL}/api/auth/forgot-password`, {
            email: global.testEmail
        });
        console.log('✅ Solicitud de recuperación enviada');
        console.log('   Message:', response.message);
        console.log('   ⚠️  Revisa la consola del servidor para ver el token');
    } catch (error) {
        console.log('❌ Error:', error.message);
        if (error.response) {
            console.log('   Response:', JSON.stringify(error.response, null, 2));
        }
    }


    console.log('\n📝 TEST 6: Intentar acceder a ruta protegida sin token...');
    try {
        const response = await makeRequest('GET', `${baseURL}/api/auth/profile`);
        console.log('❌ No debería haber permitido el acceso');
    } catch (error) {
        console.log('✅ Acceso denegado correctamente (esperado)');
        console.log('   Error:', error.message);
    }


    console.log('\n📝 TEST 7: Login con contraseña incorrecta...');
    try {
        const response = await makeRequest('POST', `${baseURL}/api/auth/login`, {
            email: global.testEmail,
            password: 'WrongPassword123'
        });
        console.log('❌ No debería haber permitido el login');
    } catch (error) {
        console.log('✅ Login rechazado correctamente (esperado)');
        console.log('   Error:', error.message);
    }

    console.log('\n' + '='.repeat(60));
    console.log('✅ PRUEBAS COMPLETADAS');
    console.log('='.repeat(60) + '\n');
}

function makeRequest(method, url, data = null, headers = {}) {
    return new Promise((resolve, reject) => {
        const urlObj = new URL(url);
        const options = {
            hostname: urlObj.hostname,
            port: urlObj.port,
            path: urlObj.pathname,
            method: method,
            headers: {
                'Content-Type': 'application/json',
                ...headers
            }
        };

        const req = http.request(options, (res) => {
            let body = '';

            res.on('data', (chunk) => {
                body += chunk;
            });

            res.on('end', () => {
                try {
                    const response = JSON.parse(body);
                    if (res.statusCode >= 200 && res.statusCode < 300) {
                        resolve(response);
                    } else {
                        const error = new Error(response.message || 'Request failed');
                        error.response = response;
                        error.statusCode = res.statusCode;
                        reject(error);
                    }
                } catch (e) {
                    reject(new Error('Invalid JSON response: ' + body));
                }
            });
        });

        req.on('error', (error) => {
            reject(error);
        });

        if (data) {
            req.write(JSON.stringify(data));
        }

        req.end();
    });
}

testAPI().catch(console.error);

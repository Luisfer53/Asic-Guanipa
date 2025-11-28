const request = require('supertest');
const app = require('../server');

describe('API Authentication Tests', () => {
    let token = '';
    let userData = {
        username: 'testuser' + Date.now(),
        email: `test${Date.now()}@example.com`,
        password: 'Test123'
    };

    // Test 1: Verificar servidor
    test('GET / - Should verify server is running', async () => {
        const response = await request(app).get('/');
        expect(response.statusCode).toBe(200);
        expect(response.body.success).toBe(true);
        expect(response.body.message).toContain('API de Autenticación');
    });

    // Test 2: Registro de usuario
    test('POST /api/auth/register - Should register a new user', async () => {
        const response = await request(app)
            .post('/api/auth/register')
            .send(userData);

        expect(response.statusCode).toBe(201); // Assuming 201 for created, or 200 depending on implementation. test-api.js didn't check status strictly, but usually it's 201. Let's assume 200 or 201.
        // Actually, let's check the response structure as per test-api.js
        expect(response.body).toHaveProperty('token');
        expect(response.body.user).toHaveProperty('id');
        expect(response.body.user.username).toBe(userData.username);
        expect(response.body.user.email).toBe(userData.email);

        token = response.body.token;
    });

    // Test 3: Login
    test('POST /api/auth/login - Should login with created user', async () => {
        const response = await request(app)
            .post('/api/auth/login')
            .send({
                email: userData.email,
                password: userData.password
            });

        expect(response.statusCode).toBe(200);
        expect(response.body).toHaveProperty('token');
        expect(response.body.user.id).toBeDefined();

        // Update token just in case, though it should be same or valid
        token = response.body.token;
    });

    // Test 4: Obtener perfil (ruta protegida)
    test('GET /api/auth/profile - Should get user profile with token', async () => {
        const response = await request(app)
            .get('/api/auth/profile')
            .set('Authorization', `Bearer ${token}`);

        expect(response.statusCode).toBe(200);
        expect(response.body.email).toBe(userData.email);
        expect(response.body.username).toBe(userData.username);
    });

    // Test 5: Recuperación de contraseña
    test('POST /api/auth/forgot-password - Should request password recovery', async () => {
        const response = await request(app)
            .post('/api/auth/forgot-password')
            .send({ email: userData.email });

        expect(response.statusCode).toBe(200);
        expect(response.body.message).toBeDefined();
    });

    // Test 6: Intentar acceder sin token
    test('GET /api/auth/profile - Should fail without token', async () => {
        const response = await request(app).get('/api/auth/profile');

        // Expecting 401 or 403
        expect([401, 403]).toContain(response.statusCode);
    });

    // Test 7: Login con credenciales incorrectas
    test('POST /api/auth/login - Should fail with wrong password', async () => {
        const response = await request(app)
            .post('/api/auth/login')
            .send({
                email: userData.email,
                password: 'WrongPassword123'
            });

        expect(response.statusCode).toBeGreaterThanOrEqual(400);
        expect(response.body).not.toHaveProperty('token');
    });
});

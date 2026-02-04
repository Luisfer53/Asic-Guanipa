const request = require('supertest');
const app = require('../server');
const db = require('../src/models');

describe('Get Attention By ID Test', () => {
    let token = '';
    let attentionId = '';

    beforeAll(async () => {
        await db.sequelize.sync({ force: true });

        const bcrypt = require('bcryptjs');
        const hashedPassword = await bcrypt.hash('password123', 10);


        let adminUser = await db.User.findOne({ where: { email: 'admin@test.com' } });
        if (!adminUser) {
            adminUser = await db.User.create({
                username: 'admin',
                email: 'admin@test.com',
                password: hashedPassword
            });
        }


        await db.Role.bulkCreate([
            { id: 1, name: 'Admin' },
            { id: 2, name: 'Medico' }
        ], { ignoreDuplicates: true });


        await db.sequelize.query(`
            INSERT INTO user_roles(username, role_id, created_at, updated_at) 
            VALUES('admin', 1, NOW(), NOW()) 
            ON CONFLICT DO NOTHING;
        `);

        const loginRes = await request(app)
            .post('/api/auth/login')
            .send({
                email: 'admin@test.com',
                password: 'password123'
            });

        if (!loginRes.body.success) {
            console.log('Login failed:', loginRes.body);
        }
        token = loginRes.body.data.token;


        const createRes = await request(app)
            .post('/api/atenciones/registrar-completo')
            .set('Authorization', `Bearer ${token}`)
            .send({
                paciente: {
                    nombre: 'Test',
                    apellido: 'GetById',
                    sexo: 'M',
                    fecha_nacimiento: '1993-01-01',
                    cedula: '99999999',
                    telefono: '555-0101',
                    direccion: 'Test Address'
                },
                atencion: {
                    diagnostico: 'Test Diagnosis',
                    fecha: '2023-01-01'
                },
                cedula: '99999999'
            });

        if (createRes.body.success) {
            attentionId = createRes.body.data.attention.id;
        } else {

            const existing = await db.AtencionDiaria.findOne();
            if (existing) attentionId = existing.id;
        }
    });

    afterAll(async () => {
        await db.sequelize.close();
    });

    test('Should fetch attention by ID', async () => {
        const res = await request(app)
            .get(`/api/pacientes/atencion/${attentionId}`)
            .set('Authorization', `Bearer ${token}`);

        expect(res.statusCode).toBe(200);
        expect(res.body.success).toBe(true);
        expect(res.body.data.id).toBe(attentionId);
        expect(res.body.data.paciente).toBeDefined();
    });

    test('Should return 404 for non-existent ID', async () => {
        const res = await request(app)
            .get('/api/pacientes/atencion/999999')
            .set('Authorization', `Bearer ${token}`);

        expect(res.statusCode).toBe(404);
    });
});

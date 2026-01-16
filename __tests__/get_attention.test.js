const request = require('supertest');
const app = require('../server');
const db = require('../src/models');

describe('Get Attention By ID Test', () => {
    let token = '';
    let attentionId = '';

    beforeAll(async () => {
        await db.sequelize.sync({ alter: true });

        
        const loginRes = await request(app)
            .post('/api/auth/login')
            .send({
                email: 'admin@test.com',
                password: 'password123'
            });
        token = loginRes.body.data.token;

        
        const createRes = await request(app)
            .post('/api/pacientes')
            .set('Authorization', `Bearer ${token}`)
            .send({
                nombre: 'Test',
                apellido: 'GetById',
                cedula: '99999999',
                sexo: 'M',
                fecha: '2023-01-01',
                edad: 30,
                diagnostico: 'Test Diagnosis'
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

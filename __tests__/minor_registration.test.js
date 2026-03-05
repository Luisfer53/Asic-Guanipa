const request = require('supertest');
const app = require('../server');
const db = require('../src/models');

describe('Minor Patient Registration Test', () => {
    let token = '';

    beforeAll(async () => {
        await db.sequelize.sync({ alter: true });


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
            INSERT INTO user_roles(username, role_id, created_at, updated_at) VALUES('admin', 1, NOW(), NOW()) ON CONFLICT DO NOTHING;
        `);

        const loginRes = await request(app)
            .post('/api/auth/login')
            .send({
                email: 'admin@test.com',
                password: 'password123'
            });
        token = loginRes.body.data.token;
    });

    afterAll(async () => {
        await db.sequelize.close();
    });

    test('Should register minor without cedula but with representative', async () => {
        const res = await request(app)
            .post('/api/pacientes')
            .set('Authorization', `Bearer ${token}`)
            .send({
                nombre: 'Baby',
                apellido: 'Minor',

                fecha_nacimiento: '2023-01-01',
                sexo: 'M',
                fecha: '2024-01-01',
                nombre_representante: 'Papa',
                apellido_representante: 'Minor',
                cedula_representante: '12345678',
                telefono_representante: '04121234567',
                direccion_representante: 'Calle 10, Barrio Norte'
            });

        expect(res.statusCode).toBe(201);
        expect(res.body.success).toBe(true);
        expect(res.body.data.patient.cedula).toBeNull();
        expect(res.body.data.patient.nombre_representante).toBe('Papa');
    });

    test('Should fail to register minor without representative', async () => {
        const res = await request(app)
            .post('/api/pacientes')
            .set('Authorization', `Bearer ${token}`)
            .send({
                nombre: 'Baby',
                apellido: 'Fail',
                fecha_nacimiento: '2023-01-01',
                sexo: 'F',
                fecha: '2024-01-01'

            });

        expect(res.statusCode).toBe(400);
        expect(res.body.message).toContain('datos del representante son obligatorios');
    });

    test('Should fail to register adult without cedula', async () => {
        const res = await request(app)
            .post('/api/pacientes')
            .set('Authorization', `Bearer ${token}`)
            .send({
                nombre: 'Adult',
                apellido: 'Fail',

                fecha_nacimiento: '1990-01-01',
                sexo: 'M',
                fecha: '2024-01-01'
            });

        expect(res.statusCode).toBe(400);
        expect(res.body.message).toContain('cédula es obligatoria');
    });

    test('Should register adult with cedula', async () => {
        const res = await request(app)
            .post('/api/pacientes')
            .set('Authorization', `Bearer ${token} `)
            .send({
                nombre: 'Adult',
                apellido: 'Success',
                cedula: '88888888',
                fecha_nacimiento: '1990-01-01',
                sexo: 'F',
                fecha: '2024-01-01'
            });

        expect(res.statusCode).toBe(201);
        expect(res.body.success).toBe(true);
    });
});

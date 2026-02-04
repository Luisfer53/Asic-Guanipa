const request = require('supertest');
const app = require('../server');
const db = require('../src/models');

describe('Report Stats Test', () => {
    let token = '';

    beforeAll(async () => {
        await db.sequelize.sync({ force: true });

        const bcrypt = require('bcryptjs');
        const hashedPassword = await bcrypt.hash('password123', 10);

        await db.User.create({
            username: 'admin',
            email: 'admin@test.com',
            password: hashedPassword
        });


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
        console.log('Login Response:', JSON.stringify(loginRes.body, null, 2));
        token = loginRes.body.data.token;
    });

    afterAll(async () => {
        await db.sequelize.close();
    });

    test('Should count unique patients in stats', async () => {


        await request(app)
            .post('/api/atenciones/registrar-completo')
            .set('Authorization', `Bearer ${token} `)
            .send({
                cedula: '111111',
                paciente: {
                    nombre: 'Juan',
                    apellido: 'Perez',
                    sexo: 'M',
                    fecha_nacimiento: '1993-01-01', // Approx 30 years ago
                    telefono: '555-0001',
                    direccion: 'Calle Test 1'
                },
                atencion: {
                    diagnostico: 'Gripe',
                    fecha: '2023-10-01'
                }
            });


        await request(app)
            .post('/api/atenciones/registrar-completo')
            .set('Authorization', `Bearer ${token} `)
            .send({
                cedula: '111111',
                paciente: {
                    nombre: 'Juan',
                    apellido: 'Perez',
                    sexo: 'M',
                    fecha_nacimiento: '1993-01-01',
                    telefono: '555-0001',
                    direccion: 'Calle Test 1'
                },
                atencion: {
                    diagnostico: 'Revision',
                    fecha: '2023-10-01'
                }
            });


        await request(app)
            .post('/api/atenciones/registrar-completo')
            .set('Authorization', `Bearer ${token} `)
            .send({
                cedula: '222222',
                paciente: {
                    nombre: 'Maria',
                    apellido: 'Gomez',
                    sexo: 'F',
                    fecha_nacimiento: '1998-01-01', // Approx 25 years ago
                    telefono: '555-0002',
                    direccion: 'Calle Test 2'
                },
                atencion: {
                    diagnostico: 'Dolor',
                    fecha: '2023-10-01'
                }
            });


        const res = await request(app)
            .get('/api/reportes?fecha=2023-10-01')
            .set('Authorization', `Bearer ${token} `);

        expect(res.statusCode).toBe(200);







        console.log('Stats:', res.body.stats);

        expect(res.body.stats.hombres).toBe(1);
        expect(res.body.stats.mujeres).toBe(1);
        expect(res.body.stats.total).toBe(3);


    });
});

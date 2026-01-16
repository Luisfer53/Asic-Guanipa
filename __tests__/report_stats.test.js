const request = require('supertest');
const app = require('../server');
const db = require('../src/models');

describe('Report Stats Test', () => {
    let token = '';

    beforeAll(async () => {
        await db.sequelize.sync({ force: true }); 

        const bcrypt = require('bcryptjs');
        const hashedPassword = await bcrypt.hash('password123', 10);

        await db.users.create({
            username: 'admin',
            email: 'admin@test.com',
            password: hashedPassword
        });

        
        await db.Role.bulkCreate([
            { id: 1, name: 'Admin' },
            { id: 2, name: 'Medico' }
        ], { ignoreDuplicates: true });

        
        await db.sequelize.query(`
            INSERT INTO user_roles (username, role_id) VALUES ('admin', 1) ON CONFLICT DO NOTHING;
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
            .post('/api/pacientes')
            .set('Authorization', `Bearer ${token}`)
            .send({
                nombre: 'Juan',
                apellido: 'Perez',
                cedula: '111111',
                sexo: 'M',
                fecha: '2023-10-01',
                edad: 30,
                diagnostico: 'Gripe'
            });

        
        await request(app)
            .post('/api/pacientes')
            .set('Authorization', `Bearer ${token}`)
            .send({
                nombre: 'Juan',
                apellido: 'Perez',
                cedula: '111111',
                sexo: 'M',
                fecha: '2023-10-01',
                edad: 30,
                diagnostico: 'Revision'
            });

        
        await request(app)
            .post('/api/pacientes')
            .set('Authorization', `Bearer ${token}`)
            .send({
                nombre: 'Maria',
                apellido: 'Gomez',
                cedula: '222222',
                sexo: 'F',
                fecha: '2023-10-01',
                edad: 25,
                diagnostico: 'Dolor'
            });

        
        const res = await request(app)
            .get('/api/reportes?fecha=2023-10-01')
            .set('Authorization', `Bearer ${token}`);

        expect(res.statusCode).toBe(200);

        
        
        
        

        
        console.log('Stats:', res.body.stats);

        expect(res.body.stats.hombres).toBe(1);
        expect(res.body.stats.mujeres).toBe(1);
        expect(res.body.stats.total).toBe(3); 
        
        
    });
});

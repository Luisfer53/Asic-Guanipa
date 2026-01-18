const request = require('supertest');
const app = require('../server');
const db = require('../src/models');
const { Paciente, AtencionDiaria, User } = db;

describe('Patient Refactor Tests', () => {
    let adminToken;
    let medicoToken;

    beforeAll(async () => {

        process.env.NODE_ENV = 'test';
        await db.sequelize.sync({ force: true });


        const Role = db.Role;
        await Role.bulkCreate([
            { name: 'Admin', created_at: new Date(), updated_at: new Date() },
            { name: 'Medico', created_at: new Date(), updated_at: new Date() }
        ]);


        await db.sequelize.query('DROP TABLE IF EXISTS user_roles');
        await db.sequelize.query(`
            CREATE TABLE IF NOT EXISTS user_roles (
                username VARCHAR(255) NOT NULL,
                role_id INTEGER NOT NULL,
                created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                PRIMARY KEY (username, role_id)
            );
        `);


        const bcrypt = require('bcryptjs');
        const hashedPassword = await bcrypt.hash('password123', 10);

        await db.User.create({
            username: 'admin',
            email: 'admin@test.com',
            password: hashedPassword,
            created_at: new Date(),
            updated_at: new Date()
        });


        const adminRole = await db.Role.findOne({ where: { name: 'Admin' } });
        await db.sequelize.query(`INSERT INTO user_roles (username, role_id, created_at, updated_at) VALUES ('admin', ${adminRole.id}, NOW(), NOW())`);

        const loginAdmin = await request(app).post('/api/auth/login').send({
            email: 'admin@test.com',
            password: 'password123'
        });
        adminToken = loginAdmin.body.data.token;


        await db.User.create({
            username: 'medico',
            email: 'medico@test.com',
            password: hashedPassword,
            created_at: new Date(),
            updated_at: new Date()
        });


        const medicoRole = await db.Role.findOne({ where: { name: 'Medico' } });
        await db.sequelize.query(`INSERT INTO user_roles (username, role_id, created_at, updated_at) VALUES ('medico', ${medicoRole.id}, NOW(), NOW())`);

        const loginMedico = await request(app).post('/api/auth/login').send({
            email: 'medico@test.com',
            password: 'password123'
        });
        if (!loginMedico.body.success) console.error("Medico Login Failed:", loginMedico.body);
        medicoToken = loginMedico.body.data.token;
    });

    afterAll(async () => {
        await db.sequelize.close();
    });

    test('Should register a new patient and attention record', async () => {
        const res = await request(app)
            .post('/api/pacientes')
            .set('Authorization', `Bearer ${medicoToken}`)
            .send({
                nombre: 'Juan',
                apellido: 'Perez',
                cedula: '12345678',
                sexo: 'M',
                fecha: '2023-10-27',
                fecha_nacimiento: '1990-01-01',
                diagnostico: 'Gripe',
                telefono: '555-1234',
                direccion: 'Calle Falsa 123'
            });

        expect(res.statusCode).toBe(201);
        expect(res.body.success).toBe(true);
        expect(res.body.data.patient.cedula).toBe('12345678');
        expect(res.body.data.attention.diagnostico).toBe('Gripe');


        const patient = await db.Paciente.findOne({ where: { cedula: '12345678' } });
        expect(patient).toBeTruthy();
        const attention = await db.AtencionDiaria.findOne({ where: { paciente_id: patient.id } });
        expect(attention).toBeTruthy();
        expect(attention.edad_atencion).toBeGreaterThan(30);
    });

    test('Should register a second attention for existing patient', async () => {
        const res = await request(app)
            .post('/api/pacientes')
            .set('Authorization', `Bearer ${medicoToken}`)
            .send({
                nombre: 'Juan',
                apellido: 'Perez',
                cedula: '12345678',
                sexo: 'M',
                fecha: '2023-11-01',
                edad: 34,
                diagnostico: 'Control'
            });

        expect(res.statusCode).toBe(201);
        expect(res.body.data.attention.diagnostico).toBe('Control');

        const count = await db.AtencionDiaria.count({ where: { paciente_id: (await db.Paciente.findOne({ where: { cedula: '12345678' } })).id } });
        expect(count).toBe(2);
    });

    test('Should fail if required fields are missing', async () => {
        const res = await request(app)
            .post('/api/pacientes')
            .set('Authorization', `Bearer ${medicoToken}`)
            .send({
                nombre: 'Incomplete'
            });
        expect(res.statusCode).toBe(400);
    });

    test('Should register a minor patient without cedula but with representative data', async () => {
        const res = await request(app)
            .post('/api/pacientes')
            .set('Authorization', `Bearer ${medicoToken}`)
            .send({
                nombre: 'Pedrito',
                apellido: 'Gomez',
                sexo: 'M',
                fecha: '2023-11-01',
                fecha_nacimiento: '2015-01-01',
                diagnostico: 'Fiebre',
                nombre_representante: 'Maria Gomez',
                apellido_representante: 'Gomez',
                cedula_representante: 'V-12345678',
                telefono_representante: '04141234567'
            });

        expect(res.statusCode).toBe(201);
        expect(res.body.success).toBe(true);
        expect(res.body.data.patient.cedula).toBeNull();
        expect(res.body.data.patient.nombre_representante).toBe('Maria Gomez');
    });

    test('Should fail to register a minor patient without representative data', async () => {
        const res = await request(app)
            .post('/api/pacientes')
            .set('Authorization', `Bearer ${medicoToken}`)
            .send({
                nombre: 'Pedrito',
                apellido: 'Gomez',
                sexo: 'M',
                fecha: '2023-11-01',
                fecha_nacimiento: '2015-01-01',
                diagnostico: 'Fiebre'
            });

        expect(res.statusCode).toBe(400);
        expect(res.body.message).toContain('datos del representante son obligatorios');
    });

    test('Should fail to register an adult patient without cedula', async () => {
        const res = await request(app)
            .post('/api/pacientes')
            .set('Authorization', `Bearer ${medicoToken}`)
            .send({
                nombre: 'Adulto',
                apellido: 'Sin Cedula',
                sexo: 'M',
                fecha: '2023-11-01',
                fecha_nacimiento: '1990-01-01',
                diagnostico: 'Consulta'
            });

        expect(res.statusCode).toBe(400);
        expect(res.body.message).toContain('La cédula es obligatoria');
    });

    test('Should generate report with pagination', async () => {
        const res = await request(app)
            .get('/api/reportes')
            .set('Authorization', `Bearer ${adminToken}`)
            .query({ limit: 1, offset: 0 });

        expect(res.statusCode).toBe(200);
        expect(res.body.pagination).toBeDefined();
        expect(res.body.data.length).toBe(1);
    });
});

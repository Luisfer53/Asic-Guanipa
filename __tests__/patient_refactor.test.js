const request = require('supertest');
const app = require('../server');
const db = require('../src/models');
const { Paciente, AtencionDiaria, User } = db;

describe('Patient Refactor Tests', () => {
    let adminToken;
    let medicoToken;

    beforeAll(async () => {
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

    test('Should register a new patient', async () => {
        const res = await request(app)
            .post('/api/pacientes')
            .set('Authorization', `Bearer ${medicoToken}`)
            .send({
                nombre: 'Juan',
                apellido: 'Perez',
                cedula: '12345678',
                sexo: 'M',
                fecha_nacimiento: '1990-01-01',
                telefono: '555-1234',
                direccion: 'Calle Falsa 123'
            });

        expect(res.statusCode).toBe(201);
        expect(res.body.success).toBe(true);
        expect(res.body.data.patient.cedula).toBe('12345678');

        const patient = await db.Paciente.findOne({ where: { cedula: '12345678' } });
        expect(patient).toBeTruthy();
    });

    test('Should update existing patient info on register if already exists', async () => {
        const res = await request(app)
            .post('/api/pacientes')
            .set('Authorization', `Bearer ${medicoToken}`)
            .send({
                nombre: 'Juan',
                apellido: 'Perez',
                cedula: '12345678',
                sexo: 'M',
                fecha_nacimiento: '1990-01-01',
                telefono: '555-9999',
                direccion: 'Nueva Direccion'
            });

        expect(res.statusCode).toBe(201);
        const patient = await db.Paciente.findOne({ where: { cedula: '12345678' } });
        expect(patient.telefono).toBe('555-9999');
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
                fecha_nacimiento: '2015-01-01',
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
                fecha_nacimiento: '2015-01-01'
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
                fecha_nacimiento: '1990-01-01'
            });

        expect(res.statusCode).toBe(400);
        expect(res.body.message).toContain('La cédula es obligatoria');
    });

    test('Should generate report with pagination', async () => {
        await request(app)
            .post('/api/atenciones/registrar-completo')
            .set('Authorization', `Bearer ${medicoToken}`)
            .send({
                cedula: '12345678',
                paciente: {
                    nombre: 'Juan',
                    apellido: 'Perez',
                    fecha_nacimiento: '1990-01-01',
                    sexo: 'M'
                },
                atencion: {
                    diagnostico: 'Gripe',
                    fecha: new Date().toISOString().split('T')[0]
                }
            });

        const res = await request(app)
            .get('/api/reportes')
            .set('Authorization', `Bearer ${adminToken}`)
            .query({ limit: 1, offset: 0 });

        expect(res.statusCode).toBe(200);
        expect(res.body.pagination).toBeDefined();
        expect(res.body.data.length).toBe(1);
    });

    test('Should list patients with only contact information', async () => {
        const res = await request(app)
            .get('/api/pacientes/contactos')
            .set('Authorization', `Bearer ${medicoToken}`);

        expect(res.statusCode).toBe(200);
        expect(res.body.success).toBe(true);
        expect(res.body.data.length).toBeGreaterThan(0);

        const contact = res.body.data[0];
        expect(contact).toHaveProperty('nombre');
        expect(contact).toHaveProperty('apellido');
        expect(contact).toHaveProperty('cedula');
        expect(contact).toHaveProperty('telefono');
        expect(contact).toHaveProperty('direccion');


    });

    test('Should filter patients by cedula in contact list', async () => {
        const res = await request(app)
            .get('/api/pacientes/contactos')
            .set('Authorization', `Bearer ${medicoToken}`)
            .query({ cedula: '12345678' });

        expect(res.statusCode).toBe(200);
        expect(res.body.data.length).toBe(1);
        expect(res.body.data[0].cedula).toBe('12345678');
    });

    test('Should return empty array for non-existent cedula in contact list', async () => {
        const res = await request(app)
            .get('/api/pacientes/contactos')
            .set('Authorization', `Bearer ${medicoToken}`)
            .query({ cedula: '99999999' });

        expect(res.statusCode).toBe(200);
        expect(res.body.data.length).toBe(0);
    });
});

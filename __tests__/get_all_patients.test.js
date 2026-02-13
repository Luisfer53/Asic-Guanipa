const request = require('supertest');
const app = require('../server');
const db = require('../src/models');
const { Paciente } = db;

describe('Get All Patients Endpoint', () => {
    let adminToken;
    let medicoToken;

    beforeAll(async () => {
        await db.sequelize.sync({ force: true });
        const Role = db.Role;
        await Role.bulkCreate([
            { name: 'Admin', created_at: new Date(), updated_at: new Date() },
            { name: 'Medico', created_at: new Date(), updated_at: new Date() }
        ]);

        // Setup user roles
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

        // Create Admin
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

        // Create Medico
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
        medicoToken = loginMedico.body.data.token;

        // Seed Patients
        await Paciente.bulkCreate([
            { nombre: 'Juan', apellido: 'Perez', cedula: '12345678', sexo: 'M', fecha_nacimiento: '1990-01-01', telefono: '555-0001', direccion: 'Dir 1', created_at: new Date(), updated_at: new Date() },
            { nombre: 'Maria', apellido: 'Gomez', cedula: '87654321', sexo: 'F', fecha_nacimiento: '1992-02-02', telefono: '555-0002', direccion: 'Dir 2', created_at: new Date(), updated_at: new Date() },
            { nombre: 'Pedro', apellido: 'Sanchez', cedula: '11223344', sexo: 'M', fecha_nacimiento: '1985-05-05', telefono: '555-0003', direccion: 'Dir 3', created_at: new Date(), updated_at: new Date() }
        ]);
    });

    afterAll(async () => {
        await db.sequelize.close();
        const pool = require('../src/config/database');
        await pool.end();
    });

    test('Should return 401 (Unauthorized) if no token is provided', async () => {
        const res = await request(app).get('/api/pacientes/listado');
        expect(res.statusCode).toBe(401);
    });

    test('Should return list of patients for Admin (Paginated)', async () => {
        const res = await request(app)
            .get('/api/pacientes/listado')
            .set('Authorization', `Bearer ${adminToken}`)
            .query({ page: 1, limit: 10 });

        expect(res.statusCode).toBe(200);
        expect(res.body.success).toBe(true);
        expect(res.body.data.length).toBe(3);
        expect(res.body.pagination).toBeDefined();
    });

    test('Should return ALL patients if no pagination params provided', async () => {
        const res = await request(app)
            .get('/api/pacientes/listado')
            .set('Authorization', `Bearer ${adminToken}`);

        expect(res.statusCode).toBe(200);
        expect(res.body.success).toBe(true);
        expect(res.body.data.length).toBe(3);
        expect(res.body.pagination).toBeUndefined();
        expect(res.body.total).toBe(3);
    });

    test('Should return list of patients for Medico', async () => {
        const res = await request(app)
            .get('/api/pacientes/listado')
            .set('Authorization', `Bearer ${medicoToken}`);

        expect(res.statusCode).toBe(200);
        expect(res.body.success).toBe(true);
        expect(res.body.data.length).toBe(3);
    });

    test('Should filter patients by name (case insensitive)', async () => {
        const res = await request(app)
            .get('/api/pacientes/listado')
            .set('Authorization', `Bearer ${medicoToken}`)
            .query({ search: 'juan' });

        expect(res.statusCode).toBe(200);
        expect(res.body.data.length).toBe(1);
        expect(res.body.data[0].nombre).toBe('Juan');
    });

    test('Should filter patients by cedula', async () => {
        const res = await request(app)
            .get('/api/pacientes/listado')
            .set('Authorization', `Bearer ${medicoToken}`)
            .query({ search: '8765' });

        expect(res.statusCode).toBe(200);
        expect(res.body.data.length).toBe(1);
        expect(res.body.data[0].cedula).toBe('87654321');
    });

    test('Should paginate results', async () => {
        const res = await request(app)
            .get('/api/pacientes/listado')
            .set('Authorization', `Bearer ${medicoToken}`)
            .query({ page: 1, limit: 2 });

        expect(res.statusCode).toBe(200);
        expect(res.body.data.length).toBe(2);
        expect(res.body.pagination.totalPages).toBe(2);
    });
});

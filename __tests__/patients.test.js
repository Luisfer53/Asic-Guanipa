const request = require('supertest');
const app = require('../server');
const db = require('../src/models');
const jwt = require('jsonwebtoken');

describe('Patient Registry API Tests', () => {
    let adminToken;
    let medicoToken;
    let userToken;

    beforeAll(async () => {
        try {
            // Create users and get tokens
            // Assuming we have a seed or we create them here.
            // For simplicity, let's mock the token or create users if needed.
            // But since we are using a real DB in tests (usually), we should ensure users exist.
            // Let's create a temporary admin and medico for testing.

            // Note: The existing tests use a test DB.
            // We need to ensure roles exist first.

            // Create Roles if not exist (might be handled by seeders, but let's be safe)
            const roles = ['Admin', 'Medico', 'Asistente', 'Basico'];
            for (const role of roles) {
                await db.Role.findOrCreate({ where: { name: role } });
            }

            const tables = await db.sequelize.query("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'");
            // console.log('TABLES:', tables[0].map(t => t.table_name));

            // Create Admin
            const admin = await db.users.create({
                username: 'testadmin_patients',
                email: 'admin_patients@test.com',
                password: 'password123'
            });
            const adminRole = await db.Role.findOne({ where: { name: 'Admin' } });
            if (!adminRole) {
                console.error('FATAL: Admin role not found!');
                throw new Error('Admin role not found');
            }

            // Use raw SQL for user_roles as model doesn't exist
            await db.sequelize.query(
                'INSERT INTO user_roles (username, role_id, created_at, updated_at) VALUES (?, ?, NOW(), NOW())',
                { replacements: [admin.username, adminRole.id] }
            );

            adminToken = jwt.sign({ id: admin.id, username: admin.username, email: admin.email }, process.env.JWT_SECRET);

            // Create Medico
            const medico = await db.users.create({
                username: 'testmedico',
                email: 'medico@test.com',
                password: 'password123'
            });
            const medicoRole = await db.Role.findOne({ where: { name: 'Medico' } });
            await db.sequelize.query(
                'INSERT INTO user_roles (username, role_id, created_at, updated_at) VALUES (?, ?, NOW(), NOW())',
                { replacements: [medico.username, medicoRole.id] }
            );

            medicoToken = jwt.sign({ id: medico.id, username: medico.username, email: medico.email }, process.env.JWT_SECRET);

            // Create Normal User (no access)
            const user = await db.users.create({
                username: 'testuser_patients',
                email: 'user_patients@test.com',
                password: 'password123'
            });
            userToken = jwt.sign({ id: user.id, username: user.username, email: user.email }, process.env.JWT_SECRET);
        } catch (error) {
            console.error('SETUP ERROR:', error);
            throw error;
        }
    });

    afterAll(async () => {
        // Cleanup
        await db.RegistroPacientesDiarios.destroy({ where: {} });
        await db.sequelize.query("DELETE FROM user_roles WHERE username IN ('testadmin_patients', 'testmedico', 'testuser_patients')");
        await db.users.destroy({ where: { username: ['testadmin_patients', 'testmedico', 'testuser_patients'] } });
        await db.sequelize.close();
    });

    describe('POST /api/pacientes', () => {
        it('should allow Medico to create a patient record', async () => {
            const res = await request(app)
                .post('/api/pacientes')
                .set('Authorization', `Bearer ${medicoToken}`)
                .send({
                    nombre: 'Juan',
                    apellido: 'Perez',
                    edad: 30,
                    sexo: 'M',
                    cedula: '12345678',
                    fecha: '2025-12-09',
                    diagnostico: 'Gripe'
                });

            expect(res.statusCode).toBe(201);
            expect(res.body.success).toBe(true);
            expect(res.body.data.cedula).toBe('12345678');
        });

        it('should deny access to normal user', async () => {
            const res = await request(app)
                .post('/api/pacientes')
                .set('Authorization', `Bearer ${userToken}`)
                .send({
                    nombre: 'Maria',
                    apellido: 'Lopez',
                    edad: 25,
                    sexo: 'F',
                    cedula: '87654321',
                    fecha: '2025-12-09'
                });

            expect(res.statusCode).toBe(403);
        });
    });

    describe('GET /api/pacientes', () => {
        it('should get list of patients', async () => {
            const res = await request(app)
                .get('/api/pacientes')
                .set('Authorization', `Bearer ${medicoToken}`);

            expect(res.statusCode).toBe(200);
            expect(Array.isArray(res.body.data)).toBe(true);
            expect(res.body.data.length).toBeGreaterThan(0);
        });
    });

    describe('GET /api/reportes', () => {
        it('should generate JSON report for Admin', async () => {
            const res = await request(app)
                .get('/api/reportes?fecha=2025-12-09')
                .set('Authorization', `Bearer ${adminToken}`);

            expect(res.statusCode).toBe(200);
            expect(res.body.stats).toBeDefined();
            expect(res.body.stats.total).toBeGreaterThan(0);
        });

        it('should deny Medico from generating reports (if restricted to Admin)', async () => {
            // Requirement said "Admin puede crear y gestionar registros. Médicos/asistentes pueden ingresar pacientes."
            // But usually reports are for admins. My route config set it to Admin only.
            const res = await request(app)
                .get('/api/reportes?fecha=2025-12-09')
                .set('Authorization', `Bearer ${medicoToken}`);

            expect(res.statusCode).toBe(403);
        });
    });
});

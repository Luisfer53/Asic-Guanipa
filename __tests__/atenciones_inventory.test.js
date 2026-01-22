const request = require('supertest');
const app = require('../server');
const { sequelize, ArticuloMedico, LoteInsumo, AtencionDiaria, ConsumoInsumo, Paciente, User, Role } = require('../src/models');
const bcrypt = require('bcryptjs');

describe('Atenciones and Inventory Modules', () => {
    let articuloId;
    let loteId;
    let pacienteId;
    let userId;
    let token;

    beforeAll(async () => {
        await sequelize.sync({ force: true }); // Reset DB for testing

        // Create Roles
        await Role.bulkCreate([
            { id: 1, name: 'Admin' },
            { id: 2, name: 'Medico' }
        ]);

        // Create prerequisites
        const articulo = await ArticuloMedico.create({
            nombre_articulo: 'Jeringa 10ml',
            unidad_medida: 'unidad'
        });
        articuloId = articulo.id;

        const paciente = await Paciente.create({
            nombre: 'Test',
            apellido: 'Patient',
            cedula: '12345678',
            fecha_nacimiento: '1990-01-01',
            sexo: 'M',
            telefono: '555-5555',
            direccion: 'Test Address'
        });
        pacienteId = paciente.id;

        const hashedPassword = await bcrypt.hash('password123', 10);
        const user = await User.create({
            username: 'medico1',
            password: hashedPassword,
            email: 'medico@test.com'
        });
        userId = user.id;

        // Associate user with role
        await sequelize.query(
            'INSERT INTO user_roles (username, role_id, created_at, updated_at) VALUES ($1, $2, NOW(), NOW())',
            { bind: [user.username, 2] }
        );

        // Login to get token
        const loginRes = await request(app)
            .post('/api/auth/login')
            .send({
                email: 'medico@test.com',
                password: 'password123'
            });
        token = loginRes.body.data.token;
    });

    afterAll(async () => {
        await sequelize.close();
    });

    describe('POST /api/inventario/lotes', () => {
        it('should register a new batch successfully', async () => {
            const res = await request(app)
                .post('/api/inventario/lotes')
                .set('Authorization', `Bearer ${token}`)
                .send({
                    id_articulo: articuloId,
                    numero_lote: 'LOTE-001',
                    stock_actual: 100,
                    fecha_vencimiento: '2030-12-31'
                });

            expect(res.statusCode).toEqual(201);
            expect(res.body.success).toBe(true);
            expect(res.body.data.numero_lote).toBe('LOTE-001');
            loteId = res.body.data.id;
        });

        it('should fail if expiration date is in the past', async () => {
            const res = await request(app)
                .post('/api/inventario/lotes')
                .set('Authorization', `Bearer ${token}`)
                .send({
                    id_articulo: articuloId,
                    numero_lote: 'LOTE-BAD',
                    stock_actual: 50,
                    fecha_vencimiento: '2020-01-01'
                });

            expect(res.statusCode).toEqual(400);
            expect(res.body.message).toContain('futura');
        });
    });

    describe('POST /api/atenciones', () => {
        it('should register attention and consume stock successfully', async () => {
            const res = await request(app)
                .post('/api/atenciones')
                .set('Authorization', `Bearer ${token}`)
                .send({
                    paciente_id: pacienteId,
                    diagnostico: 'Gripe',
                    edad_atencion: 30,
                    id_usuario_registra: userId,
                    consumos: [
                        {
                            id_lote_insumo: loteId,
                            cantidad_usada: 10
                        }
                    ]
                });

            expect(res.statusCode).toEqual(201);
            expect(res.body.success).toBe(true);

            // Verify records
            const atencion = await AtencionDiaria.findOne({ where: { diagnostico: 'Gripe' } });
            expect(atencion).toBeTruthy();

            const consumo = await ConsumoInsumo.findOne({ where: { id_atencion: atencion.id } });
            expect(consumo).toBeTruthy();
            expect(consumo.cantidad_usada).toBe(10);
        });

        it('should fail if stock is insufficient', async () => {
            const res = await request(app)
                .post('/api/atenciones')
                .set('Authorization', `Bearer ${token}`)
                .send({
                    paciente_id: pacienteId,
                    diagnostico: 'Fractura',
                    edad_atencion: 30,
                    id_usuario_registra: userId,
                    consumos: [
                        {
                            id_lote_insumo: loteId,
                            cantidad_usada: 9999 // More than available
                        }
                    ]
                });

            expect(res.statusCode).toEqual(400);
            expect(res.body.message).toContain('Stock insuficiente');

            // Verify rollback: Atencion should not be created
            const atencion = await AtencionDiaria.findOne({ where: { diagnostico: 'Fractura' } });
            expect(atencion).toBeNull();
        });
    });
});

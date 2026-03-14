const request = require('supertest');
const app = require('../server');
const { sequelize, ArticuloMedico, LoteInsumo, AtencionDiaria, ConsumoInsumo, Paciente, User, Role } = require('../src/models');
const bcrypt = require('bcryptjs');

describe('POST /api/atenciones/registrar-completo - Unified Patient-Attention Registration', () => {
    let articuloId;
    let loteId;
    let userId;
    let token;

    beforeAll(async () => {
        await sequelize.sync({ force: true });


        await Role.bulkCreate([
            { id: 1, name: 'Admin' },
            { id: 2, name: 'Medico' }
        ]);


        const articulo = await ArticuloMedico.create({
            nombre_articulo: 'Jeringa 10ml',
            unidad_medida: 'unidad'
        });
        articuloId = articulo.id;

        const lote = await LoteInsumo.create({
            id_articulo: articuloId,
            numero_lote: 'LOTE-TEST-001',
            stock_actual: 100,
            fecha_vencimiento: '2030-12-31'
        });
        loteId = lote.id;

        const hashedPassword = await bcrypt.hash('password123', 10);
        const user = await User.create({
            username: 'medico1',
            password: hashedPassword,
            email: 'medico@test.com'
        });
        userId = user.id;


        await sequelize.query(
            'INSERT INTO user_roles (username, role_id, created_at, updated_at) VALUES ($1, $2, NOW(), NOW())',
            { bind: [user.username, 2] }
        );


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

    describe('New patient registration (adult)', () => {
        it('should create new patient and attention with supplies', async () => {
            const res = await request(app)
                .post('/api/atenciones/registrar-completo')
                .set('Authorization', `Bearer ${token}`)
                .send({
                    cedula: '12345678',
                    paciente: {
                        nombre: 'Juan',
                        apellido: 'Pérez',
                        fecha_nacimiento: '1990-05-15',
                        sexo: 'M',
                        telefono: '04141234567',
                        direccion: 'Calle Principal'
                    },
                    atencion: {
                        diagnostico: 'Consulta general',
                        fecha: '2026-01-22'
                    },
                    consumos: [
                        {
                            id_lote_insumo: loteId,
                            cantidad_usada: 5
                        }
                    ]
                });

            expect(res.statusCode).toEqual(201);
            expect(res.body.success).toBe(true);
            expect(res.body.message).toContain('exitosamente');
            expect(res.body.data.paciente).toBeTruthy();
            expect(res.body.data.paciente.cedula).toBe('12345678');
            expect(res.body.data.atencion).toBeTruthy();
            expect(res.body.data.atencion.diagnostico).toBe('Consulta general');
            expect(res.body.data.paciente_existia).toBe(false);


            const allPatients1 = await Paciente.findAll();
            const paciente = allPatients1.find(p => p.cedula === '12345678');
            expect(paciente).toBeTruthy();
            expect(paciente.nombre).toBe('Juan');


            const atencion = await AtencionDiaria.findOne({
                where: { paciente_id: paciente.id }
            });
            expect(atencion).toBeTruthy();


            const consumo = await ConsumoInsumo.findOne({
                where: { id_atencion: atencion.id }
            });
            expect(consumo).toBeTruthy();
            expect(consumo.cantidad_usada).toBe(5);
        });
    });

    describe('Existing patient registration', () => {
        it('should update existing patient and create new attention', async () => {
            const res = await request(app)
                .post('/api/atenciones/registrar-completo')
                .set('Authorization', `Bearer ${token}`)
                .send({
                    cedula: '12345678',
                    paciente: {
                        nombre: 'Juan',
                        apellido: 'Pérez',
                        fecha_nacimiento: '1990-05-15',
                        sexo: 'M',
                        telefono: '04149999999',
                        direccion: 'Nueva dirección'
                    },
                    atencion: {
                        diagnostico: 'Control de seguimiento'
                    },
                    consumos: []
                });

            expect(res.statusCode).toEqual(201);
            expect(res.body.success).toBe(true);
            expect(res.body.data.paciente_existia).toBe(true);


            const allPatients2 = await Paciente.findAll();
            const paciente = allPatients2.find(p => p.cedula === '12345678');
            expect(paciente.telefono).toBe('04149999999');
            expect(paciente.direccion).toBe('Nueva dirección');


            const atenciones = await AtencionDiaria.findAll({
                where: { paciente_id: paciente.id }
            });
            expect(atenciones.length).toBe(2);
        });
    });

    describe('Minor patient registration', () => {
        it('should create minor patient without cedula but with representative', async () => {
            const res = await request(app)
                .post('/api/atenciones/registrar-completo')
                .set('Authorization', `Bearer ${token}`)
                .send({
                    paciente: {
                        nombre: 'Carlos',
                        apellido: 'Rodríguez',
                        fecha_nacimiento: '2015-03-10',
                        sexo: 'M',
                        nombre_representante: 'María',
                        apellido_representante: 'González',
                        cedula_representante: '87654321',
                        telefono_representante: '04149876543',
                        direccion_representante: 'Urb. Los Pinos, Casa 12'
                    },
                    atencion: {
                        diagnostico: 'Consulta pediátrica'
                    },
                    consumos: [
                        {
                            id_lote_insumo: loteId,
                            cantidad_usada: 2
                        }
                    ]
                });

            expect(res.statusCode).toEqual(201);
            expect(res.body.success).toBe(true);
            expect(res.body.data.paciente.nombre_representante).toBe('María');
            expect(res.body.data.paciente.cedula_representante).toBe('87654321');
        });
    });

    describe('Validation errors', () => {
        it('should fail if adult patient has no cedula', async () => {
            const res = await request(app)
                .post('/api/atenciones/registrar-completo')
                .set('Authorization', `Bearer ${token}`)
                .send({
                    paciente: {
                        nombre: 'Pedro',
                        apellido: 'López',
                        fecha_nacimiento: '1985-01-01',
                        sexo: 'M'
                    },
                    atencion: {
                        diagnostico: 'Test'
                    }
                });

            expect(res.statusCode).toEqual(400);
            expect(res.body.message).toContain('cédula');
            expect(res.body.message).toContain('mayores de edad');
        });

        it('should fail if minor has no representative data', async () => {
            const res = await request(app)
                .post('/api/atenciones/registrar-completo')
                .set('Authorization', `Bearer ${token}`)
                .send({
                    paciente: {
                        nombre: 'Niño',
                        apellido: 'Sin Representante',
                        fecha_nacimiento: '2020-01-01',
                        sexo: 'M'
                    },
                    atencion: {
                        diagnostico: 'Test'
                    }
                });

            expect(res.statusCode).toEqual(400);
            expect(res.body.message).toContain('representante');
        });

        it('should fail if stock is insufficient', async () => {
            const res = await request(app)
                .post('/api/atenciones/registrar-completo')
                .set('Authorization', `Bearer ${token}`)
                .send({
                    cedula: '99999999',
                    paciente: {
                        nombre: 'Test',
                        apellido: 'Stock',
                        fecha_nacimiento: '1990-01-01',
                        sexo: 'M'
                    },
                    atencion: {
                        diagnostico: 'Test stock'
                    },
                    consumos: [
                        {
                            id_lote_insumo: loteId,
                            cantidad_usada: 9999
                        }
                    ]
                });

            expect(res.statusCode).toEqual(400);
            expect(res.body.message).toContain('Stock insuficiente');


            const allPatients3 = await Paciente.findAll();
            const paciente = allPatients3.find(p => p.cedula === '99999999');
            expect(paciente).toBeUndefined();
        });

        it('should fail if lote does not exist', async () => {
            const res = await request(app)
                .post('/api/atenciones/registrar-completo')
                .set('Authorization', `Bearer ${token}`)
                .send({
                    cedula: '88888888',
                    paciente: {
                        nombre: 'Test',
                        apellido: 'Lote',
                        fecha_nacimiento: '1990-01-01',
                        sexo: 'M'
                    },
                    atencion: {
                        diagnostico: 'Test lote'
                    },
                    consumos: [
                        {
                            id_lote_insumo: 99999,
                            cantidad_usada: 1
                        }
                    ]
                });

            expect(res.statusCode).toEqual(400);
            expect(res.body.message).toContain('no encontrado');
        });
    });
});

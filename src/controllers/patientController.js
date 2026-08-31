const db = require('../models');
const { Op } = require('sequelize');
const { logAction } = require('../utils/auditLogger');
const { calcularEdad, nombreCompleto, semanaEpidemiologica } = require('../utils/formatters');

const normalizeDireccionPayload = (direccion) => {
    if (!direccion) return null;
    if (typeof direccion === 'string') {
        return { calle: direccion };
    }
    if (typeof direccion === 'object' && Object.keys(direccion).length > 0) {
        return {
            calle: direccion.calle || direccion.direccion || null,
            numero_casa: direccion.numero_casa || direccion.numeroCasa || null,
            punto_referencia: direccion.punto_referencia || direccion.puntoReferencia || null,
            sector: direccion.sector || null,
        };
    }
    return null;
};

const upsertTelefono = async (id_persona, telefono, transaction) => {
    if (!telefono) return null;
    const existingMatch = await db.Telefono.findOne({ where: { id_persona, numero_telefono: telefono }, transaction });
    if (existingMatch) return existingMatch;

    const existing = await db.Telefono.findOne({ where: { id_persona }, transaction });
    if (existing) {
        return existing.update({ numero_telefono: telefono }, { transaction });
    }
    return db.Telefono.create({ id_persona, numero_telefono: telefono }, { transaction });
};

const upsertCorreo = async (id_persona, correo, transaction) => {
    if (!correo) return null;
    const existingMatch = await db.Correo.findOne({ where: { id_persona, correo }, transaction });
    if (existingMatch) return existingMatch;

    const existing = await db.Correo.findOne({ where: { id_persona }, transaction });
    if (existing) {
        return existing.update({ correo }, { transaction });
    }
    return db.Correo.create({ id_persona, correo }, { transaction });
};

const upsertDireccion = async (id_persona, direccion, transaction) => {
    const payload = normalizeDireccionPayload(direccion);
    if (!payload) return null;

    const { calle, numero_casa, punto_referencia, sector } = payload;
    if (!calle && !numero_casa && !punto_referencia && !sector) return null;

    let id_sector = null;
    if (sector) {
        let sectorObj = await db.SectorGuanipa.findOne({ where: { nombre_sector: sector }, transaction });
        if (!sectorObj) {
            sectorObj = await db.SectorGuanipa.create({ nombre_sector: sector }, { transaction });
        }
        id_sector = sectorObj.id_sector;
    }

    const direccionRecord = await db.Direccion.findOne({ where: { id_persona }, transaction });
    if (direccionRecord) {
        return direccionRecord.update({
            id_sector,
            calle: calle || direccionRecord.calle,
            numero_casa: numero_casa || direccionRecord.numero_casa,
            punto_referencia: punto_referencia || direccionRecord.punto_referencia,
        }, { transaction });
    }

    return db.Direccion.create({
        id_persona,
        id_sector,
        calle: calle || null,
        numero_casa: numero_casa || null,
        punto_referencia: punto_referencia || null,
    }, { transaction });
};

// ─── Includes reutilizables ────────────────────────────────────────────────────
const includePersonaPaciente = {
    model: db.Persona,
    as: 'persona',
    attributes: ['id_persona', 'cedula_identidad', 'nombre1', 'nombre2',
        'apellido1', 'apellido2', 'sexo', 'fecha_nacimiento', 'estado_civil', 'ocupacion'],
    include: [
        { model: db.Telefono, as: 'telefonos', attributes: ['id_telefono', 'numero_telefono'] },
        { model: db.Correo, as: 'correos', attributes: ['id_correo', 'correo'] },
        {
            model: db.Direccion, as: 'direcciones',
            attributes: ['id_direccion', 'parroquia', 'calle', 'numero_casa', 'punto_referencia'],
            include: [{ model: db.SectorGuanipa, as: 'sector', attributes: ['id_sector', 'nombre_sector'] }]
        }
    ]
};

const includeRepresentante = {
    model: db.Persona,
    as: 'representante',
    attributes: ['id_persona', 'cedula_identidad', 'nombre1', 'nombre2', 'apellido1', 'apellido2'],
    include: [
        { model: db.Telefono, as: 'telefonos', attributes: ['numero_telefono'] }
    ]
};



// ─────────────────────────────────────────────────────────────────────────────
// CREAR PACIENTE (solo datos demográficos, sin atención)
// ─────────────────────────────────────────────────────────────────────────────
const createPatient = async (req, res) => {
    const transaction = await db.sequelize.transaction();
    try {
        const {
            cedula_identidad, nombre1, nombre2, apellido1, apellido2,
            sexo, estado_civil, ocupacion, fecha_nacimiento,
            telefono, correo, direccion,
            calle, numero_casa, punto_referencia, sector,
            // Clínicos
            peso, tipo_sangre, alergias, enfermedades_cronicas,
            vacunas, discapacidad, antecedentes_familiares,
            // Representante (para menores)
            cedula_representante, nombre1_rep, nombre2_rep, apellido1_rep, apellido2_rep,
            telefono_representante, parentesco_representante
        } = req.body;

        if (!nombre1 || !apellido1 || !sexo) {
            await transaction.rollback();
            return res.status(400).json({
                success: false,
                message: 'Faltan campos obligatorios: nombre1, apellido1, sexo'
            });
        }

        const edad = calcularEdad(fecha_nacimiento);
        const esMenor = edad !== null && edad < 18;

        // Validar representante para menores
        if (esMenor && (!cedula_representante && !(nombre1_rep || apellido1_rep))) {
            await transaction.rollback();
            return res.status(400).json({
                success: false,
                message: 'Para menores de edad, debe indicar al menos el nombre o apellido del representante'
            });
        }

        // Verificar cédula única
        if (cedula_identidad) {
            const existe = await db.Persona.findOne({ where: { cedula_identidad }, transaction });
            if (existe) {
                await transaction.rollback();
                return res.status(409).json({
                    success: false,
                    message: `La cédula ${cedula_identidad} ya está registrada`
                });
            }
        }

        // 1. Crear persona del paciente
        const persona = await db.Persona.create({
            cedula_identidad: cedula_identidad || null,
            nombre1, nombre2: nombre2 || null,
            apellido1, apellido2: apellido2 || null,
            sexo, estado_civil, ocupacion, fecha_nacimiento
        }, { transaction });

        // 2. Teléfono
        if (telefono) {
            await db.Telefono.create({ id_persona: persona.id_persona, numero_telefono: telefono }, { transaction });
        }
        // 3. Correo
        if (correo) {
            await db.Correo.create({ id_persona: persona.id_persona, correo }, { transaction });
        }
        // 4. Dirección (soporta objeto, string o campos individuales calle/numero_casa/punto_referencia/sector)
        const sectorNombre = sector || (typeof direccion === 'object' ? direccion.sector : null);
        let id_sector = null;
        if (sectorNombre) {
            let sectorObj = await db.SectorGuanipa.findOne({ where: { nombre_sector: sectorNombre }, transaction });
            if (!sectorObj) {
                sectorObj = await db.SectorGuanipa.create({ nombre_sector: sectorNombre }, { transaction });
            }
            id_sector = sectorObj.id_sector;
        }

        const calleVal = calle || (typeof direccion === 'object' ? direccion.calle : (typeof direccion === 'string' ? direccion : null));
        const numCasaVal = numero_casa || (typeof direccion === 'object' ? direccion.numero_casa : null);
        const refVal = punto_referencia || (typeof direccion === 'object' ? direccion.punto_referencia : null);

        if (id_sector || calleVal || numCasaVal || refVal) {
            await db.Direccion.create({
                id_persona: persona.id_persona,
                id_sector,
                calle: calleVal || null,
                numero_casa: numCasaVal || null,
                punto_referencia: refVal || null
            }, { transaction });
        }

        // 5. Representante (si es menor)
        let idRepresentante = null;
        let parentesco = null;
        if (esMenor && cedula_representante) {
            let personaRep = await db.Persona.findOne({ where: { cedula_identidad: cedula_representante }, transaction });
            if (!personaRep) {
                personaRep = await db.Persona.create({
                    cedula_identidad: cedula_representante,
                    nombre1: nombre1_rep || null,
                    nombre2: nombre2_rep || null,
                    apellido1: apellido1_rep || null,
                    apellido2: apellido2_rep || null
                }, { transaction });
            }
            if (telefono_representante) {
                const yaExisteTel = await db.Telefono.findOne({ where: { id_persona: personaRep.id_persona }, transaction });
                if (!yaExisteTel) {
                    await db.Telefono.create({ id_persona: personaRep.id_persona, numero_telefono: telefono_representante }, { transaction });
                }
            }
            idRepresentante = personaRep.id_persona;
            parentesco = parentesco_representante || null;
        }

        // 6. Crear paciente clínico
        const paciente = await db.Paciente.create({
            id_persona: persona.id_persona,
            id_representante: idRepresentante,
            parentesco_representante: parentesco,
            fecha_registro: new Date(),
            peso: peso || null,
            tipo_sangre: tipo_sangre || null,
            alergias: alergias || null,
            enfermedades_cronicas: enfermedades_cronicas || null,
            vacunas: vacunas || null,
            discapacidad: discapacidad || null,
            antecedentes_familiares: antecedentes_familiares || null
        }, { transaction });

        await transaction.commit();

        await logAction(
            req.user?.nombre_usuario || 'sistema',
            `Registro de paciente: ${nombre1} ${apellido1}`,
            'pacientes',
            { id_paciente: paciente.id_paciente, cedula: cedula_identidad }
        );

        res.status(201).json({
            success: true,
            message: 'Paciente registrado exitosamente',
            data: { paciente, persona }
        });
    } catch (error) {
        await transaction.rollback();
        console.error('Error creating patient record:', error);
        res.status(500).json({ success: false, message: 'Error al registrar paciente', error: error.message });
    }
};

// ─────────────────────────────────────────────────────────────────────────────
// OBTENER LISTADO DE PACIENTES (paginado, con búsqueda)
// ─────────────────────────────────────────────────────────────────────────────
const getAllPatients = async (req, res) => {
    try {
        const { page, limit, search = '', cedula } = req.query;

        const rawConditions = [];

        if (cedula && cedula.trim()) {
            const cleanCedula = cedula.replace(/[^0-9a-zA-Z]/g, '').replace(/^[vVeEpPjJ]/, '');
            rawConditions.push({ cedula_identidad: { [Op.iLike]: `%${cedula.trim()}%` } });
            if (cleanCedula && cleanCedula !== cedula.trim()) {
                rawConditions.push({ cedula_identidad: { [Op.iLike]: `%${cleanCedula}%` } });
            }
        }

        if (search && search.trim()) {
            const tokens = search.trim().split(/\s+/).filter(Boolean);
            tokens.forEach((token) => {
                const cleanCedula = token.replace(/[^0-9a-zA-Z]/g, '').replace(/^[vVeEpPjJ]/, '');
                rawConditions.push(
                    { nombre1: { [Op.iLike]: `%${token}%` } },
                    { nombre2: { [Op.iLike]: `%${token}%` } },
                    { apellido1: { [Op.iLike]: `%${token}%` } },
                    { apellido2: { [Op.iLike]: `%${token}%` } },
                    { cedula_identidad: { [Op.iLike]: `%${token}%` } }
                );
                if (cleanCedula && cleanCedula !== token && /^[0-9]+$/.test(cleanCedula)) {
                    rawConditions.push(
                        { cedula_identidad: { [Op.iLike]: `%${cleanCedula}%` } }
                    );
                }
            });
        }

        const hasSearchFilter = rawConditions.length > 0;
        const personaWhere = hasSearchFilter ? { [Op.or]: rawConditions } : undefined;

        const personaInclude = {
            ...includePersonaPaciente,
            where: personaWhere,
            required: hasSearchFilter
        };

        const queryOpts = {
            include: [personaInclude, includeRepresentante],
            order: [[{ model: db.Persona, as: 'persona' }, 'apellido1', 'ASC']],
            subQuery: false,
            distinct: true
        };

        if (page && limit) {
            const p = parseInt(page);
            const l = parseInt(limit);
            queryOpts.limit = l;
            queryOpts.offset = (p - 1) * l;
        }

        const { count, rows } = await db.Paciente.findAndCountAll(queryOpts);

        const response = {
            success: true,
            data: rows,
            total: count
        };

        if (page && limit) {
            const p = parseInt(page);
            const l = parseInt(limit);
            response.pagination = {
                total: count,
                page: p,
                limit: l,
                totalPages: Math.ceil(count / l)
            };
        }

        res.status(200).json(response);
    } catch (error) {
        console.error('Error fetching all patients:', error);
        res.status(500).json({ success: false, message: 'Error al obtener listado de pacientes', error: error.message });
    }
};

// ─────────────────────────────────────────────────────────────────────────────
// OBTENER PACIENTES (con sus atenciones — endpoint legacy de reportes)
// ─────────────────────────────────────────────────────────────────────────────
const getPatients = async (req, res) => {
    try {
        const { fecha, cedula } = req.query;
        const atencionWhere = {};
        if (fecha) atencionWhere.fecha_visita = fecha;

        const personaWhere = {};
        if (cedula) personaWhere.cedula_identidad = { [Op.iLike]: `%${cedula}%` };

        const includeOpts = [
            {
                ...includePersonaPaciente,
                ...(Object.keys(personaWhere).length > 0 ? { where: personaWhere, required: true } : {})
            }
        ];

        const atenciones = await db.AtencionDiaria.findAll({
            where: atencionWhere,
            include: includeOpts,
            order: [['fecha_visita', 'DESC']]
        });

        res.status(200).json({ success: true, data: atenciones });
    } catch (error) {
        console.error('Error fetching patients:', error);
        res.status(500).json({ success: false, message: 'Error al obtener pacientes', error: error.message });
    }
};

// ─────────────────────────────────────────────────────────────────────────────
// HISTORIAL DE ATENCIONES DE UN PACIENTE
// ─────────────────────────────────────────────────────────────────────────────
const getPatientHistory = async (req, res) => {
    try {
        const identifier = req.params.cedula || req.params.identifier;
        if (!identifier) {
            return res.status(400).json({ success: false, message: 'Identificador de paciente no proporcionado' });
        }

        let paciente = null;

        // 1. Buscar por id_paciente directo si es numérico
        if (!isNaN(identifier) && Number(identifier) > 0) {
            paciente = await db.Paciente.findByPk(identifier, {
                include: [includePersonaPaciente]
            });
        }

        // 2. Buscar por cedula_identidad de la persona
        if (!paciente) {
            const persona = await db.Persona.findOne({
                where: {
                    cedula_identidad: {
                        [Op.iLike]: `%${identifier}%`
                    }
                }
            });
            if (persona) {
                paciente = await db.Paciente.findOne({
                    where: { id_persona: persona.id_persona },
                    include: [includePersonaPaciente]
                });
            }
        }

        if (!paciente) {
            return res.status(404).json({ success: false, message: `Paciente no encontrado con identificador: ${identifier}` });
        }


        const atenciones = await db.AtencionDiaria.findAll({
            where: { id_paciente: paciente.id_paciente },
            include: [
                { model: db.CentroSalud, as: 'centro', attributes: ['id_centro', 'nombre_centro'] },
                {
                    model: db.AtencionDiagnostico, as: 'diagnosticos',
                    include: [{ model: db.Diagnostico, as: 'diagnostico', attributes: ['id_diagnostico', 'condicion', 'descripcion', 'gravedad'] }]
                },
                {
                    model: db.Tratamiento, as: 'tratamientos',
                    attributes: ['id_tratamiento_id', 'tipo_tratamiento', 'detalles']
                },
                {
                    model: db.RegistroVacunacion, as: 'vacunaciones',
                    include: [
                        {
                            model: db.LoteInsumo, as: 'lote',
                            include: [{ model: db.ArticuloMedico, as: 'articulo', attributes: ['id_articulo', 'nombre_articulo', 'tipo'] }]
                        },
                        { model: db.EsquemaDosificacion, as: 'esquema', attributes: ['id_esquema', 'numero_dosis'] }
                    ]
                },
                {
                    model: db.ConsumoInsumo, as: 'consumos',
                    include: [
                        {
                            model: db.LoteInsumo, as: 'lote',
                            include: [{ model: db.ArticuloMedico, as: 'articulo', attributes: ['id_articulo', 'nombre_articulo', 'tipo', 'unidad_medida'] }]
                        }
                    ]
                }
            ],
            order: [['fecha_visita', 'DESC']]
        });

        res.status(200).json({
            success: true,
            paciente: {
                id_paciente: paciente.id_paciente,
                persona: paciente.persona,
                peso: paciente.peso,
                tipo_sangre: paciente.tipo_sangre,
                alergias: paciente.alergias,
                enfermedades_cronicas: paciente.enfermedades_cronicas,
                discapacidad: paciente.discapacidad,
                antecedentes_familiares: paciente.antecedentes_familiares
            },
            atenciones,
            total_atenciones: atenciones.length
        });
    } catch (error) {
        console.error('Error fetching patient history:', error);
        res.status(500).json({ success: false, message: 'Error al obtener historial', error: error.message });
    }
};

// ─────────────────────────────────────────────────────────────────────────────
// OBTENER ATENCIÓN POR ID
// ─────────────────────────────────────────────────────────────────────────────
const getAttentionById = async (req, res) => {
    try {
        const { id } = req.params;
        const atencion = await db.AtencionDiaria.findByPk(id, {
            include: [
                { model: db.Paciente, as: 'paciente', include: [includePersonaPaciente] },
                { model: db.CentroSalud, as: 'centro' },
                {
                    model: db.ConsumoInsumo, as: 'consumos',
                    include: [{ model: db.LoteInsumo, as: 'lote', include: [{ model: db.ArticuloMedico, as: 'articulo' }] }]
                },
                {
                    model: db.RegistroVacunacion, as: 'vacunaciones',
                    include: [{ model: db.EsquemaDosificacion, as: 'esquema' }]
                },
                {
                    model: db.AtencionDiagnostico, as: 'diagnosticos',
                    include: [{ model: db.Diagnostico, as: 'diagnostico' }]
                },
                {
                    model: db.Tratamiento, as: 'tratamientos',
                    include: [{
                        model: db.TratamientoMedicamento, as: 'medicamentos',
                        include: [{ model: db.ArticuloMedico, as: 'articulo' }]
                    }]
                }
            ]
        });

        if (!atencion) {
            return res.status(404).json({ success: false, message: 'Atención no encontrada' });
        }
        res.status(200).json({ success: true, data: atencion });
    } catch (error) {
        console.error('Error fetching attention by ID:', error);
        res.status(500).json({ success: false, message: 'Error al obtener la atención', error: error.message });
    }
};

// ─────────────────────────────────────────────────────────────────────────────
// ACTUALIZAR DATOS DEL PACIENTE (información clínica y demográfica)
// ─────────────────────────────────────────────────────────────────────────────
const updatePatientData = async (req, res) => {
    const transaction = await db.sequelize.transaction();
    try {
        const { id } = req.params;
        const {
            nombre1, nombre2, apellido1, apellido2, cedula_identidad,
            sexo, estado_civil, ocupacion, fecha_nacimiento,
            telefono, correo, direccion,
            calle, numero_casa, punto_referencia, sector,
            peso, tipo_sangre, alergias, enfermedades_cronicas,
            vacunas, discapacidad, antecedentes_familiares
        } = req.body;

        const paciente = await db.Paciente.findByPk(id, {
            include: [includePersonaPaciente],
            transaction
        });

        if (!paciente) {
            await transaction.rollback();
            return res.status(404).json({ success: false, message: 'Paciente no encontrado' });
        }

        // Actualizar persona
        const personaUpdates = {};
        if (nombre1 !== undefined) personaUpdates.nombre1 = nombre1;
        if (nombre2 !== undefined) personaUpdates.nombre2 = nombre2;
        if (apellido1 !== undefined) personaUpdates.apellido1 = apellido1;
        if (apellido2 !== undefined) personaUpdates.apellido2 = apellido2;
        if (cedula_identidad !== undefined) personaUpdates.cedula_identidad = cedula_identidad;
        if (sexo !== undefined) personaUpdates.sexo = sexo;
        if (estado_civil !== undefined) personaUpdates.estado_civil = estado_civil;
        if (ocupacion !== undefined) personaUpdates.ocupacion = ocupacion;
        if (fecha_nacimiento !== undefined) personaUpdates.fecha_nacimiento = fecha_nacimiento;

        if (Object.keys(personaUpdates).length > 0) {
            await paciente.persona.update(personaUpdates, { transaction });
        }

        // Actualizar teléfono, correo y dirección
        if (telefono !== undefined) {
            await upsertTelefono(paciente.id_persona, telefono, transaction);
        }
        if (correo !== undefined) {
            await upsertCorreo(paciente.id_persona, correo, transaction);
        }
        if (direccion !== undefined || calle !== undefined || numero_casa !== undefined || punto_referencia !== undefined || sector !== undefined) {
            const direccionPayload = normalizeDireccionPayload(direccion) || {};
            await upsertDireccion(paciente.id_persona, {
                calle: calle ?? direccionPayload.calle,
                numero_casa: numero_casa ?? direccionPayload.numero_casa,
                punto_referencia: punto_referencia ?? direccionPayload.punto_referencia,
                sector: sector ?? direccionPayload.sector,
            }, transaction);
        }

        // Actualizar datos clínicos del paciente
        const clinicosUpdates = {};
        if (peso !== undefined) clinicosUpdates.peso = peso;
        if (tipo_sangre !== undefined) clinicosUpdates.tipo_sangre = tipo_sangre;
        if (alergias !== undefined) clinicosUpdates.alergias = alergias;
        if (enfermedades_cronicas !== undefined) clinicosUpdates.enfermedades_cronicas = enfermedades_cronicas;
        if (vacunas !== undefined) clinicosUpdates.vacunas = vacunas;
        if (discapacidad !== undefined) clinicosUpdates.discapacidad = discapacidad;
        if (antecedentes_familiares !== undefined) clinicosUpdates.antecedentes_familiares = antecedentes_familiares;

        if (Object.keys(clinicosUpdates).length > 0) {
            await paciente.update(clinicosUpdates, { transaction });
        }

        await transaction.commit();

        await logAction(
            req.user?.nombre_usuario || 'sistema',
            `Actualización de datos de paciente: ${nombre1 || ''} ${apellido1 || ''}`,
            'pacientes',
            { id_paciente: paciente.id_paciente }
        );

        res.status(200).json({
            success: true,
            message: 'Datos del paciente actualizados correctamente',
            data: paciente
        });
    } catch (error) {
        await transaction.rollback();
        console.error('Error al actualizar paciente:', error);
        res.status(500).json({ success: false, message: 'Error al actualizar paciente', error: error.message });
    }
};

// ─────────────────────────────────────────────────────────────────────────────
// ELIMINAR REGISTRO DE ATENCIÓN
// ─────────────────────────────────────────────────────────────────────────────
const deletePatient = async (req, res) => {
    try {
        const { id } = req.params;
        const record = await db.AtencionDiaria.findByPk(id);
        if (!record) {
            return res.status(404).json({ success: false, message: 'Registro no encontrado' });
        }
        await record.destroy();
        await logAction(
            req.user?.nombre_usuario || 'sistema',
            `Eliminación de atención: ID ${id}`,
            'atenciones_diarias',
            { id, id_paciente: record.id_paciente }
        );
        res.status(200).json({ success: true, message: 'Registro eliminado' });
    } catch (error) {
        console.error('Error deleting patient:', error);
        res.status(500).json({ success: false, message: 'Error al eliminar registro', error: error.message });
    }
};

// ─────────────────────────────────────────────────────────────────────────────
// CONTACTOS DE PACIENTES (para listados de directorio)
// ─────────────────────────────────────────────────────────────────────────────
const getPatientContacts = async (req, res) => {
    try {
        const { cedula } = req.query;
        const personaWhere = {};
        if (cedula) personaWhere.cedula_identidad = { [Op.iLike]: `%${cedula}%` };

        const pacientes = await db.Paciente.findAll({
            include: [{
                ...includePersonaPaciente,
                ...(Object.keys(personaWhere).length > 0 ? { where: personaWhere, required: true } : {})
            }],
            order: [[{ model: db.Persona, as: 'persona' }, 'apellido1', 'ASC']]
        });

        res.status(200).json({ success: true, data: pacientes });
    } catch (error) {
        console.error('Error fetching patient contacts:', error);
        res.status(500).json({ success: false, message: 'Error al obtener contactos de pacientes', error: error.message });
    }
};

// updatePatient (legacy - actualizar datos de atención)
const updatePatient = async (req, res) => {
    const transaction = await db.sequelize.transaction();
    try {
        const { id } = req.params;
        const updateData = req.body;

        const atencion = await db.AtencionDiaria.findByPk(id, {
            include: [{ model: db.Paciente, as: 'paciente', include: [includePersonaPaciente] }],
            transaction
        });

        if (!atencion) {
            await transaction.rollback();
            return res.status(404).json({ success: false, message: 'Registro de atención no encontrado' });
        }

        if (updateData.diagnostico_general) atencion.diagnostico_general = updateData.diagnostico_general;
        if (updateData.fecha_visita) atencion.fecha_visita = updateData.fecha_visita;
        await atencion.save({ transaction });

        await transaction.commit();

        await logAction(
            req.user?.nombre_usuario || 'sistema',
            `Edición de atención ID ${id}`,
            'atenciones_diarias',
            { id }
        );

        res.status(200).json({ success: true, message: 'Registro actualizado', data: atencion });
    } catch (error) {
        await transaction.rollback();
        console.error('Error updating patient:', error);
        res.status(500).json({ success: false, message: 'Error al actualizar registro', error: error.message });
    }
};

module.exports = {
    createPatient,
    getPatients,
    getPatientHistory,
    getAttentionById,
    updatePatient,
    deletePatient,
    getPatientContacts,
    getAllPatients,
    updatePatientData
};



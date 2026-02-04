const { sequelize, AtencionDiaria, ConsumoInsumo, LoteInsumo, Paciente } = require('../models');

exports.registrarCompleto = async (req, res) => {
    const t = await sequelize.transaction();

    try {
        const { cedula, paciente, atencion, consumos } = req.body;

        if (!paciente || !atencion) {
            throw new Error('Los datos del paciente y la atención son obligatorios');
        }

        const { nombre, apellido, fecha_nacimiento, sexo, telefono, direccion,
            nombre_representante, apellido_representante, cedula_representante, telefono_representante } = paciente;
        const { diagnostico, fecha } = atencion;
        const id_usuario_registra = req.user ? req.user.id : null;

        let edad_atencion;
        if (fecha_nacimiento) {
            const dob = new Date(fecha_nacimiento);
            const today = new Date();
            let age = today.getFullYear() - dob.getFullYear();
            const m = today.getMonth() - dob.getMonth();
            if (m < 0 || (m === 0 && today.getDate() < dob.getDate())) {
                age--;
            }
            edad_atencion = age;
        } else {
            throw new Error('La fecha de nacimiento es obligatoria');
        }

        const isMinor = edad_atencion < 18;

        if (!nombre || !apellido || !sexo) {
            throw new Error('Nombre, apellido y sexo son obligatorios');
        }

        if (isMinor) {
            if (!nombre_representante || !apellido_representante || !cedula_representante || !telefono_representante) {
                throw new Error('Para menores de edad, los datos del representante son obligatorios');
            }
        } else {
            if (!cedula) {
                throw new Error('La cédula es obligatoria para mayores de edad');
            }
        }

        let pacienteRecord = null;
        let wasExisting = false;
        if (cedula) {
            pacienteRecord = await Paciente.findOne({ where: { cedula }, transaction: t });
            if (pacienteRecord) wasExisting = true;
        }

        if (pacienteRecord) {
            const updateData = {};
            if (telefono !== undefined) updateData.telefono = telefono;
            if (direccion !== undefined) updateData.direccion = direccion;

            if (isMinor) {
                if (nombre_representante) updateData.nombre_representante = nombre_representante;
                if (apellido_representante) updateData.apellido_representante = apellido_representante;
                if (cedula_representante) updateData.cedula_representante = cedula_representante;
                if (telefono_representante) updateData.telefono_representante = telefono_representante;
            }

            if (Object.keys(updateData).length > 0) {
                await pacienteRecord.update(updateData, { transaction: t });
            }
        } else {
            pacienteRecord = await Paciente.create({
                nombre,
                apellido,
                cedula: cedula || null,
                fecha_nacimiento,
                sexo,
                telefono,
                direccion,
                nombre_representante: isMinor ? nombre_representante : null,
                apellido_representante: isMinor ? apellido_representante : null,
                cedula_representante: isMinor ? cedula_representante : null,
                telefono_representante: isMinor ? telefono_representante : null
            }, { transaction: t });
        }

        if (consumos && consumos.length > 0) {
            for (const consumo of consumos) {
                const lote = await LoteInsumo.findByPk(consumo.id_lote_insumo, { transaction: t });
                if (!lote) {
                    throw new Error(`Lote con ID ${consumo.id_lote_insumo} no encontrado.`);
                }
                if (lote.stock_actual < consumo.cantidad_usada) {
                    throw new Error(`Stock insuficiente para el lote ${lote.numero_lote}. Disponible: ${lote.stock_actual}, Solicitado: ${consumo.cantidad_usada}`);
                }
            }
        }

        const nuevaAtencion = await AtencionDiaria.create({
            paciente_id: pacienteRecord.id,
            diagnostico,
            edad_atencion,
            id_usuario_registra,
            fecha: fecha || new Date()
        }, { transaction: t });

        if (consumos && consumos.length > 0) {
            const consumosData = consumos.map(c => ({
                id_atencion: nuevaAtencion.id,
                id_lote_insumo: c.id_lote_insumo,
                cantidad_usada: c.cantidad_usada
            }));
            await ConsumoInsumo.bulkCreate(consumosData, { transaction: t });
        }

        await t.commit();

        res.status(201).json({
            success: true,
            message: 'Paciente y atención registrados exitosamente',
            data: {
                paciente: pacienteRecord,
                atencion: nuevaAtencion,
                patient: pacienteRecord,
                attention: nuevaAtencion,
                paciente_existia: wasExisting
            }
        });

    } catch (error) {
        await t.rollback();
        console.error('Error al registrar paciente y atención:', error);
        res.status(400).json({
            success: false,
            message: error.message || 'Error al registrar paciente y atención',
            error: process.env.NODE_ENV === 'development' ? error : {}
        });
    }
};

exports.registrarPacienteLegacy = async (req, res) => {
    const {
        nombre, apellido, edad, fecha_nacimiento, sexo, cedula, telefono, direccion,
        nombre_representante, apellido_representante, cedula_representante, telefono_representante,
        diagnostico, fecha
    } = req.body;

    let final_fecha_nacimiento = fecha_nacimiento;
    if (!final_fecha_nacimiento && edad !== undefined) {
        const today = new Date();
        final_fecha_nacimiento = new Date(today.getFullYear() - edad, today.getMonth(), today.getDate());
    }

    req.body = {
        cedula,
        paciente: {
            nombre, apellido, fecha_nacimiento: final_fecha_nacimiento, sexo, telefono, direccion,
            nombre_representante, apellido_representante, cedula_representante, telefono_representante
        },
        atencion: {
            diagnostico: diagnostico || 'Consulta general',
            fecha: fecha || new Date()
        },
        consumos: []
    };

    return exports.registrarCompleto(req, res);
};

exports.registrarAtencionLegacy = async (req, res) => {
    const { paciente_id, diagnostico, edad_atencion, id_usuario_registra, consumos, fecha } = req.body;

    try {
        const paciente = await Paciente.findByPk(paciente_id);
        if (!paciente) {
            return res.status(404).json({ success: false, message: 'Paciente no encontrado' });
        }

        req.body = {
            cedula: paciente.cedula,
            paciente: {
                nombre: paciente.nombre,
                apellido: paciente.apellido,
                fecha_nacimiento: paciente.fecha_nacimiento,
                sexo: paciente.sexo,
                telefono: paciente.telefono,
                direccion: paciente.direccion,
                nombre_representante: paciente.nombre_representante,
                apellido_representante: paciente.apellido_representante,
                cedula_representante: paciente.cedula_representante,
                telefono_representante: paciente.telefono_representante
            },
            atencion: {
                diagnostico: diagnostico || 'Consulta general',
                fecha: fecha || new Date()
            },
            consumos: consumos || []
        };

        return exports.registrarCompleto(req, res);
    } catch (error) {
        return res.status(500).json({ success: false, message: error.message });
    }
};

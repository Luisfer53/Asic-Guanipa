const { sequelize, AtencionDiaria, ConsumoInsumo, LoteInsumo,
    Paciente, Persona, Diagnostico, AtencionDiagnostico, RegistroVacunacion,
    EsquemaDosificacion, CentroSalud, OperativoSalud, SectorGuanipa } = require('../models');
const db = require('../models');
const { Op } = require('sequelize');
const { logAction } = require('../utils/auditLogger');
const { calcularEdad, semanaEpidemiologica, nombreCompleto } = require('../utils/formatters');

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

/**
 * POST /api/atenciones/registrar-completo
 *
 * Body esperado:
 * {
 *   persona: { cedula_identidad, nombre1, nombre2, apellido1, apellido2,
 *              sexo, fecha_nacimiento, telefono, correo, direccion },
 *   paciente_clinico: { peso, tipo_sangre, alergias, enfermedades_cronicas, ... },
 *   representante: { cedula_identidad, nombre1, apellido1, telefono, parentesco }, // opcional
 *   atencion: { fecha_visita, id_centro, id_operativo, diagnostico_general,
 *               semana_epidemiologica },
 *   diagnosticos: [ { id_diagnostico, observacion_medica } ],  // opcional
 *   consumos: [ { id_lote_insumo, cantidad_usada } ],           // opcional
 *   vacunaciones: [ { id_lote, id_esquema, dosis_aplicada } ]  // opcional
 * }
 */
exports.registrarCompleto = async (req, res) => {
    const t = await sequelize.transaction();

    try {
        const personaData = req.body.persona || req.body.paciente;
        const atencion = req.body.atencion;
        const paciente_clinico = req.body.paciente_clinico || {};
        const representanteData = req.body.representante;
        const diagnosticos = req.body.diagnosticos || [];
        const consumos = req.body.consumos || [];
        const vacunaciones = req.body.vacunaciones || [];

        if (!personaData || !atencion) {
            await t.rollback();
            return res.status(400).json({
                success: false,
                message: 'Los datos de la persona y la atención son obligatorios'
            });
        }

        const { cedula_identidad, nombre1, apellido1, sexo, fecha_nacimiento,
            telefono, correo, direccion } = personaData;

        if (!nombre1 || !apellido1 || !sexo) {
            await t.rollback();
            return res.status(400).json({
                success: false,
                message: 'nombre1, apellido1 y sexo son obligatorios'
            });
        }

        const id_usuario_registra = req.user ? req.user.id : null;
        const edad = calcularEdad(fecha_nacimiento);
        const esMenor = edad !== null && edad < 18;

        // ── 1. Buscar o crear Persona ──────────────────────────────────────────
        let persona = null;
        let wasExisting = false;
        if (cedula_identidad) {
            persona = await Persona.findOne({ where: { cedula_identidad }, transaction: t });
            if (persona) wasExisting = true;
        }

        if (!persona) {
            persona = await Persona.create({
                cedula_identidad: cedula_identidad || null,
                nombre1, nombre2: personaData.nombre2 || null,
                apellido1, apellido2: personaData.apellido2 || null,
                sexo, fecha_nacimiento: fecha_nacimiento || null,
                estado_civil: personaData.estado_civil || null,
                ocupacion: personaData.ocupacion || null
            }, { transaction: t });
        } else {
            // Actualizar datos de contacto si se enviaron
            const updates = {};
            if (personaData.nombre2) updates.nombre2 = personaData.nombre2;
            if (personaData.apellido2) updates.apellido2 = personaData.apellido2;
            if (Object.keys(updates).length > 0) {
                await persona.update(updates, { transaction: t });
            }
        }

        // ── 2. Teléfono, correo y dirección ────────────────────────────────────
        if (telefono) {
            await upsertTelefono(persona.id_persona, telefono, t);
        }
        if (correo) {
            await upsertCorreo(persona.id_persona, correo, t);
        }
        if (direccion !== undefined && direccion !== null) {
            await upsertDireccion(persona.id_persona, direccion, t);
        }

        // ── 3. Representante (menores) ─────────────────────────────────────────
        let idRepresentante = null;
        let parentesco = null;
        if (esMenor && representanteData && representanteData.cedula_identidad) {
            let personaRep = await Persona.findOne({
                where: { cedula_identidad: representanteData.cedula_identidad },
                transaction: t
            });
            if (!personaRep) {
                personaRep = await Persona.create({
                    cedula_identidad: representanteData.cedula_identidad,
                    nombre1: representanteData.nombre1 || null,
                    nombre2: representanteData.nombre2 || null,
                    apellido1: representanteData.apellido1 || null,
                    apellido2: representanteData.apellido2 || null
                }, { transaction: t });
            }
            if (representanteData.telefono) {
                const telRep = await db.Telefono.findOne({ where: { id_persona: personaRep.id_persona }, transaction: t });
                if (!telRep) {
                    await db.Telefono.create({ id_persona: personaRep.id_persona, numero_telefono: representanteData.telefono }, { transaction: t });
                }
            }
            idRepresentante = personaRep.id_persona;
            parentesco = representanteData.parentesco || null;
        }

        // ── 4. Buscar o crear Paciente clínico ────────────────────────────────
        let pacienteRecord = await Paciente.findOne({
            where: { id_persona: persona.id_persona },
            transaction: t
        });

        if (!pacienteRecord) {
            pacienteRecord = await Paciente.create({
                id_persona: persona.id_persona,
                id_representante: idRepresentante,
                parentesco_representante: parentesco,
                fecha_registro: new Date(),
                ...paciente_clinico
            }, { transaction: t });
        } else if (idRepresentante && !pacienteRecord.id_representante) {
            await pacienteRecord.update({ id_representante: idRepresentante, parentesco_representante: parentesco }, { transaction: t });
        }

        // ── 5. Validar stock de consumos ──────────────────────────────────────
        if (consumos && consumos.length > 0) {
            for (const consumo of consumos) {
                const lote = await LoteInsumo.findByPk(consumo.id_lote_insumo, { transaction: t });
                if (!lote) throw new Error(`Lote ID ${consumo.id_lote_insumo} no encontrado`);
                if (lote.stock_actual < consumo.cantidad_usada) {
                    throw new Error(`Stock insuficiente: Lote ${lote.numero_lote}. Disponible: ${lote.stock_actual}, Solicitado: ${consumo.cantidad_usada}`);
                }
            }
        }

        // ── 6. Crear Atención Diaria ───────────────────────────────────────────
        const fechaVisita = atencion.fecha_visita || new Date();

        // Construir diagnostico_general incluyendo motivo de consulta si existe
        let diagnosticoGeneral = atencion.diagnostico_general || null;
        const motivoConsulta = atencion.motivo_consulta || null;
        if (motivoConsulta && diagnosticoGeneral) {
            diagnosticoGeneral = `[Motivo: ${motivoConsulta}] ${diagnosticoGeneral}`;
        } else if (motivoConsulta) {
            diagnosticoGeneral = `[Motivo: ${motivoConsulta}]`;
        }

        const nuevaAtencion = await AtencionDiaria.create({
            id_paciente: pacienteRecord.id_paciente,
            fecha_visita: fechaVisita,
            semana_epidemiologica: atencion.semana_epidemiologica || semanaEpidemiologica(fechaVisita),
            diagnostico_general: diagnosticoGeneral,
            id_centro: atencion.id_centro || null,
            id_operativo: atencion.id_operativo || null,
            id_usuario_registra
        }, { transaction: t });

        // ── 6b. Guardar tratamiento indicado, observaciones y signos vitales como registros Tratamiento ──
        const tratamientoIndicado = atencion.tratamiento_indicado || null;
        const observaciones = atencion.observaciones || null;

        if (tratamientoIndicado && tratamientoIndicado.trim() !== '') {
            await db.Tratamiento.create({
                id_atencion: nuevaAtencion.id_atencion,
                tipo_tratamiento: 'Indicación Médica',
                detalles: tratamientoIndicado.trim()
            }, { transaction: t });
        }

        if (observaciones && observaciones.trim() !== '') {
            await db.Tratamiento.create({
                id_atencion: nuevaAtencion.id_atencion,
                tipo_tratamiento: 'Observación Médica',
                detalles: observaciones.trim()
            }, { transaction: t });
        }

        // Guardar signos vitales si fueron ingresados en la jornada
        const signosList = [];
        if (atencion.peso_kg) {
            signosList.push(`Peso: ${atencion.peso_kg} kg`);
            if (!pacienteRecord.peso || pacienteRecord.peso !== atencion.peso_kg) {
                await pacienteRecord.update({ peso: atencion.peso_kg }, { transaction: t });
            }
        }
        if (atencion.talla_cm) signosList.push(`Talla: ${atencion.talla_cm} cm`);
        if (atencion.temperatura_c) signosList.push(`Temp: ${atencion.temperatura_c} °C`);
        if (atencion.presion_arterial) signosList.push(`P.A: ${atencion.presion_arterial} mmHg`);
        if (atencion.frecuencia_cardiaca) signosList.push(`F.C: ${atencion.frecuencia_cardiaca} lpm`);
        if (atencion.frecuencia_respiratoria) signosList.push(`F.R: ${atencion.frecuencia_respiratoria} rpm`);
        if (atencion.saturacion_o2) signosList.push(`SatO2: ${atencion.saturacion_o2}%`);

        if (signosList.length > 0) {
            await db.Tratamiento.create({
                id_atencion: nuevaAtencion.id_atencion,
                tipo_tratamiento: 'Signos Vitales',
                detalles: signosList.join(' · ')
            }, { transaction: t });
        }

        // ── 7. Diagnósticos específicos ───────────────────────────────────────
        if (diagnosticos && diagnosticos.length > 0) {
            for (const diag of diagnosticos) {
                await AtencionDiagnostico.create({
                    id_atencion_diaria: nuevaAtencion.id_atencion,
                    id_diagnostico: diag.id_diagnostico,
                    observacion_medica: diag.observacion_medica || null,
                    fecha_registro: fechaVisita
                }, { transaction: t });
            }
        }

        // ── 8. Consumo de insumos y actualización de stock ────────────────────
        if (consumos && consumos.length > 0) {
            for (const consumo of consumos) {
                await ConsumoInsumo.create({
                    id_atencion: nuevaAtencion.id_atencion,
                    id_lote_insumo: consumo.id_lote_insumo,
                    cantidad_usada: consumo.cantidad_usada
                }, { transaction: t });

                const lote = await LoteInsumo.findByPk(consumo.id_lote_insumo, { transaction: t });
                await lote.update({
                    stock_actual: lote.stock_actual - consumo.cantidad_usada
                }, { transaction: t });
            }
        }

        // ── 9. Vacunaciones ───────────────────────────────────────────────────
        if (vacunaciones && vacunaciones.length > 0) {
            for (const vac of vacunaciones) {
                await RegistroVacunacion.create({
                    id_atencion: nuevaAtencion.id_atencion,
                    id_lote: vac.id_lote,
                    id_esquema: vac.id_esquema || null,
                    dosis_aplicada: vac.dosis_aplicada || null
                }, { transaction: t });

                // Descontar del inventario también
                if (vac.id_lote) {
                    const loteVac = await LoteInsumo.findByPk(vac.id_lote, { transaction: t });
                    if (loteVac && loteVac.stock_actual > 0) {
                        await loteVac.update({ stock_actual: loteVac.stock_actual - 1 }, { transaction: t });
                    }
                }
            }
        }

        await t.commit();

        await logAction(
            req.user ? req.user.username : 'sistema',
            `Registro de atención médica: ${nombre1} ${apellido1}`,
            'atenciones_diarias',
            {
                id_paciente: pacienteRecord.id_paciente,
                id_atencion: nuevaAtencion.id_atencion,
                consumos_cantidad: consumos.length,
                vacunaciones_cantidad: vacunaciones.length,
                diagnosticos_cantidad: diagnosticos.length
            }
        );

        res.status(201).json({
            success: true,
            message: 'Atención médica registrada exitosamente',
            data: {
                persona,
                paciente: pacienteRecord,
                atencion: nuevaAtencion,
                paciente_existia: wasExisting
            }
        });

    } catch (error) {
        await t.rollback();
        console.error('Error al registrar atención:', error);
        res.status(400).json({
            success: false,
            message: error.message || 'Error al registrar atención',
            error: process.env.NODE_ENV === 'development' ? error : {}
        });
    }
};

/**
 * Compatibilidad legacy: registrar paciente con formato antiguo (campos planos).
 * Convierte la request al formato nuevo y delega en registrarCompleto.
 */
exports.registrarPacienteLegacy = async (req, res) => {
    const {
        nombre, apellido, edad, fecha_nacimiento, sexo, cedula, telefono, direccion,
        nombre_representante, apellido_representante, cedula_representante, telefono_representante,
        direccion_representante, diagnostico, fecha
    } = req.body;

    let final_fecha_nacimiento = fecha_nacimiento;
    if (!final_fecha_nacimiento && edad !== undefined) {
        const today = new Date();
        final_fecha_nacimiento = new Date(today.getFullYear() - edad, today.getMonth(), today.getDate());
    }

    req.body = {
        persona: {
            cedula_identidad: cedula || null,
            nombre1: nombre,
            apellido1: apellido,
            sexo,
            fecha_nacimiento: final_fecha_nacimiento,
            telefono,
            direccion: direccion ? { calle: direccion } : undefined
        },
        representante: cedula_representante ? {
            cedula_identidad: cedula_representante,
            nombre1: nombre_representante,
            apellido1: apellido_representante,
            telefono: telefono_representante
        } : undefined,
        atencion: {
            diagnostico_general: diagnostico || 'Consulta general',
            fecha_visita: fecha || new Date()
        },
        consumos: [],
        diagnosticos: [],
        vacunaciones: []
    };

    return exports.registrarCompleto(req, res);
};

/**
 * Compatibilidad legacy: registrar atención para paciente existente por id.
 */
exports.registrarAtencionLegacy = async (req, res) => {
    const { paciente_id, diagnostico, edad_atencion, consumos, fecha } = req.body;

    try {
        const paciente = await Paciente.findByPk(paciente_id, {
            include: [{ model: Persona, as: 'persona' }]
        });
        if (!paciente) {
            return res.status(404).json({ success: false, message: 'Paciente no encontrado' });
        }

        const p = paciente.persona;
        req.body = {
            persona: {
                cedula_identidad: p.cedula_identidad,
                nombre1: p.nombre1,
                nombre2: p.nombre2,
                apellido1: p.apellido1,
                apellido2: p.apellido2,
                sexo: p.sexo,
                fecha_nacimiento: p.fecha_nacimiento
            },
            atencion: {
                diagnostico_general: diagnostico || 'Consulta general',
                fecha_visita: fecha || new Date()
            },
            consumos: consumos || [],
            diagnosticos: [],
            vacunaciones: []
        };
        return exports.registrarCompleto(req, res);
    } catch (error) {
        return res.status(500).json({ success: false, message: error.message });
    }
};

// ─────────────────────────────────────────────────────────────────────────────
// GESTIÓN DE OPERATIVOS DE SALUD (JORNADAS MÉDICAS)
// ─────────────────────────────────────────────────────────────────────────────

exports.crearOperativo = async (req, res) => {
    try {
        let { id_centro_organizador, nombre_operativo, nombre, fecha_operativo, fecha_inicio, fecha_fin, descripcion, tipo_jornada, lugar } = req.body;

        const nombreFinal = nombre_operativo || nombre;
        if (!nombreFinal) {
            return res.status(400).json({
                success: false,
                message: 'El nombre del operativo o jornada es obligatorio'
            });
        }

        if (!id_centro_organizador) {
            const primerCentro = await CentroSalud.findOne();
            id_centro_organizador = primerCentro ? primerCentro.id_centro : 1;
        }

        let descFinal = descripcion || '';
        if (tipo_jornada || lugar) {
            const metaInfo = `[Tipo: ${tipo_jornada || 'N/A'}] [Lugar: ${lugar || 'N/A'}]`;
            descFinal = descFinal ? `${metaInfo} ${descFinal}` : metaInfo;
        }

        const operativo = await OperativoSalud.create({
            id_centro_organizador,
            nombre_operativo: nombreFinal,
            fecha_operativo: fecha_operativo || fecha_inicio || new Date(),
            fecha_fin: fecha_fin || null,
            descripcion: descFinal || null
        });

        await logAction(
            req.user ? req.user.username : 'sistema',
            `Creación de jornada/operativo de salud: ${nombreFinal}`,
            'operativos_salud',
            { id_operativo: operativo.id_operativo }
        );

        res.status(201).json({
            success: true,
            message: 'Jornada médica / Operativo de salud creado exitosamente',
            data: operativo
        });
    } catch (error) {
        console.error('Error al crear operativo:', error);
        res.status(500).json({
            success: false,
            message: 'Error al crear operativo de salud',
            error: error.message
        });
    }
};

exports.actualizarOperativo = async (req, res) => {
    try {
        const { id } = req.params;
        const { nombre_operativo, nombre, fecha_operativo, fecha_inicio, fecha_fin, descripcion, id_centro_organizador } = req.body;

        const operativo = await OperativoSalud.findByPk(id);
        if (!operativo) {
            return res.status(404).json({ success: false, message: 'Jornada / Operativo no encontrado' });
        }

        const nombreFinal = nombre_operativo || nombre || operativo.nombre_operativo;
        const fechaInicioFinal = fecha_operativo || fecha_inicio || operativo.fecha_operativo;

        await operativo.update({
            nombre_operativo: nombreFinal,
            fecha_operativo: fechaInicioFinal,
            fecha_fin: fecha_fin !== undefined ? fecha_fin : operativo.fecha_fin,
            descripcion: descripcion !== undefined ? descripcion : operativo.descripcion,
            id_centro_organizador: id_centro_organizador || operativo.id_centro_organizador
        });

        await logAction(
            req.user ? req.user.username : 'sistema',
            `Actualización de jornada/operativo ID ${id}: ${nombreFinal}`,
            'operativos_salud',
            { id_operativo: id }
        );

        const actualizado = await OperativoSalud.findByPk(id, {
            include: [{ model: CentroSalud, as: 'centroOrganizador', attributes: ['id_centro', 'nombre_centro'] }]
        });

        res.status(200).json({
            success: true,
            message: 'Jornada / Operativo actualizado exitosamente (plazo extendido)',
            data: actualizado
        });
    } catch (error) {
        console.error('Error al actualizar operativo:', error);
        res.status(500).json({
            success: false,
            message: 'Error al actualizar operativo de salud',
            error: error.message
        });
    }
};

exports.eliminarOperativo = async (req, res) => {
    try {
        const { id } = req.params;
        const operativo = await OperativoSalud.findByPk(id);
        if (!operativo) {
            return res.status(404).json({ success: false, message: 'Jornada / Operativo no encontrado' });
        }

        await operativo.destroy();

        await logAction(
            req.user ? req.user.username : 'sistema',
            `Eliminación de jornada/operativo ID ${id}`,
            'operativos_salud',
            { id_operativo: id }
        );

        res.status(200).json({
            success: true,
            message: 'Jornada / Operativo eliminado exitosamente'
        });
    } catch (error) {
        console.error('Error al eliminar operativo:', error);
        res.status(500).json({
            success: false,
            message: 'Error al eliminar operativo de salud',
            error: error.message
        });
    }
};

exports.listarOperativos = async (req, res) => {
    try {
        const { search, centro, fecha_inicio, fecha_fin } = req.query;
        const operativosWhere = {};

        if (centro) {
            const centroId = parseInt(centro, 10);
            if (!Number.isNaN(centroId)) {
                operativosWhere.id_centro_organizador = centroId;
            }
        }
        if (fecha_inicio) {
            operativosWhere.fecha_operativo = { [Op.gte]: fecha_inicio };
        }
        if (fecha_fin) {
            operativosWhere.fecha_fin = { [Op.lte]: fecha_fin };
        }

        if (search && search.trim().length > 0) {
            const tokens = search.trim().split(/\s+/).filter(Boolean);
            if (tokens.length > 0) {
                operativosWhere[Op.and] = tokens.map((token) => ({
                    [Op.or]: [
                        { nombre_operativo: { [Op.iLike]: `%${token}%` } },
                        { descripcion: { [Op.iLike]: `%${token}%` } }
                    ]
                }));
            }
        }

        const operativos = await OperativoSalud.findAll({
            where: operativosWhere,
            include: [
                { model: CentroSalud, as: 'centroOrganizador', attributes: ['id_centro', 'nombre_centro'] },
                {
                    model: db.AtencionDiaria,
                    as: 'atenciones',
                    include: [
                        {
                            model: db.Paciente,
                            as: 'paciente',
                            include: [
                                {
                                    model: db.Persona,
                                    as: 'persona',
                                    attributes: ['id_persona', 'nombre1', 'apellido1', 'cedula_identidad', 'sexo', 'fecha_nacimiento']
                                }
                            ]
                        },
                        {
                            model: db.RegistroVacunacion,
                            as: 'vacunaciones',
                            include: [
                                {
                                    model: db.LoteInsumo,
                                    as: 'lote',
                                    include: [{ model: db.ArticuloMedico, as: 'articulo', attributes: ['nombre_articulo'] }]
                                }
                            ]
                        },
                        {
                            model: db.ConsumoInsumo,
                            as: 'consumos',
                            include: [
                                {
                                    model: db.LoteInsumo,
                                    as: 'lote',
                                    include: [{ model: db.ArticuloMedico, as: 'articulo', attributes: ['nombre_articulo'] }]
                                }
                            ]
                        },
                        {
                            model: db.AtencionDiagnostico,
                            as: 'diagnosticos',
                            include: [{ model: db.Diagnostico, as: 'diagnostico', attributes: ['condicion'] }]
                        }
                    ]
                }
            ],
            order: [['fecha_operativo', 'DESC']]
        });

        res.status(200).json({
            success: true,
            count: operativos.length,
            data: operativos
        });
    } catch (error) {
        console.error('Error al listar operativos:', error);
        res.status(500).json({
            success: false,
            message: 'Error al listar operativos de salud',
            error: error.message
        });
    }
};

// ─────────────────────────────────────────────────────────────────────────────
// GESTIÓN DE CENTROS DE SALUD
// ─────────────────────────────────────────────────────────────────────────────

exports.listarCentros = async (req, res) => {
    try {
        const centros = await CentroSalud.findAll({
            where: { es_puesto_activo: true },
            order: [['nombre_centro', 'ASC']]
        });
        res.status(200).json({ success: true, count: centros.length, data: centros });
    } catch (error) {
        console.error('Error al listar centros de salud:', error);
        res.status(500).json({ success: false, message: 'Error al listar centros de salud', error: error.message });
    }
};

exports.crearCentro = async (req, res) => {
    try {
        const { nombre_centro, es_puesto_activo = true } = req.body;
        if (!nombre_centro) {
            return res.status(400).json({ success: false, message: 'nombre_centro es obligatorio' });
        }
        const centro = await CentroSalud.create({ nombre_centro, es_puesto_activo });
        res.status(201).json({ success: true, message: 'Centro de salud creado exitosamente', data: centro });
    } catch (error) {
        console.error('Error al crear centro de salud:', error);
        res.status(500).json({ success: false, message: 'Error al crear centro de salud', error: error.message });
    }
};

// ─────────────────────────────────────────────────────────────────────────────
// GESTIÓN DE SECTORES DE GUANIPA (RF-18: Estructura Geográfica de Salud)
// ─────────────────────────────────────────────────────────────────────────────

exports.listarSectores = async (req, res) => {
    try {
        const sectores = await db.SectorGuanipa.findAll({
            order: [['nombre_sector', 'ASC']]
        });
        res.status(200).json({ success: true, count: sectores.length, data: sectores });
    } catch (error) {
        console.error('Error al listar sectores de Guanipa:', error);
        res.status(500).json({ success: false, message: 'Error al listar sectores', error: error.message });
    }
};

exports.crearSector = async (req, res) => {
    try {
        const { nombre_sector } = req.body;
        if (!nombre_sector) {
            return res.status(400).json({ success: false, message: 'nombre_sector es obligatorio' });
        }
        const sector = await db.SectorGuanipa.create({ nombre_sector });
        res.status(201).json({ success: true, message: 'Sector creado exitosamente', data: sector });
    } catch (error) {
        console.error('Error al crear sector:', error);
        res.status(500).json({ success: false, message: 'Error al crear sector', error: error.message });
    }
};



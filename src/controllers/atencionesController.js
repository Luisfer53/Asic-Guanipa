const db = require('../models');
const { sequelize, AtencionDiaria, ConsumoInsumo, LoteInsumo, Paciente, Persona, RegistroVacunacion, OperativoSalud, CentroSalud, SectorGuanipa, OperativoStock, ArticuloMedico } = db;
const { semanaEpidemiologica } = require('../utils/formatters');
const { logAction } = require('../utils/auditLogger');

exports.registrarCompleto = async (req, res) => {
    const t = await sequelize.transaction();

    try {
        const { cedula, paciente, persona, atencion, consumos, vacunaciones } = req.body;
        const personaData = paciente || persona;

        if (!personaData || !atencion) {
            throw new Error('Los datos del paciente y de la atención son obligatorios');
        }

        const nombre = personaData.nombre || personaData.nombre1;
        const apellido = personaData.apellido || personaData.apellido1;
        const nombre2 = personaData.nombre2 || null;
        const apellido2 = personaData.apellido2 || null;
        const fecha_nacimiento = personaData.fecha_nacimiento;
        const sexo = personaData.sexo;
        const telefono = personaData.telefono;
        const direccion = personaData.direccion;

        const cedulaDoc = cedula || personaData.cedula || personaData.cedula_identidad || null;

        if (!nombre || !apellido || !sexo) {
            throw new Error('Nombre, apellido y sexo son obligatorios');
        }

        let pacienteRecord = null;
        let personaRecord = null;

        // 1. Buscar si ya existe por cédula
        if (cedulaDoc && cedulaDoc.trim()) {
            personaRecord = await db.Persona.findOne({
                where: { cedula_identidad: cedulaDoc.trim() },
                transaction: t
            });
            if (personaRecord) {
                pacienteRecord = await db.Paciente.findOne({
                    where: { id_persona: personaRecord.id_persona },
                    transaction: t
                });
            }
        }

        // Si no existe persona, crearla
        if (!personaRecord) {
            personaRecord = await db.Persona.create({
                cedula_identidad: cedulaDoc ? cedulaDoc.trim() : null,
                nombre1: nombre,
                nombre2: nombre2,
                apellido1: apellido,
                apellido2: apellido2,
                sexo: sexo.toUpperCase().startsWith('M') ? 'M' : 'F',
                fecha_nacimiento: fecha_nacimiento || null
            }, { transaction: t });

            if (telefono) {
                await db.Telefono.create({
                    id_persona: personaRecord.id_persona,
                    numero_telefono: telefono
                }, { transaction: t });
            }
        }

        // Si no existe paciente para esa persona, crearlo
        if (!pacienteRecord) {
            pacienteRecord = await db.Paciente.create({
                id_persona: personaRecord.id_persona,
                fecha_registro: new Date(),
                peso: atencion.peso_kg || (vacunaciones && vacunaciones[0] && vacunaciones[0].peso) || null
            }, { transaction: t });
        }

        // 2. Resolver centro de salud
        let idCentro = atencion.id_centro || null;
        if (!idCentro && atencion.guardia_centro) {
            const c = await db.CentroSalud.findOne({
                where: { nombre_centro: atencion.guardia_centro },
                transaction: t
            });
            if (c) idCentro = c.id_centro;
        }

        // Si la atención está asociada a una jornada, validar autorización del usuario
        if (atencion.id_operativo) {
            const op = await OperativoSalud.findByPk(atencion.id_operativo, { transaction: t });
            if (!op) {
                throw new Error(`La jornada seleccionada (ID ${atencion.id_operativo}) no existe.`);
            }
            if (['finalizada', 'cancelada'].includes(op.estado)) {
                throw new Error(`La jornada "${op.nombre_operativo}" se encuentra ${op.estado}. No se pueden registrar más atenciones en ella.`);
            }

            // Validar que el usuario que registra sea el responsable o un participante asignado
            const usuarioActual = req.user?.username || req.user?.nombre_usuario || '';
            let participantes = [];
            try {
                participantes = JSON.parse(op.personal_participante || '[]');
            } catch (_) {
                participantes = (op.personal_participante || '').split(',').map(s => s.trim());
            }
            if (!Array.isArray(participantes)) participantes = [participantes];

            const usernamesAutorizados = participantes.map(p => (typeof p === 'object' && p !== null ? p.username : p)).filter(Boolean);
            if (op.responsable) {
                usernamesAutorizados.push(op.responsable);
            }

            const esAdmin = req.user?.roles && req.user.roles.includes('Admin');
            const estaAutorizado = esAdmin || usernamesAutorizados.some(u => (u || '').toLowerCase() === usuarioActual.toLowerCase());

            if (!estaAutorizado) {
                throw new Error(`Acceso denegado: El usuario "${usuarioActual}" no está asignado como participante en la jornada "${op.nombre_operativo}". Solo el personal asignado puede registrar en ella.`);
            }
        }

        // 3. Crear registro de atención diaria (Consulta Médica o Inmunización)
        const fechaVisita = atencion.fecha_visita || atencion.fecha || new Date();
        const tipoAtencion = atencion.tipo_atencion || (vacunaciones && vacunaciones.length > 0 ? 'inmunizacion' : 'consulta_medica');
        const diagDefault = tipoAtencion === 'inmunizacion' ? 'Inmunización preventiva' : 'Consulta médica general';

        const nuevaAtencion = await AtencionDiaria.create({
            id_paciente: pacienteRecord.id_paciente,
            fecha_visita: fechaVisita,
            semana_epidemiologica: semanaEpidemiologica(fechaVisita) || 1,
            tipo_atencion: tipoAtencion,
            diagnostico_general: atencion.diagnostico_general || atencion.diagnostico || diagDefault,
            motivo_consulta: atencion.motivo_consulta || null,
            presion_arterial: atencion.presion_arterial || null,
            frecuencia_cardiaca: atencion.frecuencia_cardiaca ? parseInt(atencion.frecuencia_cardiaca, 10) : null,
            frecuencia_respiratoria: atencion.frecuencia_respiratoria ? parseInt(atencion.frecuencia_respiratoria, 10) : null,
            saturacion_oxigeno: atencion.saturacion_oxigeno ? parseInt(atencion.saturacion_oxigeno, 10) : null,
            temperatura: (atencion.temperatura !== undefined && atencion.temperatura !== '') ? parseFloat(atencion.temperatura) : null,
            peso: (atencion.peso !== undefined && atencion.peso !== '') ? parseFloat(atencion.peso) : (atencion.peso_kg ? parseFloat(atencion.peso_kg) : null),
            talla: (atencion.talla !== undefined && atencion.talla !== '') ? parseFloat(atencion.talla) : (atencion.talla_cm ? parseFloat(atencion.talla_cm) : null),
            tratamiento_indicado: atencion.tratamiento_indicado || atencion.tratamiento || null,
            observaciones: atencion.observaciones || null,
            id_centro: idCentro,
            id_operativo: atencion.id_operativo || null,
            id_usuario_registra: req.user?.id || 1
        }, { transaction: t });

        // Si se registró peso en la atención y el paciente no lo tenía, actualizarlo
        const pesoFinal = atencion.peso || atencion.peso_kg;
        if (pesoFinal && parseFloat(pesoFinal) > 0) {
            await pacienteRecord.update({ peso: parseFloat(pesoFinal) }, { transaction: t });
        }

        // 4. Registrar consumos de insumos y descontar stock (con soporte de stock bloqueado por jornada)
        if (consumos && consumos.length > 0) {
            for (const consumo of consumos) {
                const loteId = consumo.id_lote_insumo || consumo.id_lote;
                if (!loteId) continue;

                const lote = await LoteInsumo.findByPk(loteId, {
                    include: [{ model: ArticuloMedico, as: 'articulo' }],
                    transaction: t
                });
                if (!lote) {
                    throw new Error(`Lote con ID ${loteId} no encontrado.`);
                }
                const cant = parseInt(consumo.cantidad_usada, 10) || 1;

                if (nuevaAtencion.id_operativo) {
                    // Atención bajo una jornada u operativo: verificar si el lote está bloqueado en dicha jornada
                    const opStock = await OperativoStock.findOne({
                        where: {
                            id_operativo: nuevaAtencion.id_operativo,
                            id_lote_insumo: loteId
                        },
                        transaction: t
                    });

                    if (opStock) {
                        if (opStock.cantidad_remanente < cant) {
                            throw new Error(`Stock asignado a la jornada agotado para el lote ${lote.numero_lote}. Remanente: ${opStock.cantidad_remanente}, Requerido: ${cant}`);
                        }
                        await opStock.update({
                            cantidad_usada: opStock.cantidad_usada + cant,
                            cantidad_remanente: Math.max(0, opStock.cantidad_remanente - cant)
                        }, { transaction: t });

                        await lote.update({
                            stock_actual: Math.max(0, lote.stock_actual - cant),
                            stock_reservado: Math.max(0, (lote.stock_reservado || 0) - cant)
                        }, { transaction: t });
                    } else {
                        // El lote no está en el stock reservado del operativo, validar stock libre
                        const stockLibre = (lote.stock_actual || 0) - (lote.stock_reservado || 0);
                        if (stockLibre < cant) {
                            throw new Error(`Stock libre insuficiente para el lote ${lote.numero_lote}. Disponible: ${stockLibre}, Solicitado: ${cant}`);
                        }
                        await lote.update({
                            stock_actual: Math.max(0, lote.stock_actual - cant)
                        }, { transaction: t });
                    }
                } else {
                    // Atención regular en el CDI: solo puede consumir stock LIBRE (no reservado para jornadas)
                    const stockLibre = (lote.stock_actual || 0) - (lote.stock_reservado || 0);
                    if (stockLibre < cant) {
                        throw new Error(`Stock libre insuficiente para el lote ${lote.numero_lote}. Hay ${lote.stock_reservado || 0} unidades reservadas para jornadas de vacunación activas. Stock libre disponible: ${stockLibre}, Solicitado: ${cant}`);
                    }
                    await lote.update({
                        stock_actual: Math.max(0, lote.stock_actual - cant)
                    }, { transaction: t });
                }

                await ConsumoInsumo.create({
                    id_atencion: nuevaAtencion.id_atencion,
                    id_lote_insumo: loteId,
                    cantidad_usada: cant
                }, { transaction: t });
            }
        }

        // 5. Registrar vacunaciones específicas (Fase 3)
        const vacs = vacunaciones || [];
        if (vacs && vacs.length > 0) {
            for (const vac of vacs) {
                const idLoteVac = vac.id_lote || vac.id_lote_insumo;
                if (!idLoteVac) continue;

                await RegistroVacunacion.create({
                    id_atencion: nuevaAtencion.id_atencion,
                    id_lote: idLoteVac,
                    id_esquema: vac.id_esquema || null,
                    dosis_aplicada: vac.dosis_aplicada || '1ra Dosis',
                    via_administracion: vac.via_administracion || null,
                    sitio_administracion: vac.sitio_administracion || null,
                    temperatura: vac.temperatura !== undefined ? vac.temperatura : null,
                    peso: vac.peso !== undefined ? vac.peso : null,
                    talla: vac.talla !== undefined ? vac.talla : null,
                    modalidad: vac.modalidad || atencion.guardia_modalidad || 'intramural'
                }, { transaction: t });

                // Si se tomó peso pediátrico y el paciente no tenía, actualizarlo
                if (vac.peso && vac.peso > 0) {
                    await pacienteRecord.update({ peso: vac.peso }, { transaction: t });
                }
            }
        }

        await t.commit();

        await logAction(
            req.user?.nombre_usuario || 'sistema',
            `Atención / Vacunación registrada: Paciente ID ${pacienteRecord.id_paciente}`,
            'atenciones_diarias',
            { id_atencion: nuevaAtencion.id_atencion, id_paciente: pacienteRecord.id_paciente }
        );

        res.status(201).json({
            success: true,
            message: 'Vacunación y atención registradas exitosamente',
            data: {
                paciente: pacienteRecord,
                atencion: nuevaAtencion
            }
        });

    } catch (error) {
        await t.rollback();
        console.error('Error al registrar atención y vacunación:', error);
        res.status(400).json({
            success: false,
            message: error.message || 'Error al registrar atención y vacunación',
            error: process.env.NODE_ENV === 'development' ? error : {}
        });
    }
};

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
        cedula,
        paciente: {
            nombre, apellido, fecha_nacimiento: final_fecha_nacimiento, sexo, telefono, direccion,
            nombre_representante, apellido_representante, cedula_representante, telefono_representante,
            direccion_representante
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
    const {
        paciente_id, id_paciente, diagnostico, diagnostico_general, edad_atencion, id_usuario_registra, consumos, fecha,
        tipo_atencion, motivo_consulta, presion_arterial, temperatura, frecuencia_cardiaca,
        frecuencia_respiratoria, saturacion_oxigeno, peso, talla, tratamiento_indicado, observaciones
    } = req.body;

    try {
        const targetId = paciente_id || id_paciente;
        if (!targetId) {
            return res.status(400).json({ success: false, message: 'Se requiere paciente_id o id_paciente' });
        }

        const paciente = await Paciente.findByPk(targetId, {
            include: [{ model: db.Persona, as: 'persona' }]
        });
        if (!paciente) {
            return res.status(404).json({ success: false, message: 'Paciente no encontrado' });
        }

        req.body = {
            cedula: paciente.persona?.cedula_identidad,
            paciente: {
                nombre: paciente.persona?.nombre1,
                apellido: paciente.persona?.apellido1,
                fecha_nacimiento: paciente.persona?.fecha_nacimiento,
                sexo: paciente.persona?.sexo,
                telefono: '',
                direccion: ''
            },
            atencion: {
                tipo_atencion: tipo_atencion || 'consulta_medica',
                motivo_consulta: motivo_consulta || null,
                presion_arterial: presion_arterial || null,
                temperatura: temperatura || null,
                frecuencia_cardiaca: frecuencia_cardiaca || null,
                frecuencia_respiratoria: frecuencia_respiratoria || null,
                saturacion_oxigeno: saturacion_oxigeno || null,
                peso: peso || null,
                talla: talla || null,
                diagnostico: diagnostico || diagnostico_general || 'Consulta general',
                tratamiento_indicado: tratamiento_indicado || null,
                observaciones: observaciones || null,
                fecha: fecha || new Date()
            },
            consumos: consumos || []
        };

        return exports.registrarCompleto(req, res);
    } catch (error) {
        return res.status(500).json({ success: false, message: error.message });
    }
};

exports.listarOperativos = async (req, res) => {
    try {
        const { estado, modalidad } = req.query;
        const where = {};
        if (estado) where.estado = estado;
        if (modalidad) where.modalidad = modalidad;

        const ops = await OperativoSalud.findAll({
            where,
            include: [
                { model: CentroSalud, as: 'centroOrganizador', attributes: ['id_centro', 'nombre_centro'] },
                {
                    model: OperativoStock,
                    as: 'stockBloqueado',
                    include: [{
                        model: LoteInsumo,
                        as: 'lote',
                        include: [{ model: ArticuloMedico, as: 'articulo' }]
                    }]
                }
            ],
            order: [['fecha_operativo', 'DESC']]
        });
        res.json({ success: true, data: ops });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

exports.crearOperativo = async (req, res) => {
    const t = await sequelize.transaction();
    try {
        const {
            nombre,
            nombre_operativo,
            fecha_operativo,
            fecha_inicio,
            fecha_fin,
            descripcion,
            id_centro_organizador,
            modalidad,
            sector_comunidad,
            responsable,
            personal_participante,
            estado,
            lotes_bloqueados
        } = req.body;

        const nombreFinal = nombre_operativo || nombre;
        if (!nombreFinal || !nombreFinal.trim()) {
            throw new Error('El nombre de la jornada/operativo es obligatorio');
        }

        let personalFinal = personal_participante;
        if (Array.isArray(personal_participante)) {
            personalFinal = JSON.stringify(personal_participante);
        } else if (personal_participante && typeof personal_participante === 'object') {
            personalFinal = JSON.stringify([personal_participante]);
        }

        const op = await OperativoSalud.create({
            nombre_operativo: nombreFinal.trim(),
            fecha_operativo: fecha_operativo || fecha_inicio || new Date(),
            fecha_fin: fecha_fin || null,
            descripcion: descripcion || null,
            id_centro_organizador: id_centro_organizador || 1,
            modalidad: modalidad || 'intramural',
            sector_comunidad: sector_comunidad || null,
            responsable: responsable || null,
            personal_participante: personalFinal || null,
            estado: estado || 'planificada'
        }, { transaction: t });

        // Procesar bloqueo de stock para esta jornada
        if (lotes_bloqueados && Array.isArray(lotes_bloqueados) && lotes_bloqueados.length > 0) {
            for (const item of lotes_bloqueados) {
                const loteId = item.id_lote_insumo || item.id_lote;
                const cant = parseInt(item.cantidad || item.cantidad_bloqueada, 10);
                if (!loteId || isNaN(cant) || cant <= 0) continue;

                const lote = await LoteInsumo.findByPk(loteId, {
                    include: [{ model: ArticuloMedico, as: 'articulo' }],
                    transaction: t
                });
                if (!lote) {
                    throw new Error(`Lote ID ${loteId} no encontrado para bloquear stock.`);
                }

                const stockLibre = (lote.stock_actual || 0) - (lote.stock_reservado || 0);
                if (stockLibre < cant) {
                    const artNom = lote.articulo?.nombre_articulo || 'Insumo';
                    throw new Error(`Stock libre insuficiente para el lote ${lote.numero_lote} (${artNom}). Disponible para reservar: ${stockLibre}, Solicitado: ${cant}`);
                }

                // Bloquear en el lote
                await lote.update({
                    stock_reservado: (lote.stock_reservado || 0) + cant
                }, { transaction: t });

                // Crear registro en OperativoStock
                await OperativoStock.create({
                    id_operativo: op.id_operativo,
                    id_lote_insumo: loteId,
                    cantidad_bloqueada: cant,
                    cantidad_usada: 0,
                    cantidad_remanente: cant
                }, { transaction: t });
            }
        }

        await t.commit();

        await logAction(
            req.user?.nombre_usuario || req.user?.username || 'sistema',
            `Creación de jornada (${op.modalidad}): ${op.nombre_operativo}`,
            'operativos_salud',
            { id_operativo: op.id_operativo, lotes_bloqueados: lotes_bloqueados?.length || 0 }
        );

        const opCompleto = await OperativoSalud.findByPk(op.id_operativo, {
            include: [
                { model: CentroSalud, as: 'centroOrganizador' },
                {
                    model: OperativoStock,
                    as: 'stockBloqueado',
                    include: [{
                        model: LoteInsumo,
                        as: 'lote',
                        include: [{ model: ArticuloMedico, as: 'articulo' }]
                    }]
                }
            ]
        });

        res.status(201).json({ success: true, message: 'Jornada creada y stock bloqueado exitosamente', data: opCompleto });
    } catch (err) {
        await t.rollback();
        console.error('Error al crear operativo con stock bloqueado:', err);
        res.status(400).json({ success: false, message: err.message || 'Error al crear jornada' });
    }
};

exports.cambiarEstadoOperativo = async (req, res) => {
    const t = await sequelize.transaction();
    try {
        const { id } = req.params;
        const { estado } = req.body; // 'activa', 'finalizada', 'cancelada', 'planificada'

        if (!['planificada', 'activa', 'finalizada', 'cancelada'].includes(estado)) {
            throw new Error('Estado inválido. Valores permitidos: planificada, activa, finalizada, cancelada');
        }

        const op = await OperativoSalud.findByPk(id, {
            include: [{ model: OperativoStock, as: 'stockBloqueado' }],
            transaction: t
        });

        if (!op) {
            throw new Error('Jornada/Operativo no encontrado');
        }

        // Si se finaliza o cancela, liberar remanentes del stock reservado al inventario general
        if (['finalizada', 'cancelada'].includes(estado) && op.estado !== estado) {
            if (op.stockBloqueado && op.stockBloqueado.length > 0) {
                for (const item of op.stockBloqueado) {
                    if (item.cantidad_remanente > 0) {
                        const lote = await LoteInsumo.findByPk(item.id_lote_insumo, { transaction: t });
                        if (lote) {
                            const nuevoReservado = Math.max(0, (lote.stock_reservado || 0) - item.cantidad_remanente);
                            await lote.update({ stock_reservado: nuevoReservado }, { transaction: t });
                        }
                        await item.update({ cantidad_remanente: 0 }, { transaction: t });
                    }
                }
            }
        }

        await op.update({
            estado,
            fecha_fin: ['finalizada', 'cancelada'].includes(estado) ? new Date() : op.fecha_fin
        }, { transaction: t });

        await t.commit();

        await logAction(
            req.user?.nombre_usuario || req.user?.username || 'sistema',
            `Cambio de estado de jornada #${id} a: ${estado}`,
            'operativos_salud',
            { id_operativo: id, nuevo_estado: estado }
        );

        res.json({ success: true, message: `Jornada marcada como ${estado}`, data: op });
    } catch (err) {
        await t.rollback();
        res.status(400).json({ success: false, message: err.message });
    }
};

exports.actualizarOperativo = async (req, res) => {
    try {
        const op = await OperativoSalud.findByPk(req.params.id);
        if (!op) return res.status(404).json({ success: false, message: 'Operativo no encontrado' });
        await op.update(req.body);
        res.json({ success: true, data: op });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

exports.eliminarOperativo = async (req, res) => {
    const t = await sequelize.transaction();
    try {
        const op = await OperativoSalud.findByPk(req.params.id, {
            include: [{ model: OperativoStock, as: 'stockBloqueado' }],
            transaction: t
        });
        if (!op) return res.status(404).json({ success: false, message: 'Operativo no encontrado' });

        // Si tenía stock bloqueado remanente, liberarlo
        if (op.stockBloqueado && op.stockBloqueado.length > 0) {
            for (const item of op.stockBloqueado) {
                if (item.cantidad_remanente > 0) {
                    const lote = await LoteInsumo.findByPk(item.id_lote_insumo, { transaction: t });
                    if (lote) {
                        const nuevoReservado = Math.max(0, (lote.stock_reservado || 0) - item.cantidad_remanente);
                        await lote.update({ stock_reservado: nuevoReservado }, { transaction: t });
                    }
                }
            }
        }

        await op.destroy({ transaction: t });
        await t.commit();

        res.json({ success: true, message: 'Operativo eliminado y stock remanente liberado' });
    } catch (err) {
        await t.rollback();
        res.status(500).json({ success: false, message: err.message });
    }
};

exports.listarCentros = async (req, res) => {
    try {
        const centros = await CentroSalud.findAll();
        res.json({ success: true, data: centros });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

exports.crearCentro = async (req, res) => {
    try {
        const { nombre_centro, es_puesto_activo } = req.body;
        const centro = await CentroSalud.create({ nombre_centro, es_puesto_activo: es_puesto_activo !== false });
        res.status(201).json({ success: true, data: centro });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

exports.listarSectores = async (req, res) => {
    try {
        const sectores = await SectorGuanipa.findAll();
        res.json({ success: true, data: sectores });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

exports.crearSector = async (req, res) => {
    try {
        const { nombre_sector } = req.body;
        const sector = await SectorGuanipa.create({ nombre_sector });
        res.status(201).json({ success: true, data: sector });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

exports.listarPersonalDisponible = async (req, res) => {
    try {
        const ROLES_PERMITIDOS = ['Admin', 'Médico', 'Medico', 'Enfermería', 'Inmunizador', 'Epidemiólogo'];
        
        const usuarios = await db.Usuario.findAll({
            where: { activo: true },
            include: [
                {
                    model: db.Persona,
                    as: 'persona',
                    attributes: ['id_persona', 'nombre1', 'nombre2', 'apellido1', 'apellido2', 'cedula_identidad']
                },
                {
                    model: db.Role,
                    as: 'roles',
                    attributes: ['id_serial', 'nombre_rol']
                }
            ],
            order: [['nombre_usuario', 'ASC']]
        });

        const personal = usuarios.filter(u => {
            const userRoles = (u.roles || []).map(r => r.nombre_rol);
            return userRoles.some(r => ROLES_PERMITIDOS.includes(r));
        }).map(u => {
            const p = u.persona || {};
            const nom1 = p.nombre1 || '';
            const ape1 = p.apellido1 || '';
            const nombreCompleto = (nom1 + ' ' + ape1).trim() || u.nombre_usuario;
            return {
                id_usuario: u.id_serial,
                username: u.nombre_usuario,
                nombre_completo: nombreCompleto,
                cedula: p.cedula_identidad || '',
                roles: (u.roles || []).map(r => r.nombre_rol)
            };
        });

        res.json({ success: true, count: personal.length, data: personal });
    } catch (err) {
        console.error('Error al listar personal disponible:', err);
        res.status(500).json({ success: false, message: err.message });
    }
};

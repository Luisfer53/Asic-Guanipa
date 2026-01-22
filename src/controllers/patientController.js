const db = require('../models');
const { Op } = require('sequelize');
const Paciente = db.Paciente;
const AtencionDiaria = db.AtencionDiaria;
const User = db.User;

const createPatient = async (req, res) => {
    const transaction = await db.sequelize.transaction();
    try {
        const { nombre, apellido, edad, fecha_nacimiento, sexo, cedula, telefono, direccion, diagnostico, fecha,
            nombre_representante, apellido_representante, cedula_representante, telefono_representante } = req.body;
        const id_usuario_registra = req.user.id;


        let edad_atencion = edad;
        if (fecha_nacimiento) {
            const dob = new Date(fecha_nacimiento);
            const today = new Date();
            let age = today.getFullYear() - dob.getFullYear();
            const m = today.getMonth() - dob.getMonth();
            if (m < 0 || (m === 0 && today.getDate() < dob.getDate())) {
                age--;
            }
            edad_atencion = age;
        }


        if (edad_atencion === undefined || edad_atencion === null) {
            await transaction.rollback();
            return res.status(400).json({ success: false, message: 'Debe proporcionar edad o fecha de nacimiento' });
        }

        const isMinor = edad_atencion < 18;


        if (!nombre || !apellido || !sexo || !fecha) {
            await transaction.rollback();
            return res.status(400).json({
                success: false,
                message: 'Faltan campos obligatorios (nombre, apellido, sexo, fecha)'
            });
        }

        if (isMinor) {

            if (!nombre_representante || !apellido_representante || !cedula_representante || !telefono_representante) {
                await transaction.rollback();
                return res.status(400).json({
                    success: false,
                    message: 'Para menores de edad, los datos del representante son obligatorios'
                });
            }
        } else {

            if (!cedula) {
                await transaction.rollback();
                return res.status(400).json({
                    success: false,
                    message: 'La cédula es obligatoria para mayores de edad'
                });
            }
        }


        let patient;


        if (cedula) {
            patient = await Paciente.findOne({ where: { cedula }, transaction });
        }

        if (!patient) {

            patient = await Paciente.create({
                nombre,
                apellido,
                cedula: cedula || null,
                fecha_nacimiento: fecha_nacimiento || null,
                sexo,
                telefono,
                direccion,

                nombre_representante: isMinor ? nombre_representante : null,
                apellido_representante: isMinor ? apellido_representante : null,
                cedula_representante: isMinor ? cedula_representante : null,
                telefono_representante: isMinor ? telefono_representante : null
            }, { transaction });
        } else {

            const updateData = { telefono, direccion };
            if (isMinor) {
                updateData.nombre_representante = nombre_representante;
                updateData.apellido_representante = apellido_representante;
                updateData.cedula_representante = cedula_representante;
                updateData.telefono_representante = telefono_representante;
            }
            await patient.update(updateData, { transaction });
        }


        await transaction.commit();

        res.status(201).json({
            success: true,
            message: 'Paciente registrado exitosamente',
            data: {
                patient
            }
        });
    } catch (error) {
        await transaction.rollback();
        console.error('Error creating patient record:', error);
        res.status(500).json({
            success: false,
            message: 'Error al registrar paciente',
            error: error.message
        });
    }
};

const getPatients = async (req, res) => {
    try {
        const { fecha, cedula } = req.query;
        const whereAttention = {};
        const wherePatient = {};

        if (fecha) whereAttention.fecha = fecha;
        if (cedula) wherePatient.cedula = cedula;

        const attentions = await AtencionDiaria.findAll({
            where: whereAttention,
            include: [
                {
                    model: Paciente,
                    as: 'paciente',
                    where: wherePatient,
                    required: !!cedula
                },
                {
                    model: User,
                    as: 'usuario',
                    attributes: ['username']
                }
            ],
            order: [['fecha', 'DESC']]
        });

        res.status(200).json({
            success: true,
            data: attentions
        });
    } catch (error) {
        console.error('Error fetching patients:', error);
        res.status(500).json({
            success: false,
            message: 'Error al obtener pacientes',
            error: error.message
        });
    }
};

const getPatientHistory = async (req, res) => {
    try {
        const { cedula } = req.params;


        const patient = await Paciente.findOne({ where: { cedula } });

        if (!patient) {
            return res.status(404).json({
                success: false,
                message: 'Paciente no encontrado'
            });
        }

        const history = await AtencionDiaria.findAll({
            where: { paciente_id: patient.id },
            include: [
                {
                    model: Paciente,
                    as: 'paciente'
                },
                {
                    model: User,
                    as: 'usuario',
                    attributes: ['username']
                }
            ],
            order: [['fecha', 'DESC']]
        });

        res.status(200).json({
            success: true,
            data: history
        });
    } catch (error) {
        console.error('Error fetching patient history:', error);
        res.status(500).json({
            success: false,
            message: 'Error al obtener historial',
            error: error.message
        });
    }
};

const updatePatient = async (req, res) => {
    const transaction = await db.sequelize.transaction();
    try {
        const { id } = req.params;




        const updateData = req.body;

        const attention = await AtencionDiaria.findByPk(id, { include: ['paciente'], transaction });

        if (!attention) {
            await transaction.rollback();
            return res.status(404).json({
                success: false,
                message: 'Registro de atención no encontrado'
            });
        }


        if (updateData.diagnostico) attention.diagnostico = updateData.diagnostico;
        if (updateData.fecha) attention.fecha = updateData.fecha;
        if (updateData.edad) attention.edad_atencion = updateData.edad;

        await attention.save({ transaction });


        const patientFields = ['nombre', 'apellido', 'sexo', 'telefono', 'direccion', 'cedula', 'fecha_nacimiento'];
        let patientUpdated = false;


        for (const field of patientFields) {
            if (updateData[field] !== undefined) {
                attention.paciente[field] = updateData[field];
                patientUpdated = true;
            }
        }

        if (patientUpdated) {
            await attention.paciente.save({ transaction });
        }

        await transaction.commit();

        res.status(200).json({
            success: true,
            message: 'Registro actualizado',
            data: attention
        });
    } catch (error) {
        await transaction.rollback();
        console.error('Error updating patient:', error);
        res.status(500).json({
            success: false,
            message: 'Error al actualizar registro',
            error: error.message
        });
    }
};

const deletePatient = async (req, res) => {
    try {
        const { id } = req.params;

        const record = await AtencionDiaria.findByPk(id);

        if (!record) {
            return res.status(404).json({
                success: false,
                message: 'Registro no encontrado'
            });
        }

        await record.destroy();

        res.status(200).json({
            success: true,
            message: 'Registro eliminado'
        });
    } catch (error) {
        console.error('Error deleting patient:', error);
        res.status(500).json({
            success: false,
            message: 'Error al eliminar registro',
            error: error.message
        });
    }
};

const getAttentionById = async (req, res) => {
    try {
        const { id } = req.params;
        const attention = await AtencionDiaria.findByPk(id, {
            include: [
                {
                    model: Paciente,
                    as: 'paciente'
                },
                {
                    model: User,
                    as: 'usuario',
                    attributes: ['username']
                }
            ]
        });

        if (!attention) {
            return res.status(404).json({
                success: false,
                message: 'Atención no encontrada'
            });
        }

        res.status(200).json({
            success: true,
            data: attention
        });
    } catch (error) {
        console.error('Error fetching attention by ID:', error);
        res.status(500).json({
            success: false,
            message: 'Error al obtener la atención',
            error: error.message
        });
    }
};

module.exports = {
    createPatient,
    getPatients,
    getPatientHistory,
    getAttentionById,
    updatePatient,
    deletePatient
};


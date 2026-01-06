const db = require('../models');
const { Op } = require('sequelize');
const RegistroPacientesDiarios = db.RegistroPacientesDiarios;

const createPatient = async (req, res) => {
    try {
        const { nombre, apellido, edad, sexo, cedula, telefono, direccion, diagnostico, fecha } = req.body;

        // Validation (Basic)
        if (!nombre || !apellido || !edad || !sexo || !cedula || !fecha) {
            return res.status(400).json({
                success: false,
                message: 'Faltan campos obligatorios'
            });
        }

        const newRecord = await RegistroPacientesDiarios.create({
            nombre, apellido, edad, sexo, cedula, telefono, direccion, diagnostico, fecha
        });

        res.status(201).json({
            success: true,
            message: 'Paciente registrado exitosamente',
            data: newRecord
        });
    } catch (error) {
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
        const where = {};

        if (fecha) where.fecha = fecha;
        if (cedula) where.cedula = cedula;

        const patients = await RegistroPacientesDiarios.findAll({ where });

        res.status(200).json({
            success: true,
            data: patients
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

        const history = await RegistroPacientesDiarios.findAll({
            where: { cedula },
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
    try {
        const { id } = req.params;
        const updateData = req.body;

        const record = await RegistroPacientesDiarios.findByPk(id);

        if (!record) {
            return res.status(404).json({
                success: false,
                message: 'Registro no encontrado'
            });
        }

        await record.update(updateData);

        res.status(200).json({
            success: true,
            message: 'Registro actualizado',
            data: record
        });
    } catch (error) {
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

        const record = await RegistroPacientesDiarios.findByPk(id);

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

module.exports = {
    createPatient,
    getPatients,
    getPatientHistory,
    updatePatient,
    deletePatient
};

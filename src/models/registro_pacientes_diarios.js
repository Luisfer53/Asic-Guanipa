'use strict';
const {
    Model
} = require('sequelize');

module.exports = (sequelize, DataTypes) => {
    class RegistroPacientesDiarios extends Model {
        static associate(models) {
            // Define association here if needed, e.g., with User
            // RegistroPacientesDiarios.belongsTo(models.User, { foreignKey: 'created_by' });
        }
    }
    RegistroPacientesDiarios.init({
        nombre: {
            type: DataTypes.STRING,
            allowNull: false
        },
        apellido: {
            type: DataTypes.STRING,
            allowNull: false
        },
        edad: {
            type: DataTypes.INTEGER,
            allowNull: false,
            validate: {
                min: 0
            }
        },
        sexo: {
            type: DataTypes.ENUM('M', 'F'),
            allowNull: false
        },
        cedula: {
            type: DataTypes.STRING,
            allowNull: false,
            // Note: We might want unique: true, but the requirement says "Permitir múltiples visitas del mismo paciente en diferentes fechas".
            // However, requirement 1 says "cedula (string, único, requerido)". 
            // This usually means the patient identity is unique, but the registry entries are many.
            // If this table represents "Visits", then cedula shouldn't be unique per row, but unique per "Patient Entity".
            // BUT, the requirements say "Cada registro se guarda como una fila en la tabla RegistroPacientesDiarios".
            // And "Permitir múltiples visitas del mismo paciente".
            // So 'cedula' cannot be unique in THIS table if this table stores visits.
            // I will interpret "cedula (string, único, requerido)" as "The identifier of the patient", 
            // but since we don't have a separate 'Patients' table requested, we might just store patient data in every visit row.
            // Wait, if I make it unique, a patient can only visit once.
            // Requirement 5: "Relación: un usuario crea registros, cada registro pertenece a un paciente identificado por su cédula."
            // Requirement 5: "Permitir múltiples visitas del mismo paciente en diferentes fechas (historial)."
            // So, I will NOT make cedula unique in the database definition of this table, 
            // OR I should have a separate Patients table.
            // The user asked for "Tablas: usuarios, RegistroPacientesDiarios". Only these two.
            // So I must store patient info in RegistroPacientesDiarios.
            // Therefore, cedula CANNOT be unique in this table.
            // I will add an index on cedula for faster lookups.
        },
        telefono: {
            type: DataTypes.STRING(11),
            allowNull: true
        },
        direccion: {
            type: DataTypes.STRING(150),
            allowNull: true
        },
        diagnostico: {
            type: DataTypes.TEXT,
            allowNull: true
        },
        fecha: {
            type: DataTypes.DATEONLY,
            allowNull: false,
            defaultValue: DataTypes.NOW
        }
    }, {
        sequelize,
        modelName: 'RegistroPacientesDiarios',
        tableName: 'registro_pacientes_diarios',
        underscored: true,
    });
    return RegistroPacientesDiarios;
};

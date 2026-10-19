'use strict';
const { Model } = require('sequelize');

/**
 * Modelo Paciente — ahora normalizado.
 * Los datos personales viven en la tabla `personas` (Persona).
 * Aquí solo se almacenan los datos clínicos propios del paciente.
 */
module.exports = (sequelize, DataTypes) => {
    class Paciente extends Model {
        static associate(models) {
            // Datos personales del paciente
            Paciente.belongsTo(models.Persona, {
                foreignKey: 'id_persona',
                as: 'persona'
            });
            // Representante legal (para menores) — también es una Persona
            Paciente.belongsTo(models.Persona, {
                foreignKey: 'id_representante',
                as: 'representante'
            });
            // Atenciones médicas
            Paciente.hasMany(models.AtencionDiaria, {
                foreignKey: 'id_paciente',
                as: 'atenciones'
            });
        }

        // Helper: nombre completo calculado
        get nombreCompleto() {
            const p = this.persona;
            if (!p) return '';
            return [p.nombre1, p.nombre2, p.apellido1, p.apellido2]
                .filter(Boolean)
                .join(' ');
        }
    }

    Paciente.init({
        id_paciente: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        id_persona: {
            type: DataTypes.INTEGER,
            allowNull: false,
            unique: true,
            references: { model: 'personas', key: 'id_persona' }
        },
        id_representante: {
            type: DataTypes.INTEGER,
            allowNull: true,
            references: { model: 'personas', key: 'id_persona' }
        },
        parentesco_representante: {
            type: DataTypes.STRING(50),
            allowNull: true
        },
        fecha_registro: {
            type: DataTypes.DATEONLY,
            allowNull: true
        },
        peso: {
            type: DataTypes.DECIMAL(5, 2),
            allowNull: true
        },
        tipo_sangre: {
            type: DataTypes.STRING(5),
            allowNull: true
        },
        alergias: {
            type: DataTypes.TEXT,
            allowNull: true
        },
        enfermedades_cronicas: {
            type: DataTypes.TEXT,
            allowNull: true
        },
        vacunas: {
            type: DataTypes.TEXT,
            allowNull: true
        },
        discapacidad: {
            type: DataTypes.TEXT,
            allowNull: true
        },
        antecedentes_familiares: {
            type: DataTypes.TEXT,
            allowNull: true
        }
    }, {
        sequelize,
        modelName: 'Paciente',
        tableName: 'pacientes',
        underscored: true,
        timestamps: false
    });

    return Paciente;
};

'use strict';
const {
    Model
} = require('sequelize');

module.exports = (sequelize, DataTypes) => {
    class Paciente extends Model {
        static associate(models) {
            Paciente.hasMany(models.AtencionDiaria, {
                foreignKey: 'paciente_id',
                as: 'atenciones'
            });
        }
    }
    Paciente.init({
        nombre: {
            type: DataTypes.STRING,
            allowNull: false
        },
        apellido: {
            type: DataTypes.STRING,
            allowNull: false
        },
        cedula: {
            type: DataTypes.STRING,
            allowNull: true,
            unique: true
        },
        fecha_nacimiento: {
            type: DataTypes.DATEONLY,
            allowNull: true
        },
        sexo: {
            type: DataTypes.ENUM('M', 'F'),
            allowNull: false
        },
        telefono: {
            type: DataTypes.STRING(20),
            allowNull: true
        },
        direccion: {
            type: DataTypes.STRING(150),
            allowNull: true
        },

        nombre_representante: {
            type: DataTypes.STRING,
            allowNull: true
        },
        apellido_representante: {
            type: DataTypes.STRING,
            allowNull: true
        },
        cedula_representante: {
            type: DataTypes.STRING,
            allowNull: true
        },
        telefono_representante: {
            type: DataTypes.STRING,
            allowNull: true
        }
    }, {
        sequelize,
        modelName: 'Paciente',
        tableName: 'pacientes',
        underscored: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at',
    });
    return Paciente;
};

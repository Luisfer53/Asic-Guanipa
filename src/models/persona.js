'use strict';
const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
    class Persona extends Model {
        static associate(models) {
            // Una persona puede ser el paciente principal
            Persona.hasOne(models.Paciente, {
                foreignKey: 'id_persona',
                as: 'datosPaciente'
            });
            // Una persona puede ser representante de muchos pacientes
            Persona.hasMany(models.Paciente, {
                foreignKey: 'id_representante',
                as: 'representados'
            });
            // Una persona puede tener un usuario del sistema
            Persona.hasOne(models.Usuario, {
                foreignKey: 'id_persona',
                as: 'usuario'
            });
            // Teléfonos, correos y direcciones
            Persona.hasMany(models.Telefono, {
                foreignKey: 'id_persona',
                as: 'telefonos'
            });
            Persona.hasMany(models.Correo, {
                foreignKey: 'id_persona',
                as: 'correos'
            });
            Persona.hasMany(models.Direccion, {
                foreignKey: 'id_persona',
                as: 'direcciones'
            });
        }
    }

    Persona.init({
        id_persona: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        cedula_identidad: {
            type: DataTypes.STRING(20),
            allowNull: true,
            unique: true
        },
        nombre1: {
            type: DataTypes.STRING(50),
            allowNull: true
        },
        nombre2: {
            type: DataTypes.STRING(50),
            allowNull: true
        },
        apellido1: {
            type: DataTypes.STRING(50),
            allowNull: true
        },
        apellido2: {
            type: DataTypes.STRING(50),
            allowNull: true
        },
        sexo: {
            type: DataTypes.STRING(10),
            allowNull: true
        },
        estado_civil: {
            type: DataTypes.STRING(50),
            allowNull: true
        },
        ocupacion: {
            type: DataTypes.STRING(100),
            allowNull: true
        },
        fecha_nacimiento: {
            type: DataTypes.DATEONLY,
            allowNull: true
        }
    }, {
        sequelize,
        modelName: 'Persona',
        tableName: 'personas',
        underscored: true,
        timestamps: false  // La tabla personas no tiene created_at/updated_at en el esquema
    });

    return Persona;
};

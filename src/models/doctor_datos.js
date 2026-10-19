'use strict';
const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
    class DoctorDatos extends Model {
        static associate(models) {
            DoctorDatos.belongsTo(models.Usuario, {
                foreignKey: 'id_usuario_sistema',
                as: 'usuario'
            });
        }
    }

    DoctorDatos.init({
        id_doctor_datos: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        id_usuario_sistema: {
            type: DataTypes.INTEGER,
            allowNull: false,
            references: { model: 'usuarios', key: 'id_serial' }
        },
        numero_carnet: {
            type: DataTypes.STRING(50),
            allowNull: false,
            unique: true
        },
        area_trabajo: {
            type: DataTypes.STRING(100),
            allowNull: true
        },
        horario: {
            type: DataTypes.STRING(100),
            allowNull: true
        },
        anos_experiencia: {
            type: DataTypes.INTEGER,
            allowNull: true
        }
    }, {
        sequelize,
        modelName: 'DoctorDatos',
        tableName: 'doctores_datos',
        underscored: true,
        timestamps: false
    });

    return DoctorDatos;
};

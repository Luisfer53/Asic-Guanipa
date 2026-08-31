'use strict';
const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
    class SeguridadUsuario extends Model {
        static associate(models) {
            SeguridadUsuario.belongsTo(models.Usuario, {
                foreignKey: 'id_usuario_sistema',
                as: 'usuario'
            });
        }
    }

    SeguridadUsuario.init({
        id_seguridad: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        id_usuario_sistema: {
            type: DataTypes.INTEGER,
            allowNull: false,
            unique: true,
            references: { model: 'usuarios', key: 'id_serial' }
        },
        codigo_recuperacion: {
            type: DataTypes.STRING(100),
            allowNull: true
        },
        fecha_creacion_contrasena: {
            type: DataTypes.DATE,
            allowNull: true
        },
        intento_acceso_fallido: {
            type: DataTypes.INTEGER,
            allowNull: true,
            defaultValue: 0
        },
        ultima_conexion: {
            type: DataTypes.DATE,
            allowNull: true
        },
        verificacion_carnet: {
            type: DataTypes.BOOLEAN,
            allowNull: true,
            defaultValue: false
        },
        pregunta_seguridad_1: { type: DataTypes.STRING(255), allowNull: true },
        respuesta_seguridad_1: { type: DataTypes.STRING(255), allowNull: true },
        pregunta_seguridad_2: { type: DataTypes.STRING(255), allowNull: true },
        respuesta_seguridad_2: { type: DataTypes.STRING(255), allowNull: true },
        pregunta_seguridad_3: { type: DataTypes.STRING(255), allowNull: true },
        respuesta_seguridad_3: { type: DataTypes.STRING(255), allowNull: true }
    }, {
        sequelize,
        modelName: 'SeguridadUsuario',
        tableName: 'seguridad_usuarios',
        underscored: true,
        timestamps: false
    });

    return SeguridadUsuario;
};

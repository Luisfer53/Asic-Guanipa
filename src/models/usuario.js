'use strict';
const { Model } = require('sequelize');

/**
 * Modelo Usuario — ahora ligado a una Persona y a un Centro de Salud.
 * Se reemplaza el campo `email` por la relación con Persona (donde se obtiene
 * el correo a través de la tabla `correos`).
 * El campo `contrasena` reemplaza a `password`.
 */
module.exports = (sequelize, DataTypes) => {
    class Usuario extends Model {
        static associate(models) {
            // Datos personales
            Usuario.belongsTo(models.Persona, {
                foreignKey: 'id_persona',
                as: 'persona'
            });
            // Centro al que pertenece
            Usuario.belongsTo(models.CentroSalud, {
                foreignKey: 'id_centro',
                as: 'centro'
            });
            // Roles (many-to-many a través de usuario_roles)
            Usuario.belongsToMany(models.Role, {
                through: 'usuario_roles',
                foreignKey: 'nombre_usuario',
                sourceKey: 'nombre_usuario',
                otherKey: 'id_rol',
                as: 'roles'
            });
            // Seguridad
            Usuario.hasOne(models.SeguridadUsuario, {
                foreignKey: 'id_usuario_sistema',
                as: 'seguridad'
            });
            // Datos de doctor (si aplica)
            Usuario.hasMany(models.DoctorDatos, {
                foreignKey: 'id_usuario_sistema',
                as: 'datosMedico'
            });
            // Atenciones registradas
            Usuario.hasMany(models.AtencionDiaria, {
                foreignKey: 'id_usuario_registra',
                as: 'atencionesRegistradas'
            });
        }
    }

    Usuario.init({
        id_serial: {
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
        id_centro: {
            type: DataTypes.INTEGER,
            allowNull: true,
            references: { model: 'centros_salud', key: 'id_centro' }
        },
        nombre_usuario: {
            type: DataTypes.STRING(100),
            allowNull: false,
            unique: true
        },
        contrasena: {
            type: DataTypes.STRING(255),
            allowNull: false
        },
        fecha_creacion: {
            type: DataTypes.DATE,
            allowNull: true
        },
        fecha_actualizacion: {
            type: DataTypes.DATE,
            allowNull: true
        },
        activo: {
            type: DataTypes.BOOLEAN,
            allowNull: false,
            defaultValue: true
        }
    }, {
        sequelize,
        modelName: 'Usuario',
        tableName: 'usuarios',
        underscored: true,
        timestamps: false   // Timestamps manuales: fecha_creacion, fecha_actualizacion
    });

    return Usuario;
};

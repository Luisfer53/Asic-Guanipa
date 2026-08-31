'use strict';
const { Model } = require('sequelize');

/**
 * Modelo Role — mantiene el mismo nombre lógico para compatibilidad
 * con el código de authController existente.
 * Nombre de tabla en BD: `roles`, PK: `id_serial`.
 */
module.exports = (sequelize, DataTypes) => {
    class Role extends Model {
        static associate(models) {
            Role.belongsToMany(models.Usuario, {
                through: 'usuario_roles',
                foreignKey: 'id_rol',
                otherKey: 'nombre_usuario',
                targetKey: 'nombre_usuario',
                as: 'usuarios'
            });
        }
    }

    Role.init({
        id_serial: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        nombre_rol: {
            type: DataTypes.STRING(100),
            allowNull: false
        },
        fecha_creacion: {
            type: DataTypes.DATE,
            allowNull: true
        },
        fecha_actualizacion: {
            type: DataTypes.DATE,
            allowNull: true
        }
    }, {
        sequelize,
        modelName: 'Role',
        tableName: 'roles',
        underscored: true,
        timestamps: false
    });

    return Role;
};
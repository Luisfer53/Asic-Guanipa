'use strict';
const { Model } = require('sequelize');

/**
 * Modelo Proveedor — catálogo de proveedores de insumos médicos.
 */
module.exports = (sequelize, DataTypes) => {
    class Proveedor extends Model {
        static associate(models) {
            Proveedor.hasMany(models.LoteInsumo, {
                foreignKey: 'id_proveedor',
                as: 'lotes'
            });
        }
    }

    Proveedor.init({
        id_proveedor: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        nombre_proveedor: {
            type: DataTypes.STRING(150),
            allowNull: false
        },
        rif: {
            type: DataTypes.STRING(50),
            allowNull: true,
            unique: true
        },
        telefono: {
            type: DataTypes.STRING(50),
            allowNull: true
        },
        direccion: {
            type: DataTypes.TEXT,
            allowNull: true
        }
    }, {
        sequelize,
        modelName: 'Proveedor',
        tableName: 'proveedores',
        underscored: true,
        timestamps: false
    });

    return Proveedor;
};

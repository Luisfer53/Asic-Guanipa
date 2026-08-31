'use strict';
const { Model } = require('sequelize');

/**
 * Modelo LoteInsumo — actualizado con id_proveedor e id_centro.
 */
module.exports = (sequelize, DataTypes) => {
    class LoteInsumo extends Model {
        static associate(models) {
            LoteInsumo.belongsTo(models.ArticuloMedico, {
                foreignKey: 'id_articulo',
                as: 'articulo'
            });
            LoteInsumo.belongsTo(models.Proveedor, {
                foreignKey: 'id_proveedor',
                as: 'proveedor'
            });
            LoteInsumo.belongsTo(models.CentroSalud, {
                foreignKey: 'id_centro',
                as: 'centro'
            });
            LoteInsumo.hasMany(models.ConsumoInsumo, {
                foreignKey: 'id_lote_insumo',
                as: 'consumos'
            });
            LoteInsumo.hasMany(models.RegistroVacunacion, {
                foreignKey: 'id_lote',
                as: 'vacunaciones'
            });
            LoteInsumo.hasMany(models.MovimientoInventario, {
                foreignKey: 'id_lote_insumo',
                as: 'movimientos'
            });
        }
    }

    LoteInsumo.init({
        id_lote_insumo: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        id_articulo: {
            type: DataTypes.INTEGER,
            allowNull: false,
            references: { model: 'articulos_medicos', key: 'id_articulo' }
        },
        id_proveedor: {
            type: DataTypes.INTEGER,
            allowNull: true,
            references: { model: 'proveedores', key: 'id_proveedor' }
        },
        id_centro: {
            type: DataTypes.INTEGER,
            allowNull: true,
            references: { model: 'centros_salud', key: 'id_centro' }
        },
        numero_lote: {
            type: DataTypes.STRING(100),
            allowNull: false,
            unique: true
        },
        fecha_vencimiento: {
            type: DataTypes.DATEONLY,
            allowNull: false
        },
        stock_actual: {
            type: DataTypes.INTEGER,
            allowNull: false,
            defaultValue: 0
        }
    }, {
        sequelize,
        modelName: 'LoteInsumo',
        tableName: 'lotes_insumos',
        underscored: true,
        timestamps: false
    });

    return LoteInsumo;
};

'use strict';
const { Model } = require('sequelize');

/**
 * Modelo MovimientoInventario — trazabilidad de despachos, donaciones,
 * devoluciones y descartes con soporte para acta legal (RF-10).
 */
module.exports = (sequelize, DataTypes) => {
    class MovimientoInventario extends Model {
        static associate(models) {
            MovimientoInventario.belongsTo(models.LoteInsumo, {
                foreignKey: 'id_lote_insumo',
                as: 'lote'
            });
            MovimientoInventario.belongsTo(models.CentroSalud, {
                foreignKey: 'id_centro',
                as: 'centro'
            });
        }
    }

    MovimientoInventario.init({
        id_movimiento: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        id_lote_insumo: {
            type: DataTypes.INTEGER,
            allowNull: false,
            references: { model: 'lotes_insumos', key: 'id_lote_insumo' }
        },
        id_centro: {
            type: DataTypes.INTEGER,
            allowNull: true,
            references: { model: 'centros_salud', key: 'id_centro' }
        },
        tipo_movimiento: {
            type: DataTypes.STRING(50),
            allowNull: false,
            comment: 'Despacho, Donación, Devolución, Descarte'
        },
        cantidad: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        numero_acta_descarte: {
            type: DataTypes.STRING(100),
            allowNull: true,
            comment: 'Soporte legal para mermas enviadas a Barcelona (RF-10)'
        },
        justificacion: {
            type: DataTypes.TEXT,
            allowNull: true
        },
        foto_evidencia: {
            type: DataTypes.STRING(255),
            allowNull: true
        },
        fecha_movimiento: {
            type: DataTypes.DATE,
            allowNull: true,
            defaultValue: DataTypes.NOW
        }
    }, {
        sequelize,
        modelName: 'MovimientoInventario',
        tableName: 'movimientos_inventario',
        underscored: true,
        timestamps: false
    });

    return MovimientoInventario;
};

'use strict';
const { Model } = require('sequelize');

/**
 * Modelo ConsumoInsumo — sin cambios estructurales mayores,
 * actualizado para coherencia con el nuevo esquema (sin timestamps).
 */
module.exports = (sequelize, DataTypes) => {
    class ConsumoInsumo extends Model {
        static associate(models) {
            ConsumoInsumo.belongsTo(models.AtencionDiaria, {
                foreignKey: 'id_atencion',
                as: 'atencion'
            });
            ConsumoInsumo.belongsTo(models.LoteInsumo, {
                foreignKey: 'id_lote_insumo',
                as: 'lote'
            });
        }
    }

    ConsumoInsumo.init({
        id_consumo: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        id_atencion: {
            type: DataTypes.INTEGER,
            allowNull: false,
            references: { model: 'atenciones_diarias', key: 'id_atencion' }
        },
        id_lote_insumo: {
            type: DataTypes.INTEGER,
            allowNull: false,
            references: { model: 'lotes_insumos', key: 'id_lote_insumo' }
        },
        cantidad_usada: {
            type: DataTypes.INTEGER,
            allowNull: false
        }
    }, {
        sequelize,
        modelName: 'ConsumoInsumo',
        tableName: 'consumo_insumos',
        underscored: true,
        timestamps: false
    });

    return ConsumoInsumo;
};

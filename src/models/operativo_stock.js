'use strict';
const { Model } = require('sequelize');

/**
 * Modelo OperativoStock — trazabilidad de stock bloqueado / asignado
 * específicamente a una jornada de vacunación / operativo de salud.
 */
module.exports = (sequelize, DataTypes) => {
    class OperativoStock extends Model {
        static associate(models) {
            OperativoStock.belongsTo(models.OperativoSalud, {
                foreignKey: 'id_operativo',
                as: 'operativo'
            });
            OperativoStock.belongsTo(models.LoteInsumo, {
                foreignKey: 'id_lote_insumo',
                as: 'lote'
            });
        }
    }

    OperativoStock.init({
        id_operativo_stock: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        id_operativo: {
            type: DataTypes.INTEGER,
            allowNull: false,
            references: { model: 'operativos_salud', key: 'id_operativo' }
        },
        id_lote_insumo: {
            type: DataTypes.INTEGER,
            allowNull: false,
            references: { model: 'lotes_insumos', key: 'id_lote_insumo' }
        },
        cantidad_bloqueada: {
            type: DataTypes.INTEGER,
            allowNull: false,
            defaultValue: 0
        },
        cantidad_usada: {
            type: DataTypes.INTEGER,
            allowNull: false,
            defaultValue: 0
        },
        cantidad_remanente: {
            type: DataTypes.INTEGER,
            allowNull: false,
            defaultValue: 0
        }
    }, {
        sequelize,
        modelName: 'OperativoStock',
        tableName: 'operativos_stock',
        underscored: true,
        timestamps: false
    });

    return OperativoStock;
};

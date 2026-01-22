'use strict';
const {
    Model
} = require('sequelize');
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
        id_atencion: {
            type: DataTypes.INTEGER,
            allowNull: false,
            references: {
                model: 'atenciones_diarias',
                key: 'id'
            }
        },
        id_lote_insumo: {
            type: DataTypes.INTEGER,
            allowNull: false,
            references: {
                model: 'lotes_insumos',
                key: 'id'
            }
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

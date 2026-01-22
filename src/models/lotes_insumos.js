'use strict';
const {
    Model
} = require('sequelize');
module.exports = (sequelize, DataTypes) => {
    class LoteInsumo extends Model {
        static associate(models) {
            LoteInsumo.belongsTo(models.ArticuloMedico, {
                foreignKey: 'id_articulo',
                as: 'articulo'
            });
            LoteInsumo.hasMany(models.ConsumoInsumo, {
                foreignKey: 'id_lote_insumo',
                as: 'consumos'
            });
            LoteInsumo.hasMany(models.RegistroVacunacion, {
                foreignKey: 'id_lote_insumo',
                as: 'vacunaciones'
            });
        }
    }
    LoteInsumo.init({
        id_articulo: {
            type: DataTypes.INTEGER,
            allowNull: false,
            references: {
                model: 'articulos_medicos',
                key: 'id'
            }
        },
        numero_lote: {
            type: DataTypes.STRING,
            allowNull: false
        },
        stock_actual: {
            type: DataTypes.INTEGER,
            allowNull: false,
            defaultValue: 0
        },
        fecha_vencimiento: {
            type: DataTypes.DATEONLY,
            allowNull: false
        }
    }, {
        sequelize,
        modelName: 'LoteInsumo',
        tableName: 'lotes_insumos',
        underscored: true,
        timestamps: false // Strict schema adherence
    });
    return LoteInsumo;
};

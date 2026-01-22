'use strict';
const {
    Model
} = require('sequelize');
module.exports = (sequelize, DataTypes) => {
    class ArticuloMedico extends Model {
        static associate(models) {
            ArticuloMedico.hasMany(models.LoteInsumo, {
                foreignKey: 'id_articulo',
                as: 'lotes'
            });
        }
    }
    ArticuloMedico.init({
        nombre_articulo: {
            type: DataTypes.STRING,
            allowNull: false
        },
        unidad_medida: {
            type: DataTypes.STRING,
            allowNull: false
        }
    }, {
        sequelize,
        modelName: 'ArticuloMedico',
        tableName: 'articulos_medicos',
        underscored: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at',
        timestamps: true // Enabling timestamps since we are standardizing
    });
    return ArticuloMedico;
};

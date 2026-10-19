'use strict';
const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
    class SectorGuanipa extends Model {
        static associate(models) {
            SectorGuanipa.hasMany(models.Direccion, {
                foreignKey: 'id_sector',
                as: 'direcciones'
            });
        }
    }

    SectorGuanipa.init({
        id_sector: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        nombre_sector: {
            type: DataTypes.STRING(100),
            allowNull: false
        }
    }, {
        sequelize,
        modelName: 'SectorGuanipa',
        tableName: 'sectores_guanipa',
        underscored: true,
        timestamps: false
    });

    return SectorGuanipa;
};

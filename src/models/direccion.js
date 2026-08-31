'use strict';
const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
    class Direccion extends Model {
        static associate(models) {
            Direccion.belongsTo(models.Persona, {
                foreignKey: 'id_persona',
                as: 'persona'
            });
            Direccion.belongsTo(models.SectorGuanipa, {
                foreignKey: 'id_sector',
                as: 'sector'
            });
        }
    }

    Direccion.init({
        id_direccion: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        id_persona: {
            type: DataTypes.INTEGER,
            allowNull: false,
            references: { model: 'personas', key: 'id_persona' }
        },
        id_sector: {
            type: DataTypes.INTEGER,
            allowNull: true,
            references: { model: 'sectores_guanipa', key: 'id_sector' }
        },
        parroquia: {
            type: DataTypes.STRING(100),
            allowNull: true
        },
        calle: {
            type: DataTypes.STRING(100),
            allowNull: true
        },
        codigo_postal: {
            type: DataTypes.STRING(20),
            allowNull: true
        },
        numero_casa: {
            type: DataTypes.STRING(50),
            allowNull: true
        },
        punto_referencia: {
            type: DataTypes.TEXT,
            allowNull: true
        }
    }, {
        sequelize,
        modelName: 'Direccion',
        tableName: 'direcciones',
        underscored: true,
        timestamps: false
    });

    return Direccion;
};

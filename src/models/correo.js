'use strict';
const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
    class Correo extends Model {
        static associate(models) {
            Correo.belongsTo(models.Persona, {
                foreignKey: 'id_persona',
                as: 'persona'
            });
        }
    }

    Correo.init({
        id_correo: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        id_persona: {
            type: DataTypes.INTEGER,
            allowNull: false,
            references: { model: 'personas', key: 'id_persona' }
        },
        correo: {
            type: DataTypes.STRING(150),
            allowNull: false
        }
    }, {
        sequelize,
        modelName: 'Correo',
        tableName: 'correos',
        underscored: true,
        timestamps: false
    });

    return Correo;
};

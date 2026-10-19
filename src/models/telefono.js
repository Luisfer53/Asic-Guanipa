'use strict';
const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
    class Telefono extends Model {
        static associate(models) {
            Telefono.belongsTo(models.Persona, {
                foreignKey: 'id_persona',
                as: 'persona'
            });
        }
    }

    Telefono.init({
        id_telefono: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        id_persona: {
            type: DataTypes.INTEGER,
            allowNull: false,
            references: { model: 'personas', key: 'id_persona' }
        },
        numero_telefono: {
            type: DataTypes.STRING(20),
            allowNull: false
        }
    }, {
        sequelize,
        modelName: 'Telefono',
        tableName: 'telefonos',
        underscored: true,
        timestamps: false
    });

    return Telefono;
};

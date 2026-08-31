'use strict';
const { Model } = require('sequelize');

/**
 * Modelo Diagnostico — catálogo de condiciones/patologías.
 */
module.exports = (sequelize, DataTypes) => {
    class Diagnostico extends Model {
        static associate(models) {
            Diagnostico.hasMany(models.AtencionDiagnostico, {
                foreignKey: 'id_diagnostico',
                as: 'atenciones'
            });
            Diagnostico.hasMany(models.Tratamiento, {
                foreignKey: 'id_diagnostico',
                as: 'tratamientos'
            });
        }
    }

    Diagnostico.init({
        id_diagnostico: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        condicion: {
            type: DataTypes.STRING(100),
            allowNull: false
        },
        descripcion: {
            type: DataTypes.TEXT,
            allowNull: true
        },
        gravedad: {
            type: DataTypes.STRING(50),
            allowNull: true
        }
    }, {
        sequelize,
        modelName: 'Diagnostico',
        tableName: 'diagnosticos',
        underscored: true,
        timestamps: false
    });

    return Diagnostico;
};

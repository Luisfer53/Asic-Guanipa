'use strict';
const { Model } = require('sequelize');

/**
 * Modelo AtencionDiagnostico — tabla puente entre atenciones_diarias y diagnosticos.
 * PK compuesta: (id_atencion_diaria, id_diagnostico).
 */
module.exports = (sequelize, DataTypes) => {
    class AtencionDiagnostico extends Model {
        static associate(models) {
            AtencionDiagnostico.belongsTo(models.AtencionDiaria, {
                foreignKey: 'id_atencion_diaria',
                as: 'atencion'
            });
            AtencionDiagnostico.belongsTo(models.Diagnostico, {
                foreignKey: 'id_diagnostico',
                as: 'diagnostico'
            });
        }
    }

    AtencionDiagnostico.init({
        id_atencion_diaria: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            references: { model: 'atenciones_diarias', key: 'id_atencion' }
        },
        id_diagnostico: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            references: { model: 'diagnosticos', key: 'id_diagnostico' }
        },
        observacion_medica: {
            type: DataTypes.TEXT,
            allowNull: true
        },
        fecha_registro: {
            type: DataTypes.DATEONLY,
            allowNull: true
        }
    }, {
        sequelize,
        modelName: 'AtencionDiagnostico',
        tableName: 'atencion_diagnosticos',
        underscored: true,
        timestamps: false
    });

    return AtencionDiagnostico;
};

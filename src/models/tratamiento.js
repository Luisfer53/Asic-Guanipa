'use strict';
const { Model } = require('sequelize');

/**
 * Modelo Tratamiento — ligado a una atención y un diagnóstico específico.
 */
module.exports = (sequelize, DataTypes) => {
    class Tratamiento extends Model {
        static associate(models) {
            Tratamiento.belongsTo(models.AtencionDiaria, {
                foreignKey: 'id_atencion',
                as: 'atencion'
            });
            Tratamiento.belongsTo(models.Diagnostico, {
                foreignKey: 'id_diagnostico',
                as: 'diagnostico'
            });
            Tratamiento.hasMany(models.TratamientoMedicamento, {
                foreignKey: 'id_tratamiento',
                as: 'medicamentos'
            });
        }
    }

    Tratamiento.init({
        id_tratamiento_id: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        id_atencion: {
            type: DataTypes.INTEGER,
            allowNull: true,
            references: { model: 'atenciones_diarias', key: 'id_atencion' }
        },
        id_diagnostico: {
            type: DataTypes.INTEGER,
            allowNull: true,
            references: { model: 'diagnosticos', key: 'id_diagnostico' }
        },
        tipo_tratamiento: {
            type: DataTypes.STRING(100),
            allowNull: true
        },
        detalles: {
            type: DataTypes.TEXT,
            allowNull: true
        },
        estado: {
            type: DataTypes.STRING(50),
            allowNull: true
        },
        fecha_inicio: {
            type: DataTypes.DATEONLY,
            allowNull: true
        },
        fecha_culminacion: {
            type: DataTypes.DATEONLY,
            allowNull: true
        }
    }, {
        sequelize,
        modelName: 'Tratamiento',
        tableName: 'tratamientos',
        underscored: true,
        timestamps: false
    });

    return Tratamiento;
};

'use strict';
const { Model } = require('sequelize');

/**
 * Modelo TratamientoMedicamento — detalle de medicamentos asignados a un tratamiento.
 */
module.exports = (sequelize, DataTypes) => {
    class TratamientoMedicamento extends Model {
        static associate(models) {
            TratamientoMedicamento.belongsTo(models.Tratamiento, {
                foreignKey: 'id_tratamiento',
                as: 'tratamiento'
            });
            TratamientoMedicamento.belongsTo(models.ArticuloMedico, {
                foreignKey: 'id_articulo',
                as: 'articulo'
            });
        }
    }

    TratamientoMedicamento.init({
        id_tratamiento_med: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        id_tratamiento: {
            type: DataTypes.INTEGER,
            allowNull: false,
            references: { model: 'tratamientos', key: 'id_tratamiento_id' }
        },
        id_articulo: {
            type: DataTypes.INTEGER,
            allowNull: false,
            references: { model: 'articulos_medicos', key: 'id_articulo' }
        },
        dosis: {
            type: DataTypes.STRING(100),
            allowNull: true
        },
        via_administracion: {
            type: DataTypes.STRING(100),
            allowNull: true
        },
        frecuencia: {
            type: DataTypes.STRING(100),
            allowNull: true
        },
        duracion: {
            type: DataTypes.STRING(50),
            allowNull: true
        },
        observacion: {
            type: DataTypes.TEXT,
            allowNull: true
        }
    }, {
        sequelize,
        modelName: 'TratamientoMedicamento',
        tableName: 'tratamiento_medicamentos',
        underscored: true,
        timestamps: false
    });

    return TratamientoMedicamento;
};

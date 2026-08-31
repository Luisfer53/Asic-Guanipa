'use strict';
const { Model } = require('sequelize');

/**
 * Modelo RegistroVacunacion — actualizado con id_esquema para validar
 * reglas biomédicas (RF-validación esquema de vacunación).
 */
module.exports = (sequelize, DataTypes) => {
    class RegistroVacunacion extends Model {
        static associate(models) {
            RegistroVacunacion.belongsTo(models.AtencionDiaria, {
                foreignKey: 'id_atencion',
                as: 'atencion'
            });
            RegistroVacunacion.belongsTo(models.LoteInsumo, {
                foreignKey: 'id_lote',
                as: 'lote'
            });
            RegistroVacunacion.belongsTo(models.EsquemaDosificacion, {
                foreignKey: 'id_esquema',
                as: 'esquema'
            });
        }
    }

    RegistroVacunacion.init({
        id_vacunacion: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        id_atencion: {
            type: DataTypes.INTEGER,
            allowNull: false,
            references: { model: 'atenciones_diarias', key: 'id_atencion' }
        },
        id_lote: {
            type: DataTypes.INTEGER,
            allowNull: false,
            references: { model: 'lotes_insumos', key: 'id_lote_insumo' }
        },
        id_esquema: {
            type: DataTypes.INTEGER,
            allowNull: true,
            references: { model: 'esquemas_dosificacion', key: 'id_esquema' }
        },
        dosis_aplicada: {
            type: DataTypes.STRING(50),
            allowNull: true
        }
    }, {
        sequelize,
        modelName: 'RegistroVacunacion',
        tableName: 'registro_vacunacion',
        underscored: true,
        timestamps: false
    });

    return RegistroVacunacion;
};

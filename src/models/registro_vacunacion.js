'use strict';
const {
    Model
} = require('sequelize');
module.exports = (sequelize, DataTypes) => {
    class RegistroVacunacion extends Model {
        static associate(models) {
            RegistroVacunacion.belongsTo(models.AtencionDiaria, {
                foreignKey: 'id_atencion',
                as: 'atencion'
            });
            RegistroVacunacion.belongsTo(models.LoteInsumo, {
                foreignKey: 'id_lote_insumo',
                as: 'lote'
            });
        }
    }
    RegistroVacunacion.init({
        id_atencion: {
            type: DataTypes.INTEGER,
            allowNull: false,
            references: {
                model: 'atenciones_diarias',
                key: 'id'
            }
        },
        id_lote_insumo: {
            type: DataTypes.INTEGER,
            allowNull: false,
            references: {
                model: 'lotes_insumos',
                key: 'id'
            }
        }
    }, {
        sequelize,
        modelName: 'RegistroVacunacion',
        tableName: 'registro_vacunacion',
        underscored: true,
        timestamps: true
    });
    return RegistroVacunacion;
};

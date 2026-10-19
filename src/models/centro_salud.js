'use strict';
const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
    class CentroSalud extends Model {
        static associate(models) {
            CentroSalud.hasMany(models.Usuario, {
                foreignKey: 'id_centro',
                as: 'usuarios'
            });
            CentroSalud.hasMany(models.AtencionDiaria, {
                foreignKey: 'id_centro',
                as: 'atenciones'
            });
            CentroSalud.hasMany(models.OperativoSalud, {
                foreignKey: 'id_centro_organizador',
                as: 'operativos'
            });
            CentroSalud.hasMany(models.LoteInsumo, {
                foreignKey: 'id_centro',
                as: 'lotes'
            });
        }
    }

    CentroSalud.init({
        id_centro: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        nombre_centro: {
            type: DataTypes.STRING(150),
            allowNull: false
        },
        es_puesto_activo: {
            type: DataTypes.BOOLEAN,
            allowNull: false,
            defaultValue: true
        }
    }, {
        sequelize,
        modelName: 'CentroSalud',
        tableName: 'centros_salud',
        underscored: true,
        timestamps: false
    });

    return CentroSalud;
};

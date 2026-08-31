'use strict';
const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
    class OperativoSalud extends Model {
        static associate(models) {
            OperativoSalud.belongsTo(models.CentroSalud, {
                foreignKey: 'id_centro_organizador',
                as: 'centroOrganizador'
            });
            OperativoSalud.hasMany(models.AtencionDiaria, {
                foreignKey: 'id_operativo',
                as: 'atenciones'
            });
        }
    }

    OperativoSalud.init({
        id_operativo: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        id_centro_organizador: {
            type: DataTypes.INTEGER,
            allowNull: false,
            references: { model: 'centros_salud', key: 'id_centro' }
        },
        nombre_operativo: {
            type: DataTypes.STRING(150),
            allowNull: false
        },
        fecha_operativo: {
            type: DataTypes.DATEONLY,
            allowNull: true
        },
        fecha_fin: {
            type: DataTypes.DATEONLY,
            allowNull: true
        },
        descripcion: {
            type: DataTypes.TEXT,
            allowNull: true
        }
    }, {
        sequelize,
        modelName: 'OperativoSalud',
        tableName: 'operativos_salud',
        underscored: true,
        timestamps: false
    });

    return OperativoSalud;
};

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
            OperativoSalud.hasMany(models.OperativoStock, {
                foreignKey: 'id_operativo',
                as: 'stockBloqueado'
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
        },
        modalidad: {
            type: DataTypes.STRING(50),
            allowNull: false,
            defaultValue: 'intramural'
        },
        sector_comunidad: {
            type: DataTypes.STRING(150),
            allowNull: true
        },
        responsable: {
            type: DataTypes.STRING(150),
            allowNull: true
        },
        personal_participante: {
            type: DataTypes.TEXT,
            allowNull: true
        },
        estado: {
            type: DataTypes.STRING(50),
            allowNull: false,
            defaultValue: 'planificada'
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

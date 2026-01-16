'use strict';
const {
    Model
} = require('sequelize');

module.exports = (sequelize, DataTypes) => {
    class AtencionDiaria extends Model {
        static associate(models) {
            AtencionDiaria.belongsTo(models.Paciente, {
                foreignKey: 'paciente_id',
                as: 'paciente'
            });
            
            AtencionDiaria.belongsTo(models.users, {
                foreignKey: 'id_usuario_registra',
                as: 'usuario'
            });
        }
    }
    AtencionDiaria.init({
        paciente_id: {
            type: DataTypes.INTEGER,
            allowNull: false,
            references: {
                model: 'pacientes',
                key: 'id'
            }
        },
        diagnostico: {
            type: DataTypes.TEXT,
            allowNull: true
        },
        fecha: {
            type: DataTypes.DATEONLY,
            allowNull: false,
            defaultValue: DataTypes.NOW
        },
        edad_atencion: { 
            type: DataTypes.INTEGER,
            allowNull: false
        },
        id_usuario_registra: {
            type: DataTypes.INTEGER,
            allowNull: false
            
        }
    }, {
        sequelize,
        modelName: 'AtencionDiaria',
        tableName: 'atenciones_diarias',
        underscored: true,
    });
    return AtencionDiaria;
};

'use strict';
const { Model } = require('sequelize');

/**
 * Modelo AtencionDiaria — actualizado al nuevo esquema.
 * Ahora referencia id_paciente (en lugar de paciente_id),
 * id_centro (FK a centros_salud) en lugar del campo texto `centro`,
 * id_operativo (opcional), semana_epidemiologica y diagnostico_general.
 * Se elimina edad_atencion y dosis (que migran a otras tablas).
 */
module.exports = (sequelize, DataTypes) => {
    class AtencionDiaria extends Model {
        static associate(models) {
            AtencionDiaria.belongsTo(models.Paciente, {
                foreignKey: 'id_paciente',
                as: 'paciente'
            });
            AtencionDiaria.belongsTo(models.Usuario, {
                foreignKey: 'id_usuario_registra',
                as: 'usuarioRegistra'
            });
            AtencionDiaria.belongsTo(models.CentroSalud, {
                foreignKey: 'id_centro',
                as: 'centro'
            });
            AtencionDiaria.belongsTo(models.OperativoSalud, {
                foreignKey: 'id_operativo',
                as: 'operativo'
            });
            // Diagnósticos (tabla puente)
            AtencionDiaria.hasMany(models.AtencionDiagnostico, {
                foreignKey: 'id_atencion_diaria',
                as: 'diagnosticos'
            });
            // Tratamientos
            AtencionDiaria.hasMany(models.Tratamiento, {
                foreignKey: 'id_atencion',
                as: 'tratamientos'
            });
            // Consumo de insumos
            AtencionDiaria.hasMany(models.ConsumoInsumo, {
                foreignKey: 'id_atencion',
                as: 'consumos'
            });
            // Registros de vacunación
            AtencionDiaria.hasMany(models.RegistroVacunacion, {
                foreignKey: 'id_atencion',
                as: 'vacunaciones'
            });
        }
    }

    AtencionDiaria.init({
        id_atencion: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        id_paciente: {
            type: DataTypes.INTEGER,
            allowNull: false,
            references: { model: 'pacientes', key: 'id_paciente' }
        },
        fecha_visita: {
            type: DataTypes.DATEONLY,
            allowNull: false,
            defaultValue: DataTypes.NOW
        },
        semana_epidemiologica: {
            type: DataTypes.INTEGER,
            allowNull: true
        },
        diagnostico_general: {
            type: DataTypes.TEXT,
            allowNull: true
        },
        id_centro: {
            type: DataTypes.INTEGER,
            allowNull: true,
            references: { model: 'centros_salud', key: 'id_centro' }
        },
        id_operativo: {
            type: DataTypes.INTEGER,
            allowNull: true,
            references: { model: 'operativos_salud', key: 'id_operativo' }
        },
        id_usuario_registra: {
            type: DataTypes.INTEGER,
            allowNull: false,
            references: { model: 'usuarios', key: 'id_serial' }
        }
    }, {
        sequelize,
        modelName: 'AtencionDiaria',
        tableName: 'atenciones_diarias',
        underscored: true,
        timestamps: false
    });

    return AtencionDiaria;
};

'use strict';
const { Model } = require('sequelize');

/**
 * Modelo EsquemaDosificacion — define reglas biomédicas de vacunación
 * (número de dosis, intervalos mínimos, rango de edad).
 */
module.exports = (sequelize, DataTypes) => {
    class EsquemaDosificacion extends Model {
        static associate(models) {
            EsquemaDosificacion.belongsTo(models.ArticuloMedico, {
                foreignKey: 'id_articulo',
                as: 'vacuna'
            });
            EsquemaDosificacion.hasMany(models.RegistroVacunacion, {
                foreignKey: 'id_esquema',
                as: 'registros'
            });
        }
    }

    EsquemaDosificacion.init({
        id_esquema: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        id_articulo: {
            type: DataTypes.INTEGER,
            allowNull: false,
            references: { model: 'articulos_medicos', key: 'id_articulo' }
        },
        numero_dosis: {
            type: DataTypes.STRING(50),
            allowNull: true,
            comment: 'Ej: Primera, Segunda, Refuerzo'
        },
        intervalo_dias_previo: {
            type: DataTypes.INTEGER,
            allowNull: true,
            comment: 'Días mínimos desde la dosis anterior'
        },
        edad_minima_meses: {
            type: DataTypes.INTEGER,
            allowNull: true
        },
        edad_maxima_meses: {
            type: DataTypes.INTEGER,
            allowNull: true
        }
    }, {
        sequelize,
        modelName: 'EsquemaDosificacion',
        tableName: 'esquemas_dosificacion',
        underscored: true,
        timestamps: false
    });

    return EsquemaDosificacion;
};

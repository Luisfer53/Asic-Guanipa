'use strict';
const { Model } = require('sequelize');

/**
 * Modelo ArticuloMedico — actualizado con los nuevos campos del esquema:
 * descripcion y stock_minimo_alerta (semáforo visual RF-08).
 */
module.exports = (sequelize, DataTypes) => {
    class ArticuloMedico extends Model {
        static associate(models) {
            ArticuloMedico.hasMany(models.LoteInsumo, {
                foreignKey: 'id_articulo',
                as: 'lotes'
            });
            ArticuloMedico.hasMany(models.EsquemaDosificacion, {
                foreignKey: 'id_articulo',
                as: 'esquemasDosificacion'
            });
            ArticuloMedico.hasMany(models.TratamientoMedicamento, {
                foreignKey: 'id_articulo',
                as: 'prescripciones'
            });
        }
    }

    ArticuloMedico.init({
        id_articulo: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        nombre_articulo: {
            type: DataTypes.STRING(150),
            allowNull: false
        },
        tipo: {
            type: DataTypes.STRING(50),
            allowNull: false,
            defaultValue: 'Insumo',
            comment: 'Tipo de artículo: Vacuna, Insumo, Medicamento, Equipo'
        },
        descripcion: {
            type: DataTypes.TEXT,
            allowNull: true
        },
        unidad_medida: {
            type: DataTypes.STRING(50),
            allowNull: false
        },
        stock_minimo_alerta: {
            type: DataTypes.INTEGER,
            allowNull: true,
            comment: 'Umbral para activar el semáforo visual de stock (RF-08)'
        }
    }, {
        sequelize,
        modelName: 'ArticuloMedico',
        tableName: 'articulos_medicos',
        underscored: true,
        timestamps: false
    });

    return ArticuloMedico;
};

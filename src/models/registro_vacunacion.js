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
        },
        via_administracion: {
            type: DataTypes.STRING(50),
            allowNull: true,
            comment: 'Ej: Intramuscular, Subcutánea, Oral, Intradérmica'
        },
        sitio_administracion: {
            type: DataTypes.STRING(50),
            allowNull: true,
            comment: 'Ej: Brazo derecho, Brazo izquierdo, Muslo derecho, Muslo izquierdo, Oral'
        },
        temperatura: {
            type: DataTypes.DECIMAL(4, 1),
            allowNull: true,
            comment: 'Temperatura en °C al momento de vacunar (screening de fiebre)'
        },
        peso: {
            type: DataTypes.DECIMAL(5, 2),
            allowNull: true,
            comment: 'Peso en kg — sólo menores de 5 años'
        },
        talla: {
            type: DataTypes.DECIMAL(5, 2),
            allowNull: true,
            comment: 'Talla en cm — sólo menores de 5 años'
        },
        modalidad: {
            type: DataTypes.STRING(20),
            allowNull: true,
            defaultValue: 'intramural',
            comment: 'intramural | extramural — inyectado desde el contexto de guardia activa'
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

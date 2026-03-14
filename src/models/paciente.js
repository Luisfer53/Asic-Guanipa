'use strict';
const { Model } = require('sequelize');
const { encrypt, decrypt } = require('../utils/encryption');

// Campos sensibles que se cifran en reposo
const ENCRYPTED_FIELDS = [
    'nombre',
    'apellido',
    'cedula',
    'telefono',
    'direccion',
    'nombre_representante',
    'apellido_representante',
    'cedula_representante',
    'telefono_representante',
    'direccion_representante'
];

module.exports = (sequelize, DataTypes) => {
    class Paciente extends Model {
        static associate(models) {
            Paciente.hasMany(models.AtencionDiaria, {
                foreignKey: 'paciente_id',
                as: 'atenciones'
            });
        }

        // Los getters han sido movidos a la configuración del modelo

        // ─── toJSON: se asegura de devolver los datos descifrados en las respuestas API
        toJSON() {
            // super.toJSON() ya ejecuta los getters del modelo, los cuales llaman a decrypt()
            return super.toJSON();
        }
    }

    Paciente.init({
        nombre: {
            type: DataTypes.TEXT,      // TEXT para acomodar texto cifrado
            allowNull: false,
            get() { return decrypt(this.getDataValue('nombre')); }
        },
        apellido: {
            type: DataTypes.TEXT,
            allowNull: false,
            get() { return decrypt(this.getDataValue('apellido')); }
        },
        cedula: {
            type: DataTypes.TEXT,
            allowNull: true,
            get() { return decrypt(this.getDataValue('cedula')); }
            // Sin unique: true → la unicidad se valida a nivel de aplicación
        },
        fecha_nacimiento: {
            type: DataTypes.DATEONLY,
            allowNull: true
        },
        sexo: {
            type: DataTypes.ENUM('M', 'F'),
            allowNull: false
        },
        telefono: {
            type: DataTypes.TEXT,
            allowNull: true,
            get() { return decrypt(this.getDataValue('telefono')); }
        },
        direccion: {
            type: DataTypes.TEXT,
            allowNull: true,
            get() { return decrypt(this.getDataValue('direccion')); }
        },
        nombre_representante: {
            type: DataTypes.TEXT,
            allowNull: true,
            get() { return decrypt(this.getDataValue('nombre_representante')); }
        },
        apellido_representante: {
            type: DataTypes.TEXT,
            allowNull: true,
            get() { return decrypt(this.getDataValue('apellido_representante')); }
        },
        cedula_representante: {
            type: DataTypes.TEXT,
            allowNull: true,
            get() { return decrypt(this.getDataValue('cedula_representante')); }
        },
        telefono_representante: {
            type: DataTypes.TEXT,
            allowNull: true,
            get() { return decrypt(this.getDataValue('telefono_representante')); }
        },
        direccion_representante: {
            type: DataTypes.TEXT,
            allowNull: true,
            get() { return decrypt(this.getDataValue('direccion_representante')); }
        }
    }, {
        sequelize,
        modelName: 'Paciente',
        underscored: true,
        timestamps: true,
        hooks: {
            // ─── Cifrar antes de insertar ─────────────────────────────────────
            beforeCreate(paciente) {
                for (const field of ENCRYPTED_FIELDS) {
                    const val = paciente.getDataValue(field);
                    if (val !== null && val !== undefined && val !== '') {
                        paciente.setDataValue(field, encrypt(val));
                    }
                }
            },
            // ─── Cifrar sólo los campos modificados al actualizar ─────────────
            beforeUpdate(paciente) {
                for (const field of ENCRYPTED_FIELDS) {
                    if (paciente.changed(field)) {
                        const val = paciente.getDataValue(field);
                        if (val !== null && val !== undefined && val !== '') {
                            paciente.setDataValue(field, encrypt(val));
                        }
                    }
                }
            }
        }
    });

    return Paciente;
};

'use strict';

const crypto = require('crypto');

const ALGORITHM = 'aes-256-gcm';
const KEY_HEX   = process.env.ENCRYPTION_KEY;
const KEY       = KEY_HEX ? Buffer.from(KEY_HEX, 'hex') : null;

function encrypt(text) {
    if (!text) return text;
    const iv      = crypto.randomBytes(16);
    const cipher  = crypto.createCipheriv(ALGORITHM, KEY, iv);
    let encrypted = cipher.update(String(text), 'utf8', 'hex');
    encrypted    += cipher.final('hex');
    const authTag = cipher.getAuthTag().toString('hex');
    return `${iv.toString('hex')}:${authTag}:${encrypted}`;
}

/** @type {import('sequelize-cli').Migration} */
module.exports = {
    async up(queryInterface, Sequelize) {
        if (!KEY) {
            throw new Error('ENCRYPTION_KEY no está definida. Abortando migración.');
        }

        // 1. Cambiar columnas STRING → TEXT y quitar restricción UNIQUE de cedula
        await queryInterface.changeColumn('pacientes', 'nombre', {
            type: Sequelize.TEXT,
            allowNull: false
        });
        await queryInterface.changeColumn('pacientes', 'apellido', {
            type: Sequelize.TEXT,
            allowNull: false
        });
        await queryInterface.changeColumn('pacientes', 'cedula', {
            type: Sequelize.TEXT,
            allowNull: true
            // Sin unique, lo cual elimina la restricción UNIQUE al redefinir la columna
        });
        await queryInterface.changeColumn('pacientes', 'telefono', {
            type: Sequelize.TEXT,
            allowNull: true
        });
        await queryInterface.changeColumn('pacientes', 'direccion', {
            type: Sequelize.TEXT,
            allowNull: true
        });
        await queryInterface.changeColumn('pacientes', 'nombre_representante', {
            type: Sequelize.TEXT,
            allowNull: true
        });
        await queryInterface.changeColumn('pacientes', 'apellido_representante', {
            type: Sequelize.TEXT,
            allowNull: true
        });
        await queryInterface.changeColumn('pacientes', 'cedula_representante', {
            type: Sequelize.TEXT,
            allowNull: true
        });
        await queryInterface.changeColumn('pacientes', 'telefono_representante', {
            type: Sequelize.TEXT,
            allowNull: true
        });
        await queryInterface.changeColumn('pacientes', 'direccion_representante', {
            type: Sequelize.TEXT,
            allowNull: true
        });

        // 2. Eliminar explícitamente el CONSTRAINT UNIQUE de cedula
        // PostgreSQL requiere DROP CONSTRAINT (no DROP INDEX) cuando es un constraint
        try {
            await queryInterface.sequelize.query(
                'ALTER TABLE pacientes DROP CONSTRAINT IF EXISTS pacientes_cedula_key'
            );
        } catch (_) { /* ignorar si no existe */ }
        try {
            await queryInterface.sequelize.query(
                'ALTER TABLE pacientes DROP CONSTRAINT IF EXISTS "pacientes_cedula_key"'
            );
        } catch (_) { /* ignorar */ }

        // 3. Cifrar los datos existentes fila por fila
        const [pacientes] = await queryInterface.sequelize.query(
            'SELECT id, nombre, apellido, cedula, telefono, direccion, ' +
            'nombre_representante, apellido_representante, cedula_representante, ' +
            'telefono_representante, direccion_representante FROM pacientes'
        );

        const FIELDS = [
            'nombre', 'apellido', 'cedula', 'telefono', 'direccion',
            'nombre_representante', 'apellido_representante', 'cedula_representante',
            'telefono_representante', 'direccion_representante'
        ];

        for (const row of pacientes) {
            const updates = {};
            for (const field of FIELDS) {
                const val = row[field];
                if (val !== null && val !== undefined && val !== '' && !val.includes(':')) {
                    updates[field] = encrypt(val);
                }
            }
            if (Object.keys(updates).length > 0) {
                const setClauses = Object.keys(updates)
                    .map((f, i) => `${f} = $${i + 1}`)
                    .join(', ');
                await queryInterface.sequelize.query(
                    `UPDATE pacientes SET ${setClauses} WHERE id = ${row.id}`,
                    { bind: Object.values(updates) }
                );
            }
        }

        console.log(`✅ Migración completada: ${pacientes.length} paciente(s) cifrado(s).`);
    },

    async down(queryInterface, Sequelize) {
        // ADVERTENCIA: El down no descifra los datos, solo revierte los tipos de columna.
        // Si necesitas descifrar datos, hazlo manualmente antes de ejecutar down.
        console.warn('⚠️  El rollback NO descifra los datos existentes.');

        await queryInterface.changeColumn('pacientes', 'nombre', {
            type: Sequelize.STRING,
            allowNull: false
        });
        await queryInterface.changeColumn('pacientes', 'apellido', {
            type: Sequelize.STRING,
            allowNull: false
        });
        await queryInterface.changeColumn('pacientes', 'cedula', {
            type: Sequelize.STRING,
            allowNull: true
        });
        await queryInterface.changeColumn('pacientes', 'telefono', {
            type: Sequelize.STRING(20),
            allowNull: true
        });
        await queryInterface.changeColumn('pacientes', 'direccion', {
            type: Sequelize.STRING(150),
            allowNull: true
        });
        await queryInterface.changeColumn('pacientes', 'nombre_representante', {
            type: Sequelize.STRING,
            allowNull: true
        });
        await queryInterface.changeColumn('pacientes', 'apellido_representante', {
            type: Sequelize.STRING,
            allowNull: true
        });
        await queryInterface.changeColumn('pacientes', 'cedula_representante', {
            type: Sequelize.STRING,
            allowNull: true
        });
        await queryInterface.changeColumn('pacientes', 'telefono_representante', {
            type: Sequelize.STRING,
            allowNull: true
        });
        await queryInterface.changeColumn('pacientes', 'direccion_representante', {
            type: Sequelize.STRING(150),
            allowNull: true
        });
    }
};

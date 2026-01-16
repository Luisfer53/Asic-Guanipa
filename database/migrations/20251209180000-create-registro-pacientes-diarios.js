'use strict';
/** @type {import('sequelize-cli').Migration} */
module.exports = {
    async up(queryInterface, Sequelize) {
        await queryInterface.createTable('registro_pacientes_diarios', {
            id: {
                allowNull: false,
                autoIncrement: true,
                primaryKey: true,
                type: Sequelize.INTEGER
            },
            nombre: {
                type: Sequelize.STRING,
                allowNull: false
            },
            apellido: {
                type: Sequelize.STRING,
                allowNull: false
            },
            edad: {
                type: Sequelize.INTEGER,
                allowNull: false
            },
            sexo: {
                type: Sequelize.ENUM('M', 'F'),
                allowNull: false
            },
            cedula: {
                type: Sequelize.STRING,
                allowNull: false
            },
            telefono: {
                type: Sequelize.STRING(20),
                allowNull: true
            },
            direccion: {
                type: Sequelize.STRING(150),
                allowNull: true
            },
            diagnostico: {
                type: Sequelize.TEXT,
                allowNull: true
            },
            fecha: {
                type: Sequelize.DATEONLY,
                allowNull: false,
                defaultValue: Sequelize.NOW
            },
            created_at: {
                allowNull: false,
                type: Sequelize.DATE
            },
            updated_at: {
                allowNull: false,
                type: Sequelize.DATE
            }
        });

        // Add index for cedula to optimize history lookups
        await queryInterface.addIndex('registro_pacientes_diarios', ['cedula']);
        // Add index for fecha to optimize report generation
        await queryInterface.addIndex('registro_pacientes_diarios', ['fecha']);
    },
    async down(queryInterface, Sequelize) {
        await queryInterface.dropTable('registro_pacientes_diarios');
    }
};

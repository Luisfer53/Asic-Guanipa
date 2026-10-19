'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up(queryInterface, Sequelize) {
    // Insertar el centro de salud por defecto si no existe
    await queryInterface.sequelize.query(`
      INSERT INTO centros_salud (id_centro, nombre_centro, es_puesto_activo)
      VALUES (1, 'CDI Guanipa', true)
      ON CONFLICT (id_centro) DO NOTHING;
    `);
  },

  async down(queryInterface, Sequelize) {
    await queryInterface.sequelize.query(
      `DELETE FROM centros_salud WHERE id_centro = 1 AND nombre_centro = 'CDI Guanipa';`
    );
  }
};

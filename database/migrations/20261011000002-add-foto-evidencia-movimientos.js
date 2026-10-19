'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up(queryInterface, Sequelize) {
    const tableDesc = await queryInterface.describeTable('movimientos_inventario');
    if (!tableDesc.foto_evidencia) {
      await queryInterface.addColumn('movimientos_inventario', 'foto_evidencia', {
        type: Sequelize.STRING(255),
        allowNull: true
      });
    }
  },

  async down(queryInterface, Sequelize) {
    await queryInterface.removeColumn('movimientos_inventario', 'foto_evidencia');
  }
};

'use strict';

/**
 * Migración para asegurar la existencia de la columna 'activo' en 'usuarios'.
 */
module.exports = {
  async up(queryInterface, Sequelize) {
    const tableInfo = await queryInterface.describeTable('usuarios');
    if (!tableInfo['activo']) {
      await queryInterface.addColumn('usuarios', 'activo', {
        type: Sequelize.BOOLEAN,
        allowNull: false,
        defaultValue: true,
        comment: 'Estado de habilitación del usuario en el sistema'
      });
    }
  },

  async down(queryInterface) {
    const tableInfo = await queryInterface.describeTable('usuarios');
    if (tableInfo['activo']) {
      await queryInterface.removeColumn('usuarios', 'activo');
    }
  }
};

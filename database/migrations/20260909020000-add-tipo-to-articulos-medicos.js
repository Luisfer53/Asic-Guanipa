'use strict';

/**
 * Migración para agregar la columna 'tipo' a 'articulos_medicos'.
 */
module.exports = {
  async up(queryInterface, Sequelize) {
    const tableInfo = await queryInterface.describeTable('articulos_medicos');
    if (!tableInfo['tipo']) {
      await queryInterface.addColumn('articulos_medicos', 'tipo', {
        type: Sequelize.STRING(50),
        allowNull: false,
        defaultValue: 'Insumo',
        comment: 'Tipo de artículo: Vacuna, Insumo, Medicamento, Equipo'
      });
    }
  },

  async down(queryInterface) {
    const tableInfo = await queryInterface.describeTable('articulos_medicos');
    if (tableInfo['tipo']) {
      await queryInterface.removeColumn('articulos_medicos', 'tipo');
    }
  }
};

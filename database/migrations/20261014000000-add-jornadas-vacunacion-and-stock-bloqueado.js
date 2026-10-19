'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up(queryInterface, Sequelize) {
    // 1. Columnas adicionales para operativos_salud
    const opDesc = await queryInterface.describeTable('operativos_salud');
    if (!opDesc.modalidad) {
      await queryInterface.addColumn('operativos_salud', 'modalidad', {
        type: Sequelize.STRING(50),
        allowNull: false,
        defaultValue: 'intramural'
      });
    }
    if (!opDesc.sector_comunidad) {
      await queryInterface.addColumn('operativos_salud', 'sector_comunidad', {
        type: Sequelize.STRING(150),
        allowNull: true
      });
    }
    if (!opDesc.responsable) {
      await queryInterface.addColumn('operativos_salud', 'responsable', {
        type: Sequelize.STRING(150),
        allowNull: true
      });
    }
    if (!opDesc.personal_participante) {
      await queryInterface.addColumn('operativos_salud', 'personal_participante', {
        type: Sequelize.TEXT,
        allowNull: true
      });
    }
    if (!opDesc.estado) {
      await queryInterface.addColumn('operativos_salud', 'estado', {
        type: Sequelize.STRING(50),
        allowNull: false,
        defaultValue: 'planificada'
      });
    }

    // 2. Columna stock_reservado en lotes_insumos
    const loteDesc = await queryInterface.describeTable('lotes_insumos');
    if (!loteDesc.stock_reservado) {
      await queryInterface.addColumn('lotes_insumos', 'stock_reservado', {
        type: Sequelize.INTEGER,
        allowNull: false,
        defaultValue: 0
      });
    }

    // 3. Crear tabla operativos_stock
    const tables = await queryInterface.showAllTables();
    if (!tables.includes('operativos_stock')) {
      await queryInterface.createTable('operativos_stock', {
        id_operativo_stock: {
          allowNull: false,
          autoIncrement: true,
          primaryKey: true,
          type: Sequelize.INTEGER
        },
        id_operativo: {
          type: Sequelize.INTEGER,
          allowNull: false,
          references: { model: 'operativos_salud', key: 'id_operativo' },
          onUpdate: 'CASCADE',
          onDelete: 'CASCADE'
        },
        id_lote_insumo: {
          type: Sequelize.INTEGER,
          allowNull: false,
          references: { model: 'lotes_insumos', key: 'id_lote_insumo' },
          onUpdate: 'CASCADE',
          onDelete: 'CASCADE'
        },
        cantidad_bloqueada: {
          type: Sequelize.INTEGER,
          allowNull: false
        },
        cantidad_usada: {
          type: Sequelize.INTEGER,
          allowNull: false,
          defaultValue: 0
        },
        cantidad_remanente: {
          type: Sequelize.INTEGER,
          allowNull: false
        }
      });
    }
  },

  async down(queryInterface, Sequelize) {
    const tables = await queryInterface.showAllTables();
    if (tables.includes('operativos_stock')) {
      await queryInterface.dropTable('operativos_stock');
    }
    const loteDesc = await queryInterface.describeTable('lotes_insumos');
    if (loteDesc.stock_reservado) {
      await queryInterface.removeColumn('lotes_insumos', 'stock_reservado');
    }
    const opDesc = await queryInterface.describeTable('operativos_salud');
    if (opDesc.estado) await queryInterface.removeColumn('operativos_salud', 'estado');
    if (opDesc.personal_participante) await queryInterface.removeColumn('operativos_salud', 'personal_participante');
    if (opDesc.responsable) await queryInterface.removeColumn('operativos_salud', 'responsable');
    if (opDesc.sector_comunidad) await queryInterface.removeColumn('operativos_salud', 'sector_comunidad');
    if (opDesc.modalidad) await queryInterface.removeColumn('operativos_salud', 'modalidad');
  }
};

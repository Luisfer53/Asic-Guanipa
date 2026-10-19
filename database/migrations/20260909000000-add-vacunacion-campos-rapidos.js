'use strict';

/**
 * Migración aditiva — Fase 3: Flujo de Inmunización Rápida
 *
 * Agrega 6 campos a egistro_vacunacion para registrar:
 * - Vía y sitio anatómico de administración
 * - Temperatura de screening (sólo fiebre, no signos vitales completos)
 * - Peso y talla opcionales (sólo menores de 5 años)
 * - Modalidad de la jornada (intramural / extramural)
 *
 * 100% aditiva — no modifica ni elimina columnas existentes.
 */
module.exports = {
  async up(queryInterface, Sequelize) {
    const tableInfo = await queryInterface.describeTable('registro_vacunacion');

    const addIfMissing = async (column, definition) => {
      if (!tableInfo[column]) {
        await queryInterface.addColumn('registro_vacunacion', column, definition);
      }
    };

    await addIfMissing('via_administracion', {
      type: Sequelize.STRING(50),
      allowNull: true,
      comment: 'Ej: Intramuscular, Subcutánea, Oral, Intradérmica'
    });

    await addIfMissing('sitio_administracion', {
      type: Sequelize.STRING(50),
      allowNull: true,
      comment: 'Ej: Brazo derecho, Brazo izquierdo, Muslo derecho, Muslo izquierdo, Oral'
    });

    await addIfMissing('temperatura', {
      type: Sequelize.DECIMAL(4, 1),
      allowNull: true,
      comment: 'Temperatura corporal en °C al momento de la vacunación (screening básico)'
    });

    await addIfMissing('peso', {
      type: Sequelize.DECIMAL(5, 2),
      allowNull: true,
      comment: 'Peso en kg — registrar sólo para menores de 5 años'
    });

    await addIfMissing('talla', {
      type: Sequelize.DECIMAL(5, 2),
      allowNull: true,
      comment: 'Talla en cm — registrar sólo para menores de 5 años'
    });

    await addIfMissing('modalidad', {
      type: Sequelize.STRING(20),
      allowNull: true,
      defaultValue: 'intramural',
      comment: 'intramural | extramural — tomado del contexto de guardia activa'
    });
  },

  async down(queryInterface) {
    const tableInfo = await queryInterface.describeTable('registro_vacunacion');
    const cols = ['via_administracion', 'sitio_administracion', 'temperatura', 'peso', 'talla', 'modalidad'];
    for (const col of cols) {
      if (tableInfo[col]) {
        await queryInterface.removeColumn('registro_vacunacion', col);
      }
    }
  }
};

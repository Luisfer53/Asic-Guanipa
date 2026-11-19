'use strict';

/**
 * Migración: Carga Histórica de Carnet de Vacunación
 *
 * Agrega campos para identificar si una vacunación fue aplicada
 * en nuestro CDI o si es un registro histórico (otro establecimiento / 
 * carnet físico previo al sistema).
 *
 * - fuente_registro: 'cdi' (normal) | 'historico' (carga manual del carnet)
 * - establecimiento_origen: nombre del establecimiento donde se aplicó (si es histórico)
 * - fecha_aplicacion: fecha real de aplicación (puede diferir de fecha_visita)
 *
 * 100% aditiva — no modifica ni elimina columnas existentes.
 */
module.exports = {
  async up(queryInterface, Sequelize) {
    // ─── Tabla registro_vacunacion ───────────────────────────────────────────
    const vacInfo = await queryInterface.describeTable('registro_vacunacion');

    const addVacCol = async (col, def) => {
      if (!vacInfo[col]) {
        await queryInterface.addColumn('registro_vacunacion', col, def);
      }
    };

    await addVacCol('fuente_registro', {
      type: Sequelize.STRING(20),
      allowNull: true,
      defaultValue: 'cdi',
      comment: "cdi = aplicada aquí | historico = carga manual de carnet previo"
    });

    await addVacCol('establecimiento_origen', {
      type: Sequelize.STRING(150),
      allowNull: true,
      comment: 'Nombre del establecimiento donde se aplicó (solo si fuente=historico)'
    });

    await addVacCol('fecha_aplicacion', {
      type: Sequelize.DATEONLY,
      allowNull: true,
      comment: 'Fecha real de aplicación de la vacuna (puede ser pasada, del carnet físico)'
    });

    await addVacCol('nombre_vacuna_libre', {
      type: Sequelize.STRING(120),
      allowNull: true,
      comment: 'Nombre de la vacuna en texto libre (cuando no existe en el catálogo PAI o no hay lote)'
    });

    // ─── Tabla atenciones_diarias: marcar atenciones históricas ─────────────
    const atenInfo = await queryInterface.describeTable('atenciones_diarias');

    if (!atenInfo['fuente_registro']) {
      await queryInterface.addColumn('atenciones_diarias', 'fuente_registro', {
        type: Sequelize.STRING(20),
        allowNull: true,
        defaultValue: 'cdi',
        comment: "cdi = atención real | historico = carga retrospectiva del carnet"
      });
    }
  },

  async down(queryInterface) {
    const vacInfo = await queryInterface.describeTable('registro_vacunacion');
    for (const col of ['fuente_registro', 'establecimiento_origen', 'fecha_aplicacion', 'nombre_vacuna_libre']) {
      if (vacInfo[col]) await queryInterface.removeColumn('registro_vacunacion', col);
    }
    const atenInfo = await queryInterface.describeTable('atenciones_diarias');
    if (atenInfo['fuente_registro']) {
      await queryInterface.removeColumn('atenciones_diarias', 'fuente_registro');
    }
  }
};

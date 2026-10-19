'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up(queryInterface, Sequelize) {
    const table = 'atenciones_diarias';

    const addCol = async (name, options) => {
      try {
        await queryInterface.addColumn(table, name, options);
      } catch (err) {
        // Si la columna ya existe, continuar sin error
        console.log(`Columna ${name} ya existe o no pudo agregarse: ${err.message}`);
      }
    };

    await addCol('tipo_atencion', {
      type: Sequelize.STRING(30),
      allowNull: true,
      defaultValue: 'inmunizacion',
    });

    await addCol('motivo_consulta', {
      type: Sequelize.TEXT,
      allowNull: true,
    });

    await addCol('presion_arterial', {
      type: Sequelize.STRING(20),
      allowNull: true,
    });

    await addCol('frecuencia_cardiaca', {
      type: Sequelize.INTEGER,
      allowNull: true,
    });

    await addCol('frecuencia_respiratoria', {
      type: Sequelize.INTEGER,
      allowNull: true,
    });

    await addCol('saturacion_oxigeno', {
      type: Sequelize.INTEGER,
      allowNull: true,
    });

    await addCol('temperatura', {
      type: Sequelize.DECIMAL(4, 1),
      allowNull: true,
    });

    await addCol('peso', {
      type: Sequelize.DECIMAL(5, 2),
      allowNull: true,
    });

    await addCol('talla', {
      type: Sequelize.DECIMAL(5, 2),
      allowNull: true,
    });

    await addCol('tratamiento_indicado', {
      type: Sequelize.TEXT,
      allowNull: true,
    });

    await addCol('observaciones', {
      type: Sequelize.TEXT,
      allowNull: true,
    });
  },

  async down(queryInterface) {
    const table = 'atenciones_diarias';
    const cols = [
      'tipo_atencion',
      'motivo_consulta',
      'presion_arterial',
      'frecuencia_cardiaca',
      'frecuencia_respiratoria',
      'saturacion_oxigeno',
      'temperatura',
      'peso',
      'talla',
      'tratamiento_indicado',
      'observaciones',
    ];
    for (const c of cols) {
      try {
        await queryInterface.removeColumn(table, c);
      } catch (_) {}
    }
  }
};

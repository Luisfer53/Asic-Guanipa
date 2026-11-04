'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    const rolesList = [
      'Admin', 'Médico', 'Enfermería', 'Estadística',
      'Básico', 'Inmunizador', 'Inventario', 'Epidemiólogo'
    ];

    for (const nombre_rol of rolesList) {
      await queryInterface.sequelize.query(
        `INSERT INTO roles (nombre_rol, fecha_creacion, fecha_actualizacion)
         VALUES (:nombre_rol, NOW(), NOW())
         ON CONFLICT (nombre_rol) DO NOTHING;`,
        { replacements: { nombre_rol } }
      );
    }
  },

  async down(queryInterface, Sequelize) {
    await queryInterface.bulkDelete('roles', null, {});
  }
};
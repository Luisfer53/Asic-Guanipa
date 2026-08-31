'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    const existingRoles = await queryInterface.sequelize.query(
      `SELECT nombre_rol FROM roles WHERE nombre_rol IN ('Admin', 'Médico', 'Enfermería', 'Estadística', 'Básico');`,
      { type: queryInterface.sequelize.QueryTypes.SELECT }
    );

    const existingRoleNames = existingRoles.map(role => role.nombre_rol);
    const rolesToInsert = [];

    const rolesList = ['Admin', 'Médico', 'Enfermería', 'Estadística', 'Básico'];

    for (const r of rolesList) {
      if (!existingRoleNames.includes(r)) {
        rolesToInsert.push({
          nombre_rol: r,
          fecha_creacion: new Date(),
          fecha_actualizacion: new Date(),
        });
      }
    }

    if (rolesToInsert.length > 0) {
      await queryInterface.bulkInsert('roles', rolesToInsert, {});
    }
  },

  async down(queryInterface, Sequelize) {
    await queryInterface.bulkDelete('roles', null, {});
  }
};
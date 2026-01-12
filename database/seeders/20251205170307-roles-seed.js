'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    const existingRoles = await queryInterface.sequelize.query(
      `SELECT name FROM roles WHERE name IN ('Admin', 'User');`,
      { type: queryInterface.sequelize.QueryTypes.SELECT }
    );

    const existingRoleNames = existingRoles.map(role => role.name);
    const rolesToInsert = [];

    if (!existingRoleNames.includes('Admin')) {
      rolesToInsert.push({
        name: 'Admin',
        createdAt: new Date(),
        updatedAt: new Date(),
      });
    }

    if (!existingRoleNames.includes('User')) {
      rolesToInsert.push({
        name: 'User',
        createdAt: new Date(),
        updatedAt: new Date(),
      });
    }

    if (rolesToInsert.length > 0) {
      await queryInterface.bulkInsert('roles', rolesToInsert, {});
    }
  },

  async down(queryInterface, Sequelize) {
    await queryInterface.bulkDelete('roles', null, {});
  }
}
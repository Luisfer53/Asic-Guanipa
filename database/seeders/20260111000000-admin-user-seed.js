'use strict';
const bcrypt = require('bcryptjs');

module.exports = {
    async up(queryInterface, Sequelize) {
        const username = 'admin_frontend';
        const email = 'admin_frontend@test.com';
        const password = 'AdminFrontend123!';
        const hashedPassword = await bcrypt.hash(password, 10);

        // Check if user exists
        const users = await queryInterface.sequelize.query(
            `SELECT id FROM users WHERE email = '${email}' OR username = '${username}';`,
            { type: queryInterface.sequelize.QueryTypes.SELECT }
        );

        let userId;

        if (users.length === 0) {
            // Create user
            const result = await queryInterface.bulkInsert('users', [{
                username: username,
                email: email,
                password: hashedPassword,
                createdAt: new Date(),
                updatedAt: new Date()
            }], { returning: true });

            userId = result[0].id;
        } else {
            userId = users[0].id;
        }

        // Get Admin role ID
        const roles = await queryInterface.sequelize.query(
            `SELECT id FROM roles WHERE name = 'Admin';`,
            { type: queryInterface.sequelize.QueryTypes.SELECT }
        );

        if (roles.length > 0) {
            const roleId = roles[0].id;

            // Check if user has role
            const userRoles = await queryInterface.sequelize.query(
                `SELECT * FROM user_roles WHERE username = '${username}' AND role_id = ${roleId};`,
                { type: queryInterface.sequelize.QueryTypes.SELECT }
            );

            if (userRoles.length === 0) {
                await queryInterface.bulkInsert('user_roles', [{
                    username: username,
                    role_id: roleId
                }], {});
            }
        }
    },

    async down(queryInterface, Sequelize) {
        // We might not want to delete the admin user in production, but for reversibility:
        // await queryInterface.bulkDelete('users', { username: 'admin_frontend' }, {});
    }
};

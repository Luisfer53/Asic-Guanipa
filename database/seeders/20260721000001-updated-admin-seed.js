'use strict';
const bcrypt = require('bcryptjs');

/** @type {import('sequelize-cli').Migration} */
module.exports = {
    async up(queryInterface, Sequelize) {
        const username = 'admin';
        const email = 'admin@cdi.gob.ve';
        const password = 'admin123';
        const hashedPassword = await bcrypt.hash(password, 10);

        // 1. Crear o verificar persona admin
        let persona = await queryInterface.sequelize.query(
            `SELECT id_persona FROM personas WHERE cedula_identidad = 'V-00000000';`,
            { type: queryInterface.sequelize.QueryTypes.SELECT }
        );

        let idPersona;
        if (persona.length === 0) {
            const [personaId] = await queryInterface.sequelize.query(
                `INSERT INTO personas (cedula_identidad, nombre1, apellido1, sexo, fecha_nacimiento) 
                 VALUES ('V-00000000', 'Administrador', 'Sistema', 'M', '1990-01-01') RETURNING id_persona;`,
                { type: queryInterface.sequelize.QueryTypes.INSERT }
            );
            idPersona = Array.isArray(personaId) ? personaId[0].id_persona : personaId;
        } else {
            idPersona = persona[0].id_persona;
        }

        // 2. Registrar correo en tabla correos
        const correos = await queryInterface.sequelize.query(
            `SELECT id_correo FROM correos WHERE correo = '${email}';`,
            { type: queryInterface.sequelize.QueryTypes.SELECT }
        );
        if (correos.length === 0) {
            await queryInterface.sequelize.query(
                `INSERT INTO correos (id_persona, correo) VALUES (${idPersona}, '${email}');`
            );
        }

        // 3. Crear o verificar roles iniciales
        const roles = ['Admin', 'Médico', 'Enfermería', 'Estadística', 'Básico'];
        for (const nombreRol of roles) {
            const r = await queryInterface.sequelize.query(
                `SELECT id_serial FROM roles WHERE nombre_rol = '${nombreRol}';`,
                { type: queryInterface.sequelize.QueryTypes.SELECT }
            );
            if (r.length === 0) {
                await queryInterface.sequelize.query(
                    `INSERT INTO roles (nombre_rol, fecha_creacion, fecha_actualizacion) VALUES ('${nombreRol}', NOW(), NOW());`
                );
            }
        }

        // 4. Crear usuario administrador
        const usuarioExistente = await queryInterface.sequelize.query(
            `SELECT id_serial FROM usuarios WHERE nombre_usuario = '${username}';`,
            { type: queryInterface.sequelize.QueryTypes.SELECT }
        );

        let idUsuario;
        if (usuarioExistente.length === 0) {
            const [uId] = await queryInterface.sequelize.query(
                `INSERT INTO usuarios (id_persona, nombre_usuario, contrasena, fecha_creacion, fecha_actualizacion) 
                 VALUES (${idPersona}, '${username}', '${hashedPassword}', NOW(), NOW()) RETURNING id_serial;`,
                { type: queryInterface.sequelize.QueryTypes.INSERT }
            );
            idUsuario = Array.isArray(uId) ? uId[0].id_serial : uId;
        } else {
            idUsuario = usuarioExistente[0].id_serial;
            await queryInterface.sequelize.query(
                `UPDATE usuarios SET contrasena = '${hashedPassword}' WHERE id_serial = ${idUsuario};`
            );
        }

        // 5. Asignar rol Admin
        const roleAdmin = await queryInterface.sequelize.query(
            `SELECT id_serial FROM roles WHERE nombre_rol = 'Admin';`,
            { type: queryInterface.sequelize.QueryTypes.SELECT }
        );
        if (roleAdmin.length > 0) {
            const idRolAdmin = roleAdmin[0].id_serial;
            const hasRole = await queryInterface.sequelize.query(
                `SELECT * FROM usuario_roles WHERE nombre_usuario = '${username}' AND id_rol = ${idRolAdmin};`,
                { type: queryInterface.sequelize.QueryTypes.SELECT }
            );
            if (hasRole.length === 0) {
                await queryInterface.sequelize.query(
                    `INSERT INTO usuario_roles (nombre_usuario, id_rol, fecha_creacion, fecha_actualizacion) 
                     VALUES ('${username}', ${idRolAdmin}, NOW(), NOW());`
                );
            }
        }

        // 6. Crear registro de seguridad
        const seg = await queryInterface.sequelize.query(
            `SELECT id_seguridad FROM seguridad_usuarios WHERE id_usuario_sistema = ${idUsuario};`,
            { type: queryInterface.sequelize.QueryTypes.SELECT }
        );
        if (seg.length === 0) {
            await queryInterface.sequelize.query(
                `INSERT INTO seguridad_usuarios (id_usuario_sistema, intento_acceso_fallido, verificacion_carnet) 
                 VALUES (${idUsuario}, 0, true);`
            );
        }
    },

    async down(queryInterface, Sequelize) {
        await queryInterface.bulkDelete('usuario_roles', { nombre_usuario: 'admin' }, {});
        await queryInterface.bulkDelete('usuarios', { nombre_usuario: 'admin' }, {});
    }
};

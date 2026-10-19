'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up(queryInterface, Sequelize) {
    // Primero eliminar duplicados si existen (mantiene el de menor id_serial)
    await queryInterface.sequelize.query(`
      DELETE FROM roles
      WHERE id_serial NOT IN (
        SELECT MIN(id_serial)
        FROM roles
        GROUP BY nombre_rol
      );
    `);

    // Añadir restricción UNIQUE sobre nombre_rol si no existe
    await queryInterface.sequelize.query(`
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_constraint
          WHERE conname = 'roles_nombre_rol_unique'
            AND conrelid = 'roles'::regclass
        ) THEN
          ALTER TABLE roles ADD CONSTRAINT roles_nombre_rol_unique UNIQUE (nombre_rol);
        END IF;
      END
      $$;
    `);
  },

  async down(queryInterface, Sequelize) {
    await queryInterface.sequelize.query(
      `ALTER TABLE roles DROP CONSTRAINT IF EXISTS roles_nombre_rol_unique;`
    );
  }
};

'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
    async up(queryInterface, Sequelize) {
        // 1. Create pacientes table
        await queryInterface.createTable('pacientes', {
            id: {
                allowNull: false,
                autoIncrement: true,
                primaryKey: true,
                type: Sequelize.INTEGER
            },
            nombre: {
                type: Sequelize.STRING,
                allowNull: false
            },
            apellido: {
                type: Sequelize.STRING,
                allowNull: false
            },
            cedula: {
                type: Sequelize.STRING,
                allowNull: true,
                unique: true
            },
            fecha_nacimiento: {
                type: Sequelize.DATEONLY,
                allowNull: true
            },
            sexo: {
                type: Sequelize.ENUM('M', 'F'),
                allowNull: false
            },
            telefono: {
                type: Sequelize.STRING(20),
                allowNull: true
            },
            direccion: {
                type: Sequelize.STRING(150),
                allowNull: true
            },
            nombre_representante: {
                type: Sequelize.STRING,
                allowNull: true
            },
            apellido_representante: {
                type: Sequelize.STRING,
                allowNull: true
            },
            cedula_representante: {
                type: Sequelize.STRING,
                allowNull: true
            },
            telefono_representante: {
                type: Sequelize.STRING,
                allowNull: true
            },
            created_at: {
                allowNull: false,
                type: Sequelize.DATE
            },
            updated_at: {
                allowNull: false,
                type: Sequelize.DATE
            }
        });

        // 2. Create articulos_medicos table
        await queryInterface.createTable('articulos_medicos', {
            id: {
                allowNull: false,
                autoIncrement: true,
                primaryKey: true,
                type: Sequelize.INTEGER
            },
            nombre_articulo: {
                type: Sequelize.STRING,
                allowNull: false
            },
            unidad_medida: {
                type: Sequelize.STRING,
                allowNull: false
            },
            created_at: {
                allowNull: false,
                type: Sequelize.DATE
            },
            updated_at: {
                allowNull: false,
                type: Sequelize.DATE
            }
        });

        // 3. Create lotes_insumos table
        await queryInterface.createTable('lotes_insumos', {
            id: {
                allowNull: false,
                autoIncrement: true,
                primaryKey: true,
                type: Sequelize.INTEGER
            },
            id_articulo: {
                type: Sequelize.INTEGER,
                allowNull: false,
                references: {
                    model: 'articulos_medicos',
                    key: 'id'
                },
                onUpdate: 'CASCADE',
                onDelete: 'CASCADE'
            },
            numero_lote: {
                type: Sequelize.STRING,
                allowNull: false
            },
            stock_actual: {
                type: Sequelize.INTEGER,
                allowNull: false,
                defaultValue: 0
            },
            fecha_vencimiento: {
                type: Sequelize.DATEONLY,
                allowNull: false
            },
            created_at: {
                allowNull: false,
                type: Sequelize.DATE
            },
            updated_at: {
                allowNull: false,
                type: Sequelize.DATE
            }
        });

        // 4. Create atenciones_diarias table
        await queryInterface.createTable('atenciones_diarias', {
            id: {
                allowNull: false,
                autoIncrement: true,
                primaryKey: true,
                type: Sequelize.INTEGER
            },
            paciente_id: {
                type: Sequelize.INTEGER,
                allowNull: false,
                references: {
                    model: 'pacientes',
                    key: 'id'
                },
                onUpdate: 'CASCADE',
                onDelete: 'CASCADE'
            },
            diagnostico: {
                type: Sequelize.TEXT,
                allowNull: true
            },
            fecha: {
                type: Sequelize.DATEONLY,
                allowNull: false
            },
            edad_atencion: {
                type: Sequelize.INTEGER,
                allowNull: false
            },
            id_usuario_registra: {
                type: Sequelize.INTEGER,
                allowNull: false,
                references: {
                    model: 'users',
                    key: 'id'
                }
            },
            created_at: {
                allowNull: false,
                type: Sequelize.DATE
            },
            updated_at: {
                allowNull: false,
                type: Sequelize.DATE
            }
        });

        // 5. Create consumo_insumos table
        await queryInterface.createTable('consumo_insumos', {
            id: {
                allowNull: false,
                autoIncrement: true,
                primaryKey: true,
                type: Sequelize.INTEGER
            },
            id_atencion: {
                type: Sequelize.INTEGER,
                allowNull: false,
                references: {
                    model: 'atenciones_diarias',
                    key: 'id'
                },
                onUpdate: 'CASCADE',
                onDelete: 'CASCADE'
            },
            id_lote_insumo: {
                type: Sequelize.INTEGER,
                allowNull: false,
                references: {
                    model: 'lotes_insumos',
                    key: 'id'
                },
                onUpdate: 'CASCADE',
                onDelete: 'CASCADE'
            },
            cantidad_usada: {
                type: Sequelize.INTEGER,
                allowNull: false
            },
            created_at: {
                allowNull: false,
                type: Sequelize.DATE
            },
            updated_at: {
                allowNull: false,
                type: Sequelize.DATE
            }
        });

        // 6. Create registro_vacunacion table
        await queryInterface.createTable('registro_vacunacion', {
            id: {
                allowNull: false,
                autoIncrement: true,
                primaryKey: true,
                type: Sequelize.INTEGER
            },
            id_atencion: {
                type: Sequelize.INTEGER,
                allowNull: false,
                references: {
                    model: 'atenciones_diarias',
                    key: 'id'
                },
                onUpdate: 'CASCADE',
                onDelete: 'CASCADE'
            },
            id_lote_insumo: {
                type: Sequelize.INTEGER,
                allowNull: false,
                references: {
                    model: 'lotes_insumos',
                    key: 'id'
                },
                onUpdate: 'CASCADE',
                onDelete: 'CASCADE'
            },
            created_at: {
                allowNull: false,
                type: Sequelize.DATE
            },
            updated_at: {
                allowNull: false,
                type: Sequelize.DATE
            }
        });
    },

    async down(queryInterface, Sequelize) {
        await queryInterface.dropTable('registro_vacunacion');
        await queryInterface.dropTable('consumo_insumos');
        await queryInterface.dropTable('atenciones_diarias');
        await queryInterface.dropTable('lotes_insumos');
        await queryInterface.dropTable('articulos_medicos');
        await queryInterface.dropTable('pacientes');
    }
};

'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
    async up(queryInterface, Sequelize) {
        // Eliminar tablas legacy preexistentes para aplicar la nueva estructura limpia
        await queryInterface.dropTable('registro_vacunacion').catch(() => {});
        await queryInterface.dropTable('consumo_insumos').catch(() => {});
        await queryInterface.dropTable('atenciones_diarias').catch(() => {});
        await queryInterface.dropTable('lotes_insumos').catch(() => {});
        await queryInterface.dropTable('articulos_medicos').catch(() => {});
        await queryInterface.dropTable('pacientes').catch(() => {});

        // 1. Tabla personas
        await queryInterface.createTable('personas', {
            id_persona: {
                allowNull: false,
                autoIncrement: true,
                primaryKey: true,
                type: Sequelize.INTEGER
            },
            cedula_identidad: {
                type: Sequelize.STRING(20),
                allowNull: true,
                unique: true
            },
            nombre1: { type: Sequelize.STRING(50), allowNull: true },
            nombre2: { type: Sequelize.STRING(50), allowNull: true },
            apellido1: { type: Sequelize.STRING(50), allowNull: true },
            apellido2: { type: Sequelize.STRING(50), allowNull: true },
            sexo: { type: Sequelize.STRING(10), allowNull: true },
            estado_civil: { type: Sequelize.STRING(50), allowNull: true },
            ocupacion: { type: Sequelize.STRING(100), allowNull: true },
            fecha_nacimiento: { type: Sequelize.DATEONLY, allowNull: true }
        });

        // 2. Tabla sectores_guanipa
        await queryInterface.createTable('sectores_guanipa', {
            id_sector: {
                allowNull: false,
                autoIncrement: true,
                primaryKey: true,
                type: Sequelize.INTEGER
            },
            nombre_sector: { type: Sequelize.STRING(100), allowNull: false }
        });

        // 3. Tabla direcciones
        await queryInterface.createTable('direcciones', {
            id_direccion: {
                allowNull: false,
                autoIncrement: true,
                primaryKey: true,
                type: Sequelize.INTEGER
            },
            id_persona: {
                type: Sequelize.INTEGER,
                allowNull: false,
                references: { model: 'personas', key: 'id_persona' },
                onUpdate: 'CASCADE',
                onDelete: 'CASCADE'
            },
            id_sector: {
                type: Sequelize.INTEGER,
                allowNull: true,
                references: { model: 'sectores_guanipa', key: 'id_sector' },
                onUpdate: 'CASCADE',
                onDelete: 'SET NULL'
            },
            parroquia: { type: Sequelize.STRING(100), allowNull: true },
            calle: { type: Sequelize.STRING(100), allowNull: true },
            codigo_postal: { type: Sequelize.STRING(20), allowNull: true },
            numero_casa: { type: Sequelize.STRING(50), allowNull: true },
            punto_referencia: { type: Sequelize.TEXT, allowNull: true }
        });

        // 4. Tabla telefonos
        await queryInterface.createTable('telefonos', {
            id_telefono: {
                allowNull: false,
                autoIncrement: true,
                primaryKey: true,
                type: Sequelize.INTEGER
            },
            id_persona: {
                type: Sequelize.INTEGER,
                allowNull: false,
                references: { model: 'personas', key: 'id_persona' },
                onUpdate: 'CASCADE',
                onDelete: 'CASCADE'
            },
            numero_telefono: { type: Sequelize.STRING(20), allowNull: false }
        });

        // 5. Tabla correos
        await queryInterface.createTable('correos', {
            id_correo: {
                allowNull: false,
                autoIncrement: true,
                primaryKey: true,
                type: Sequelize.INTEGER
            },
            id_persona: {
                type: Sequelize.INTEGER,
                allowNull: false,
                references: { model: 'personas', key: 'id_persona' },
                onUpdate: 'CASCADE',
                onDelete: 'CASCADE'
            },
            correo: { type: Sequelize.STRING(150), allowNull: false }
        });

        // 6. Tabla centros_salud
        await queryInterface.createTable('centros_salud', {
            id_centro: {
                allowNull: false,
                autoIncrement: true,
                primaryKey: true,
                type: Sequelize.INTEGER
            },
            nombre_centro: { type: Sequelize.STRING(150), allowNull: false },
            es_puesto_activo: { type: Sequelize.BOOLEAN, allowNull: false, defaultValue: true }
        });

        // 7. Tabla pacientes
        await queryInterface.createTable('pacientes', {
            id_paciente: {
                allowNull: false,
                autoIncrement: true,
                primaryKey: true,
                type: Sequelize.INTEGER
            },
            id_persona: {
                type: Sequelize.INTEGER,
                allowNull: false,
                unique: true,
                references: { model: 'personas', key: 'id_persona' },
                onUpdate: 'CASCADE',
                onDelete: 'CASCADE'
            },
            id_representante: {
                type: Sequelize.INTEGER,
                allowNull: true,
                references: { model: 'personas', key: 'id_persona' },
                onUpdate: 'CASCADE',
                onDelete: 'SET NULL'
            },
            parentesco_representante: { type: Sequelize.STRING(50), allowNull: true },
            fecha_registro: { type: Sequelize.DATEONLY, allowNull: true },
            peso: { type: Sequelize.DECIMAL(5, 2), allowNull: true },
            tipo_sangre: { type: Sequelize.STRING(5), allowNull: true },
            alergias: { type: Sequelize.TEXT, allowNull: true },
            enfermedades_cronicas: { type: Sequelize.TEXT, allowNull: true },
            vacunas: { type: Sequelize.TEXT, allowNull: true },
            discapacidad: { type: Sequelize.TEXT, allowNull: true },
            antecedentes_familiares: { type: Sequelize.TEXT, allowNull: true }
        });

        // 8. Tabla usuarios
        await queryInterface.createTable('usuarios', {
            id_serial: {
                allowNull: false,
                autoIncrement: true,
                primaryKey: true,
                type: Sequelize.INTEGER
            },
            id_persona: {
                type: Sequelize.INTEGER,
                allowNull: false,
                unique: true,
                references: { model: 'personas', key: 'id_persona' },
                onUpdate: 'CASCADE',
                onDelete: 'CASCADE'
            },
            id_centro: {
                type: Sequelize.INTEGER,
                allowNull: true,
                references: { model: 'centros_salud', key: 'id_centro' },
                onUpdate: 'CASCADE',
                onDelete: 'SET NULL'
            },
            nombre_usuario: { type: Sequelize.STRING(100), allowNull: false, unique: true },
            contrasena: { type: Sequelize.STRING(255), allowNull: false },
            fecha_creacion: { type: Sequelize.DATE, allowNull: true },
            fecha_actualizacion: { type: Sequelize.DATE, allowNull: true }
        });

        // 9. Tabla roles (eliminamos la tabla preexistente si existe para actualizar a id_serial y nombre_rol)
        await queryInterface.dropTable('usuario_roles').catch(() => {});
        await queryInterface.dropTable('user_roles').catch(() => {});
        await queryInterface.dropTable('roles').catch(() => {});

        await queryInterface.createTable('roles', {
            id_serial: {
                allowNull: false,
                autoIncrement: true,
                primaryKey: true,
                type: Sequelize.INTEGER
            },
            nombre_rol: { type: Sequelize.STRING(100), allowNull: false },
            fecha_creacion: { type: Sequelize.DATE, allowNull: true },
            fecha_actualizacion: { type: Sequelize.DATE, allowNull: true }
        });

        // 10. Tabla usuario_roles
        await queryInterface.createTable('usuario_roles', {
            id_serial: {
                allowNull: false,
                autoIncrement: true,
                primaryKey: true,
                type: Sequelize.INTEGER
            },
            nombre_usuario: {
                type: Sequelize.STRING(100),
                allowNull: false,
                references: { model: 'usuarios', key: 'nombre_usuario' },
                onUpdate: 'CASCADE',
                onDelete: 'CASCADE'
            },
            id_rol: {
                type: Sequelize.INTEGER,
                allowNull: false,
                references: { model: 'roles', key: 'id_serial' },
                onUpdate: 'CASCADE',
                onDelete: 'CASCADE'
            },
            fecha_creacion: { type: Sequelize.DATE, allowNull: true },
            fecha_actualizacion: { type: Sequelize.DATE, allowNull: true }
        });

        // 11. Tabla seguridad_usuarios
        await queryInterface.createTable('seguridad_usuarios', {
            id_seguridad: {
                allowNull: false,
                autoIncrement: true,
                primaryKey: true,
                type: Sequelize.INTEGER
            },
            id_usuario_sistema: {
                type: Sequelize.INTEGER,
                allowNull: false,
                unique: true,
                references: { model: 'usuarios', key: 'id_serial' },
                onUpdate: 'CASCADE',
                onDelete: 'CASCADE'
            },
            codigo_recuperacion: { type: Sequelize.STRING(100), allowNull: true },
            fecha_creacion_contrasena: { type: Sequelize.DATE, allowNull: true },
            intento_acceso_fallido: { type: Sequelize.INTEGER, allowNull: true, defaultValue: 0 },
            ultima_conexion: { type: Sequelize.DATE, allowNull: true },
            verificacion_carnet: { type: Sequelize.BOOLEAN, allowNull: true, defaultValue: false },
            pregunta_seguridad_1: { type: Sequelize.STRING(255), allowNull: true },
            respuesta_seguridad_1: { type: Sequelize.STRING(255), allowNull: true },
            pregunta_seguridad_2: { type: Sequelize.STRING(255), allowNull: true },
            respuesta_seguridad_2: { type: Sequelize.STRING(255), allowNull: true },
            pregunta_seguridad_3: { type: Sequelize.STRING(255), allowNull: true },
            respuesta_seguridad_3: { type: Sequelize.STRING(255), allowNull: true }
        });

        // 12. Tabla doctores_datos
        await queryInterface.createTable('doctores_datos', {
            id_doctor_datos: {
                allowNull: false,
                autoIncrement: true,
                primaryKey: true,
                type: Sequelize.INTEGER
            },
            id_usuario_sistema: {
                type: Sequelize.INTEGER,
                allowNull: false,
                references: { model: 'usuarios', key: 'id_serial' },
                onUpdate: 'CASCADE',
                onDelete: 'CASCADE'
            },
            numero_carnet: { type: Sequelize.STRING(50), allowNull: false, unique: true },
            area_trabajo: { type: Sequelize.STRING(100), allowNull: true },
            horario: { type: Sequelize.STRING(100), allowNull: true },
            anos_experiencia: { type: Sequelize.INTEGER, allowNull: true }
        });

        // 13. Tabla operativos_salud
        await queryInterface.createTable('operativos_salud', {
            id_operativo: {
                allowNull: false,
                autoIncrement: true,
                primaryKey: true,
                type: Sequelize.INTEGER
            },
            id_centro_organizador: {
                type: Sequelize.INTEGER,
                allowNull: false,
                references: { model: 'centros_salud', key: 'id_centro' },
                onUpdate: 'CASCADE',
                onDelete: 'CASCADE'
            },
            nombre_operativo: { type: Sequelize.STRING(150), allowNull: false },
            fecha_operativo: { type: Sequelize.DATEONLY, allowNull: true },
            descripcion: { type: Sequelize.TEXT, allowNull: true }
        });

        // 14. Tabla atenciones_diarias
        await queryInterface.createTable('atenciones_diarias', {
            id_atencion: {
                allowNull: false,
                autoIncrement: true,
                primaryKey: true,
                type: Sequelize.INTEGER
            },
            id_paciente: {
                type: Sequelize.INTEGER,
                allowNull: false,
                references: { model: 'pacientes', key: 'id_paciente' },
                onUpdate: 'CASCADE',
                onDelete: 'CASCADE'
            },
            fecha_visita: { type: Sequelize.DATEONLY, allowNull: false },
            semana_epidemiologica: { type: Sequelize.INTEGER, allowNull: true },
            diagnostico_general: { type: Sequelize.TEXT, allowNull: true },
            id_centro: {
                type: Sequelize.INTEGER,
                allowNull: true,
                references: { model: 'centros_salud', key: 'id_centro' },
                onUpdate: 'CASCADE',
                onDelete: 'SET NULL'
            },
            id_operativo: {
                type: Sequelize.INTEGER,
                allowNull: true,
                references: { model: 'operativos_salud', key: 'id_operativo' },
                onUpdate: 'CASCADE',
                onDelete: 'SET NULL'
            },
            id_usuario_registra: {
                type: Sequelize.INTEGER,
                allowNull: false,
                references: { model: 'usuarios', key: 'id_serial' },
                onUpdate: 'CASCADE',
                onDelete: 'CASCADE'
            }
        });

        // 15. Tabla diagnosticos
        await queryInterface.createTable('diagnosticos', {
            id_diagnostico: {
                allowNull: false,
                autoIncrement: true,
                primaryKey: true,
                type: Sequelize.INTEGER
            },
            condicion: { type: Sequelize.STRING(100), allowNull: false },
            descripcion: { type: Sequelize.TEXT, allowNull: true },
            gravedad: { type: Sequelize.STRING(50), allowNull: true }
        });

        // 16. Tabla atencion_diagnosticos
        await queryInterface.createTable('atencion_diagnosticos', {
            id_atencion_diaria: {
                type: Sequelize.INTEGER,
                primaryKey: true,
                allowNull: false,
                references: { model: 'atenciones_diarias', key: 'id_atencion' },
                onUpdate: 'CASCADE',
                onDelete: 'CASCADE'
            },
            id_diagnostico: {
                type: Sequelize.INTEGER,
                primaryKey: true,
                allowNull: false,
                references: { model: 'diagnosticos', key: 'id_diagnostico' },
                onUpdate: 'CASCADE',
                onDelete: 'CASCADE'
            },
            observacion_medica: { type: Sequelize.TEXT, allowNull: true },
            fecha_registro: { type: Sequelize.DATEONLY, allowNull: true }
        });

        // 17. Tabla tratamientos
        await queryInterface.createTable('tratamientos', {
            id_tratamiento_id: {
                allowNull: false,
                autoIncrement: true,
                primaryKey: true,
                type: Sequelize.INTEGER
            },
            id_atencion: {
                type: Sequelize.INTEGER,
                allowNull: true,
                references: { model: 'atenciones_diarias', key: 'id_atencion' },
                onUpdate: 'CASCADE',
                onDelete: 'SET NULL'
            },
            id_diagnostico: {
                type: Sequelize.INTEGER,
                allowNull: true,
                references: { model: 'diagnosticos', key: 'id_diagnostico' },
                onUpdate: 'CASCADE',
                onDelete: 'SET NULL'
            },
            tipo_tratamiento: { type: Sequelize.STRING(100), allowNull: true },
            detalles: { type: Sequelize.TEXT, allowNull: true },
            estado: { type: Sequelize.STRING(50), allowNull: true },
            fecha_inicio: { type: Sequelize.DATEONLY, allowNull: true },
            fecha_culminacion: { type: Sequelize.DATEONLY, allowNull: true }
        });

        // 18. Tabla articulos_medicos
        await queryInterface.createTable('articulos_medicos', {
            id_articulo: {
                allowNull: false,
                autoIncrement: true,
                primaryKey: true,
                type: Sequelize.INTEGER
            },
            nombre_articulo: { type: Sequelize.STRING(150), allowNull: false },
            descripcion: { type: Sequelize.TEXT, allowNull: true },
            unidad_medida: { type: Sequelize.STRING(50), allowNull: false },
            stock_minimo_alerta: { type: Sequelize.INTEGER, allowNull: true }
        });

        // 19. Tabla tratamiento_medicamentos
        await queryInterface.createTable('tratamiento_medicamentos', {
            id_tratamiento_med: {
                allowNull: false,
                autoIncrement: true,
                primaryKey: true,
                type: Sequelize.INTEGER
            },
            id_tratamiento: {
                type: Sequelize.INTEGER,
                allowNull: false,
                references: { model: 'tratamientos', key: 'id_tratamiento_id' },
                onUpdate: 'CASCADE',
                onDelete: 'CASCADE'
            },
            id_articulo: {
                type: Sequelize.INTEGER,
                allowNull: false,
                references: { model: 'articulos_medicos', key: 'id_articulo' },
                onUpdate: 'CASCADE',
                onDelete: 'CASCADE'
            },
            dosis: { type: Sequelize.STRING(100), allowNull: true },
            via_administracion: { type: Sequelize.STRING(100), allowNull: true },
            frecuencia: { type: Sequelize.STRING(100), allowNull: true },
            duracion: { type: Sequelize.STRING(50), allowNull: true },
            observacion: { type: Sequelize.TEXT, allowNull: true }
        });

        // 20. Tabla proveedores
        await queryInterface.createTable('proveedores', {
            id_proveedor: {
                allowNull: false,
                autoIncrement: true,
                primaryKey: true,
                type: Sequelize.INTEGER
            },
            nombre_proveedor: { type: Sequelize.STRING(150), allowNull: false },
            rif: { type: Sequelize.STRING(50), allowNull: true, unique: true },
            telefono: { type: Sequelize.STRING(50), allowNull: true },
            direccion: { type: Sequelize.TEXT, allowNull: true }
        });

        // 21. Tabla esquemas_dosificacion
        await queryInterface.createTable('esquemas_dosificacion', {
            id_esquema: {
                allowNull: false,
                autoIncrement: true,
                primaryKey: true,
                type: Sequelize.INTEGER
            },
            id_articulo: {
                type: Sequelize.INTEGER,
                allowNull: false,
                references: { model: 'articulos_medicos', key: 'id_articulo' },
                onUpdate: 'CASCADE',
                onDelete: 'CASCADE'
            },
            numero_dosis: { type: Sequelize.STRING(50), allowNull: true },
            intervalo_dias_previo: { type: Sequelize.INTEGER, allowNull: true },
            edad_minima_meses: { type: Sequelize.INTEGER, allowNull: true },
            edad_maxima_meses: { type: Sequelize.INTEGER, allowNull: true }
        });

        // 22. Tabla lotes_insumos
        await queryInterface.createTable('lotes_insumos', {
            id_lote_insumo: {
                allowNull: false,
                autoIncrement: true,
                primaryKey: true,
                type: Sequelize.INTEGER
            },
            id_articulo: {
                type: Sequelize.INTEGER,
                allowNull: false,
                references: { model: 'articulos_medicos', key: 'id_articulo' },
                onUpdate: 'CASCADE',
                onDelete: 'CASCADE'
            },
            id_proveedor: {
                type: Sequelize.INTEGER,
                allowNull: true,
                references: { model: 'proveedores', key: 'id_proveedor' },
                onUpdate: 'CASCADE',
                onDelete: 'SET NULL'
            },
            id_centro: {
                type: Sequelize.INTEGER,
                allowNull: true,
                references: { model: 'centros_salud', key: 'id_centro' },
                onUpdate: 'CASCADE',
                onDelete: 'SET NULL'
            },
            numero_lote: { type: Sequelize.STRING(100), allowNull: false, unique: true },
            fecha_vencimiento: { type: Sequelize.DATEONLY, allowNull: false },
            stock_actual: { type: Sequelize.INTEGER, allowNull: false, defaultValue: 0 }
        });

        // 23. Tabla movimientos_inventario
        await queryInterface.createTable('movimientos_inventario', {
            id_movimiento: {
                allowNull: false,
                autoIncrement: true,
                primaryKey: true,
                type: Sequelize.INTEGER
            },
            id_lote_insumo: {
                type: Sequelize.INTEGER,
                allowNull: false,
                references: { model: 'lotes_insumos', key: 'id_lote_insumo' },
                onUpdate: 'CASCADE',
                onDelete: 'CASCADE'
            },
            id_centro: {
                type: Sequelize.INTEGER,
                allowNull: true,
                references: { model: 'centros_salud', key: 'id_centro' },
                onUpdate: 'CASCADE',
                onDelete: 'SET NULL'
            },
            tipo_movimiento: { type: Sequelize.STRING(50), allowNull: false },
            cantidad: { type: Sequelize.INTEGER, allowNull: false },
            numero_acta_descarte: { type: Sequelize.STRING(100), allowNull: true },
            justificacion: { type: Sequelize.TEXT, allowNull: true },
            fecha_movimiento: { type: Sequelize.DATE, allowNull: true, defaultValue: Sequelize.NOW }
        });

        // 24. Tabla registro_vacunacion
        await queryInterface.createTable('registro_vacunacion', {
            id_vacunacion: {
                allowNull: false,
                autoIncrement: true,
                primaryKey: true,
                type: Sequelize.INTEGER
            },
            id_atencion: {
                type: Sequelize.INTEGER,
                allowNull: false,
                references: { model: 'atenciones_diarias', key: 'id_atencion' },
                onUpdate: 'CASCADE',
                onDelete: 'CASCADE'
            },
            id_lote: {
                type: Sequelize.INTEGER,
                allowNull: false,
                references: { model: 'lotes_insumos', key: 'id_lote_insumo' },
                onUpdate: 'CASCADE',
                onDelete: 'CASCADE'
            },
            id_esquema: {
                type: Sequelize.INTEGER,
                allowNull: true,
                references: { model: 'esquemas_dosificacion', key: 'id_esquema' },
                onUpdate: 'CASCADE',
                onDelete: 'SET NULL'
            },
            dosis_aplicada: { type: Sequelize.STRING(50), allowNull: true }
        });

        // 25. Tabla consumo_insumos
        await queryInterface.createTable('consumo_insumos', {
            id_consumo: {
                allowNull: false,
                autoIncrement: true,
                primaryKey: true,
                type: Sequelize.INTEGER
            },
            id_atencion: {
                type: Sequelize.INTEGER,
                allowNull: false,
                references: { model: 'atenciones_diarias', key: 'id_atencion' },
                onUpdate: 'CASCADE',
                onDelete: 'CASCADE'
            },
            id_lote_insumo: {
                type: Sequelize.INTEGER,
                allowNull: false,
                references: { model: 'lotes_insumos', key: 'id_lote_insumo' },
                onUpdate: 'CASCADE',
                onDelete: 'CASCADE'
            },
            cantidad_usada: { type: Sequelize.INTEGER, allowNull: false }
        });
    },

    async down(queryInterface, Sequelize) {
        await queryInterface.dropTable('consumo_insumos');
        await queryInterface.dropTable('registro_vacunacion');
        await queryInterface.dropTable('movimientos_inventario');
        await queryInterface.dropTable('lotes_insumos');
        await queryInterface.dropTable('esquemas_dosificacion');
        await queryInterface.dropTable('proveedores');
        await queryInterface.dropTable('tratamiento_medicamentos');
        await queryInterface.dropTable('articulos_medicos');
        await queryInterface.dropTable('tratamientos');
        await queryInterface.dropTable('atencion_diagnosticos');
        await queryInterface.dropTable('diagnosticos');
        await queryInterface.dropTable('atenciones_diarias');
        await queryInterface.dropTable('operativos_salud');
        await queryInterface.dropTable('doctores_datos');
        await queryInterface.dropTable('seguridad_usuarios');
        await queryInterface.dropTable('usuario_roles');
        await queryInterface.dropTable('roles');
        await queryInterface.dropTable('usuarios');
        await queryInterface.dropTable('pacientes');
        await queryInterface.dropTable('centros_salud');
        await queryInterface.dropTable('correos');
        await queryInterface.dropTable('telefonos');
        await queryInterface.dropTable('direcciones');
        await queryInterface.dropTable('sectores_guanipa');
        await queryInterface.dropTable('personas');
    }
};

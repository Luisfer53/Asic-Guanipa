/*
================================================================================
  SISTEMA DE INFORMACIÓN GERENCIAL - ASIC GUANIPA / CDI PEDRO URBINA
  Proyecto Integrador de Objetivos (PIO) - UPTJAA Núcleo Guanipa
================================================================================
  Archivo     : triggers_y_procedimientos.sql
  Motor BD    : PostgreSQL (PL/pgSQL)
  Descripción : Triggers y Procedimientos Almacenados del sistema de 
                inmunización, atención médica y control de inventario.

  ESTRUCTURA DEL RECURSO:
    • SECCIÓN 1: TRIGGERS (DISPARADORES AUTOMÁTICOS)
        1. trigger_descontar_stock   : Descuento automático de inventario
        2. trigger_auditoria_consumo : Registro detallado en bitácora
    
    • SECCIÓN 2: PROCEDIMIENTOS ALMACENADOS (STORED PROCEDURES)
        1. sp_registrar_atencion_medica       : Transacción médica atómica
        2. sp_registrar_movimiento_inventario : Control de inventario seguro

    • SECCIÓN 3: CONSULTAS DE VERIFICACIÓN (AUDITORÍA EN PGADMIN)
================================================================================
*/


/*
================================================================================
  SECCIÓN 1: TRIGGERS (DISPARADORES AUTOMÁTICOS)
================================================================================
*/

-- -----------------------------------------------------------------------------
-- NOMBRE   : trigger_descontar_stock
-- TABLA    : consumo_insumos
-- EVENTO   : AFTER INSERT (después de registrar uso de insumo/medicamento)
-- FUNCIÓN  : actualizar_stock_insumos()
-- OBJETIVO : Garantizar la integridad y consistencia del inventario real en
--            lotes_insumos ante consumos médicos en el CDI Pedro Urbina.
-- -----------------------------------------------------------------------------

-- Paso 1: Definición de la función ejecutora del trigger
CREATE OR REPLACE FUNCTION actualizar_stock_insumos()
RETURNS TRIGGER AS $$
BEGIN
    -- Restar la cantidad consumida del lote correspondiente
    UPDATE lotes_insumos
    SET    stock_actual = stock_actual - NEW.cantidad_usada
    WHERE  id_lote_insumo = NEW.id_lote_insumo;

    -- Validación de seguridad: Prevenir stock negativo
    IF (SELECT stock_actual
        FROM   lotes_insumos
        WHERE  id_lote_insumo = NEW.id_lote_insumo) < 0 THEN
        RAISE EXCEPTION
            'Error de Inventario: Stock insuficiente en el Lote ID %. Cantidad no disponible.',
            NEW.id_lote_insumo;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION actualizar_stock_insumos() IS
    'Actualiza automáticamente el stock disponible en la tabla lotes_insumos al registrar consumos.';

-- Paso 2: Asociación del trigger a la tabla objetivo
DROP TRIGGER IF EXISTS trigger_descontar_stock ON consumo_insumos;

CREATE TRIGGER trigger_descontar_stock
    AFTER INSERT ON consumo_insumos
    FOR EACH ROW
    EXECUTE FUNCTION actualizar_stock_insumos();

COMMENT ON TRIGGER trigger_descontar_stock ON consumo_insumos IS
    'Disparador automático que descuenta inventario tras cada inserción en consumo_insumos.';


-- -----------------------------------------------------------------------------
-- NOMBRE   : trigger_auditoria_consumo
-- TABLA    : consumo_insumos
-- EVENTO   : AFTER INSERT
-- FUNCIÓN  : registrar_auditoria_consumo()
-- OBJETIVO : Trazabilidad total de consumos médicos y fiscalización en bitácora.
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION registrar_auditoria_consumo()
RETURNS TRIGGER AS $$
DECLARE
    v_nombre_articulo VARCHAR(150);
    v_numero_lote     VARCHAR(100);
BEGIN
    -- Obtención de datos descriptivos mediante consulta combinada (JOIN)
    SELECT am.nombre_articulo, li.numero_lote
    INTO   v_nombre_articulo, v_numero_lote
    FROM   lotes_insumos li
    JOIN   articulos_medicos am ON am.id_articulo = li.id_articulo
    WHERE  li.id_lote_insumo = NEW.id_lote_insumo;

    -- Registro formal de auditoría en la tabla bitácora
    INSERT INTO bitacora (
        usuario,
        accion,
        tabla,
        detalles,
        created_at,
        updated_at
    )
    VALUES (
        'SISTEMA_TRIGGER',
        'CONSUMO_INSUMO',
        'consumo_insumos',
        FORMAT(
            'Atención ID: %s | Artículo: %s | Lote: %s | Cantidad Consumida: %s unidades',
            NEW.id_atencion,
            v_nombre_articulo,
            v_numero_lote,
            NEW.cantidad_usada
        ),
        NOW(),
        NOW()
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION registrar_auditoria_consumo() IS
    'Registra entradas detalladas en la bitácora del sistema para auditorías de inventario.';

DROP TRIGGER IF EXISTS trigger_auditoria_consumo ON consumo_insumos;

CREATE TRIGGER trigger_auditoria_consumo
    AFTER INSERT ON consumo_insumos
    FOR EACH ROW
    EXECUTE FUNCTION registrar_auditoria_consumo();

COMMENT ON TRIGGER trigger_auditoria_consumo ON consumo_insumos IS
    'Registra en bitácora la traza completa de consumos realizados durante atenciones médicas.';


/*
================================================================================
  SECCIÓN 2: PROCEDIMIENTOS ALMACENADOS (STORED PROCEDURES)
================================================================================
*/

-- -----------------------------------------------------------------------------
-- NOMBRE    : sp_registrar_atencion_medica
-- TIPO      : Procedimiento Almacenado (Transacción Atómica ACID)
-- OBJETIVO  : Registrar en un solo bloque atómico la atención diaria, 
--             los diagnósticos vinculados y los consumos de insumos.
-- -----------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE sp_registrar_atencion_medica(
    IN  p_id_paciente           INTEGER,
    IN  p_fecha_visita          DATE,
    IN  p_semana_epidemio       INTEGER,
    IN  p_diagnostico_general   TEXT,
    IN  p_id_centro             INTEGER,
    IN  p_id_usuario_registra   INTEGER,
    IN  p_id_diagnostico        INTEGER,
    IN  p_observacion_medica    TEXT,
    IN  p_id_lote_insumo        INTEGER,
    IN  p_cantidad_usada        INTEGER,
    OUT p_id_atencion_out       INTEGER
)
LANGUAGE plpgsql AS $$
BEGIN
    -- 1. Inserción de la atención médica principal
    INSERT INTO atenciones_diarias (
        id_paciente,
        fecha_visita,
        semana_epidemiologica,
        diagnostico_general,
        id_centro,
        id_usuario_registra
    )
    VALUES (
        p_id_paciente,
        p_fecha_visita,
        p_semana_epidemio,
        p_diagnostico_general,
        p_id_centro,
        p_id_usuario_registra
    )
    RETURNING id_atencion INTO p_id_atencion_out;

    -- 2. Registro del diagnóstico clínico asociado
    IF p_id_diagnostico IS NOT NULL THEN
        INSERT INTO atencion_diagnosticos (
            id_atencion_diaria,
            id_diagnostico,
            observacion_medica,
            fecha_registro
        )
        VALUES (
            p_id_atencion_out,
            p_id_diagnostico,
            p_observacion_medica,
            p_fecha_visita
        );
    END IF;

    -- 3. Registro del consumo de insumo (Dispara automáticamente trigger_descontar_stock)
    IF p_id_lote_insumo IS NOT NULL
       AND p_cantidad_usada IS NOT NULL
       AND p_cantidad_usada > 0
    THEN
        INSERT INTO consumo_insumos (
            id_atencion,
            id_lote_insumo,
            cantidad_usada
        )
        VALUES (
            p_id_atencion_out,
            p_id_lote_insumo,
            p_cantidad_usada
        );
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Transacción Fallida en sp_registrar_atencion_medica: %', SQLERRM;
END;
$$;

COMMENT ON PROCEDURE sp_registrar_atencion_medica IS
    'Procedimiento atómico para registro de consulta diaria, diagnósticos e insumos consumidos.';


-- -----------------------------------------------------------------------------
-- NOMBRE    : sp_registrar_movimiento_inventario
-- TIPO      : Procedimiento Almacenado (Control de Concurrencia con SELECT FOR UPDATE)
-- OBJETIVO  : Movimientos de inventario (Entrada, Descarte, Devolución) evitando
--             condiciones de carrera entre múltiples usuarios simultáneos.
-- -----------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE sp_registrar_movimiento_inventario(
    IN p_id_lote_insumo    INTEGER,
    IN p_id_centro         INTEGER,
    IN p_tipo_movimiento   VARCHAR(50),
    IN p_cantidad          INTEGER,
    IN p_numero_acta       VARCHAR(100),
    IN p_justificacion     TEXT
)
LANGUAGE plpgsql AS $$
DECLARE
    v_stock_actual INTEGER;
BEGIN
    -- Validar tipos de movimiento aceptados
    IF p_tipo_movimiento NOT IN ('Entrada', 'Descarte', 'Devolución') THEN
        RAISE EXCEPTION 'Tipo de movimiento no válido: %. Opciones: Entrada, Descarte, Devolución.', p_tipo_movimiento;
    END IF;

    -- Validar cantidad positiva
    IF p_cantidad <= 0 THEN
        RAISE EXCEPTION 'La cantidad del movimiento debe ser superior a cero. Valor recibido: %', p_cantidad;
    END IF;

    -- Bloqueo exclusivo de fila (Pessimistic Locking / FOR UPDATE)
    SELECT stock_actual
    INTO   v_stock_actual
    FROM   lotes_insumos
    WHERE  id_lote_insumo = p_id_lote_insumo
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Registro de Lote con ID % no existe en la base de datos.', p_id_lote_insumo;
    END IF;

    -- Ajuste según el tipo de operación
    IF p_tipo_movimiento = 'Descarte' THEN
        UPDATE lotes_insumos
        SET    stock_actual = 0
        WHERE  id_lote_insumo = p_id_lote_insumo;
    ELSE
        UPDATE lotes_insumos
        SET    stock_actual = stock_actual + p_cantidad
        WHERE  id_lote_insumo = p_id_lote_insumo;
    END IF;

    -- Registro en la tabla de trazabilidad de movimientos
    INSERT INTO movimientos_inventario (
        id_lote_insumo,
        id_centro,
        tipo_movimiento,
        cantidad,
        numero_acta_descarte,
        justificacion,
        fecha_movimiento
    )
    VALUES (
        p_id_lote_insumo,
        p_id_centro,
        p_tipo_movimiento,
        p_cantidad,
        p_numero_acta,
        p_justificacion,
        NOW()
    );

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Transacción Fallida en sp_registrar_movimiento_inventario: %', SQLERRM;
END;
$$;

COMMENT ON PROCEDURE sp_registrar_movimiento_inventario IS
    'Gestión segura de movimientos de inventario con control de concurrencia y actas legales.';


/*
================================================================================
  SECCIÓN 3: CONSULTAS DE VERIFICACIÓN (AUDITORÍA EN PGADMIN)
================================================================================
*/

-- 1. Consultar Triggers activos en el esquema público
SELECT 
    trigger_name       AS "Trigger Registrado",
    event_object_table AS "Tabla Asociada",
    event_manipulation AS "Evento SQL",
    action_timing      AS "Momento de Ejecución"
FROM information_schema.triggers
WHERE trigger_schema = 'public'
ORDER BY event_object_table, trigger_name;

-- 2. Consultar Procedimientos Almacenados instalados
SELECT 
    routine_name      AS "Procedimiento Almacenado",
    routine_type      AS "Tipo de Objeto",
    external_language AS "Lenguaje de Programación"
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_type = 'PROCEDURE'
ORDER BY routine_name;

-- 3. Fiscalización de los últimos eventos registrados en Bitácora
SELECT 
    usuario    AS "Usuario Responsable",
    accion     AS "Acción Ejecutada",
    tabla      AS "Tabla Afectada",
    detalles   AS "Detalles de la Operación",
    created_at AS "Fecha y Hora"
FROM bitacora
ORDER BY created_at DESC
LIMIT 15;

/*
================================================================================
  FIN DEL SCRIPT SQL - ASIC GUANIPA / CDI PEDRO URBINA
================================================================================
*/

-- ═══════════════════════════════════════════════════════════════
-- SEED PAI Venezuela — MPPS 2024
-- Vacunas del Programa Ampliado de Inmunizaciones + Esquemas
-- Base de datos: auth_system (CDI Pedro Urbina / ASIC Guanipa)
-- ═══════════════════════════════════════════════════════════════

-- ─── 1. Insertar vacunas PAI faltantes ───────────────────────
-- TOXOIDE (id=1) y FIEBRE AMARILLA (id=2) ya existen
-- Se usa INSERT ... ON CONFLICT DO NOTHING por si se re-ejecuta

-- Corregir nombre de FIEBRE AMARILLA (error tipográfico en BD)
UPDATE articulos_medicos
  SET nombre_articulo = 'FIEBRE AMARILLA'
  WHERE id_articulo = 2 AND nombre_articulo = 'FIEBRE AMARRILLA';

-- Insertar vacunas PAI adicionales
INSERT INTO articulos_medicos (nombre_articulo, tipo, descripcion, unidad_medida, stock_minimo_alerta)
VALUES
  ('BCG',                              'Vacuna', 'Bacilo Calmette-Guérin contra tuberculosis. Recién nacidos al nacer.',                     'Dosis', 10),
  ('PENTAVALENTE (DPT+HB+Hib)',        'Vacuna', 'DPT-Hepatitis B-Haemophilus influenzae tipo b. Lactantes 2-4-6 meses.',                   'Dosis', 20),
  ('ANTIPOLIO ORAL (OPV)',             'Vacuna', 'Vacuna oral contra poliovirus (Sabin). Lactantes 2-4-6 meses y refuerzo 18 meses.',        'Dosis', 20),
  ('ANTIPOLIO INACTIVADA (IPV)',       'Vacuna', 'Poliovirus inactivada (Salk). 2 dosis: 2 y 4 meses.',                                     'Dosis', 10),
  ('ROTAVIRUS',                        'Vacuna', 'Vacuna oral contra rotavirus. 2 dosis: 2 y 4 meses.',                                     'Dosis', 10),
  ('NEUMOCOCO CONJUGADA (PCV13)',      'Vacuna', 'Neumocócica conjugada 13 valente. 2 dosis + refuerzo.',                                   'Dosis', 10),
  ('SRP (SARAMPIÓN-RUBÉOLA-PAPERAS)', 'Vacuna', 'Triple viral. 1ra dosis 12 meses, 2da dosis 15-18 meses.',                                'Dosis', 15),
  ('VARICELA',                         'Vacuna', 'Vacuna contra varicela. 1 dosis a los 12 meses.',                                         'Dosis', 10),
  ('HEPATITIS A',                      'Vacuna', 'Vacuna contra hepatitis A. 2 dosis: 12 y 18 meses.',                                      'Dosis', 10),
  ('HEPATITIS B',                      'Vacuna', 'Vacuna contra hepatitis B. Recién nacidos + completar en adultos.',                        'Dosis', 10),
  ('DPT REFUERZO',                     'Vacuna', 'Difteria-Tos Ferina-Tétanos refuerzo escolar (4-6 años).',                                'Dosis', 10),
  ('INFLUENZA',                        'Vacuna', 'Vacuna trivalente contra influenza estacional. Anual. Niños 6m+, embarazadas, adultos.',   'Dosis', 20)
ON CONFLICT DO NOTHING;

-- ─── 2. Limpiar esquemas anteriores ──────────────────────────
TRUNCATE esquemas_dosificacion RESTART IDENTITY;

-- ─── 3. Insertar esquemas PAI MPPS ───────────────────────────
-- Columnas: id_articulo, numero_dosis, intervalo_dias_previo, edad_minima_meses, edad_maxima_meses

-- BCG
INSERT INTO esquemas_dosificacion (id_articulo, numero_dosis, intervalo_dias_previo, edad_minima_meses, edad_maxima_meses)
  SELECT id_articulo, '1ra Dosis (Recién Nacido)', NULL, 0, 1
  FROM articulos_medicos WHERE nombre_articulo = 'BCG';

-- Hepatitis B
INSERT INTO esquemas_dosificacion (id_articulo, numero_dosis, intervalo_dias_previo, edad_minima_meses, edad_maxima_meses)
  SELECT id_articulo, '1ra Dosis (RN)', NULL, 0, 1
  FROM articulos_medicos WHERE nombre_articulo = 'HEPATITIS B';

INSERT INTO esquemas_dosificacion (id_articulo, numero_dosis, intervalo_dias_previo, edad_minima_meses, edad_maxima_meses)
  SELECT id_articulo, '2da Dosis', 60, 2, 6
  FROM articulos_medicos WHERE nombre_articulo = 'HEPATITIS B';

INSERT INTO esquemas_dosificacion (id_articulo, numero_dosis, intervalo_dias_previo, edad_minima_meses, edad_maxima_meses)
  SELECT id_articulo, '3ra Dosis', 60, 6, 12
  FROM articulos_medicos WHERE nombre_articulo = 'HEPATITIS B';

-- Rotavirus
INSERT INTO esquemas_dosificacion (id_articulo, numero_dosis, intervalo_dias_previo, edad_minima_meses, edad_maxima_meses)
  SELECT id_articulo, '1ra Dosis', NULL, 2, 4
  FROM articulos_medicos WHERE nombre_articulo = 'ROTAVIRUS';

INSERT INTO esquemas_dosificacion (id_articulo, numero_dosis, intervalo_dias_previo, edad_minima_meses, edad_maxima_meses)
  SELECT id_articulo, '2da Dosis', 60, 4, 6
  FROM articulos_medicos WHERE nombre_articulo = 'ROTAVIRUS';

-- Pentavalente
INSERT INTO esquemas_dosificacion (id_articulo, numero_dosis, intervalo_dias_previo, edad_minima_meses, edad_maxima_meses)
  SELECT id_articulo, '1ra Dosis', NULL, 2, 4
  FROM articulos_medicos WHERE nombre_articulo = 'PENTAVALENTE (DPT+HB+Hib)';

INSERT INTO esquemas_dosificacion (id_articulo, numero_dosis, intervalo_dias_previo, edad_minima_meses, edad_maxima_meses)
  SELECT id_articulo, '2da Dosis', 60, 4, 6
  FROM articulos_medicos WHERE nombre_articulo = 'PENTAVALENTE (DPT+HB+Hib)';

INSERT INTO esquemas_dosificacion (id_articulo, numero_dosis, intervalo_dias_previo, edad_minima_meses, edad_maxima_meses)
  SELECT id_articulo, '3ra Dosis', 60, 6, 12
  FROM articulos_medicos WHERE nombre_articulo = 'PENTAVALENTE (DPT+HB+Hib)';

INSERT INTO esquemas_dosificacion (id_articulo, numero_dosis, intervalo_dias_previo, edad_minima_meses, edad_maxima_meses)
  SELECT id_articulo, 'Refuerzo 1', 365, 18, 24
  FROM articulos_medicos WHERE nombre_articulo = 'PENTAVALENTE (DPT+HB+Hib)';

-- OPV (Antipolio oral)
INSERT INTO esquemas_dosificacion (id_articulo, numero_dosis, intervalo_dias_previo, edad_minima_meses, edad_maxima_meses)
  SELECT id_articulo, '1ra Dosis', NULL, 2, 4
  FROM articulos_medicos WHERE nombre_articulo = 'ANTIPOLIO ORAL (OPV)';

INSERT INTO esquemas_dosificacion (id_articulo, numero_dosis, intervalo_dias_previo, edad_minima_meses, edad_maxima_meses)
  SELECT id_articulo, '2da Dosis', 60, 4, 6
  FROM articulos_medicos WHERE nombre_articulo = 'ANTIPOLIO ORAL (OPV)';

INSERT INTO esquemas_dosificacion (id_articulo, numero_dosis, intervalo_dias_previo, edad_minima_meses, edad_maxima_meses)
  SELECT id_articulo, '3ra Dosis', 60, 6, 12
  FROM articulos_medicos WHERE nombre_articulo = 'ANTIPOLIO ORAL (OPV)';

INSERT INTO esquemas_dosificacion (id_articulo, numero_dosis, intervalo_dias_previo, edad_minima_meses, edad_maxima_meses)
  SELECT id_articulo, 'Refuerzo 1', 180, 18, 24
  FROM articulos_medicos WHERE nombre_articulo = 'ANTIPOLIO ORAL (OPV)';

-- IPV (Antipolio inactivada)
INSERT INTO esquemas_dosificacion (id_articulo, numero_dosis, intervalo_dias_previo, edad_minima_meses, edad_maxima_meses)
  SELECT id_articulo, '1ra Dosis', NULL, 2, 4
  FROM articulos_medicos WHERE nombre_articulo = 'ANTIPOLIO INACTIVADA (IPV)';

INSERT INTO esquemas_dosificacion (id_articulo, numero_dosis, intervalo_dias_previo, edad_minima_meses, edad_maxima_meses)
  SELECT id_articulo, '2da Dosis', 60, 4, 6
  FROM articulos_medicos WHERE nombre_articulo = 'ANTIPOLIO INACTIVADA (IPV)';

-- Neumococo PCV13
INSERT INTO esquemas_dosificacion (id_articulo, numero_dosis, intervalo_dias_previo, edad_minima_meses, edad_maxima_meses)
  SELECT id_articulo, '1ra Dosis', NULL, 2, 4
  FROM articulos_medicos WHERE nombre_articulo = 'NEUMOCOCO CONJUGADA (PCV13)';

INSERT INTO esquemas_dosificacion (id_articulo, numero_dosis, intervalo_dias_previo, edad_minima_meses, edad_maxima_meses)
  SELECT id_articulo, '2da Dosis', 60, 4, 6
  FROM articulos_medicos WHERE nombre_articulo = 'NEUMOCOCO CONJUGADA (PCV13)';

INSERT INTO esquemas_dosificacion (id_articulo, numero_dosis, intervalo_dias_previo, edad_minima_meses, edad_maxima_meses)
  SELECT id_articulo, 'Refuerzo 1', 180, 12, 18
  FROM articulos_medicos WHERE nombre_articulo = 'NEUMOCOCO CONJUGADA (PCV13)';

-- SRP (Triple viral)
INSERT INTO esquemas_dosificacion (id_articulo, numero_dosis, intervalo_dias_previo, edad_minima_meses, edad_maxima_meses)
  SELECT id_articulo, '1ra Dosis', NULL, 12, 18
  FROM articulos_medicos WHERE nombre_articulo = 'SRP (SARAMPIÓN-RUBÉOLA-PAPERAS)';

INSERT INTO esquemas_dosificacion (id_articulo, numero_dosis, intervalo_dias_previo, edad_minima_meses, edad_maxima_meses)
  SELECT id_articulo, '2da Dosis', 90, 15, 60
  FROM articulos_medicos WHERE nombre_articulo = 'SRP (SARAMPIÓN-RUBÉOLA-PAPERAS)';

-- Varicela
INSERT INTO esquemas_dosificacion (id_articulo, numero_dosis, intervalo_dias_previo, edad_minima_meses, edad_maxima_meses)
  SELECT id_articulo, '1ra Dosis', NULL, 12, 24
  FROM articulos_medicos WHERE nombre_articulo = 'VARICELA';

INSERT INTO esquemas_dosificacion (id_articulo, numero_dosis, intervalo_dias_previo, edad_minima_meses, edad_maxima_meses)
  SELECT id_articulo, '2da Dosis', 90, 24, 60
  FROM articulos_medicos WHERE nombre_articulo = 'VARICELA';

-- Hepatitis A
INSERT INTO esquemas_dosificacion (id_articulo, numero_dosis, intervalo_dias_previo, edad_minima_meses, edad_maxima_meses)
  SELECT id_articulo, '1ra Dosis', NULL, 12, 18
  FROM articulos_medicos WHERE nombre_articulo = 'HEPATITIS A';

INSERT INTO esquemas_dosificacion (id_articulo, numero_dosis, intervalo_dias_previo, edad_minima_meses, edad_maxima_meses)
  SELECT id_articulo, '2da Dosis', 180, 18, NULL
  FROM articulos_medicos WHERE nombre_articulo = 'HEPATITIS A';

-- Influenza (anual)
INSERT INTO esquemas_dosificacion (id_articulo, numero_dosis, intervalo_dias_previo, edad_minima_meses, edad_maxima_meses)
  SELECT id_articulo, '1ra Dosis (< 9 años sin vacuna previa)', NULL, 6, 108
  FROM articulos_medicos WHERE nombre_articulo = 'INFLUENZA';

INSERT INTO esquemas_dosificacion (id_articulo, numero_dosis, intervalo_dias_previo, edad_minima_meses, edad_maxima_meses)
  SELECT id_articulo, '2da Dosis (< 9 años sin vacuna previa)', 30, 6, 108
  FROM articulos_medicos WHERE nombre_articulo = 'INFLUENZA';

INSERT INTO esquemas_dosificacion (id_articulo, numero_dosis, intervalo_dias_previo, edad_minima_meses, edad_maxima_meses)
  SELECT id_articulo, 'Refuerzo Anual', 365, 6, NULL
  FROM articulos_medicos WHERE nombre_articulo = 'INFLUENZA';

-- Fiebre Amarilla
INSERT INTO esquemas_dosificacion (id_articulo, numero_dosis, intervalo_dias_previo, edad_minima_meses, edad_maxima_meses)
  SELECT id_articulo, 'Única', NULL, 12, NULL
  FROM articulos_medicos WHERE nombre_articulo = 'FIEBRE AMARILLA';

-- Toxoide TD (embarazadas y adultos)
INSERT INTO esquemas_dosificacion (id_articulo, numero_dosis, intervalo_dias_previo, edad_minima_meses, edad_maxima_meses)
  SELECT id_articulo, '1ra Dosis', NULL, 0, NULL
  FROM articulos_medicos WHERE nombre_articulo = 'TOXOIDE';

INSERT INTO esquemas_dosificacion (id_articulo, numero_dosis, intervalo_dias_previo, edad_minima_meses, edad_maxima_meses)
  SELECT id_articulo, '2da Dosis', 60, 0, NULL
  FROM articulos_medicos WHERE nombre_articulo = 'TOXOIDE';

INSERT INTO esquemas_dosificacion (id_articulo, numero_dosis, intervalo_dias_previo, edad_minima_meses, edad_maxima_meses)
  SELECT id_articulo, '3ra Dosis', 180, 0, NULL
  FROM articulos_medicos WHERE nombre_articulo = 'TOXOIDE';

INSERT INTO esquemas_dosificacion (id_articulo, numero_dosis, intervalo_dias_previo, edad_minima_meses, edad_maxima_meses)
  SELECT id_articulo, 'Refuerzo 1 (cada 10 años)', 3650, 0, NULL
  FROM articulos_medicos WHERE nombre_articulo = 'TOXOIDE';

INSERT INTO esquemas_dosificacion (id_articulo, numero_dosis, intervalo_dias_previo, edad_minima_meses, edad_maxima_meses)
  SELECT id_articulo, 'Refuerzo 2 (cada 10 años)', 3650, 0, NULL
  FROM articulos_medicos WHERE nombre_articulo = 'TOXOIDE';

-- DPT Refuerzo escolar
INSERT INTO esquemas_dosificacion (id_articulo, numero_dosis, intervalo_dias_previo, edad_minima_meses, edad_maxima_meses)
  SELECT id_articulo, 'Refuerzo 1 (Escolar 4-6 años)', NULL, 48, 72
  FROM articulos_medicos WHERE nombre_articulo = 'DPT REFUERZO';

INSERT INTO esquemas_dosificacion (id_articulo, numero_dosis, intervalo_dias_previo, edad_minima_meses, edad_maxima_meses)
  SELECT id_articulo, 'Refuerzo 2 (Preescolar 6-8 años)', 365, 72, 96
  FROM articulos_medicos WHERE nombre_articulo = 'DPT REFUERZO';

-- ─── 4. Verificación final ────────────────────────────────────
SELECT
  a.nombre_articulo AS vacuna,
  e.numero_dosis AS dosis,
  e.intervalo_dias_previo AS intervalo_dias,
  e.edad_minima_meses AS edad_min_m,
  e.edad_maxima_meses AS edad_max_m
FROM esquemas_dosificacion e
JOIN articulos_medicos a ON a.id_articulo = e.id_articulo
ORDER BY a.nombre_articulo, e.id_esquema;

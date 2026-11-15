'use strict';

/**
 * Seeder Oficial PAI Venezuela (MPPS)
 * Inserta las 14 vacunas reglamentarias y sus 36 reglas de dosificación/esquemas.
 */

const VACUNAS = [
  { nombre_articulo: 'BCG', tipo: 'Vacuna', descripcion: 'Bacilo Calmette-Guérin contra tuberculosis. Recién nacidos al nacer.', unidad_medida: 'Dosis', stock_minimo_alerta: 10 },
  { nombre_articulo: 'PENTAVALENTE (DPT+HB+Hib)', tipo: 'Vacuna', descripcion: 'DPT-Hepatitis B-Haemophilus influenzae tipo b. Lactantes 2-4-6 meses.', unidad_medida: 'Dosis', stock_minimo_alerta: 20 },
  { nombre_articulo: 'ANTIPOLIO ORAL (OPV)', tipo: 'Vacuna', descripcion: 'Vacuna oral contra poliovirus (Sabin). Lactantes 2-4-6 meses y refuerzo 18 meses.', unidad_medida: 'Dosis', stock_minimo_alerta: 20 },
  { nombre_articulo: 'ANTIPOLIO INACTIVADA (IPV)', tipo: 'Vacuna', descripcion: 'Poliovirus inactivada (Salk). 2 dosis: 2 y 4 meses.', unidad_medida: 'Dosis', stock_minimo_alerta: 10 },
  { nombre_articulo: 'ROTAVIRUS', tipo: 'Vacuna', descripcion: 'Vacuna oral contra rotavirus. 2 dosis: 2 y 4 meses.', unidad_medida: 'Dosis', stock_minimo_alerta: 10 },
  { nombre_articulo: 'NEUMOCOCO CONJUGADA (PCV13)', tipo: 'Vacuna', descripcion: 'Neumocócica conjugada 13 valente. 2 dosis + refuerzo.', unidad_medida: 'Dosis', stock_minimo_alerta: 10 },
  { nombre_articulo: 'SRP (SARAMPIÓN-RUBÉOLA-PAPERAS)', tipo: 'Vacuna', descripcion: 'Triple viral. 1ra dosis 12 meses, 2da dosis 15-18 meses.', unidad_medida: 'Dosis', stock_minimo_alerta: 15 },
  { nombre_articulo: 'VARICELA', tipo: 'Vacuna', descripcion: 'Vacuna contra varicela. 1 dosis a los 12 meses.', unidad_medida: 'Dosis', stock_minimo_alerta: 10 },
  { nombre_articulo: 'HEPATITIS A', tipo: 'Vacuna', descripcion: 'Vacuna contra hepatitis A. 2 dosis: 12 y 18 meses.', unidad_medida: 'Dosis', stock_minimo_alerta: 10 },
  { nombre_articulo: 'HEPATITIS B', tipo: 'Vacuna', descripcion: 'Vacuna contra hepatitis B. Recién nacidos + completar en adultos.', unidad_medida: 'Dosis', stock_minimo_alerta: 10 },
  { nombre_articulo: 'DPT REFUERZO', tipo: 'Vacuna', descripcion: 'Difteria-Tos Ferina-Tétanos refuerzo escolar (4-6 años).', unidad_medida: 'Dosis', stock_minimo_alerta: 10 },
  { nombre_articulo: 'INFLUENZA', tipo: 'Vacuna', descripcion: 'Vacuna trivalente contra influenza estacional. Anual.', unidad_medida: 'Dosis', stock_minimo_alerta: 20 },
  { nombre_articulo: 'FIEBRE AMARILLA', tipo: 'Vacuna', descripcion: 'Vacuna contra fiebre amarilla (cepa 17D). Dosis única.', unidad_medida: 'Dosis', stock_minimo_alerta: 10 },
  { nombre_articulo: 'TOXOIDE', tipo: 'Vacuna', descripcion: 'Toxoide tetánico diftérico (adultos/embarazadas).', unidad_medida: 'Dosis', stock_minimo_alerta: 15 }
];

const ESQUEMAS = [
  // BCG
  { vacuna: 'BCG', numero_dosis: 'Dosis Única (Al nacer / Recién nacido/a)', intervalo: null, min: 0, max: 1 },
  // Hepatitis B
  { vacuna: 'HEPATITIS B', numero_dosis: '1ra Dosis (Al nacer / Recién nacido/a)', intervalo: null, min: 0, max: 1 },
  { vacuna: 'HEPATITIS B', numero_dosis: '2da Dosis', intervalo: 60, min: 2, max: 6 },
  { vacuna: 'HEPATITIS B', numero_dosis: '3ra Dosis', intervalo: 60, min: 6, max: 12 },
  // Rotavirus
  { vacuna: 'ROTAVIRUS', numero_dosis: '1ra Dosis', intervalo: null, min: 2, max: 4 },
  { vacuna: 'ROTAVIRUS', numero_dosis: '2da Dosis', intervalo: 60, min: 4, max: 6 },
  // Pentavalente
  { vacuna: 'PENTAVALENTE (DPT+HB+Hib)', numero_dosis: '1ra Dosis', intervalo: null, min: 2, max: 4 },
  { vacuna: 'PENTAVALENTE (DPT+HB+Hib)', numero_dosis: '2da Dosis', intervalo: 60, min: 4, max: 6 },
  { vacuna: 'PENTAVALENTE (DPT+HB+Hib)', numero_dosis: '3ra Dosis', intervalo: 60, min: 6, max: 12 },
  { vacuna: 'PENTAVALENTE (DPT+HB+Hib)', numero_dosis: 'Refuerzo 1', intervalo: 180, min: 18, max: 24 },
  // Polio Oral
  { vacuna: 'ANTIPOLIO ORAL (OPV)', numero_dosis: '1ra Dosis', intervalo: null, min: 2, max: 4 },
  { vacuna: 'ANTIPOLIO ORAL (OPV)', numero_dosis: '2da Dosis', intervalo: 60, min: 4, max: 6 },
  { vacuna: 'ANTIPOLIO ORAL (OPV)', numero_dosis: '3ra Dosis', intervalo: 60, min: 6, max: 12 },
  { vacuna: 'ANTIPOLIO ORAL (OPV)', numero_dosis: 'Refuerzo 1', intervalo: 180, min: 18, max: 24 },
  // Polio Inactivada
  { vacuna: 'ANTIPOLIO INACTIVADA (IPV)', numero_dosis: '1ra Dosis', intervalo: null, min: 2, max: 4 },
  { vacuna: 'ANTIPOLIO INACTIVADA (IPV)', numero_dosis: '2da Dosis', intervalo: 60, min: 4, max: 6 },
  // Neumococo
  { vacuna: 'NEUMOCOCO CONJUGADA (PCV13)', numero_dosis: '1ra Dosis', intervalo: null, min: 2, max: 4 },
  { vacuna: 'NEUMOCOCO CONJUGADA (PCV13)', numero_dosis: '2da Dosis', intervalo: 60, min: 4, max: 6 },
  { vacuna: 'NEUMOCOCO CONJUGADA (PCV13)', numero_dosis: 'Refuerzo 1', intervalo: 180, min: 12, max: 18 },
  // SRP
  { vacuna: 'SRP (SARAMPIÓN-RUBÉOLA-PAPERAS)', numero_dosis: '1ra Dosis', intervalo: null, min: 12, max: 18 },
  { vacuna: 'SRP (SARAMPIÓN-RUBÉOLA-PAPERAS)', numero_dosis: '2da Dosis', intervalo: 90, min: 15, max: 60 },
  // Varicela
  { vacuna: 'VARICELA', numero_dosis: '1ra Dosis', intervalo: null, min: 12, max: 24 },
  { vacuna: 'VARICELA', numero_dosis: '2da Dosis', intervalo: 90, min: 24, max: 60 },
  // Hepatitis A
  { vacuna: 'HEPATITIS A', numero_dosis: '1ra Dosis', intervalo: null, min: 12, max: 18 },
  { vacuna: 'HEPATITIS A', numero_dosis: '2da Dosis', intervalo: 180, min: 18, max: null },
  // Influenza
  { vacuna: 'INFLUENZA', numero_dosis: '1ra Dosis (< 9 años sin vacuna previa)', intervalo: null, min: 6, max: 108 },
  { vacuna: 'INFLUENZA', numero_dosis: '2da Dosis (< 9 años sin vacuna previa)', intervalo: 30, min: 6, max: 108 },
  { vacuna: 'INFLUENZA', numero_dosis: 'Refuerzo Anual', intervalo: 365, min: 6, max: null },
  // Fiebre Amarilla
  { vacuna: 'FIEBRE AMARILLA', numero_dosis: 'Dosis Única', intervalo: null, min: 12, max: null },
  // Toxoide
  { vacuna: 'TOXOIDE', numero_dosis: '1ra Dosis', intervalo: null, min: 0, max: null },
  { vacuna: 'TOXOIDE', numero_dosis: '2da Dosis', intervalo: 30, min: 0, max: null },
  { vacuna: 'TOXOIDE', numero_dosis: '3ra Dosis', intervalo: 180, min: 0, max: null },
  { vacuna: 'TOXOIDE', numero_dosis: 'Refuerzo 1 (Cada 10 años)', intervalo: 3650, min: 0, max: null },
  { vacuna: 'TOXOIDE', numero_dosis: 'Refuerzo 2 (Cada 10 años)', intervalo: 3650, min: 0, max: null },
  // DPT Refuerzo
  { vacuna: 'DPT REFUERZO', numero_dosis: 'Refuerzo 1 (Escolar 4-6 años)', intervalo: null, min: 48, max: 72 },
  { vacuna: 'DPT REFUERZO', numero_dosis: 'Refuerzo 2 (Preescolar 6-8 años)', intervalo: 365, min: 72, max: 96 }
];

module.exports = {
  async up(queryInterface, Sequelize) {
    // 1. Asegurar vacunas en articulos_medicos
    for (const v of VACUNAS) {
      await queryInterface.sequelize.query(`
        INSERT INTO articulos_medicos (nombre_articulo, tipo, descripcion, unidad_medida, stock_minimo_alerta)
        SELECT :nombre, :tipo, :desc, :unidad, :stock
        WHERE NOT EXISTS (
          SELECT 1 FROM articulos_medicos WHERE nombre_articulo = :nombre
        );
      `, {
        replacements: {
          nombre: v.nombre_articulo,
          tipo: v.tipo,
          desc: v.descripcion,
          unidad: v.unidad_medida,
          stock: v.stock_minimo_alerta
        }
      });
    }

    // 2. Insertar esquemas si no existen
    for (const esq of ESQUEMAS) {
      await queryInterface.sequelize.query(`
        INSERT INTO esquemas_dosificacion (id_articulo, numero_dosis, intervalo_dias_previo, edad_minima_meses, edad_maxima_meses)
        SELECT a.id_articulo, :dosis, :intervalo, :min, :max
        FROM articulos_medicos a
        WHERE a.nombre_articulo = :vacuna
          AND NOT EXISTS (
            SELECT 1 FROM esquemas_dosificacion ed 
            WHERE ed.id_articulo = a.id_articulo AND ed.numero_dosis = :dosis
          );
      `, {
        replacements: {
          vacuna: esq.vacuna,
          dosis: esq.numero_dosis,
          intervalo: esq.intervalo,
          min: esq.min,
          max: esq.max
        }
      });
    }
  },

  async down(queryInterface, Sequelize) {
    // No revertir vacunas para preservar integridad referencial de atenciones
  }
};

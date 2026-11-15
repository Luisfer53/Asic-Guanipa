'use strict';
/**
 * seed_pai.js  —  Siembra vacunas PAI Venezuela + esquemas de dosificación MPPS
 * Ejecutar: node scripts/seed_pai.js
 */
const db = require('../src/models');
const { ArticuloMedico, EsquemaDosificacion, sequelize } = db;

// ─────────────────────────────────────────────────────────────────────────────
// Vacunas PAI Venezuela (MPPS 2024) con tipo 'Vacuna'
// Ajustamos los que ya existen y agregamos los faltantes
// ─────────────────────────────────────────────────────────────────────────────
const VACUNAS_PAI = [
  // nombre_articulo, descripcion, unidad
  { nombre: 'TOXOIDE TETÁNICO Y DIFTÉRICO (TD)', descripcion: 'Vacuna contra tétanos y difteria. Uso en embarazadas y adultos.', unidad: 'Dosis' },
  { nombre: 'FIEBRE AMARILLA',                   descripcion: 'Vacuna antiamaríllica (viral viva atenuada). Dosis única.', unidad: 'Dosis' },
  { nombre: 'BCG',                               descripcion: 'Bacilo Calmette-Guérin contra tuberculosis. Recién nacidos.', unidad: 'Dosis' },
  { nombre: 'PENTAVALENTE (DPT+HB+Hib)',         descripcion: 'DPT-Hepatitis B-Haemophilus influenzae tipo b. Lactantes.', unidad: 'Dosis' },
  { nombre: 'ANTIPOLIO ORAL (OPV)',              descripcion: 'Vacuna oral contra poliovirus (Sabin). Lactantes y preescolares.', unidad: 'Dosis' },
  { nombre: 'ROTAVIRUS',                         descripcion: 'Vacuna oral contra rotavirus. 2 dosis en lactantes menores.', unidad: 'Dosis' },
  { nombre: 'NEUMOCOCO CONJUGADA (PCV13)',        descripcion: 'Vacuna neumocócica conjugada 13 valente. Lactantes.', unidad: 'Dosis' },
  { nombre: 'INFLUENZA',                         descripcion: 'Vacuna trivalente contra influenza estacional. Anual.', unidad: 'Dosis' },
  { nombre: 'SRP (SARAMPIÓN-RUBÉOLA-PAPERAS)',   descripcion: 'Triple viral. 1ra dosis a los 12 meses, 2da dosis 15-18 meses.', unidad: 'Dosis' },
  { nombre: 'VARICELA',                          descripcion: 'Vacuna contra varicela. 1 dosis a los 12 meses.', unidad: 'Dosis' },
  { nombre: 'HEPATITIS A',                       descripcion: 'Vacuna contra hepatitis A. 2 dosis: 12 y 18 meses.', unidad: 'Dosis' },
  { nombre: 'HEPATITIS B',                       descripcion: 'Vacuna contra hepatitis B. Recién nacidos + completar en adultos.', unidad: 'Dosis' },
  { nombre: 'DPT (REFUERZO)',                    descripcion: 'Difteria-Tos Ferina-Tétanos refuerzo escolar.', unidad: 'Dosis' },
  { nombre: 'ANTIPOLIO INACTIVADA (IPV)',        descripcion: 'Poliovirus inactivada (Salk). Complemento esquema OPV.', unidad: 'Dosis' },
];

// ─────────────────────────────────────────────────────────────────────────────
// Esquemas de dosificación PAI MPPS Venezuela
// id_articulo se resuelve dinámicamente por nombre
// ─────────────────────────────────────────────────────────────────────────────
// Formato: { vacuna: <coincide nombre>, dosis: <label>, intervalo_dias: <null|n>, edad_min_m, edad_max_m }
const ESQUEMAS_PAI = [
  // BCG
  { vacuna: 'BCG', dosis: 'Única', intervalo: null, edadMin: 0, edadMax: 1 },

  // Hepatitis B (recién nacido)
  { vacuna: 'HEPATITIS B', dosis: '1ra Dosis (RN)', intervalo: null, edadMin: 0, edadMax: 1 },
  { vacuna: 'HEPATITIS B', dosis: '2da Dosis',       intervalo: 60,   edadMin: 2, edadMax: 6 },
  { vacuna: 'HEPATITIS B', dosis: '3ra Dosis',       intervalo: 60,   edadMin: 6, edadMax: 12 },

  // Rotavirus
  { vacuna: 'ROTAVIRUS', dosis: '1ra Dosis', intervalo: null, edadMin: 2, edadMax: 4 },
  { vacuna: 'ROTAVIRUS', dosis: '2da Dosis', intervalo: 60,   edadMin: 4, edadMax: 6 },

  // Pentavalente (DPT+HB+Hib)
  { vacuna: 'PENTAVALENTE', dosis: '1ra Dosis', intervalo: null, edadMin: 2,  edadMax: 4 },
  { vacuna: 'PENTAVALENTE', dosis: '2da Dosis', intervalo: 60,   edadMin: 4,  edadMax: 6 },
  { vacuna: 'PENTAVALENTE', dosis: '3ra Dosis', intervalo: 60,   edadMin: 6,  edadMax: 12 },
  { vacuna: 'PENTAVALENTE', dosis: 'Refuerzo 1', intervalo: 365, edadMin: 18, edadMax: 24 },

  // OPV
  { vacuna: 'ANTIPOLIO ORAL', dosis: '1ra Dosis',  intervalo: null, edadMin: 2,  edadMax: 4 },
  { vacuna: 'ANTIPOLIO ORAL', dosis: '2da Dosis',  intervalo: 60,   edadMin: 4,  edadMax: 6 },
  { vacuna: 'ANTIPOLIO ORAL', dosis: '3ra Dosis',  intervalo: 60,   edadMin: 6,  edadMax: 12 },
  { vacuna: 'ANTIPOLIO ORAL', dosis: 'Refuerzo 1', intervalo: 180,  edadMin: 18, edadMax: 24 },

  // IPV
  { vacuna: 'ANTIPOLIO INACTIVADA', dosis: '1ra Dosis', intervalo: null, edadMin: 2, edadMax: 4 },
  { vacuna: 'ANTIPOLIO INACTIVADA', dosis: '2da Dosis', intervalo: 60,   edadMin: 4, edadMax: 6 },

  // Neumococo PCV13
  { vacuna: 'NEUMOCOCO', dosis: '1ra Dosis',  intervalo: null, edadMin: 2,  edadMax: 4 },
  { vacuna: 'NEUMOCOCO', dosis: '2da Dosis',  intervalo: 60,   edadMin: 4,  edadMax: 6 },
  { vacuna: 'NEUMOCOCO', dosis: 'Refuerzo 1', intervalo: 180,  edadMin: 12, edadMax: 18 },

  // SRP
  { vacuna: 'SRP', dosis: '1ra Dosis', intervalo: null, edadMin: 12, edadMax: 18 },
  { vacuna: 'SRP', dosis: '2da Dosis', intervalo: 90,   edadMin: 15, edadMax: 60 },

  // Varicela
  { vacuna: 'VARICELA', dosis: '1ra Dosis', intervalo: null, edadMin: 12, edadMax: 24 },
  { vacuna: 'VARICELA', dosis: '2da Dosis', intervalo: 90,   edadMin: 24, edadMax: 60 },

  // Hepatitis A
  { vacuna: 'HEPATITIS A', dosis: '1ra Dosis', intervalo: null, edadMin: 12, edadMax: 18 },
  { vacuna: 'HEPATITIS A', dosis: '2da Dosis', intervalo: 180,  edadMin: 18, edadMax: 60 },

  // Influenza (anual)
  { vacuna: 'INFLUENZA', dosis: '1ra Dosis',     intervalo: null, edadMin: 6,  edadMax: 12 },
  { vacuna: 'INFLUENZA', dosis: '2da Dosis',     intervalo: 30,   edadMin: 6,  edadMax: 12 },
  { vacuna: 'INFLUENZA', dosis: 'Refuerzo Anual', intervalo: 365, edadMin: 12, edadMax: 999 },

  // Fiebre Amarilla
  { vacuna: 'FIEBRE AMARILLA', dosis: 'Única', intervalo: null, edadMin: 12, edadMax: 999 },

  // Toxoide TD (embarazadas y adultos)
  { vacuna: 'TOXOIDE', dosis: '1ra Dosis',  intervalo: null, edadMin: 0, edadMax: 999 },
  { vacuna: 'TOXOIDE', dosis: '2da Dosis',  intervalo: 60,   edadMin: 0, edadMax: 999 },
  { vacuna: 'TOXOIDE', dosis: '3ra Dosis',  intervalo: 180,  edadMin: 0, edadMax: 999 },
  { vacuna: 'TOXOIDE', dosis: 'Refuerzo 1', intervalo: 365,  edadMin: 0, edadMax: 999 },
  { vacuna: 'TOXOIDE', dosis: 'Refuerzo 2', intervalo: 365,  edadMin: 0, edadMax: 999 },

  // DPT Refuerzo escolar
  { vacuna: 'DPT', dosis: 'Refuerzo 1 (Escolar)',   intervalo: null, edadMin: 48, edadMax: 72 },
  { vacuna: 'DPT', dosis: 'Refuerzo 2 (Preescolar)', intervalo: 365, edadMin: 72, edadMax: 96 },
];

async function main() {
  try {
    console.log('═══ SEED PAI VENEZUELA ═══\n');

    // 1. Cargar artículos existentes
    const articulosExistentes = await ArticuloMedico.findAll({
      where: { tipo: 'Vacuna' },
      attributes: ['id_articulo', 'nombre_articulo'],
    });
    const mapaNombres = {}; // nombre_upper → id
    articulosExistentes.forEach(a => {
      mapaNombres[a.nombre_articulo.toUpperCase()] = a.id_articulo;
    });
    console.log('Vacunas en BD antes del seed:', JSON.stringify(mapaNombres));

    // 2. Agregar vacunas PAI faltantes
    for (const v of VACUNAS_PAI) {
      const nombreUpper = v.nombre.toUpperCase();
      // Busca coincidencia parcial para no duplicar TOXOIDE vs TOXOIDE TETÁNICO
      const yaExiste = Object.keys(mapaNombres).find(k =>
        k.includes(nombreUpper.split('(')[0].trim()) ||
        nombreUpper.split('(')[0].trim().includes(k.split('(')[0].trim())
      );
      if (!yaExiste) {
        const nuevo = await ArticuloMedico.create({
          nombre_articulo: nombreUpper,
          tipo: 'Vacuna',
          descripcion: v.descripcion,
          unidad_medida: v.unidad,
          stock_minimo_alerta: 10,
        });
        mapaNombres[nombreUpper] = nuevo.id_articulo;
        console.log(`  ✅ Vacuna creada: ${nombreUpper} (id=${nuevo.id_articulo})`);
      } else {
        console.log(`  ⏭  Vacuna ya existe: ${yaExiste}`);
      }
    }

    // 3. Limpiar esquemas anteriores (si hay)
    const count = await EsquemaDosificacion.count();
    if (count > 0) {
      await EsquemaDosificacion.destroy({ where: {}, truncate: false });
      console.log(`\n🗑  ${count} esquemas anteriores eliminados.`);
    }

    // 4. Insertar esquemas PAI
    console.log('\n📋 Insertando esquemas de dosificación PAI...');
    let creados = 0, omitidos = 0;

    for (const e of ESQUEMAS_PAI) {
      // Resolver id_articulo por coincidencia parcial de nombre
      const keyword = e.vacuna.toUpperCase();
      const idArticulo = Object.entries(mapaNombres).find(([k]) =>
        k.includes(keyword) || keyword.includes(k.split(' ')[0])
      )?.[1];

      if (!idArticulo) {
        console.log(`  ⚠️  Sin vacuna para: "${e.vacuna}" — esquema omitido.`);
        omitidos++;
        continue;
      }

      await EsquemaDosificacion.create({
        id_articulo: idArticulo,
        numero_dosis: e.dosis,
        intervalo_dias_previo: e.intervalo ?? null,
        edad_minima_meses: e.edadMin ?? null,
        edad_maxima_meses: e.edadMax !== 999 ? e.edadMax : null,
      });
      creados++;
    }

    console.log(`\n✅ Seed completado: ${creados} esquemas insertados, ${omitidos} omitidos.`);

    // 5. Verificar
    const total = await EsquemaDosificacion.count();
    console.log(`📊 Total en esquemas_dosificacion: ${total}`);

  } catch (err) {
    console.error('❌ Error en seed PAI:', err.message);
    process.exit(1);
  } finally {
    await sequelize.close();
  }
}

main();

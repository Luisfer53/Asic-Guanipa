'use strict';
const db = require('../src/models');
const { ArticuloMedico, EsquemaDosificacion, sequelize } = db;

async function fix() {
  try {
    // 1. Restaurar nombres exactos de articulos por id
    const articulosExactos = [
      { id: 1,  nombre: 'TOXOIDE', descripcion: 'Vacuna contra tétanos y difteria. Uso en embarazadas y adultos.' },
      { id: 2,  nombre: 'FIEBRE AMARILLA', descripcion: 'Vacuna antiamarílica (viral viva atenuada). Dosis única.' },
      { id: 5,  nombre: 'BCG', descripcion: 'Bacilo Calmette-Guérin contra tuberculosis. Al nacer (Recién nacido/a).' },
      { id: 6,  nombre: 'PENTAVALENTE (DPT+HB+Hib)', descripcion: 'DPT-Hepatitis B-Haemophilus influenzae tipo b. Lactantes 2, 4, 6 meses y refuerzo 18 meses.' },
      { id: 7,  nombre: 'ANTIPOLIO ORAL (OPV)', descripcion: 'Vacuna oral contra poliovirus (Sabin). Lactantes 2, 4, 6 meses y refuerzo 18 meses.' },
      { id: 8,  nombre: 'ANTIPOLIO INACTIVADA (IPV)', descripcion: 'Poliovirus inactivada (Salk). 2 dosis: 2 y 4 meses.' },
      { id: 9,  nombre: 'ROTAVIRUS', descripcion: 'Vacuna oral contra rotavirus. 2 dosis: 2 y 4 meses.' },
      { id: 10, nombre: 'NEUMOCOCO CONJUGADA (PCV13)', descripcion: 'Neumocócica conjugada 13 valente. 2 dosis + refuerzo.' },
      { id: 11, nombre: 'SRP (SARAMPIÓN-RUBÉOLA-PAPERAS)', descripcion: 'Triple viral contra sarampión, rubéola y paperas. 1ra dosis 12 meses, 2da dosis 15-18 meses.' },
      { id: 12, nombre: 'VARICELA', descripcion: 'Vacuna contra varicela. 1ra dosis a los 12 meses.' },
      { id: 13, nombre: 'HEPATITIS A', descripcion: 'Vacuna contra hepatitis A. 2 dosis: 12 y 18 meses.' },
      { id: 14, nombre: 'HEPATITIS B', descripcion: 'Vacuna contra hepatitis B. Al nacer (Recién nacido/a) y completar en adultos.' },
      { id: 15, nombre: 'DPT REFUERZO', descripcion: 'Difteria-Tos Ferina-Tétanos refuerzo escolar (4-6 años).' },
      { id: 16, nombre: 'INFLUENZA', descripcion: 'Vacuna trivalente contra influenza estacional. Anual. Niños 6m+, embarazadas y adultos.' },
    ];

    for (const a of articulosExactos) {
      const art = await ArticuloMedico.findByPk(a.id);
      if (art) {
        await art.update({ nombre_articulo: a.nombre, descripcion: a.descripcion });
        console.log(`Articulo ${a.id} fijado como: ${a.nombre}`);
      }
    }

    // 2. Corregir esquemas por id_esquema directamente
    const esquemasExactos = [
      // BCG (id_articulo: 5)
      { id: 1,  id_art: 5,  dosis: 'Dosis Única (Al nacer / Recién nacido/a)' },

      // Hepatitis B (id_articulo: 14)
      { id: 2,  id_art: 14, dosis: '1ra Dosis (Al nacer / Recién nacido/a)' },
      { id: 3,  id_art: 14, dosis: '2da Dosis' },
      { id: 4,  id_art: 14, dosis: '3ra Dosis' },

      // Rotavirus (id_articulo: 9)
      { id: 5,  id_art: 9,  dosis: '1ra Dosis' },
      { id: 6,  id_art: 9,  dosis: '2da Dosis' },

      // Pentavalente (id_articulo: 6)
      { id: 7,  id_art: 6,  dosis: '1ra Dosis' },
      { id: 8,  id_art: 6,  dosis: '2da Dosis' },
      { id: 9,  id_art: 6,  dosis: '3ra Dosis' },
      { id: 10, id_art: 6,  dosis: 'Refuerzo 1' },

      // OPV (id_articulo: 7)
      { id: 11, id_art: 7,  dosis: '1ra Dosis' },
      { id: 12, id_art: 7,  dosis: '2da Dosis' },
      { id: 13, id_art: 7,  dosis: '3ra Dosis' },
      { id: 14, id_art: 7,  dosis: 'Refuerzo 1' },

      // IPV (id_articulo: 8)
      { id: 15, id_art: 8,  dosis: '1ra Dosis' },
      { id: 16, id_art: 8,  dosis: '2da Dosis' },

      // Neumococo (id_articulo: 10)
      { id: 17, id_art: 10, dosis: '1ra Dosis' },
      { id: 18, id_art: 10, dosis: '2da Dosis' },
      { id: 19, id_art: 10, dosis: 'Refuerzo 1' },

      // SRP (id_articulo: 11)
      { id: 20, id_art: 11, dosis: '1ra Dosis' },
      { id: 21, id_art: 11, dosis: '2da Dosis' },

      // Varicela (id_articulo: 12)
      { id: 22, id_art: 12, dosis: '1ra Dosis' },
      { id: 23, id_art: 12, dosis: '2da Dosis' },

      // Hepatitis A (id_articulo: 13)
      { id: 24, id_art: 13, dosis: '1ra Dosis' },
      { id: 25, id_art: 13, dosis: '2da Dosis' },

      // Influenza (id_articulo: 16)
      { id: 26, id_art: 16, dosis: '1ra Dosis (< 9 años sin vacuna previa)' },
      { id: 27, id_art: 16, dosis: '2da Dosis (< 9 años sin vacuna previa)' },
      { id: 28, id_art: 16, dosis: 'Refuerzo Anual' },

      // Fiebre Amarilla (id_articulo: 2)
      { id: 29, id_art: 2,  dosis: 'Dosis Única' },

      // Toxoide (id_articulo: 1)
      { id: 30, id_art: 1,  dosis: '1ra Dosis' },
      { id: 31, id_art: 1,  dosis: '2da Dosis' },
      { id: 32, id_art: 1,  dosis: '3ra Dosis' },
      { id: 33, id_art: 1,  dosis: 'Refuerzo 1 (Cada 10 años)' },
      { id: 34, id_art: 1,  dosis: 'Refuerzo 2 (Cada 10 años)' },

      // DPT Refuerzo (id_articulo: 15)
      { id: 35, id_art: 15, dosis: 'Refuerzo 1 (Escolar 4-6 años)' },
      { id: 36, id_art: 15, dosis: 'Refuerzo 2 (Preescolar 6-8 años)' },
    ];

    for (const e of esquemasExactos) {
      const esq = await EsquemaDosificacion.findByPk(e.id);
      if (esq) {
        await esq.update({ id_articulo: e.id_art, numero_dosis: e.dosis });
        console.log(`Esquema ${e.id} [art=${e.id_art}] => ${e.dosis}`);
      }
    }

    console.log('\n--- Todo verificado y asignado correctamente ---');
  } catch (err) {
    console.error('Error:', err);
  } finally {
    await sequelize.close();
  }
}

fix();

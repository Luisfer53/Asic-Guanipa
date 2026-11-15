'use strict';
/**
 * fix_pai_texts.js
 * Corrige errores gramaticales y de codificación (mojibake UTF-8)
 * en articulos_medicos y esquemas_dosificacion.
 */
const db = require('../src/models');
const { ArticuloMedico, EsquemaDosificacion, sequelize } = db;

async function run() {
  try {
    console.log('--- Corrigiendo articulos_medicos ---');

    // 1. Corregir nombres y descripciones en articulos_medicos
    const articulosFixes = [
      {
        pattern: /BCG/i,
        nombre: 'BCG',
        descripcion: 'Bacilo Calmette-Guérin contra tuberculosis. Al nacer (Recién nacido/a).',
      },
      {
        pattern: /NEUMOCOCO/i,
        nombre: 'NEUMOCOCO CONJUGADA (PCV13)',
        descripcion: 'Neumocócica conjugada 13 valente. 2 dosis + refuerzo.',
      },
      {
        pattern: /SRP|SARAMPI/i,
        nombre: 'SRP (SARAMPIÓN-RUBÉOLA-PAPERAS)',
        descripcion: 'Triple viral contra sarampión, rubéola y paperas. 1ra dosis 12 meses, 2da dosis 15-18 meses.',
      },
      {
        pattern: /HEPATITIS B/i,
        nombre: 'HEPATITIS B',
        descripcion: 'Vacuna contra hepatitis B. Al nacer (Recién nacido/a) y completar en adultos.',
      },
      {
        pattern: /DPT REFUERZO/i,
        nombre: 'DPT REFUERZO',
        descripcion: 'Difteria-Tos Ferina-Tétanos refuerzo escolar (4-6 años).',
      },
      {
        pattern: /INFLUENZA/i,
        nombre: 'INFLUENZA',
        descripcion: 'Vacuna trivalente contra influenza estacional. Anual. Niños 6m+, embarazadas y adultos.',
      },
      {
        pattern: /FIEBRE AMAR/i,
        nombre: 'FIEBRE AMARILLA',
        descripcion: 'Vacuna antiamarílica (viral viva atenuada). Dosis única a partir de los 12 meses.',
      },
      {
        pattern: /TOXOIDE/i,
        nombre: 'TOXOIDE',
        descripcion: 'Vacuna contra tétanos y difteria. Uso en embarazadas y adultos.',
      },
    ];

    for (const fix of articulosFixes) {
      const art = await ArticuloMedico.findOne({
        where: {
          nombre_articulo: { [db.Sequelize.Op.iLike]: `%${fix.nombre.split(' ')[0]}%` }
        }
      });
      if (art) {
        await art.update({
          nombre_articulo: fix.nombre,
          descripcion: fix.descripcion,
        });
        console.log(`Articulo ${art.id_articulo} actualizado: ${fix.nombre}`);
      }
    }

    console.log('\n--- Corrigiendo esquemas_dosificacion ---');
    // 2. Corregir numero_dosis en esquemas_dosificacion
    const esquemas = await EsquemaDosificacion.findAll({
      include: [{ model: ArticuloMedico, as: 'vacuna' }]
    });

    for (const esq of esquemas) {
      let nuevaDosis = esq.numero_dosis;
      const vacNombre = esq.vacuna ? esq.vacuna.nombre_articulo.toUpperCase() : '';

      // BCG
      if (vacNombre.includes('BCG')) {
        nuevaDosis = 'Dosis Única (Al nacer / Recién nacido/a)';
      }
      // Hepatitis B primera dosis
      else if (vacNombre.includes('HEPATITIS B') && (esq.numero_dosis.includes('1ra') || esq.numero_dosis.includes('RN'))) {
        nuevaDosis = '1ra Dosis (Al nacer / Recién nacido/a)';
      }
      // Fiebre Amarilla
      else if (vacNombre.includes('FIEBRE AMARILLA')) {
        nuevaDosis = 'Dosis Única';
      }
      // Influenza
      else if (vacNombre.includes('INFLUENZA')) {
        if (esq.numero_dosis.includes('1ra')) {
          nuevaDosis = '1ra Dosis (< 9 años sin vacuna previa)';
        } else if (esq.numero_dosis.includes('2da')) {
          nuevaDosis = '2da Dosis (< 9 años sin vacuna previa)';
        } else if (esq.numero_dosis.toLowerCase().includes('refuerzo')) {
          nuevaDosis = 'Refuerzo Anual';
        }
      }
      // Toxoide refuerzos
      else if (vacNombre.includes('TOXOIDE')) {
        if (esq.numero_dosis.includes('Refuerzo 1')) {
          nuevaDosis = 'Refuerzo 1 (Cada 10 años)';
        } else if (esq.numero_dosis.includes('Refuerzo 2')) {
          nuevaDosis = 'Refuerzo 2 (Cada 10 años)';
        }
      }
      // DPT refuerzos
      else if (vacNombre.includes('DPT REFUERZO')) {
        if (esq.numero_dosis.includes('Refuerzo 1')) {
          nuevaDosis = 'Refuerzo 1 (Escolar 4-6 años)';
        } else if (esq.numero_dosis.includes('Refuerzo 2')) {
          nuevaDosis = 'Refuerzo 2 (Preescolar 6-8 años)';
        }
      }
      // Limpieza general de caracteres corruptos en cualquier registro
      nuevaDosis = nuevaDosis
        .replace(/aÃ±os/g, 'años')
        .replace(/aÃ±o/g, 'año')
        .replace(/Ãšnica/g, 'Única')
        .replace(/Ãºnica/g, 'única')
        .replace(/ReciÃ©n Nacido/g, 'Recién nacido/a')
        .replace(/ReciÃ©n/g, 'Recién')
        .replace(/reciÃ©n/g, 'recién');

      if (nuevaDosis !== esq.numero_dosis) {
        await esq.update({ numero_dosis: nuevaDosis });
        console.log(`Esquema ${esq.id_esquema} [${vacNombre}] actualizado: "${nuevaDosis}"`);
      }
    }

    console.log('\n¡Corrección completada exitosamente!');
  } catch (err) {
    console.error('Error:', err);
  } finally {
    await sequelize.close();
  }
}

run();

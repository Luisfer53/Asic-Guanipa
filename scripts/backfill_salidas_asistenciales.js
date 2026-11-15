'use strict';
/**
 * backfill_salidas_asistenciales.js
 * Genera registros de Kárdex ('Salida Asistencial') para las atenciones clínicas
 * previas que consumieron insumos o aplicaron vacunas y no tenían movimiento asociado.
 */
const db = require('../src/models');
const { ConsumoInsumo, MovimientoInventario, AtencionDiaria, Paciente, Persona, LoteInsumo, ArticuloMedico, sequelize } = db;

async function backfill() {
  try {
    const consumos = await ConsumoInsumo.findAll({
      include: [
        {
          model: AtencionDiaria,
          as: 'atencion',
          include: [{ model: Paciente, as: 'paciente', include: [{ model: Persona, as: 'persona' }] }]
        },
        {
          model: LoteInsumo,
          as: 'lote',
          include: [{ model: ArticuloMedico, as: 'articulo' }]
        }
      ]
    });

    console.log(`Encontrados ${consumos.length} consumos clínicos.`);

    let creados = 0;
    for (const c of consumos) {
      if (!c.atencion || !c.lote) continue;

      const persona = c.atencion.paciente?.persona;
      const pacienteNombre = persona ? `${persona.nombre1 || ''} ${persona.apellido1 || ''}`.trim() : 'Paciente asistido';
      const cedulaTxt = persona?.cedula_identidad ? ` (C.I. ${persona.cedula_identidad})` : '';
      const tipoAtencion = c.atencion.tipo_atencion === 'inmunizacion' ? 'Inmunización / PAI' : (c.atencion.tipo_atencion || 'Atención Médica');
      const loteNum = c.lote.numero_lote || 'S/L';

      const justificacion = `Consumo clínico en ${tipoAtencion} — Paciente: ${pacienteNombre}${cedulaTxt} (Lote: ${loteNum})`;

      // Verificar si ya existe un movimiento idéntico para no duplicar
      const existe = await MovimientoInventario.findOne({
        where: {
          id_lote_insumo: c.id_lote_insumo,
          tipo_movimiento: 'Salida Asistencial',
          cantidad: c.cantidad_usada,
          fecha_movimiento: c.atencion.fecha_visita
        }
      });

      if (!existe) {
        await MovimientoInventario.create({
          id_lote_insumo: c.id_lote_insumo,
          id_centro: c.atencion.id_centro || 1,
          tipo_movimiento: 'Salida Asistencial',
          cantidad: c.cantidad_usada,
          justificacion,
          fecha_movimiento: c.atencion.fecha_visita || new Date()
        });
        creados++;
      }
    }

    console.log(`✅ Backfill completado: ${creados} salidas asistenciales agregadas al Kárdex.`);
  } catch (err) {
    console.error('Error en backfill:', err);
  } finally {
    await sequelize.close();
  }
}

backfill();

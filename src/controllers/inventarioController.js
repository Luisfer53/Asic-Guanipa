const db = require('../models');
const { LoteInsumo, ArticuloMedico, MovimientoInventario } = require('../models');
const { Op } = require('sequelize');
const { logAction } = require('../utils/auditLogger');
const fs = require('fs');
const path = require('path');
const QRCode = require('qrcode');
const PDFDocument = require('pdfkit');

// ─────────────────────────────────────────────────────────────────────────────
// ARTÍCULOS MÉDICOS
// ─────────────────────────────────────────────────────────────────────────────

exports.registrarArticulo = async (req, res) => {
    try {
        const { nombre_articulo, descripcion, unidad_medida, stock_minimo_alerta, tipo } = req.body;

        if (!nombre_articulo || !unidad_medida) {
            return res.status(400).json({
                success: false,
                message: 'Nombre del artículo y unidad de medida son obligatorios'
            });
        }

        const existingArticle = await ArticuloMedico.findOne({ where: { nombre_articulo } });
        if (existingArticle) {
            return res.status(400).json({ success: false, message: 'Ya existe un artículo con ese nombre' });
        }

        const nuevoArticulo = await ArticuloMedico.create({
            nombre_articulo,
            tipo: tipo || 'Insumo',
            descripcion: descripcion || null,
            unidad_medida,
            stock_minimo_alerta: stock_minimo_alerta || null
        });

        await logAction(
            req.user ? req.user.username : 'sistema',
            `Registro de artículo médico [${tipo || 'Insumo'}]: ${nombre_articulo}`,
            'articulos_medicos',
            { id: nuevoArticulo.id_articulo, unidad_medida, tipo: tipo || 'Insumo' }
        );

        res.status(201).json({
            success: true,
            message: 'Artículo médico registrado exitosamente',
            data: nuevoArticulo
        });
    } catch (error) {
        console.error('Error al registrar artículo:', error);
        res.status(500).json({
            success: false,
            message: 'Error interno del servidor al registrar el artículo',
            error: process.env.NODE_ENV === 'development' ? error : {}
        });
    }
};

exports.listarArticulos = async (req, res) => {
    try {
        const articulos = await ArticuloMedico.findAll({
            order: [['nombre_articulo', 'ASC']],
            include: [{
                model: db.EsquemaDosificacion,
                as: 'esquemasDosificacion',
                required: false
            }]
        });
        res.status(200).json({ success: true, count: articulos.length, data: articulos });
    } catch (error) {
        console.error('Error al listar artículos:', error);
        res.status(500).json({ success: false, message: 'Error al obtener la lista de artículos', error: process.env.NODE_ENV === 'development' ? error : {} });
    }
};

exports.actualizarArticulo = async (req, res) => {
    try {
        const { id } = req.params;
        const { nombre_articulo, descripcion, unidad_medida, stock_minimo_alerta, tipo } = req.body;

        const articulo = await ArticuloMedico.findByPk(id);
        if (!articulo) {
            return res.status(404).json({ success: false, message: 'Artículo médico no encontrado' });
        }

        await articulo.update({
            nombre_articulo: nombre_articulo || articulo.nombre_articulo,
            tipo: tipo || articulo.tipo,
            descripcion: descripcion !== undefined ? descripcion : articulo.descripcion,
            unidad_medida: unidad_medida || articulo.unidad_medida,
            stock_minimo_alerta: stock_minimo_alerta !== undefined ? stock_minimo_alerta : articulo.stock_minimo_alerta
        });

        await logAction(
            req.user ? req.user.username : 'sistema',
            `Actualización de artículo médico [${articulo.tipo}]: ${articulo.nombre_articulo}`,
            'articulos_medicos',
            { id: articulo.id_articulo, nombre_articulo, unidad_medida, tipo }
        );

        res.status(200).json({ success: true, message: 'Artículo actualizado exitosamente', data: articulo });
    } catch (error) {
        console.error('Error al actualizar artículo:', error);
        res.status(500).json({ success: false, message: 'Error al actualizar artículo', error: error.message });
    }
};

exports.eliminarArticulo = async (req, res) => {
    try {
        const { id } = req.params;
        const articulo = await ArticuloMedico.findByPk(id);
        if (!articulo) {
            return res.status(404).json({ success: false, message: 'Artículo médico no encontrado' });
        }

        await articulo.destroy();

        await logAction(
            req.user ? req.user.username : 'sistema',
            `Eliminación de artículo médico: ${articulo.nombre_articulo}`,
            'articulos_medicos',
            { id }
        );

        res.status(200).json({ success: true, message: 'Artículo eliminado exitosamente' });
    } catch (error) {
        console.error('Error al eliminar artículo:', error);
        res.status(500).json({ success: false, message: 'Error al eliminar artículo (puede estar en uso por lotes o atenciones)', error: error.message });
    }
};


// ─────────────────────────────────────────────────────────────────────────────
// LOTES DE INSUMOS
// ─────────────────────────────────────────────────────────────────────────────

exports.registrarLote = async (req, res) => {
    try {
        const {
            id_articulo, id_proveedor, id_centro,
            numero_lote, stock_actual, fecha_vencimiento
        } = req.body;

        if (!numero_lote || !fecha_vencimiento) {
            return res.status(400).json({
                success: false,
                message: 'Número de lote y fecha de vencimiento son obligatorios.'
            });
        }

        let targetArtId = parseInt(id_articulo);
        let articulo = null;

        if (targetArtId && !isNaN(targetArtId)) {
            articulo = await ArticuloMedico.findByPk(targetArtId);
        }

        if (!articulo) {
            // Intento de fallback: buscar el primer artículo disponible
            articulo = await ArticuloMedico.findOne();
            if (!articulo) {
                return res.status(404).json({ success: false, message: 'No existen artículos médicos registrados. Registre primero una vacuna o artículo.' });
            }
            targetArtId = articulo.id_articulo;
        }

        // Buscar si ya existe un lote con ese número
        let loteExistente = await LoteInsumo.findOne({ where: { numero_lote } });
        if (loteExistente) {
            loteExistente.stock_actual += parseInt(stock_actual || 0);
            loteExistente.fecha_vencimiento = fecha_vencimiento;
            await loteExistente.save();

            return res.status(200).json({
                success: true,
                message: `El lote ${numero_lote} ya existía. Se incrementó el stock actual a ${loteExistente.stock_actual}.`,
                data: loteExistente
            });
        }

        const nuevoLote = await LoteInsumo.create({
            id_articulo: targetArtId,
            id_proveedor: id_proveedor || null,
            id_centro: id_centro || 1,
            numero_lote,
            stock_actual: parseInt(stock_actual || 0),
            fecha_vencimiento
        });

        // Registrar movimiento de entrada
        await MovimientoInventario.create({
            id_lote_insumo: nuevoLote.id_lote_insumo,
            id_centro: id_centro || 1,
            tipo_movimiento: 'Entrada',
            cantidad: parseInt(stock_actual || 0),
            justificacion: 'Registro inicial de lote',
            fecha_movimiento: new Date()
        });

        await logAction(
            req.user ? req.user.username : 'sistema',
            `Registro de lote: ${numero_lote} (Artículo: ${articulo.nombre_articulo})`,
            'lotes_insumos',
            { id: nuevoLote.id_lote_insumo, stock_inicial: stock_actual, fecha_vencimiento }
        );

        const nuevoLoteConArticulo = await LoteInsumo.findByPk(nuevoLote.id_lote_insumo, {
            include: [
                { model: ArticuloMedico, as: 'articulo' },
                { model: db.Proveedor, as: 'proveedor', attributes: ['id_proveedor', 'nombre_proveedor'] },
                { model: db.CentroSalud, as: 'centro', attributes: ['id_centro', 'nombre_centro'] }
            ]
        });

        res.status(201).json({ success: true, message: 'Lote registrado exitosamente', data: nuevoLoteConArticulo });
    } catch (error) {
        console.error('Error al registrar lote:', error);
        res.status(500).json({
            success: false,
            message: 'Error al registrar el lote: ' + error.message,
            error: process.env.NODE_ENV === 'development' ? error : {}
        });
    }
};

exports.actualizarLote = async (req, res) => {
    try {
        const { id } = req.params;
        const {
            id_articulo, id_proveedor, id_centro,
            numero_lote, stock_actual, fecha_vencimiento
        } = req.body;

        const lote = await LoteInsumo.findByPk(id);
        if (!lote) {
            return res.status(404).json({ success: false, message: 'Lote no encontrado' });
        }

        await lote.update({
            id_articulo: id_articulo ? parseInt(id_articulo) : lote.id_articulo,
            id_proveedor: id_proveedor !== undefined ? (id_proveedor ? parseInt(id_proveedor) : null) : lote.id_proveedor,
            id_centro: id_centro !== undefined ? (id_centro ? parseInt(id_centro) : null) : lote.id_centro,
            numero_lote: numero_lote || lote.numero_lote,
            stock_actual: stock_actual !== undefined ? parseInt(stock_actual) : lote.stock_actual,
            fecha_vencimiento: fecha_vencimiento || lote.fecha_vencimiento
        });

        await logAction(
            req.user ? req.user.username : 'sistema',
            `Actualización de lote: ${lote.numero_lote}`,
            'lotes_insumos',
            { id: lote.id_lote_insumo, numero_lote: lote.numero_lote, stock_actual: lote.stock_actual }
        );

        const loteActualizado = await LoteInsumo.findByPk(lote.id_lote_insumo, {
            include: [
                { model: ArticuloMedico, as: 'articulo' },
                { model: db.Proveedor, as: 'proveedor', attributes: ['id_proveedor', 'nombre_proveedor'] },
                { model: db.CentroSalud, as: 'centro', attributes: ['id_centro', 'nombre_centro'] }
            ]
        });

        res.status(200).json({ success: true, message: 'Lote actualizado exitosamente', data: loteActualizado });
    } catch (error) {
        console.error('Error al actualizar lote:', error);
        res.status(500).json({ success: false, message: 'Error al actualizar lote', error: error.message });
    }
};

exports.eliminarLote = async (req, res) => {
    try {
        const { id } = req.params;
        const lote = await LoteInsumo.findByPk(id);
        if (!lote) {
            return res.status(404).json({ success: false, message: 'Lote no encontrado' });
        }

        await lote.destroy();

        await logAction(
            req.user ? req.user.username : 'sistema',
            `Eliminación de lote: ${lote.numero_lote}`,
            'lotes_insumos',
            { id }
        );

        res.status(200).json({ success: true, message: 'Lote eliminado exitosamente' });
    } catch (error) {
        console.error('Error al eliminar lote:', error);
        res.status(500).json({ success: false, message: 'Error al eliminar lote', error: error.message });
    }
};

exports.obtenerInventario = async (req, res) => {
    try {
        const lotes = await LoteInsumo.findAll({
            include: [
                { model: ArticuloMedico, as: 'articulo' },
                { model: db.Proveedor, as: 'proveedor', attributes: ['id_proveedor', 'nombre_proveedor'] },
                { model: db.CentroSalud, as: 'centro', attributes: ['id_centro', 'nombre_centro'] }
            ],
            order: [['fecha_vencimiento', 'ASC']]
        });

        const today = new Date();
        const thirtyDaysFromNow = new Date();
        thirtyDaysFromNow.setDate(today.getDate() + 30);

        const data = lotes.map(lote => {
            const fechaVencimiento = new Date(lote.fecha_vencimiento);
            const stockMinimo = lote.articulo?.stock_minimo_alerta ?? 10;
            const alertaStock = lote.stock_actual < stockMinimo;
            const alertaVencimiento = fechaVencimiento <= thirtyDaysFromNow;
            const vencido = fechaVencimiento <= today;

            return {
                ...lote.toJSON(),
                alertas: {
                    stock_bajo: alertaStock,
                    stock_minimo_alerta: stockMinimo,
                    proximo_vencer: alertaVencimiento && !vencido,
                    vencido
                }
            };
        });

        res.status(200).json({ success: true, count: data.length, data });
    } catch (error) {
        console.error('Error al obtener inventario:', error);
        res.status(500).json({ success: false, message: 'Error al obtener el inventario', error: process.env.NODE_ENV === 'development' ? error : {} });
    }
};

// ─────────────────────────────────────────────────────────────────────────────
// DESCARTES (RF-10: con acta legal)
// ─────────────────────────────────────────────────────────────────────────────

exports.descartarLotes = async (req, res) => {
    const transaction = await db.sequelize.transaction();
    try {
        const { ids, metodo_disposicion, fecha_retiro, numero_acta_descarte, justificacion, foto_evidencia } = req.body;

        if (!ids || !Array.isArray(ids) || ids.length === 0) {
            await transaction.rollback();
            return res.status(400).json({ success: false, message: 'Debe proporcionar una lista de IDs de lotes a descartar' });
        }

        const lotes = await LoteInsumo.findAll({
            where: { id_lote_insumo: ids },
            include: [{ model: ArticuloMedico, as: 'articulo' }],
            transaction
        });

        if (lotes.length === 0) {
            await transaction.rollback();
            return res.status(404).json({ success: false, message: 'No se encontraron los lotes especificados' });
        }

        // Procesar foto de evidencia si viene en base64
        let fotoUrl = null;
        if (foto_evidencia && typeof foto_evidencia === 'string') {
            if (foto_evidencia.startsWith('data:image')) {
                try {
                    const base64Data = foto_evidencia.replace(/^data:image\/\w+;base64,/, '');
                    const fileName = `foto_descarte_${Date.now()}_${Math.floor(Math.random()*1000)}.jpg`;
                    const filePath = path.join(__dirname, '../../public/uploads/descartes', fileName);
                    fs.writeFileSync(filePath, Buffer.from(base64Data, 'base64'));
                    fotoUrl = `/uploads/descartes/${fileName}`;
                } catch (imgErr) {
                    console.error('Error al guardar evidencia fotográfica:', imgErr);
                }
            } else if (foto_evidencia.startsWith('/uploads')) {
                fotoUrl = foto_evidencia;
            }
        }

        const movimientosCreados = [];

        for (const lote of lotes) {
            const stockAnterior = lote.stock_actual;

            // Registrar movimiento de descarte
            const mov = await MovimientoInventario.create({
                id_lote_insumo: lote.id_lote_insumo,
                id_centro: lote.id_centro || null,
                tipo_movimiento: 'Descarte',
                cantidad: stockAnterior,
                numero_acta_descarte: numero_acta_descarte || null,
                justificacion: justificacion || `Método: ${metodo_disposicion || 'Deterioro/Vencimiento'} - Fecha retiro: ${fecha_retiro || new Date().toISOString().split('T')[0]}`,
                foto_evidencia: fotoUrl,
                fecha_movimiento: new Date()
            }, { transaction });

            movimientosCreados.push(mov.id_movimiento);

            lote.stock_actual = 0;
            await lote.save({ transaction });

            await logAction(
                req.user ? req.user.username : 'sistema',
                `Descarte de biológico/insumo: Lote ${lote.numero_lote} (${lote.articulo?.nombre_articulo || 'N/A'})`,
                'lotes_insumos',
                { id: lote.id_lote_insumo, stock_anterior: stockAnterior, metodo_disposicion, fecha_retiro, numero_acta_descarte }
            );
        }

        await transaction.commit();

        res.status(200).json({
            success: true,
            message: `Descarte registrado exitosamente para ${lotes.length} lotes`,
            movimiento_ids: movimientosCreados,
            primer_movimiento_id: movimientosCreados[0],
            foto_evidencia: fotoUrl
        });
    } catch (error) {
        await transaction.rollback();
        console.error('Error al registrar descarte:', error);
        res.status(500).json({ success: false, message: 'Error al registrar descarte', error: error.message });
    }
};

// ─────────────────────────────────────────────────────────────────────────────
// GENERACIÓN DE NOTA DE SALIDA PDF Y CÓDIGO QR PARA ESCANEAR EN DESCARTE (RF-10)
// ─────────────────────────────────────────────────────────────────────────────

exports.generarNotaSalidaPDF = async (req, res) => {
    try {
        const { id } = req.params;
        const movimiento = await MovimientoInventario.findByPk(id, {
            include: [
                {
                    model: LoteInsumo, as: 'lote',
                    include: [{ model: ArticuloMedico, as: 'articulo' }]
                },
                { model: db.CentroSalud, as: 'centro' }
            ]
        });

        if (!movimiento) {
            return res.status(404).json({ success: false, message: 'Movimiento de descarte no encontrado' });
        }

        let movimientosActa = [movimiento];
        if (movimiento.numero_acta_descarte) {
            movimientosActa = await MovimientoInventario.findAll({
                where: { numero_acta_descarte: movimiento.numero_acta_descarte },
                include: [
                    {
                        model: LoteInsumo, as: 'lote',
                        include: [{ model: ArticuloMedico, as: 'articulo' }]
                    },
                    { model: db.CentroSalud, as: 'centro' }
                ]
            });
        }

        const domain = 'https://thing-edwards-invalid-therapist.trycloudflare.com';
        const verifyUrl = `${domain}/api/inventario/movimientos/${movimiento.id_movimiento}/verificar`;

        const qrBuffer = await QRCode.toBuffer(verifyUrl, { margin: 1, width: 140 });

        const doc = new PDFDocument({ margin: 40, size: 'LETTER' });

        res.setHeader('Content-Type', 'application/pdf');
        res.setHeader('Content-Disposition', `inline; filename="nota_salida_${movimiento.id_movimiento}.pdf"`);

        doc.pipe(res);

        // Encabezado institucional
        doc.fillColor('#0D47A1').fontSize(13).text('REPÚBLICA BOLIVARIANA DE VENEZUELA', { align: 'center' });
        doc.fontSize(11).text('MINISTERIO DEL PODER POPULAR PARA LA SALUD', { align: 'center' });
        doc.fontSize(10).text('ASIC SAN JOSÉ DE GUANIPA — CDI PEDRO URBINA', { align: 'center' });
        doc.moveDown(0.5);

        doc.strokeColor('#0D47A1').lineWidth(2).moveTo(40, doc.y).lineTo(570, doc.y).stroke();
        doc.moveDown(1);

        // Título del Acta / Nota de Salida
        doc.fillColor('#B71C1C').fontSize(15).text('NOTA DE SALIDA Y ACTA OFICIAL DE DESCARTE', { align: 'center', bold: true });
        doc.fillColor('#333333').fontSize(10).text(`N° ACTA / CONTROL: ${movimiento.numero_acta_descarte || ('ACTA-DESCARTE-' + movimiento.id_movimiento)}`, { align: 'center' });
        doc.moveDown(1);

        const fechaEmision = movimiento.fecha_movimiento 
            ? new Date(movimiento.fecha_movimiento).toLocaleDateString('es-VE')
            : new Date().toLocaleDateString('es-VE');

        doc.fillColor('#000000').fontSize(10);
        doc.text(`Fecha de Registro: ${fechaEmision}`);
        doc.text(`Tipo de Movimiento: ${movimiento.tipo_movimiento.toUpperCase()} (RETIRO / MERMA)`);
        doc.text(`Centro de Origen: ${movimiento.centro ? movimiento.centro.nombre_centro : 'CDI Pedro Urbina / ASIC Guanipa'}`);
        doc.moveDown(1);

        // Tabla de ítems descartados
        doc.fillColor('#0D47A1').fontSize(11).text('DETALLE DE INSUMOS Y MEDICAMENTOS DESCARTADOS:', { underline: true });
        doc.moveDown(0.5);

        let tableTop = doc.y;
        doc.rect(40, tableTop, 530, 20).fill('#0D47A1');
        doc.fillColor('#FFFFFF').fontSize(9);
        doc.text('Artículo / Insumo', 50, tableTop + 5, { width: 170 });
        doc.text('N° Lote', 220, tableTop + 5, { width: 90 });
        doc.text('Cantidad', 310, tableTop + 5, { width: 60 });
        doc.text('F. Vencimiento', 370, tableTop + 5, { width: 80 });
        doc.text('Tipo', 450, tableTop + 5, { width: 110 });

        let currentY = tableTop + 20;
        doc.fillColor('#333333').fontSize(9);

        movimientosActa.forEach((m, idx) => {
            const art = m.lote && m.lote.articulo ? m.lote.articulo.nombre_articulo : 'Insumo Médico';
            const numLote = m.lote ? m.lote.numero_lote : 'N/A';
            const cant = m.cantidad || 0;
            const fVenc = m.lote && m.lote.fecha_vencimiento ? m.lote.fecha_vencimiento : 'N/A';
            const tipoArt = m.lote && m.lote.articulo ? m.lote.articulo.tipo : 'Insumo';

            const bg = idx % 2 === 0 ? '#F5F5F5' : '#FFFFFF';
            doc.rect(40, currentY, 530, 20).fill(bg);
            doc.fillColor('#333333');
            doc.text(art, 50, currentY + 5, { width: 165 });
            doc.text(numLote, 220, currentY + 5, { width: 85 });
            doc.text(`${cant}`, 310, currentY + 5, { width: 55 });
            doc.text(fVenc, 370, currentY + 5, { width: 75 });
            doc.text(tipoArt, 450, currentY + 5, { width: 105 });
            currentY += 20;
        });

        doc.y = currentY + 10;
        doc.moveDown(0.5);

        doc.fillColor('#0D47A1').fontSize(11).text('JUSTIFICACIÓN DEL RETIRO:', { underline: true });
        doc.fillColor('#333333').fontSize(10).text(movimiento.justificacion || 'Descarte oficial por caducidad o deterioro.');
        doc.moveDown(1);

        // Evidencia Fotográfica en PDF si está disponible
        if (movimiento.foto_evidencia) {
            const relPath = movimiento.foto_evidencia.replace(/^\//, '');
            const fullImgPath = path.join(__dirname, '../../public', relPath);
            if (fs.existsSync(fullImgPath)) {
                try {
                    doc.fillColor('#0D47A1').fontSize(11).text('EVIDENCIA FOTOGRÁFICA REGISTRADA:');
                    doc.image(fullImgPath, { width: 150, height: 110 });
                    doc.moveDown(1);
                } catch (_) {}
            }
        }

        const bottomY = Math.max(doc.y, 570);

        // Código QR
        doc.image(qrBuffer, 440, bottomY, { width: 100 });
        doc.fillColor('#555555').fontSize(7).text('ESCANEE PARA VERIFICAR\nEN SISTEMA ASIC GUANIPA', 430, bottomY + 105, { width: 120, align: 'center' });

        // Firmas
        doc.fillColor('#000000').fontSize(8);
        doc.text('_______________________________', 40, bottomY + 30);
        doc.text('ENTREGADO POR: Farmacia / Almacén', 40, bottomY + 42);

        doc.text('_______________________________', 240, bottomY + 30);
        doc.text('AUTORIZADO POR: Dirección ASIC', 240, bottomY + 42);

        doc.text('_______________________________', 40, bottomY + 80);
        doc.text('RECIBIDO POR: Comisión de Traslado', 40, bottomY + 92);

        doc.end();
    } catch (error) {
        console.error('Error al generar PDF de nota de salida:', error);
        res.status(500).json({ success: false, message: 'Error al generar Nota de Salida en PDF', error: error.message });
    }
};

exports.verificarMovimiento = async (req, res) => {
    try {
        const { id } = req.params;
        const movimiento = await MovimientoInventario.findByPk(id, {
            include: [
                {
                    model: LoteInsumo, as: 'lote',
                    include: [{ model: ArticuloMedico, as: 'articulo' }]
                },
                { model: db.CentroSalud, as: 'centro' }
            ]
        });

        if (!movimiento) {
            return res.status(404).send(`
                <html>
                    <body style="font-family:sans-serif; text-align:center; padding:50px;">
                        <h1 style="color:#C62828;">❌ Documento no encontrado</h1>
                        <p>El código QR escaneado no corresponde a ningún descarte registrado.</p>
                    </body>
                </html>
            `);
        }

        let movimientosActa = [movimiento];
        if (movimiento.numero_acta_descarte) {
            movimientosActa = await MovimientoInventario.findAll({
                where: { numero_acta_descarte: movimiento.numero_acta_descarte },
                include: [
                    {
                        model: LoteInsumo, as: 'lote',
                        include: [{ model: ArticuloMedico, as: 'articulo' }]
                    },
                    { model: db.CentroSalud, as: 'centro' }
                ]
            });
        }

        const isJson = req.headers.accept && req.headers.accept.includes('application/json');
        if (isJson) {
            return res.json({ success: true, movimiento, acta_completa: movimientosActa });
        }

        const fecha = movimiento.fecha_movimiento 
            ? new Date(movimiento.fecha_movimiento).toLocaleString('es-VE')
            : 'N/A';

        const filasHtml = movimientosActa.map(m => `
            <tr>
                <td style="padding:10px;border-bottom:1px solid #E2E8F0;">${m.lote && m.lote.articulo ? m.lote.articulo.nombre_articulo : 'Insumo'}</td>
                <td style="padding:10px;border-bottom:1px solid #E2E8F0;">${m.lote ? m.lote.numero_lote : 'N/A'}</td>
                <td style="padding:10px;border-bottom:1px solid #E2E8F0;font-weight:bold;color:#0D47A1;">${m.cantidad}</td>
                <td style="padding:10px;border-bottom:1px solid #E2E8F0;">${m.lote ? (m.lote.fecha_vencimiento || 'N/A') : 'N/A'}</td>
            </tr>
        `).join('');

        const domain = 'https://thing-edwards-invalid-therapist.trycloudflare.com';
        const fotoHtml = movimiento.foto_evidencia 
            ? `<div style="margin-top:20px;text-align:center;"><p style="font-size:13px;font-weight:bold;color:#475569;">Evidencia Fotográfica del Registro:</p><img src="${domain}${movimiento.foto_evidencia}" style="max-width:100%; max-height:280px; border-radius:10px; border:2px solid #E2E8F0;"/></div>`
            : '';

        res.send(`
            <!DOCTYPE html>
            <html lang="es">
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>Verificación de Acta de Descarte — ASIC Guanipa</title>
                <style>
                    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #F8FAFC; margin: 0; padding: 20px; color: #1E293B; }
                    .card { max-width: 600px; margin: 0 auto; background: white; border-radius: 16px; padding: 24px; box-shadow: 0 10px 25px rgba(0,0,0,0.08); border: 1px solid #E2E8F0; }
                    .badge { background: #DCFCE7; color: #15803D; padding: 8px 16px; border-radius: 20px; font-weight: bold; font-size: 13px; display: inline-flex; align-items: center; gap: 6px; }
                    h2 { color: #0D47A1; margin-top: 14px; margin-bottom: 2px; font-size: 20px; }
                    .meta { background: #F1F5F9; padding: 14px; border-radius: 10px; font-size: 13px; margin-top: 16px; line-height: 1.6; }
                    table { width: 100%; border-collapse: collapse; margin-top: 16px; font-size: 13px; }
                    th { background: #0D47A1; color: white; padding: 10px; text-align: left; font-size: 12px; }
                </style>
            </head>
            <body>
                <div class="card">
                    <div style="text-align:center;">
                        <span class="badge">✓ DOCUMENTO AUTÉNTICO VERIFICADO</span>
                        <h2>ASIC San José de Guanipa</h2>
                        <p style="margin:0;color:#64748B;font-size:13px;">CDI Pedro Urbina — Sistema de Salud Nominal</p>
                    </div>
                    <div class="meta">
                        <p style="margin:2px 0;"><strong>N° Acta / Control:</strong> ${movimiento.numero_acta_descarte || ('ACTA-' + movimiento.id_movimiento)}</p>
                        <p style="margin:2px 0;"><strong>Tipo Movimiento:</strong> ${movimiento.tipo_movimiento.toUpperCase()}</p>
                        <p style="margin:2px 0;"><strong>Fecha Registro:</strong> ${fecha}</p>
                        <p style="margin:2px 0;"><strong>Justificación:</strong> ${movimiento.justificacion || 'N/A'}</p>
                    </div>
                    <h3 style="font-size:15px;color:#0F172A;margin-top:20px;margin-bottom:8px;">Lotes / Insumos Descartados:</h3>
                    <table>
                        <thead>
                            <tr>
                                <th>Artículo</th>
                                <th>Lote</th>
                                <th>Cantidad</th>
                                <th>Vencimiento</th>
                            </tr>
                        </thead>
                        <tbody>
                            ${filasHtml}
                        </tbody>
                    </table>
                    ${fotoHtml}
                </div>
            </body>
            </html>
        `);
    } catch (error) {
        console.error('Error al verificar movimiento:', error);
        res.status(500).send('Error interno al verificar documento');
    }
};

// ─────────────────────────────────────────────────────────────────────────────
// MOVIMIENTOS DE INVENTARIO
// ─────────────────────────────────────────────────────────────────────────────

exports.obtenerMovimientos = async (req, res) => {
    try {
        const { id_lote, tipo, desde, hasta } = req.query;
        const where = {};
        if (id_lote) where.id_lote_insumo = id_lote;
        if (tipo) where.tipo_movimiento = tipo;
        if (desde || hasta) {
            where.fecha_movimiento = {};
            if (desde) where.fecha_movimiento[Op.gte] = new Date(desde);
            if (hasta) where.fecha_movimiento[Op.lte] = new Date(hasta);
        }

        const movimientos = await MovimientoInventario.findAll({
            where,
            include: [
                {
                    model: LoteInsumo, as: 'lote',
                    include: [{ model: ArticuloMedico, as: 'articulo', attributes: ['nombre_articulo'] }]
                },
                { model: db.CentroSalud, as: 'centro', attributes: ['nombre_centro'] }
            ],
            order: [['fecha_movimiento', 'DESC']],
            limit: 500
        });

        res.status(200).json({ success: true, count: movimientos.length, data: movimientos });
    } catch (error) {
        console.error('Error al obtener movimientos:', error);
        res.status(500).json({ success: false, message: 'Error al obtener movimientos', error: error.message });
    }
};

// ─────────────────────────────────────────────────────────────────────────────
// ESQUEMAS DE DOSIFICACIÓN
// ─────────────────────────────────────────────────────────────────────────────

exports.listarEsquemas = async (req, res) => {
    try {
        const esquemas = await db.EsquemaDosificacion.findAll({
            include: [{
                model: ArticuloMedico,
                as: 'vacuna',
                attributes: ['id_articulo', 'nombre_articulo']
            }],
            order: [['id_articulo', 'ASC'], ['id_esquema', 'ASC']]
        });
        res.status(200).json({ success: true, count: esquemas.length, data: esquemas });
    } catch (error) {
        console.error('Error al listar esquemas:', error);
        res.status(500).json({ success: false, message: 'Error al obtener esquemas', error: error.message });
    }
};

exports.crearEsquema = async (req, res) => {
    try {
        const { id_articulo, numero_dosis, intervalo_dias_previo, edad_minima_meses, edad_maxima_meses } = req.body;
        if (!id_articulo || !numero_dosis) {
            return res.status(400).json({ success: false, message: 'La vacuna (id_articulo) y el número/nombre de dosis son obligatorios.' });
        }

        const esquema = await db.EsquemaDosificacion.create({
            id_articulo,
            numero_dosis,
            intervalo_dias_previo: intervalo_dias_previo ? parseInt(intervalo_dias_previo) : null,
            edad_minima_meses: edad_minima_meses ? parseInt(edad_minima_meses) : null,
            edad_maxima_meses: edad_maxima_meses ? parseInt(edad_maxima_meses) : null
        });

        await logAction(
            req.user ? req.user.username : 'sistema',
            `Registro de esquema de dosificación para artículo ID ${id_articulo} (${numero_dosis})`,
            'esquemas_dosificacion',
            { id: esquema.id_esquema }
        );

        const nuevoEsquema = await db.EsquemaDosificacion.findByPk(esquema.id_esquema, {
            include: [{ model: ArticuloMedico, as: 'vacuna', attributes: ['id_articulo', 'nombre_articulo'] }]
        });

        res.status(201).json({ success: true, message: 'Esquema de dosificación registrado con éxito', data: nuevoEsquema });
    } catch (error) {
        console.error('Error al crear esquema:', error);
        res.status(500).json({ success: false, message: 'Error al crear esquema de dosificación', error: error.message });
    }
};

exports.actualizarEsquema = async (req, res) => {
    try {
        const { id } = req.params;
        const { numero_dosis, intervalo_dias_previo, edad_minima_meses, edad_maxima_meses } = req.body;

        const esquema = await db.EsquemaDosificacion.findByPk(id);
        if (!esquema) {
            return res.status(404).json({ success: false, message: 'Esquema no encontrado' });
        }

        await esquema.update({
            numero_dosis: numero_dosis !== undefined ? numero_dosis : esquema.numero_dosis,
            intervalo_dias_previo: intervalo_dias_previo !== undefined ? parseInt(intervalo_dias_previo) : esquema.intervalo_dias_previo,
            edad_minima_meses: edad_minima_meses !== undefined ? parseInt(edad_minima_meses) : esquema.edad_minima_meses,
            edad_maxima_meses: edad_maxima_meses !== undefined ? parseInt(edad_maxima_meses) : esquema.edad_maxima_meses
        });

        const actualizado = await db.EsquemaDosificacion.findByPk(id, {
            include: [{ model: ArticuloMedico, as: 'vacuna', attributes: ['id_articulo', 'nombre_articulo'] }]
        });

        res.status(200).json({ success: true, message: 'Esquema actualizado correctamente', data: actualizado });
    } catch (error) {
        console.error('Error al actualizar esquema:', error);
        res.status(500).json({ success: false, message: 'Error al actualizar esquema', error: error.message });
    }
};

exports.eliminarEsquema = async (req, res) => {
    try {
        const { id } = req.params;
        const esquema = await db.EsquemaDosificacion.findByPk(id);
        if (!esquema) {
            return res.status(404).json({ success: false, message: 'Esquema no encontrado' });
        }
        await esquema.destroy();
        res.status(200).json({ success: true, message: 'Esquema eliminado exitosamente' });
    } catch (error) {
        console.error('Error al eliminar esquema:', error);
        res.status(500).json({ success: false, message: 'Error al eliminar esquema', error: error.message });
    }
};

// ─────────────────────────────────────────────────────────────────────────────
// PROVEEDORES
// ─────────────────────────────────────────────────────────────────────────────

exports.listarProveedores = async (req, res) => {
    try {
        const proveedores = await db.Proveedor.findAll({ order: [['nombre_proveedor', 'ASC']] });
        res.status(200).json({ success: true, count: proveedores.length, data: proveedores });
    } catch (error) {
        console.error('Error al listar proveedores:', error);
        res.status(500).json({ success: false, message: 'Error al obtener proveedores', error: error.message });
    }
};

exports.registrarProveedor = async (req, res) => {
    try {
        const { nombre_proveedor, rif, telefono, direccion } = req.body;
        if (!nombre_proveedor) {
            return res.status(400).json({ success: false, message: 'El nombre del proveedor es obligatorio' });
        }
        const proveedor = await db.Proveedor.create({ nombre_proveedor, rif, telefono, direccion });
        await logAction(
            req.user ? req.user.username : 'sistema',
            `Registro de proveedor: ${nombre_proveedor}`,
            'proveedores',
            { id: proveedor.id_proveedor }
        );
        res.status(201).json({ success: true, message: 'Proveedor registrado exitosamente', data: proveedor });
    } catch (error) {
        console.error('Error al registrar proveedor:', error);
        res.status(500).json({ success: false, message: 'Error al registrar proveedor', error: error.message });
    }
};

const { LoteInsumo, ArticuloMedico } = require('../models');
const { Op } = require('sequelize');

/**
 * Register a new medical article
 */
exports.registrarArticulo = async (req, res) => {
    try {
        const { nombre_articulo, unidad_medida } = req.body;

        // Validate required fields
        if (!nombre_articulo || !unidad_medida) {
            return res.status(400).json({
                success: false,
                message: 'Nombre del artículo y unidad de medida son obligatorios'
            });
        }

        // Check if article already exists
        const existingArticle = await ArticuloMedico.findOne({
            where: { nombre_articulo }
        });

        if (existingArticle) {
            return res.status(400).json({
                success: false,
                message: 'Ya existe un artículo con ese nombre'
            });
        }

        const nuevoArticulo = await ArticuloMedico.create({
            nombre_articulo,
            unidad_medida
        });

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

/**
 * Register a new batch of medical supplies
 */
exports.registrarLote = async (req, res) => {
    try {
        const { id_articulo, numero_lote, stock_actual, fecha_vencimiento } = req.body;

        // Validate Expiration Date
        const today = new Date();
        const vencimiento = new Date(fecha_vencimiento);

        if (vencimiento <= today) {
            return res.status(400).json({
                success: false,
                message: 'La fecha de vencimiento debe ser futura.'
            });
        }

        // Validate Article Existence
        const articulo = await ArticuloMedico.findByPk(id_articulo);
        if (!articulo) {
            return res.status(404).json({
                success: false,
                message: 'Artículo médico no encontrado.'
            });
        }

        const nuevoLote = await LoteInsumo.create({
            id_articulo,
            numero_lote,
            stock_actual,
            fecha_vencimiento
        });

        res.status(201).json({
            success: true,
            message: 'Lote registrado exitosamente',
            data: nuevoLote
        });

    } catch (error) {
        console.error('Error al registrar lote:', error);
        res.status(500).json({
            success: false,
            message: 'Error interno del servidor al registrar el lote',
            error: process.env.NODE_ENV === 'development' ? error : {}
        });
    }
};

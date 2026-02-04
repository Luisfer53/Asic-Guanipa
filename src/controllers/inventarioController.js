const { LoteInsumo, ArticuloMedico } = require('../models');
const { Op } = require('sequelize');


exports.registrarArticulo = async (req, res) => {
    try {
        const { nombre_articulo, unidad_medida } = req.body;


        if (!nombre_articulo || !unidad_medida) {
            return res.status(400).json({
                success: false,
                message: 'Nombre del artículo y unidad de medida son obligatorios'
            });
        }


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


exports.registrarLote = async (req, res) => {
    try {
        const { id_articulo, numero_lote, stock_actual, fecha_vencimiento } = req.body;


        const today = new Date();
        const vencimiento = new Date(fecha_vencimiento);

        if (vencimiento <= today) {
            return res.status(400).json({
                success: false,
                message: 'La fecha de vencimiento debe ser futura.'
            });
        }


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


exports.obtenerInventario = async (req, res) => {
    try {
        const lotes = await LoteInsumo.findAll({
            include: [{
                model: ArticuloMedico,
                as: 'articulo'
            }],
            order: [['fecha_vencimiento', 'ASC']]
        });

        const today = new Date();
        const thirtyDaysFromNow = new Date();
        thirtyDaysFromNow.setDate(today.getDate() + 30);

        const data = lotes.map(lote => {
            const fechaVencimiento = new Date(lote.fecha_vencimiento);
            const alertaStock = lote.stock_actual < 10;
            const alertaVencimiento = fechaVencimiento <= thirtyDaysFromNow;
            const vencido = fechaVencimiento <= today;

            return {
                nombre_articulo: lote.articulo ? lote.articulo.nombre_articulo : 'N/A',
                id: lote.id,
                numero_lote: lote.numero_lote,
                ...lote.toJSON(),
                alertas: {
                    stock_bajo: alertaStock,
                    proximo_vencer: alertaVencimiento && !vencido,
                    vencido: vencido
                }
            };
        });

        res.status(200).json({
            success: true,
            count: data.length,
            data
        });

    } catch (error) {
        console.error('Error al obtener inventario:', error);
        res.status(500).json({
            success: false,
            message: 'Error al obtener el inventario',
            error: process.env.NODE_ENV === 'development' ? error : {}
        });
    }
};

exports.listarArticulos = async (req, res) => {
    try {
        const articulos = await ArticuloMedico.findAll({
            order: [['nombre_articulo', 'ASC']]
        });

        res.status(200).json({
            success: true,
            count: articulos.length,
            data: articulos
        });
    } catch (error) {
        console.error('Error al listar artículos:', error);
        res.status(500).json({
            success: false,
            message: 'Error al obtener la lista de artículos',
            error: process.env.NODE_ENV === 'development' ? error : {}
        });
    }
};


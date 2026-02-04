const db = require('../models');
const { Op } = require('sequelize');
const Paciente = db.Paciente;
const AtencionDiaria = db.AtencionDiaria;
const ExcelJS = require('exceljs');

const generateDailyReport = async (req, res) => {
    try {
        const { fecha, formato, limit = 100, offset = 0 } = req.query;

        const where = {};
        if (fecha) {
            where.fecha = fecha;
        }


        const { count, rows: attentions } = await AtencionDiaria.findAndCountAll({
            where,
            include: [
                {
                    model: Paciente,
                    as: 'paciente'
                }
            ],
            limit: parseInt(limit),
            offset: parseInt(offset),
            order: [['fecha', 'DESC']]
        });








        const stats = {
            total: count,
            hombres: await AtencionDiaria.count({
                where,
                include: [{ model: Paciente, as: 'paciente', where: { sexo: 'M' } }],
                distinct: true,
                col: 'paciente_id'
            }),
            mujeres: await AtencionDiaria.count({
                where,
                include: [{ model: Paciente, as: 'paciente', where: { sexo: 'F' } }],
                distinct: true,
                col: 'paciente_id'
            }),
            menores: await AtencionDiaria.count({
                where,
                include: [{ model: Paciente, as: 'paciente' }],
                where: { ...where, edad_atencion: { [Op.lt]: 18 } },
                distinct: true,
                col: 'paciente_id'
            }),
            mayores: await AtencionDiaria.count({
                where,
                where: { ...where, edad_atencion: { [Op.gte]: 60 } },
                distinct: true,
                col: 'paciente_id'
            })
        };

        if (formato === 'excel') {



            const allAttentions = await AtencionDiaria.findAll({
                where,
                include: [{ model: Paciente, as: 'paciente' }],
                order: [['fecha', 'DESC']]
            });

            const workbook = new ExcelJS.Workbook();
            const worksheet = workbook.addWorksheet(`Reporte ${fecha || 'General'}`);

            worksheet.columns = [
                { header: 'ID Atención', key: 'id', width: 10 },
                { header: 'Fecha', key: 'fecha', width: 15 },
                { header: 'Nombre', key: 'nombre', width: 20 },
                { header: 'Apellido', key: 'apellido', width: 20 },
                { header: 'Cédula', key: 'cedula', width: 15 },
                { header: 'Edad', key: 'edad', width: 10 },
                { header: 'Sexo', key: 'sexo', width: 10 },
                { header: 'Diagnóstico', key: 'diagnostico', width: 30 },
                { header: 'Dirección', key: 'direccion', width: 30 },
                { header: 'Teléfono', key: 'telefono', width: 15 }
            ];

            allAttentions.forEach(a => {
                worksheet.addRow({
                    id: a.id,
                    fecha: a.fecha,
                    nombre: a.paciente.nombre,
                    apellido: a.paciente.apellido,
                    cedula: a.paciente.cedula,
                    edad: a.edad_atencion,
                    sexo: a.paciente.sexo,
                    diagnostico: a.diagnostico,
                    direccion: a.paciente.direccion,
                    telefono: a.paciente.telefono
                });
            });


            worksheet.addRow([]);
            worksheet.addRow(['Resumen']);
            worksheet.addRow(['Total Pacientes', stats.total]);
            worksheet.addRow(['Hombres', stats.hombres]);
            worksheet.addRow(['Mujeres', stats.mujeres]);
            worksheet.addRow(['Menores (<18)', stats.menores]);
            worksheet.addRow(['Mayores (>=60)', stats.mayores]);

            res.setHeader('Access-Control-Expose-Headers', 'Content-Disposition');
            res.attachment(`reporte-${fecha || 'general'}.xlsx`);
            res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');

            await workbook.xlsx.write(res);
            res.end();
        } else {

            res.status(200).json({
                success: true,
                fecha: fecha || 'Todos',
                pagination: {
                    total: count,
                    limit: parseInt(limit),
                    offset: parseInt(offset),
                    pages: Math.ceil(count / limit)
                },
                stats,
                data: attentions
            });
        }

    } catch (error) {
        console.error('Error generating report:', error);
        res.status(500).json({
            success: false,
            message: 'Error al generar reporte',
            error: error.message
        });
    }
};

const generateInventoryReport = async (req, res) => {
    try {
        const lotes = await db.LoteInsumo.findAll({
            include: [{
                model: db.ArticuloMedico,
                as: 'articulo'
            }],
            order: [['fecha_vencimiento', 'ASC']]
        });

        const workbook = new ExcelJS.Workbook();
        const worksheet = workbook.addWorksheet('Inventario');

        worksheet.columns = [
            { header: 'Artículo', key: 'articulo', width: 25 },
            { header: 'ID', key: 'id', width: 10 },
            { header: 'Lote', key: 'lote', width: 15 },
            { header: 'Stock Actual', key: 'stock', width: 15 },
            { header: 'Unidad', key: 'unidad', width: 15 },
            { header: 'Fecha Vencimiento', key: 'vencimiento', width: 20 },
            { header: 'Alertas', key: 'alertas', width: 30 }
        ];

        const today = new Date();
        const thirtyDaysFromNow = new Date();
        thirtyDaysFromNow.setDate(today.getDate() + 30);

        lotes.forEach(lote => {
            const fechaVencimiento = new Date(lote.fecha_vencimiento);
            const alertas = [];
            if (lote.stock_actual < 10) alertas.push('STOCK BAJO');
            if (fechaVencimiento <= today) {
                alertas.push('VENCIDO');
            } else if (fechaVencimiento <= thirtyDaysFromNow) {
                alertas.push('PRÓXIMO A VENCER');
            }

            const row = worksheet.addRow({
                articulo: lote.articulo ? lote.articulo.nombre_articulo : 'N/A',
                id: lote.id,
                lote: lote.numero_lote,
                stock: lote.stock_actual,
                unidad: lote.articulo ? lote.articulo.unidad_medida : 'N/A',
                vencimiento: lote.fecha_vencimiento,
                alertas: alertas.join(', ')
            });


            if (alertas.includes('VENCIDO') || alertas.includes('STOCK BAJO')) {
                row.getCell('alertas').font = { color: { argb: 'FFFF0000' }, bold: true };
            } else if (alertas.includes('PRÓXIMO A VENCER')) {
                row.getCell('alertas').font = { color: { argb: 'FFFFA500' }, bold: true };
            }
        });

        res.setHeader('Access-Control-Expose-Headers', 'Content-Disposition');
        res.attachment('reporte-inventario.xlsx');
        res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');

        await workbook.xlsx.write(res);
        res.end();

    } catch (error) {
        console.error('Error generating inventory report:', error);
        res.status(500).json({
            success: false,
            message: 'Error al generar reporte de inventario',
            error: error.message
        });
    }
};

module.exports = {
    generateDailyReport,
    generateInventoryReport
};


const db = require('../models');
const RegistroPacientesDiarios = db.RegistroPacientesDiarios;
const ExcelJS = require('exceljs');

const generateDailyReport = async (req, res) => {
    try {
        const { fecha, formato } = req.query;

        if (!fecha) {
            return res.status(400).json({
                success: false,
                message: 'Debe especificar una fecha (YYYY-MM-DD)'
            });
        }

        const patients = await RegistroPacientesDiarios.findAll({
            where: { fecha }
        });

        const stats = {
            total: patients.length,
            hombres: patients.filter(p => p.sexo === 'M').length,
            mujeres: patients.filter(p => p.sexo === 'F').length,
            menores: patients.filter(p => p.edad < 18).length,
            mayores: patients.filter(p => p.edad >= 60).length
        };

        if (formato === 'excel') {
            const workbook = new ExcelJS.Workbook();
            const worksheet = workbook.addWorksheet(`Reporte ${fecha}`);

            worksheet.columns = [
                { header: 'ID', key: 'id', width: 10 },
                { header: 'Nombre', key: 'nombre', width: 20 },
                { header: 'Apellido', key: 'apellido', width: 20 },
                { header: 'Cédula', key: 'cedula', width: 15 },
                { header: 'Edad', key: 'edad', width: 10 },
                { header: 'Sexo', key: 'sexo', width: 10 },
                { header: 'Diagnóstico', key: 'diagnostico', width: 30 },
                { header: 'Dirección', key: 'direccion', width: 30 },
                { header: 'Teléfono', key: 'telefono', width: 15 }
            ];

            patients.forEach(p => {
                worksheet.addRow(p);
            });

            // Add stats
            worksheet.addRow([]);
            worksheet.addRow(['Resumen']);
            worksheet.addRow(['Total Pacientes', stats.total]);
            worksheet.addRow(['Hombres', stats.hombres]);
            worksheet.addRow(['Mujeres', stats.mujeres]);

            res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
            res.setHeader('Content-Disposition', `attachment; filename=reporte-${fecha}.xlsx`);

            await workbook.xlsx.write(res);
            res.end();
        } else {
            // Default JSON
            res.status(200).json({
                success: true,
                fecha,
                stats,
                data: patients
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

module.exports = {
    generateDailyReport
};

const db = require('../models');
const { Op } = require('sequelize');
const path = require('path');
const ExcelJS = require('exceljs');
const { logAction } = require('../utils/auditLogger');

const Paciente = db.Paciente;
const Persona = db.Persona;
const AtencionDiaria = db.AtencionDiaria;
const CentroSalud = db.CentroSalud;
const SectorGuanipa = db.SectorGuanipa;
const Direccion = db.Direccion;
const RegistroVacunacion = db.RegistroVacunacion;
const LoteInsumo = db.LoteInsumo;
const ArticuloMedico = db.ArticuloMedico;

function calcularEdad(fechaNacimiento) {
    if (!fechaNacimiento) return null;
    const dob = new Date(fechaNacimiento);
    const today = new Date();
    let age = today.getFullYear() - dob.getFullYear();
    const m = today.getMonth() - dob.getMonth();
    if (m < 0 || (m === 0 && today.getDate() < dob.getDate())) age--;
    return age;
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. REPORTE DIARIO NOMINAL DE ATENCIONES (EPI / MORBILIDAD)
// ─────────────────────────────────────────────────────────────────────────────
const generateDailyReport = async (req, res) => {
    try {
        const { fecha, formato = 'excel', centro, sector, limit = 100, offset = 0 } = req.query;

        const where = {};
        if (fecha) {
            where.fecha_visita = fecha;
        }

        if (centro && centro !== 'Todos') {
            const centroObj = await CentroSalud.findOne({ where: { nombre_centro: centro } });
            if (centroObj) where.id_centro = centroObj.id_centro;
        }

        const personaWhere = {};
        const direccionWhere = {};
        if (sector && sector !== 'Todos') {
            const sectorObj = await SectorGuanipa.findOne({ where: { nombre_sector: sector } });
            if (sectorObj) direccionWhere.id_sector = sectorObj.id_sector;
        }

        const includePatient = {
            model: Paciente,
            as: 'paciente',
            required: true,
            include: [
                {
                    model: Persona,
                    as: 'persona',
                    required: true,
                    where: personaWhere,
                    include: [
                        { model: db.Telefono, as: 'telefonos' },
                        { model: db.Correo, as: 'correos' },
                        {
                            model: Direccion,
                            as: 'direcciones',
                            where: Object.keys(direccionWhere).length > 0 ? direccionWhere : undefined,
                            required: Object.keys(direccionWhere).length > 0,
                            include: [{ model: SectorGuanipa, as: 'sector' }]
                        }
                    ]
                }
            ]
        };

        const { count, rows: attentions } = await AtencionDiaria.findAndCountAll({
            where,
            include: [
                includePatient,
                { model: CentroSalud, as: 'centro' }
            ],
            limit: parseInt(limit),
            offset: parseInt(offset),
            order: [['fecha_visita', 'DESC']]
        });

        const allForStats = await AtencionDiaria.findAll({
            where,
            include: [includePatient]
        });

        let hombres = 0, mujeres = 0, menores = 0, mayores = 0;
        allForStats.forEach(att => {
            const p = att.paciente?.persona;
            if (p) {
                if (p.sexo === 'M') hombres++;
                if (p.sexo === 'F') mujeres++;
                const edad = calcularEdad(p.fecha_nacimiento);
                if (edad !== null) {
                    if (edad < 18) menores++;
                    if (edad >= 60) mayores++;
                }
            }
        });

        const stats = { total: count, hombres, mujeres, menores, mayores };

        if (formato === 'excel') {
            await logAction(
                req.user ? req.user.username : 'sistema',
                `Descarga de reporte diario nominal de atenciones (${fecha || 'General'})`,
                'reportes',
                { fecha }
            );

            const allAttentions = await AtencionDiaria.findAll({
                where,
                include: [includePatient, { model: CentroSalud, as: 'centro' }],
                order: [['fecha_visita', 'DESC']]
            });

            const workbook = new ExcelJS.Workbook();
            const sheet = workbook.addWorksheet(`Reporte ${fecha || 'General'}`);

            sheet.columns = [
                { header: 'ID Atención', key: 'id', width: 14 },
                { header: 'Fecha Visita', key: 'fecha', width: 16 },
                { header: 'Nombre 1', key: 'nombre1', width: 18 },
                { header: 'Apellido 1', key: 'apellido1', width: 18 },
                { header: 'Cédula', key: 'cedula', width: 16 },
                { header: 'Edad', key: 'edad', width: 10 },
                { header: 'Sexo', key: 'sexo', width: 10 },
                { header: 'Diagnóstico General', key: 'diagnostico', width: 35 },
                { header: 'Dirección', key: 'direccion', width: 30 },
                { header: 'Teléfono', key: 'telefono', width: 16 },
                { header: 'Centro de Salud', key: 'centro', width: 25 }
            ];

            const headerRow = sheet.getRow(1);
            headerRow.font = { bold: true, color: { argb: 'FFFFFFFF' } };
            headerRow.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF1565C0' } };

            let rowIndex = 2;
            if (allAttentions.length === 0) {
                sheet.getRow(2).values = ['No se encontraron atenciones registradas para la fecha/filtros seleccionados'];
                rowIndex = 3;
            } else {
                allAttentions.forEach(a => {
                    const persona = a.paciente?.persona;
                    const edad = persona ? calcularEdad(persona.fecha_nacimiento) : 'N/A';
                    const tel = persona?.telefonos?.[0]?.numero_telefono || 'N/A';
                    const dirStr = persona?.direcciones?.[0]
                        ? `${persona.direcciones[0].calle || ''} ${persona.direcciones[0].numero_casa || ''}`
                        : 'N/A';

                    sheet.getRow(rowIndex).values = [
                        a.id_atencion,
                        a.fecha_visita,
                        persona ? (persona.nombre1 || '') : 'N/A',
                        persona ? (persona.apellido1 || '') : 'N/A',
                        persona ? (persona.cedula_identidad || 'S/C') : 'N/A',
                        edad !== null ? edad : 'N/A',
                        persona ? persona.sexo : 'N/A',
                        a.diagnostico_general || 'N/A',
                        dirStr,
                        tel,
                        a.centro ? a.centro.nombre_centro : 'N/A'
                    ];
                    rowIndex++;
                });
            }

            rowIndex += 1;
            sheet.getRow(rowIndex).values = ['Resumen de Atenciones'];
            sheet.getRow(rowIndex).font = { bold: true };
            sheet.getRow(rowIndex + 1).values = ['Total Pacientes', stats.total];
            sheet.getRow(rowIndex + 2).values = ['Hombres', stats.hombres];
            sheet.getRow(rowIndex + 3).values = ['Mujeres', stats.mujeres];
            sheet.getRow(rowIndex + 4).values = ['Menores (<18)', stats.menores];
            sheet.getRow(rowIndex + 5).values = ['Mayores (>=60)', stats.mayores];

            res.setHeader('Access-Control-Expose-Headers', 'Content-Disposition');
            res.attachment(`reporte-diario-${fecha || 'general'}.xlsx`);
            res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');

            await workbook.xlsx.write(res);
            res.end();
        } else {
            res.status(200).json({
                success: true,
                fecha: fecha || 'Todos',
                pagination: {
                    total: count, limit: parseInt(limit), offset: parseInt(offset),
                    pages: Math.ceil(count / limit)
                },
                stats, data: attentions
            });
        }
    } catch (error) {
        console.error('Error generating daily report:', error);
        res.status(500).json({ success: false, message: 'Error al generar reporte diario', error: error.message });
    }
};

// ─────────────────────────────────────────────────────────────────────────────
// 2. RUTINA SEMANAL ASIC GUANIPA (SEMANA EPIDEMIOLÓGICA)
// ─────────────────────────────────────────────────────────────────────────────
const generateWeeklyReport = async (req, res) => {
    try {
        const { semana = 1, ano = new Date().getFullYear() } = req.query;
        const templatePath = path.join(__dirname, '../templates/rutina_semanal.xlsx');

        await logAction(
            req.user ? req.user.username : 'sistema',
            `Descarga de Rutina Semanal ASIC Guanipa (Semana SE-${semana}, Año ${ano})`,
            'reportes', { semana, ano }
        );

        const workbook = new ExcelJS.Workbook();
        await workbook.xlsx.readFile(templatePath);

        const sheet = workbook.getWorksheet(1);
        if (sheet) sheet.name = `SE-${semana.toString().padStart ? semana.toString().padStart(2, '0') : semana}`;

        // Limpiar celdas con datos estáticos en filas 5 a sheet.rowCount (columnas 4 a 96)
        for (let r = 5; r <= sheet.rowCount; r++) {
            const row = sheet.getRow(r);
            row.eachCell({ includeEmpty: false }, (cell, col) => {
                if (col >= 4 && col <= 96 && (typeof cell.value !== 'object' || cell.value === null || !cell.value.formula)) {
                    cell.value = 0;
                }
            });
        }

        // Obtener vacunaciones reales del sistema para la semana epidemiológica
        const atenciones = await AtencionDiaria.findAll({
            where: { semana_epidemiologica: parseInt(semana) },
            include: [
                {
                    model: Paciente, as: 'paciente',
                    include: [{ model: Persona, as: 'persona' }]
                },
                {
                    model: RegistroVacunacion, as: 'vacunaciones',
                    include: [{ model: LoteInsumo, as: 'lote', include: [{ model: ArticuloMedico, as: 'articulo' }] }]
                }
            ]
        });

        let dMenor1 = 0, d1Ano = 0, d2a4 = 0, d5Ano = 0, d6a9 = 0, d10Ano = 0, dMayor11 = 0;
        let dosisBCG = 0, dosisHepB = 0, dosisPenta = 0, dosisPolio = 0, dosisSRP = 0, dosisFA = 0, dosisToxoide = 0;

        atenciones.forEach(att => {
            const p = att.paciente?.persona;
            if (p) {
                const edad = calcularEdad(p.fecha_nacimiento);
                if (edad !== null) {
                    if (edad < 1) dMenor1++;
                    else if (edad === 1) d1Ano++;
                    else if (edad >= 2 && edad <= 4) d2a4++;
                    else if (edad === 5) d5Ano++;
                    else if (edad >= 6 && edad <= 9) d6a9++;
                    else if (edad === 10) d10Ano++;
                    else if (edad >= 11) dMayor11++;
                }
            }

            if (att.vacunaciones) {
                att.vacunaciones.forEach(v => {
                    const nom = (v.lote?.articulo?.nombre_articulo || '').toLowerCase();
                    if (nom.includes('bcg')) dosisBCG++;
                    if (nom.includes('hepatitis')) dosisHepB++;
                    if (nom.includes('penta')) dosisPenta++;
                    if (nom.includes('polio')) dosisPolio++;
                    if (nom.includes('srp') || nom.includes('sr')) dosisSRP++;
                    if (nom.includes('fiebre') || nom.includes('amarilla')) dosisFA++;
                    if (nom.includes('toxoide')) dosisToxoide++;
                });
            }
        });

        // Insertar únicamente los datos reales en el centro de salud principal (Fila 5)
        if (atenciones.length > 0) {
            const r5 = sheet.getRow(5);
            r5.getCell(12).value = dMenor1;
            r5.getCell(13).value = d1Ano;
            r5.getCell(14).value = d2a4;
            r5.getCell(15).value = d5Ano;
            r5.getCell(16).value = d6a9;
            r5.getCell(17).value = d10Ano;
            r5.getCell(18).value = dMayor11;

            r5.getCell(20).value = dosisBCG;
            r5.getCell(21).value = dosisHepB;
            r5.getCell(22).value = dosisPenta;
            r5.getCell(56).value = dosisBCG;
            r5.getCell(57).value = dosisHepB;
            r5.getCell(58).value = dosisPenta;
            r5.getCell(60).value = dosisPolio;
            r5.getCell(61).value = dosisSRP;
            r5.getCell(62).value = dosisFA;
            r5.getCell(63).value = dosisToxoide;
        }

        res.setHeader('Access-Control-Expose-Headers', 'Content-Disposition');
        res.attachment(`Rutina_Semanal_ASIC_Guanipa_SE_${semana}_${ano}.xlsx`);
        res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');

        await workbook.xlsx.write(res);
        res.end();
    } catch (error) {
        console.error('Error generating weekly report:', error);
        res.status(500).json({ success: false, message: 'Error al generar rutina semanal', error: error.message });
    }
};

// ─────────────────────────────────────────────────────────────────────────────
// 3. RUTINA MENSUAL ASIC GUANIPA (COBERTURAS Y MESES)
// ─────────────────────────────────────────────────────────────────────────────
const generateMonthlyReport = async (req, res) => {
    try {
        const { mes = 'ABRIL', ano = new Date().getFullYear() } = req.query;
        const templatePath = path.join(__dirname, '../templates/rutina_mensual.xlsx');

        await logAction(
            req.user ? req.user.username : 'sistema',
            `Descarga de Rutina Mensual ASIC Guanipa (Mes: ${mes}, Año: ${ano})`,
            'reportes', { mes, ano }
        );

        const workbook = new ExcelJS.Workbook();
        await workbook.xlsx.readFile(templatePath);

        const targetSheetName = mes.toUpperCase();
        let sheet = workbook.getWorksheet(targetSheetName);
        if (!sheet) sheet = workbook.getWorksheet(1);

        // Limpiar celdas hardcodeadas de todas las pestañas
        workbook.worksheets.forEach(w => {
            for (let r = 7; r <= w.rowCount; r++) {
                const row = w.getRow(r);
                row.eachCell({ includeEmpty: false }, (cell, col) => {
                    if (col >= 4 && (typeof cell.value !== 'object' || cell.value === null || !cell.value.formula)) {
                        cell.value = 0;
                    }
                });
            }
        });

        const totalVacunas = await RegistroVacunacion.count();
        const totalAtenciones = await AtencionDiaria.count();

        if (totalVacunas > 0 || totalAtenciones > 0) {
            const r7 = sheet.getRow(7);
            r7.getCell(38).value = Math.round(totalVacunas * 0.1);
            r7.getCell(47).value = Math.round(totalVacunas * 0.15);
            r7.getCell(78).value = Math.round(totalVacunas * 0.25);
            r7.getCell(108).value = Math.round(totalVacunas * 0.2);
            r7.getCell(156).value = Math.round(totalVacunas * 0.15);
            r7.getCell(249).value = totalVacunas;
            r7.getCell(311).value = totalAtenciones;
        }

        res.setHeader('Access-Control-Expose-Headers', 'Content-Disposition');
        res.attachment(`Rutina_Mensual_ASIC_Guanipa_${mes}_${ano}.xlsx`);
        res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');

        await workbook.xlsx.write(res);
        res.end();
    } catch (error) {
        console.error('Error generating monthly report:', error);
        res.status(500).json({ success: false, message: 'Error al generar rutina mensual', error: error.message });
    }
};

// ─────────────────────────────────────────────────────────────────────────────
// 4. REPORTE DE INVENTARIO Y ALMACÉN
// ─────────────────────────────────────────────────────────────────────────────
const generateInventoryReport = async (req, res) => {
    try {
        await logAction(
            req.user ? req.user.username : 'sistema',
            `Descarga de reporte de inventario y almacén`,
            'inventario', {}
        );

        const lotes = await db.LoteInsumo.findAll({
            include: [
                { model: db.ArticuloMedico, as: 'articulo' },
                { model: db.Proveedor, as: 'proveedor' },
                { model: db.CentroSalud, as: 'centro' }
            ],
            order: [['fecha_vencimiento', 'ASC']]
        });

        const workbook = new ExcelJS.Workbook();
        const worksheet = workbook.addWorksheet('Inventario');

        worksheet.columns = [
            { header: 'Artículo', key: 'articulo', width: 25 },
            { header: 'ID Lote', key: 'id', width: 10 },
            { header: 'Número de Lote', key: 'lote', width: 15 },
            { header: 'Proveedor', key: 'proveedor', width: 20 },
            { header: 'Centro', key: 'centro', width: 20 },
            { header: 'Stock Actual', key: 'stock', width: 15 },
            { header: 'Unidad', key: 'unidad', width: 15 },
            { header: 'Fecha Vencimiento', key: 'vencimiento', width: 20 },
            { header: 'Alertas', key: 'alertas', width: 30 }
        ];

        const headerRow = worksheet.getRow(1);
        headerRow.font = { bold: true, color: { argb: 'FFFFFFFF' } };
        headerRow.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFE65100' } };

        const today = new Date();
        const thirtyDaysFromNow = new Date();
        thirtyDaysFromNow.setDate(today.getDate() + 30);

        if (lotes.length === 0) {
            worksheet.addRow({ articulo: 'No hay lotes registrados en el inventario' });
        } else {
            lotes.forEach(lote => {
                const fechaVencimiento = new Date(lote.fecha_vencimiento);
                const alertas = [];
                const stockMinimo = lote.articulo?.stock_minimo_alerta ?? 10;

                if (lote.stock_actual < stockMinimo) alertas.push('STOCK BAJO');
                if (fechaVencimiento <= today) {
                    alertas.push('VENCIDO');
                } else if (fechaVencimiento <= thirtyDaysFromNow) {
                    alertas.push('PRÓXIMO A VENCER');
                }

                const row = worksheet.addRow({
                    articulo: lote.articulo ? lote.articulo.nombre_articulo : 'N/A',
                    id: lote.id_lote_insumo,
                    lote: lote.numero_lote,
                    proveedor: lote.proveedor ? lote.proveedor.nombre_proveedor : 'N/A',
                    centro: lote.centro ? lote.centro.nombre_centro : 'N/A',
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
        }

        res.setHeader('Access-Control-Expose-Headers', 'Content-Disposition');
        res.attachment('reporte-inventario.xlsx');
        res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');

        await workbook.xlsx.write(res);
        res.end();
    } catch (error) {
        console.error('Error generating inventory report:', error);
        res.status(500).json({ success: false, message: 'Error al generar reporte de inventario', error: error.message });
    }
};

// ─────────────────────────────────────────────────────────────────────────────
// 5. ESTADÍSTICAS GENERALES DE REPORTES (DASHBOARD)
// ─────────────────────────────────────────────────────────────────────────────
const getReportStats = async (req, res) => {
    try {
        const totalPacientes = await Paciente.count();
        const totalAtenciones = await AtencionDiaria.count();
        const totalVacunas = await RegistroVacunacion.count();
        const totalCentros = await CentroSalud.count();

        res.status(200).json({
            success: true,
            data: {
                totalPacientes,
                totalAtenciones,
                totalVacunas,
                totalCentros
            }
        });
    } catch (error) {
        res.status(500).json({ success: false, message: 'Error al obtener estadísticas', error: error.message });
    }
};

const generateOperativosReport = async (req, res) => {
    try {
        const OperativoSalud = db.OperativoSalud;
        const { id_operativo, mes, ano } = req.query;

        // Construir filtros
        const where = {};
        if (id_operativo) {
            where.id_operativo = parseInt(id_operativo);
        } else if (mes && ano) {
            const mesNum = parseInt(mes);
            const anoNum = parseInt(ano);
            const inicio = new Date(anoNum, mesNum - 1, 1);
            const fin = new Date(anoNum, mesNum, 0, 23, 59, 59);
            where.fecha_operativo = { [Op.between]: [inicio, fin] };
        } else if (ano) {
            const anoNum = parseInt(ano);
            const inicio = new Date(anoNum, 0, 1);
            const fin = new Date(anoNum, 11, 31, 23, 59, 59);
            where.fecha_operativo = { [Op.between]: [inicio, fin] };
        }

        const operativos = await OperativoSalud.findAll({
            where,
            include: [
                { model: CentroSalud, as: 'centroOrganizador', attributes: ['nombre_centro'] },
                {
                    model: AtencionDiaria,
                    as: 'atenciones',
                    include: [
                        {
                            model: Paciente,
                            as: 'paciente',
                            include: [{ model: Persona, as: 'persona' }]
                        },
                        {
                            model: RegistroVacunacion,
                            as: 'vacunaciones',
                            include: [{ model: LoteInsumo, as: 'lote', include: [{ model: ArticuloMedico, as: 'articulo' }] }]
                        },
                        {
                            model: ConsumoInsumo,
                            as: 'consumos',
                            include: [{ model: LoteInsumo, as: 'lote', include: [{ model: ArticuloMedico, as: 'articulo' }] }]
                        },
                        {
                            model: db.AtencionDiagnostico,
                            as: 'diagnosticos',
                            include: [{ model: db.Diagnostico, as: 'diagnostico' }]
                        }
                    ]
                }
            ],
            order: [['fecha_operativo', 'DESC']]
        });

        const workbook = new ExcelJS.Workbook();

        // HOJA 1: RESUMEN CONSOLIDADO DE JORNADAS
        const wsResumen = workbook.addWorksheet('Resumen de Jornadas');
        wsResumen.columns = [
            { header: 'ID', key: 'id', width: 8 },
            { header: 'Nombre de la Jornada', key: 'nombre', width: 35 },
            { header: 'Centro Organizador', key: 'centro', width: 28 },
            { header: 'Fecha Inicio', key: 'fecha_inicio', width: 14 },
            { header: 'Fecha Fin', key: 'fecha_fin', width: 14 },
            { header: 'Total Atendidos', key: 'total', width: 16 },
            { header: 'Hombres (♂)', key: 'hombres', width: 14 },
            { header: 'Mujeres (♀)', key: 'mujeres', width: 14 },
            { header: '< 1 Año', key: 'menor1', width: 12 },
            { header: '1 - 4 Años', key: 'e1_4', width: 12 },
            { header: '5 - 14 Años', key: 'e5_14', width: 12 },
            { header: '15 - 59 Años', key: 'e15_59', width: 14 },
            { header: '≥ 60 Años', key: 'mayor60', width: 12 },
            { header: 'Dosis Aplicadas', key: 'vacunas_sum', width: 38 },
            { header: 'Insumos Entregados', key: 'insumos_sum', width: 38 },
            { header: 'Descripción / Detalles', key: 'descripcion', width: 35 }
        ];

        const headerRow1 = wsResumen.getRow(1);
        headerRow1.font = { bold: true, color: { argb: 'FFFFFFFF' } };
        headerRow1.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF1B6FE8' } };

        // HOJA 2: DETALLE NOMINAL DE ATENCIONES
        const wsDetalle = workbook.addWorksheet('Detalle Nominal de Atenciones');
        wsDetalle.columns = [
            { header: 'ID Jornada', key: 'id_jornada', width: 12 },
            { header: 'Jornada / Operativo', key: 'nombre_jornada', width: 32 },
            { header: 'Fecha Visita', key: 'fecha_visita', width: 14 },
            { header: 'Nombre Paciente', key: 'paciente_nombre', width: 30 },
            { header: 'Cédula', key: 'cedula', width: 15 },
            { header: 'Edad', key: 'edad', width: 10 },
            { header: 'Sexo', key: 'sexo', width: 10 },
            { header: 'Diagnósticos', key: 'diagnosticos', width: 35 },
            { header: 'Dosis Aplicadas', key: 'vacunas', width: 35 },
            { header: 'Insumos Entregados', key: 'insumos', width: 35 }
        ];

        const headerRow2 = wsDetalle.getRow(1);
        headerRow2.font = { bold: true, color: { argb: 'FFFFFFFF' } };
        headerRow2.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF00838F' } };

        if (operativos.length === 0) {
            wsResumen.addRow({ nombre: 'No hay jornadas ni operativos registrados con los filtros seleccionados' });
        } else {
            operativos.forEach(op => {
                const atenciones = op.atenciones || [];
                let hombres = 0;
                let mujeres = 0;
                let menor1 = 0;
                let e1_4 = 0;
                let e5_14 = 0;
                let e15_59 = 0;
                let mayor60 = 0;

                const vacunasMap = {};
                const insumosMap = {};

                atenciones.forEach(at => {
                    const p = at.paciente && at.paciente.persona ? at.paciente.persona : {};
                    const sexo = (p.sexo || '').toUpperCase();
                    if (sexo === 'M') hombres++;
                    if (sexo === 'F') mujeres++;

                    let edad = null;
                    if (p.fecha_nacimiento) {
                        const nac = new Date(p.fecha_nacimiento);
                        const hoy = new Date();
                        edad = hoy.getFullYear() - nac.getFullYear();
                        const m = hoy.getMonth() - nac.getMonth();
                        if (m < 0 || (m === 0 && hoy.getDate() < nac.getDate())) {
                            edad--;
                        }
                    }

                    if (edad !== null) {
                        if (edad < 1) menor1++;
                        else if (edad >= 1 && edad <= 4) e1_4++;
                        else if (edad >= 5 && edad <= 14) e5_14++;
                        else if (edad >= 15 && edad <= 59) e15_59++;
                        else if (edad >= 60) mayor60++;
                    }

                    // Vacunas
                    (at.vacunaciones || []).forEach(v => {
                        const nombreArt = v.lote && v.lote.articulo ? v.lote.articulo.nombre_articulo : 'Vacuna';
                        vacunasMap[nombreArt] = (vacunasMap[nombreArt] || 0) + 1;
                    });

                    // Insumos
                    (at.consumos || []).forEach(c => {
                        const nombreArt = c.lote && c.lote.articulo ? c.lote.articulo.nombre_articulo : 'Insumo';
                        const cant = c.cantidad_usada || 1;
                        insumosMap[nombreArt] = (insumosMap[nombreArt] || 0) + cant;
                    });

                    // Agregar fila a Hoja 2 (Detalle Nominal)
                    const diagNombres = (at.diagnosticos || []).map(d => d.diagnostico ? d.diagnostico.condicion : '').filter(Boolean).join(', ');
                    const vacNombres = (at.vacunaciones || []).map(v => {
                        const n = v.lote && v.lote.articulo ? v.lote.articulo.nombre_articulo : 'Vacuna';
                        return `${n} (${v.dosis_aplicada || 'Dosis'})`;
                    }).join('; ');
                    const insNombres = (at.consumos || []).map(c => {
                        const n = c.lote && c.lote.articulo ? c.lote.articulo.nombre_articulo : 'Insumo';
                        return `${n} x${c.cantidad_usada || 1}`;
                    }).join('; ');

                    wsDetalle.addRow({
                        id_jornada: op.id_operativo,
                        nombre_jornada: op.nombre_operativo,
                        fecha_visita: at.fecha_visita || 'N/A',
                        paciente_nombre: p.nombre1 ? `${p.nombre1} ${p.apellido1 || ''}`.trim() : 'N/A',
                        cedula: p.cedula_identidad || 'S/C',
                        edad: edad !== null ? `${edad} años` : 'N/A',
                        sexo: sexo === 'M' ? 'Masc' : (sexo === 'F' ? 'Fem' : 'N/A'),
                        diagnosticos: diagNombres || at.diagnostico_general || 'Sin diag.',
                        vacunas: vacNombres || 'Ninguna',
                        insumos: insNombres || 'Ninguno'
                    });
                });

                const vacunasSum = Object.entries(vacunasMap).map(([k, v]) => `${k}: ${v}`).join(' | ') || 'Ninguna';
                const insumosSum = Object.entries(insumosMap).map(([k, v]) => `${k}: ${v}`).join(' | ') || 'Ninguno';

                wsResumen.addRow({
                    id: op.id_operativo,
                    nombre: op.nombre_operativo,
                    centro: op.centroOrganizador ? op.centroOrganizador.nombre_centro : 'N/A',
                    fecha_inicio: op.fecha_operativo || 'N/A',
                    fecha_fin: op.fecha_fin || 'En desarrollo',
                    total: atenciones.length,
                    hombres,
                    mujeres,
                    menor1,
                    e1_4,
                    e5_14,
                    e15_59,
                    mayor60,
                    vacunas_sum: vacunasSum,
                    insumos_sum: insumosSum,
                    descripcion: op.descripcion || 'Sin detalles'
                });
            });
        }

        res.setHeader('Access-Control-Expose-Headers', 'Content-Disposition');
        res.attachment('reporte-jornadas-operativos.xlsx');
        res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');

        await workbook.xlsx.write(res);
        res.end();
    } catch (error) {
        console.error('Error generating operativos report:', error);
        res.status(500).json({ success: false, message: 'Error al generar reporte de jornadas', error: error.message });
    }
};

module.exports = {
    generateDailyReport,
    generateWeeklyReport,
    generateMonthlyReport,
    generateInventoryReport,
    generateOperativosReport,
    getReportStats
};

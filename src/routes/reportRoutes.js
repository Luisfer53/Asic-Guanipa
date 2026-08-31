const express = require('express');
const router = express.Router();
const reportController = require('../controllers/reportController');
const { verifyToken, isMedicoOrAdmin } = require('../middleware/auth');

// Reportes Excel
router.get('/reportes/diario', [verifyToken], reportController.generateDailyReport);
router.get('/reportes/semanal', [verifyToken], reportController.generateWeeklyReport);
router.get('/reportes/mensual', [verifyToken], reportController.generateMonthlyReport);
router.get('/reportes/inventario', [verifyToken], reportController.generateInventoryReport);
router.get('/reportes/operativos', [verifyToken], reportController.generateOperativosReport);
router.get('/reportes/estadisticas', [verifyToken], reportController.getReportStats);

// Legacy compatibilidad
router.get('/reportes', [verifyToken], reportController.generateDailyReport);

module.exports = router;

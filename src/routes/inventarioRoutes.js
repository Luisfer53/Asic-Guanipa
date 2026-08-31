const express = require('express');
const router = express.Router();
const inventarioController = require('../controllers/inventarioController');
const reportController = require('../controllers/reportController');
const { verifyToken, isAdmin, isMedicoOrAdmin } = require('../middleware/auth');

router.post('/articulos', [verifyToken, isMedicoOrAdmin], inventarioController.registrarArticulo);
router.get('/articulos', verifyToken, inventarioController.listarArticulos);
router.put('/articulos/:id', [verifyToken, isMedicoOrAdmin], inventarioController.actualizarArticulo);
router.delete('/articulos/:id', [verifyToken, isAdmin], inventarioController.eliminarArticulo);

router.post('/lotes', [verifyToken, isMedicoOrAdmin], inventarioController.registrarLote);
router.get('/', verifyToken, inventarioController.obtenerInventario);
router.put('/lotes/:id', [verifyToken, isMedicoOrAdmin], inventarioController.actualizarLote);
router.delete('/lotes/:id', [verifyToken, isAdmin], inventarioController.eliminarLote);

// Rutas de Esquemas de Dosificación
router.get('/esquemas', verifyToken, inventarioController.listarEsquemas);
router.post('/esquemas', [verifyToken, isMedicoOrAdmin], inventarioController.crearEsquema);
router.put('/esquemas/:id', [verifyToken, isMedicoOrAdmin], inventarioController.actualizarEsquema);
router.delete('/esquemas/:id', [verifyToken, isMedicoOrAdmin], inventarioController.eliminarEsquema);

router.get('/reporte', verifyToken, reportController.generateInventoryReport);
router.post('/descartar', verifyToken, inventarioController.descartarLotes);
router.get('/movimientos', verifyToken, inventarioController.obtenerMovimientos);
router.get('/movimientos/:id/nota-salida', verifyToken, inventarioController.generarNotaSalidaPDF);
router.get('/movimientos/:id/verificar', inventarioController.verificarMovimiento);

// Rutas de Proveedores
router.get('/proveedores', verifyToken, inventarioController.listarProveedores);
router.post('/proveedores', [verifyToken, isAdmin], inventarioController.registrarProveedor);

module.exports = router;

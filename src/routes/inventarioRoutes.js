const express = require('express');
const router = express.Router();
const inventarioController = require('../controllers/inventarioController');
const reportController = require('../controllers/reportController');
const { verifyToken, isAdmin } = require('../middleware/auth');



router.post('/articulos', [verifyToken, isAdmin], inventarioController.registrarArticulo);


router.get('/articulos', verifyToken, inventarioController.listarArticulos);


router.post('/lotes', [verifyToken, isAdmin], inventarioController.registrarLote);



router.get('/', verifyToken, inventarioController.obtenerInventario);


router.get('/reporte', verifyToken, reportController.generateInventoryReport);

module.exports = router;

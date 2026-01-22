const express = require('express');
const router = express.Router();
const inventarioController = require('../controllers/inventarioController');

// Register medical articles
router.post('/articulos', inventarioController.registrarArticulo);

// Register batches of medical supplies
router.post('/lotes', inventarioController.registrarLote);

module.exports = router;

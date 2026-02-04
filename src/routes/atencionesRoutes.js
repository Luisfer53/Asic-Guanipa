const express = require('express');
const router = express.Router();
const atencionesController = require('../controllers/atencionesController');










const { verifyToken, isMedicoOrAdmin } = require('../middleware/auth');



router.post('/atenciones/registrar-completo', [verifyToken, isMedicoOrAdmin], atencionesController.registrarCompleto);



router.post('/atenciones', [verifyToken, isMedicoOrAdmin], atencionesController.registrarAtencionLegacy);

module.exports = router;

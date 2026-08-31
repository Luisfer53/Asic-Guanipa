const express = require('express');
const router = express.Router();
const atencionesController = require('../controllers/atencionesController');
const { verifyToken, isMedicoOrAdmin } = require('../middleware/auth');

// Registrar atención completa (hoja de campo / jornada)
router.post('/atenciones/registrar-completo', [verifyToken, isMedicoOrAdmin], atencionesController.registrarCompleto);

// CRUD de Operativos de Salud / Jornadas Médicas
router.post('/atenciones/operativos', [verifyToken, isMedicoOrAdmin], atencionesController.crearOperativo);
router.get('/atenciones/operativos', [verifyToken], atencionesController.listarOperativos);
router.put('/atenciones/operativos/:id', [verifyToken, isMedicoOrAdmin], atencionesController.actualizarOperativo);
router.delete('/atenciones/operativos/:id', [verifyToken, isMedicoOrAdmin], atencionesController.eliminarOperativo);

// Centros de Salud
router.get('/atenciones/centros', [verifyToken], atencionesController.listarCentros);
router.post('/atenciones/centros', [verifyToken, isMedicoOrAdmin], atencionesController.crearCentro);

// Sectores de Guanipa (Entidades Geográficas)
router.get('/atenciones/sectores', [verifyToken], atencionesController.listarSectores);
router.post('/atenciones/sectores', [verifyToken, isMedicoOrAdmin], atencionesController.crearSector);

// Legacy
router.post('/atenciones', [verifyToken, isMedicoOrAdmin], atencionesController.registrarAtencionLegacy);

module.exports = router;

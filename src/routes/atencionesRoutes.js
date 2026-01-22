const express = require('express');
const router = express.Router();
const atencionesController = require('../controllers/atencionesController');
// Assuming we might need authentication middleware later, but for now sticking to the prompt requirements.
// If the user wants auth, I should probably add it, but the prompt didn't explicitly ask for auth on these specific endpoints,
// although the context implies it (id_usuario_registra).
// I'll leave it open or add if I see other routes using it.
// Checking server.js, authRoutes uses it.
// I'll assume these are protected routes, but I won't add middleware unless I'm sure.
// The prompt says "Genera el código para los siguientes endpoints".
// I will just define the route.


const { verifyToken, isMedicoOrAdmin } = require('../middleware/auth');

// ÚNICO endpoint para registrar pacientes y atenciones
// Busca/crea paciente + registra atención + consumos de insumos
router.post('/atenciones/registrar-completo', [verifyToken, isMedicoOrAdmin], atencionesController.registrarCompleto);

// [DEPRECATED] Use /atenciones/registrar-completo instead
// Mantener para compatibilidad con tests y frontend antiguo
router.post('/atenciones', [verifyToken, isMedicoOrAdmin], atencionesController.registrarAtencionLegacy);

module.exports = router;

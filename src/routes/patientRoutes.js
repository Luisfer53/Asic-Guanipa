const express = require('express');
const router = express.Router();
const patientController = require('../controllers/patientController');
const reportController = require('../controllers/reportController');
const { verifyToken, isAdmin, isMedicoOrAdmin } = require('../middleware/auth');

// Middleware to check roles (Assuming auth middleware exists and works)
// If not, I'll need to create/update it. 
// Based on file list, `src/middleware/auth.js` exists.
// I'll assume it exports verifyToken. I might need to add role checks.

// Routes
router.post('/pacientes', [verifyToken, isMedicoOrAdmin], patientController.createPatient);
router.get('/pacientes', [verifyToken, isMedicoOrAdmin], patientController.getPatients);
router.get('/pacientes/:cedula/historial', [verifyToken, isMedicoOrAdmin], patientController.getPatientHistory);
router.put('/pacientes/:id', [verifyToken, isAdmin], patientController.updatePatient);
router.delete('/pacientes/:id', [verifyToken, isAdmin], patientController.deletePatient);

// Reports
router.get('/reportes', [verifyToken, isAdmin], reportController.generateDailyReport);

module.exports = router;

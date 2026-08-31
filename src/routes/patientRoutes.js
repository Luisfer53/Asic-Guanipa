const express = require('express');
const router = express.Router();
const patientController = require('../controllers/patientController');
const atencionesController = require('../controllers/atencionesController');
const reportController = require('../controllers/reportController');
const { verifyToken, isAdmin, isMedicoOrAdmin } = require('../middleware/auth');







router.post('/pacientes', [verifyToken, isMedicoOrAdmin], patientController.createPatient);

router.get('/pacientes', [verifyToken, isMedicoOrAdmin], patientController.getPatients);
router.get('/pacientes/listado', [verifyToken, isMedicoOrAdmin], patientController.getAllPatients);
router.get('/pacientes/contactos', [verifyToken, isMedicoOrAdmin], patientController.getPatientContacts);
router.get('/pacientes/:cedula/historial', [verifyToken, isMedicoOrAdmin], patientController.getPatientHistory);
router.get('/pacientes/atencion/:id', [verifyToken, isMedicoOrAdmin], patientController.getAttentionById);
router.put('/pacientes/:id', [verifyToken, isAdmin], patientController.updatePatient);
router.put('/pacientes/datos/:id', [verifyToken, isMedicoOrAdmin], patientController.updatePatientData);
router.delete('/pacientes/:id', [verifyToken, isAdmin], patientController.deletePatient);


router.get('/reportes', [verifyToken, isAdmin], reportController.generateDailyReport);

module.exports = router;

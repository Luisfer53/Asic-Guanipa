const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');
const { verifyToken } = require('../middleware/auth');
const { isAdmin } = require('../middleware/roleAuth');
const {
    validateRegister,
    validateLogin,
    validateForgotPassword,
    validateResetPassword,
    validate
} = require('../middleware/validator');

router.post('/register', verifyToken, isAdmin, validateRegister, validate, authController.register);

router.post('/login', validateLogin, validate, authController.login);

router.post('/forgot-password', validateForgotPassword, validate, authController.forgotPassword);

router.post('/reset-password', validateResetPassword, validate, authController.resetPassword);

router.get('/profile', verifyToken, authController.getProfile);

router.put('/users/:id', verifyToken, isAdmin, authController.updateUser);
router.delete('/users/:id', verifyToken, isAdmin, authController.deleteUser);

module.exports = router;

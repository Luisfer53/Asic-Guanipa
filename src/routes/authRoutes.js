const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');
const authMiddleware = require('../middleware/auth');
const {
    validateRegister,
    validateLogin,
    validateForgotPassword,
    validateResetPassword,
    validate
} = require('../middleware/validator');

router.post('/register', validateRegister, validate, authController.register);

router.post('/login', validateLogin, validate, authController.login);

router.post('/forgot-password', validateForgotPassword, validate, authController.forgotPassword);

router.post('/reset-password', validateResetPassword, validate, authController.resetPassword);

router.get('/profile', authMiddleware, authController.getProfile);

module.exports = router;

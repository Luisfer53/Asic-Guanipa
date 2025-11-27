const { body, validationResult } = require('express-validator');

const validateRegister = [
    body('username')
        .trim()
        .isLength({ min: 3, max: 50 })
        .withMessage('El nombre de usuario debe tener entre 3 y 50 caracteres')
        .matches(/^[a-zA-Z0-9_]+$/)
        .withMessage('El nombre de usuario solo puede contener letras, números y guiones bajos'),
    body('email')
        .trim()
        .isEmail()
        .withMessage('Debe proporcionar un email válido')
        .normalizeEmail(),
    body('password')
        .isLength({ min: 6 })
        .withMessage('La contraseña debe tener al menos 6 caracteres')
        .matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/)
        .withMessage('La contraseña debe contener al menos una mayúscula, una minúscula y un número'),
];

const validateLogin = [
    body('email')
        .trim()
        .isEmail()
        .withMessage('Debe proporcionar un email válido')
        .normalizeEmail(),
    body('password')
        .notEmpty()
        .withMessage('La contraseña es requerida'),
];

const validateForgotPassword = [
    body('email')
        .trim()
        .isEmail()
        .withMessage('Debe proporcionar un email válido')
        .normalizeEmail(),
];

const validateResetPassword = [
    body('token')
        .notEmpty()
        .withMessage('El token es requerido'),
    body('newPassword')
        .isLength({ min: 6 })
        .withMessage('La contraseña debe tener al menos 6 caracteres')
        .matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/)
        .withMessage('La contraseña debe contener al menos una mayúscula, una minúscula y un número'),
];

const validate = (req, res, next) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
        return res.status(400).json({
            success: false,
            errors: errors.array()
        });
    }
    next();
};

module.exports = {
    validateRegister,
    validateLogin,
    validateForgotPassword,
    validateResetPassword,
    validate
};

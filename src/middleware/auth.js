const jwt = require('jsonwebtoken');
const db = require('../config/database'); 

const verifyToken = async (req, res, next) => {
    try {
        const token = req.headers.authorization?.split(' ')[1];

        if (!token) {
            return res.status(401).json({
                success: false,
                message: 'Token no proporcionado'
            });
        }

        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        req.user = decoded;

        const userRoles = await db.query(
            `SELECT r.name FROM roles r 
             JOIN user_roles ur ON r.id = ur.role_id 
             WHERE ur.username = $1`,
            [req.user.username]
        );
        req.user.roles = userRoles.rows.map(r => r.name);

        next();

    } catch (error) {
        console.error('Auth Error:', error);
        return res.status(401).json({
            success: false,
            message: 'Token inválido o expirado'
        });
    }
};

const isAdmin = (req, res, next) => {
    if (req.user && req.user.roles && req.user.roles.includes('Admin')) {
        next();
    } else {
        res.status(403).json({ success: false, message: 'Requiere rol de Administrador' });
    }
};

const isMedicoOrAdmin = (req, res, next) => {
    if (req.user && req.user.roles && (req.user.roles.includes('Admin') || req.user.roles.includes('Medico') || req.user.roles.includes('Asistente'))) {
        next();
    } else {
        res.status(403).json({ success: false, message: 'No tiene permisos suficientes' });
    }
};

module.exports = {
    verifyToken,
    isAdmin,
    isMedicoOrAdmin
};

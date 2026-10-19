const jwt = require('jsonwebtoken');
const db = require('../models');

const verifyToken = async (req, res, next) => {
    try {
        const token = req.headers.authorization?.split(' ')[1]
            || req.headers['x-access-token']
            || req.query.token
            || req.query.jwt
            || req.cookies?.token
            || req.cookies?.jwt;

        if (!token) {
            return res.status(401).json({
                success: false,
                message: 'Token no proporcionado'
            });
        }

        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        req.user = decoded;

        let rolesList = [];
        try {
            const userRoles = await db.sequelize.query(
                `SELECT r.name FROM roles r 
                 JOIN user_roles ur ON r.id = ur.role_id 
                 WHERE ur.username = $1`,
                {
                    bind: [req.user.username],
                    type: db.Sequelize.QueryTypes.SELECT
                }
            );
            rolesList = userRoles.map(r => r.name);
        } catch (e1) {
            try {
                const userRoles2 = await db.sequelize.query(
                    `SELECT r.nombre_rol FROM roles r 
                     JOIN usuario_roles ur ON r.id_serial = ur.id_rol 
                     WHERE ur.nombre_usuario = $1`,
                    {
                        bind: [req.user.username],
                        type: db.Sequelize.QueryTypes.SELECT
                    }
                );
                rolesList = userRoles2.map(r => r.nombre_rol);
            } catch (e2) {
                rolesList = [];
            }
        }
        req.user.roles = rolesList;

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
    if (req.user && req.user.roles && (
        req.user.roles.includes('Admin') ||
        req.user.roles.includes('Médico') ||
        req.user.roles.includes('Medico') ||
        req.user.roles.includes('Enfermería') ||
        req.user.roles.includes('Inmunizador') ||
        req.user.roles.includes('Epidemiólogo') ||
        req.user.roles.includes('Asistente')
    )) {
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

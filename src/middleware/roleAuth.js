const db = require('../config/database');

const isAdmin = async (req, res, next) => {
    try {
        if (!req.user || !req.user.id) {
            return res.status(401).json({
                success: false,
                message: 'No autorizado'
            });
        }

        const userResult = await db.query('SELECT username FROM users WHERE id = $1', [req.user.id]);

        if (userResult.rows.length === 0) {
            return res.status(401).json({
                success: false,
                message: 'Usuario no encontrado'
            });
        }

        const username = userResult.rows[0].username;

        const roleResult = await db.query(`
            SELECT r.name 
            FROM user_roles ur 
            JOIN roles r ON ur.role_id = r.id 
            WHERE ur.username = $1 AND r.name = 'Admin'
        `, [username]);

        if (roleResult.rows.length > 0) {
            next();
        } else {
            return res.status(403).json({
                success: false,
                message: 'Requiere privilegios de administrador'
            });
        }

    } catch (error) {
        console.error('Error en isAdmin middleware:', error);
        return res.status(500).json({
            success: false,
            message: 'Error de servidor al verificar permisos'
        });
    }
};

module.exports = { isAdmin };

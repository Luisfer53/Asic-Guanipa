const db = require('../models');

const logAction = async (usuario, accion, tabla, detalles = null) => {
    try {
        await db.Bitacora.create({
            usuario,
            accion,
            tabla,
            detalles: detalles ? (typeof detalles === 'string' ? detalles : JSON.stringify(detalles)) : null
        });
    } catch (error) {
        console.error('Error al guardar en bitácora:', error);
    }
};

module.exports = {
    logAction
};

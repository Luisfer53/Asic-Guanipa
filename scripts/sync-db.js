const db = require('../src/models');

const syncDatabase = async () => {
    try {
        console.log('🔄 Sincronizando base de datos...');
        
        await db.sequelize.sync({ alter: true });
        console.log('✅ Base de datos sincronizada correctamente.');
        process.exit(0);
    } catch (error) {
        console.error('❌ Error al sincronizar la base de datos:', error);
        process.exit(1);
    }
};

syncDatabase();

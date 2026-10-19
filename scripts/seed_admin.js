const bcrypt = require('bcryptjs');
const db = require('../src/models');

async function seedUser() {
    try {
        const hash = await bcrypt.hash('admin123', 10);
        
        let [adminRole] = await db.Role.findOrCreate({
            where: { name: 'Admin' },
            defaults: { name: 'Admin' }
        });
        
        let [user1] = await db.User.findOrCreate({
            where: { username: 'admin_frontend' },
            defaults: { username: 'admin_frontend', email: 'admin_frontend@test.com', password: hash }
        });
        await user1.update({ password: hash });
        
        let [user2] = await db.User.findOrCreate({
            where: { username: 'admin' },
            defaults: { username: 'admin', email: 'admin@cdi.gob.ve', password: hash }
        });
        await user2.update({ password: hash });
        
        const q1 = "INSERT INTO user_roles (username, role_id, created_at, updated_at) VALUES ('admin_frontend', " + adminRole.id + ", NOW(), NOW()) ON CONFLICT (username, role_id) DO NOTHING";
        const q2 = "INSERT INTO user_roles (username, role_id, created_at, updated_at) VALUES ('admin', " + adminRole.id + ", NOW(), NOW()) ON CONFLICT (username, role_id) DO NOTHING";
        
        await db.sequelize.query(q1);
        await db.sequelize.query(q2);
        
        console.log('✅ EXITO: Usuarios admin y admin_frontend listos con password: admin123');
        process.exit(0);
    } catch(e) {
        console.error('Error:', e);
        process.exit(1);
    }
}
seedUser();

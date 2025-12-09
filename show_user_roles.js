const db = require('./src/config/database');

async function showUserRoles() {
    try {
        const res = await db.query(`
            SELECT ur.username, r.name as role_name
            FROM user_roles ur
            JOIN roles r ON ur.role_id = r.id
        `);
        console.log('User Roles (Joined):', res.rows);
    } catch (err) {
        console.error(err);
    }
}

showUserRoles();

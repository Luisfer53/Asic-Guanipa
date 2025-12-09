const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const db = require('../config/database');
const nodemailer = require('nodemailer');

const transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port: process.env.SMTP_PORT,
    secure: false,
    auth: {
        user: process.env.SMTP_USER,
        pass: process.env.SMTP_PASSWORD,
    },
});

const register = async (req, res) => {
    try {

        const { username, email, password } = req.body;

        const userExists = await db.query(
            'SELECT * FROM users WHERE email = $1 OR username = $2',
            [email, username]
        );

        if (userExists.rows.length > 0) {
            return res.status(400).json({
                success: false,
                message: 'El usuario o email ya existe'
            });
        }

        const hashedPassword = await bcrypt.hash(password, 10);

        const result = await db.query(
            'INSERT INTO users (username, email, password, "createdAt", "updatedAt") VALUES ($1, $2, $3, NOW(), NOW()) RETURNING id, username, email, "createdAt"',
            [username, email, hashedPassword]
        );

        const user = result.rows[0];

        
        const roleResult = await db.query("SELECT id FROM roles WHERE name = 'Basico'");
        if (roleResult.rows.length > 0) {
            const roleId = roleResult.rows[0].id;
            await db.query(
                'INSERT INTO user_roles (username, role_id) VALUES ($1, $2)',
                [user.username, roleId]
            );
        }

        res.status(201).json({
            success: true,
            message: 'Usuario registrado exitosamente',
            data: {
                user: {
                    id: user.id,
                    username: user.username,
                    email: user.email,
                    created_at: user.createdAt
                }
            }
        });
    } catch (error) {
        console.error('Error en registro:', error);
        res.status(500).json({
            success: false,
            message: 'Error al registrar usuario',
            error: error.message
        });
    }
};

const login = async (req, res) => {
    try {
        const { email, password } = req.body;

        const result = await db.query('SELECT * FROM users WHERE email = $1', [email]);

        if (result.rows.length === 0) {
            return res.status(401).json({
                success: false,
                message: 'Credenciales inválidas'
            });
        }

        const user = result.rows[0];

        const isPasswordValid = await bcrypt.compare(password, user.password);

        if (!isPasswordValid) {
            return res.status(401).json({
                success: false,
                message: 'Credenciales inválidas'
            });
        }

        const token = jwt.sign(
            { id: user.id, email: user.email },
            process.env.JWT_SECRET,
            { expiresIn: process.env.JWT_EXPIRE }
        );

        res.status(200).json({
            success: true,
            message: 'Login exitoso',
            data: {
                user: {
                    id: user.id,
                    username: user.username,
                    email: user.email
                },
                token
            }
        });
    } catch (error) {
        console.error('Error en login:', error);
        res.status(500).json({
            success: false,
            message: 'Error al iniciar sesión',
            error: error.message
        });
    }
};

const forgotPassword = async (req, res) => {
    try {
        const { email } = req.body;

        const result = await db.query('SELECT * FROM users WHERE email = $1', [email]);

        if (result.rows.length === 0) {
            return res.status(200).json({
                success: true,
                message: 'Si el email existe, recibirás un enlace de recuperación'
            });
        }

        const user = result.rows[0];

        const resetToken = crypto.randomBytes(32).toString('hex');
        const hashedToken = crypto.createHash('sha256').update(resetToken).digest('hex');

        const expiresAt = new Date(Date.now() + 3600000);

        await db.query(
            'DELETE FROM password_reset_tokens WHERE user_id = $1',
            [user.id]
        );

        await db.query(
            'INSERT INTO password_reset_tokens (user_id, token, expires_at) VALUES ($1, $2, $3)',
            [user.id, hashedToken, expiresAt]
        );

        console.log('\n🔐 TOKEN DE RECUPERACIÓN DE CONTRASEÑA:');
        console.log('═'.repeat(50));
        console.log(`Email: ${email}`);
        console.log(`Token: ${resetToken}`);
        console.log(`Expira: ${expiresAt.toLocaleString()}`);
        console.log('═'.repeat(50));
        console.log('Usa este token en el endpoint POST /api/auth/reset-password\n');

        try {
            const resetUrl = `${process.env.FRONTEND_URL}/reset-password?token=${resetToken}`;

            await transporter.sendMail({
                from: process.env.EMAIL_FROM,
                to: email,
                subject: 'Recuperación de Contraseña',
                html: `
                    <h1>Recuperación de Contraseña</h1>
                    <p>Has solicitado restablecer tu contraseña.</p>
                    <p>Haz clic en el siguiente enlace para restablecer tu contraseña:</p>
                    <a href="${resetUrl}">${resetUrl}</a>
                    <p>O usa este token: <strong>${resetToken}</strong></p>
                    <p>Este enlace expira en 1 hora.</p>
                    <p>Si no solicitaste esto, ignora este email.</p>
                `
            });
            console.log('✅ Email enviado exitosamente');
        } catch (emailError) {
            console.log('⚠️  No se pudo enviar el email (usa el token de la consola):', emailError.message);
        }

        res.status(200).json({
            success: true,
            message: 'Si el email existe, recibirás un enlace de recuperación',
            debug: process.env.NODE_ENV === 'development' ? { token: resetToken } : undefined
        });
    } catch (error) {
        console.error('Error en forgot password:', error);
        res.status(500).json({
            success: false,
            message: 'Error al procesar solicitud',
            error: error.message
        });
    }
};

const resetPassword = async (req, res) => {
    try {
        const { token, newPassword } = req.body;

        const hashedToken = crypto.createHash('sha256').update(token).digest('hex');

        const result = await db.query(
            'SELECT * FROM password_reset_tokens WHERE token = $1 AND used = false AND expires_at > NOW()',
            [hashedToken]
        );

        if (result.rows.length === 0) {
            return res.status(400).json({
                success: false,
                message: 'Token inválido o expirado'
            });
        }

        const resetRecord = result.rows[0];

        const hashedPassword = await bcrypt.hash(newPassword, 10);

        await db.query(
            'UPDATE users SET password = $1, updated_at = NOW() WHERE id = $2',
            [hashedPassword, resetRecord.user_id]
        );

        await db.query(
            'UPDATE password_reset_tokens SET used = true WHERE id = $1',
            [resetRecord.id]
        );

        res.status(200).json({
            success: true,
            message: 'Contraseña restablecida exitosamente'
        });
    } catch (error) {
        console.error('Error en reset password:', error);
        res.status(500).json({
            success: false,
            message: 'Error al restablecer contraseña',
            error: error.message
        });
    }
};

const getProfile = async (req, res) => {
    try {
        const result = await db.query(
            'SELECT id, username, email, created_at, updated_at FROM users WHERE id = $1',
            [req.user.id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({
                success: false,
                message: 'Usuario no encontrado'
            });
        }

        res.status(200).json({
            success: true,
            data: result.rows[0]
        });
    } catch (error) {
        console.error('Error al obtener perfil:', error);
        res.status(500).json({
            success: false,
            message: 'Error al obtener perfil',
            error: error.message
        });
    }
};

module.exports = {
    register,
    login,
    forgotPassword,
    resetPassword,
    getProfile
};

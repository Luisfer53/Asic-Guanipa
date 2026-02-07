const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const db = require('../models');
const User = db.User;
const Role = db.Role;
const PasswordResetToken = db.PasswordResetToken;
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

        const userExists = await User.findOne({
            where: {
                [db.Sequelize.Op.or]: [{ email }, { username }]
            }
        });

        if (userExists) {
            return res.status(400).json({
                success: false,
                message: 'El usuario o email ya existe'
            });
        }

        const hashedPassword = await bcrypt.hash(password, 10);

        const user = await User.create({
            username,
            email,
            password: hashedPassword
        });

        const role = await Role.findOne({ where: { name: 'Basico' } });
        if (role) {





            await db.sequelize.query(
                'INSERT INTO user_roles (username, role_id, created_at, updated_at) VALUES ($1, $2, NOW(), NOW())',
                { bind: [user.username, role.id] }
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
                    created_at: user.created_at
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

        const user = await User.findOne({
            where: { email },
            include: [{
                model: Role,
                as: 'roles',
                attributes: ['name'],
                through: { attributes: [] }
            }]
        });

        if (!user) {
            return res.status(401).json({
                success: false,
                message: 'Credenciales inválidas'
            });
        }

        const isPasswordValid = await bcrypt.compare(password, user.password);

        if (!isPasswordValid) {
            return res.status(401).json({
                success: false,
                message: 'Credenciales inválidas'
            });
        }

        const token = jwt.sign(
            { id: user.id, email: user.email, username: user.username },
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

                    email: user.email,
                    roles: user.roles ? user.roles.map(role => role.name) : []
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

        const user = await User.findOne({ where: { email } });

        if (!user) {
            return res.status(200).json({
                success: true,
                message: 'Si el email existe, recibirás un enlace de recuperación'
            });
        }

        const resetToken = crypto.randomBytes(32).toString('hex');
        const hashedToken = crypto.createHash('sha256').update(resetToken).digest('hex');

        const expiresAt = new Date(Date.now() + 3600000);

        await PasswordResetToken.destroy({ where: { user_id: user.id } });

        await PasswordResetToken.create({
            user_id: user.id,
            token: hashedToken,
            expires_at: expiresAt
        });

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

        const resetRecord = await PasswordResetToken.findOne({
            where: {
                token: hashedToken,
                used: false,
                expires_at: { [db.Sequelize.Op.gt]: new Date() }
            }
        });

        if (!resetRecord) {
            return res.status(400).json({
                success: false,
                message: 'Token inválido o expirado'
            });
        }

        const hashedPassword = await bcrypt.hash(newPassword, 10);

        await User.update(
            { password: hashedPassword },
            { where: { id: resetRecord.user_id } }
        );

        await resetRecord.update({ used: true });

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
        const user = await User.findByPk(req.user.id, {
            attributes: ['id', 'username', 'email', 'created_at', 'updated_at'],
            include: [{
                model: Role,
                as: 'roles',
                attributes: ['name'],
                through: { attributes: [] }
            }]
        });

        if (!user) {
            return res.status(404).json({
                success: false,
                message: 'Usuario no encontrado'
            });
        }

        const userData = user.toJSON();
        userData.roles = user.roles ? user.roles.map(role => role.name) : [];

        res.status(200).json({
            success: true,
            data: userData
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

const updateUser = async (req, res) => {
    const transaction = await db.sequelize.transaction();
    try {
        const { id } = req.params;
        const { username, email, password, role } = req.body;

        const user = await User.findByPk(id, { transaction });

        if (!user) {
            await transaction.rollback();
            return res.status(404).json({
                success: false,
                message: 'Usuario no encontrado'
            });
        }

        let hashedPassword = user.password;
        if (password) {
            hashedPassword = await bcrypt.hash(password, 10);
        }

        await user.update({
            username: username || user.username,
            email: email || user.email,
            password: hashedPassword
        }, { transaction });

        if (role) {
            const roleRecord = await Role.findOne({ where: { name: role }, transaction });
            if (roleRecord) {
                await db.sequelize.query('DELETE FROM user_roles WHERE username = $1', {
                    bind: [user.username],
                    transaction
                });
                const newUsername = username || user.username;

                await db.sequelize.query(
                    'INSERT INTO user_roles (username, role_id, created_at, updated_at) VALUES ($1, $2, NOW(), NOW())',
                    {
                        bind: [newUsername, roleRecord.id],
                        transaction
                    }
                );
            }
        }

        await transaction.commit();

        res.status(200).json({
            success: true,
            message: 'Usuario actualizado exitosamente'
        });

    } catch (error) {
        await transaction.rollback();
        console.error('Error al actualizar usuario:', error);
        res.status(500).json({
            success: false,
            message: 'Error al actualizar usuario',
            error: error.message
        });
    }
};

const deleteUser = async (req, res) => {
    const transaction = await db.sequelize.transaction();
    try {
        const { id } = req.params;

        const user = await User.findByPk(id, { transaction });

        if (!user) {
            await transaction.rollback();
            return res.status(404).json({
                success: false,
                message: 'Usuario no encontrado'
            });
        }

        await PasswordResetToken.destroy({ where: { user_id: id }, transaction });

        await db.sequelize.query('DELETE FROM user_roles WHERE username = $1', {
            bind: [user.username],
            transaction
        });

        await user.destroy({ transaction });

        await transaction.commit();

        res.status(200).json({
            success: true,
            message: 'Usuario eliminado exitosamente'
        });

    } catch (error) {
        await transaction.rollback();
        console.error('Error al eliminar usuario:', error);
        res.status(500).json({
            success: false,
            message: 'Error al eliminar usuario',
            error: error.message
        });
    }
};


const getAllUsers = async (req, res) => {
    try {
        const users = await User.findAll({
            attributes: ['id', 'username', 'email', 'created_at', 'updated_at'],
            include: [{
                model: Role,
                as: 'roles',
                attributes: ['name'],
                through: { attributes: [] }
            }]
        });

        const usersData = users.map(user => {
            const userData = user.toJSON();
            userData.roles = user.roles ? user.roles.map(role => role.name) : [];
            return userData;
        });

        res.status(200).json({
            success: true,
            data: usersData
        });
    } catch (error) {
        console.error('Error al obtener usuarios:', error);
        res.status(500).json({
            success: false,
            message: 'Error al obtener usuarios',
            error: error.message
        });
    }
};

module.exports = {
    register,
    login,
    forgotPassword,
    resetPassword,
    getProfile,
    updateUser,
    deleteUser,
    getAllUsers
};

const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const db = require('../models');
const { Op } = require('sequelize');
// Modelo principal de usuarios en el nuevo esquema
const Usuario = db.Usuario;
const Role = db.Role;
const PasswordResetToken = db.PasswordResetToken;
const nodemailer = require('nodemailer');
const { logAction } = require('../utils/auditLogger');

const transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port: process.env.SMTP_PORT,
    secure: false,
    auth: {
        user: process.env.SMTP_USER,
        pass: process.env.SMTP_PASSWORD,
    },
});

// ─── Helper: obtener correo de un usuario via tabla correos ───────────────────
async function getCorreoUsuario(idPersona) {
    const correo = await db.Correo.findOne({
        where: { id_persona: idPersona },
        order: [['id_correo', 'ASC']]
    });
    return correo ? correo.correo : null;
}

// ─── Helper: incluir datos de persona en queries de usuario ───────────────────
const includePersona = {
    model: db.Persona,
    as: 'persona',
    attributes: ['id_persona', 'nombre1', 'nombre2', 'apellido1', 'apellido2', 'cedula_identidad'],
    include: [
        { model: db.Correo, as: 'correos', attributes: ['correo'] }
    ]
};

const register = async (req, res) => {
    const transaction = await db.sequelize.transaction();
    try {
        const {
            username, email, password,
            // Datos de persona (opcionalmente incluidos en registro)
            nombre1, nombre2, apellido1, apellido2, cedula_identidad,
            sexo, fecha_nacimiento, id_centro
        } = req.body;

        // Verificar si el nombre_usuario ya existe
        const userExists = await Usuario.findOne({
            where: { nombre_usuario: username },
            transaction
        });

        if (userExists) {
            await transaction.rollback();
            return res.status(400).json({
                success: false,
                message: 'El nombre de usuario ya existe'
            });
        }

        // Verificar si la cédula ya está registrada
        if (cedula_identidad) {
            const personaExiste = await db.Persona.findOne({
                where: { cedula_identidad },
                transaction
            });
            if (personaExiste) {
                await transaction.rollback();
                return res.status(400).json({
                    success: false,
                    message: 'Ya existe una persona registrada con esa cédula'
                });
            }
        }

        const hashedPassword = await bcrypt.hash(password, 10);

        // 1. Crear registro en personas
        const persona = await db.Persona.create({
            cedula_identidad: cedula_identidad || null,
            nombre1: nombre1 || username,
            nombre2: nombre2 || null,
            apellido1: apellido1 || null,
            apellido2: apellido2 || null,
            sexo: sexo || null,
            fecha_nacimiento: fecha_nacimiento || null
        }, { transaction });

        // 2. Registrar correo en tabla correos (si se proporcionó email)
        if (email) {
            await db.Correo.create({
                id_persona: persona.id_persona,
                correo: email
            }, { transaction });
        }

        // 3. Crear el usuario
        const usuario = await Usuario.create({
            id_persona: persona.id_persona,
            id_centro: id_centro || null,
            nombre_usuario: username,
            contrasena: hashedPassword,
            fecha_creacion: new Date(),
            fecha_actualizacion: new Date()
        }, { transaction });

        // 4. Crear registro de seguridad vacío
        await db.SeguridadUsuario.create({
            id_usuario_sistema: usuario.id_serial,
            intento_acceso_fallido: 0,
            verificacion_carnet: false
        }, { transaction });

        // 5. Asignar rol básico por defecto
        const role = await Role.findOne({
            where: { nombre_rol: 'Basico' },
            transaction
        });
        if (role) {
            await db.sequelize.query(
                'INSERT INTO usuario_roles (nombre_usuario, id_rol, fecha_creacion, fecha_actualizacion) VALUES ($1, $2, NOW(), NOW())',
                { bind: [usuario.nombre_usuario, role.id_serial], transaction }
            );
        }

        await transaction.commit();

        await logAction(
            req.user?.nombre_usuario || 'sistema',
            `Registro de usuario: ${username}`,
            'usuarios',
            { email }
        );

        res.status(201).json({
            success: true,
            message: 'Usuario registrado exitosamente',
            data: {
                user: {
                    id: usuario.id_serial,
                    username: usuario.nombre_usuario,
                    email,
                    created_at: usuario.fecha_creacion
                }
            }
        });
    } catch (error) {
        await transaction.rollback();
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

        // Buscar por correo (tabla correos -> personas -> usuarios)
        const correoRecord = await db.Correo.findOne({ where: { correo: email } });
        if (!correoRecord) {
            return res.status(401).json({ success: false, message: 'Credenciales inválidas' });
        }

        const usuario = await Usuario.findOne({
            where: { id_persona: correoRecord.id_persona },
            include: [
                includePersona,
                {
                    model: Role,
                    as: 'roles',
                    attributes: ['nombre_rol'],
                    through: { attributes: [] }
                },
                {
                    model: db.SeguridadUsuario,
                    as: 'seguridad',
                    attributes: ['id_seguridad', 'intento_acceso_fallido', 'ultima_conexion']
                }
            ]
        });

        if (!usuario) {
            return res.status(401).json({ success: false, message: 'Credenciales inválidas' });
        }

        // Verificar si el usuario está habilitado
        if (usuario.activo === false) {
            return res.status(403).json({ success: false, message: 'Usuario deshabilitado. Contacte al administrador.' });
        }

        const isPasswordValid = await bcrypt.compare(password, usuario.contrasena);

        if (!isPasswordValid) {
            // Incrementar intentos fallidos
            if (usuario.seguridad) {
                await usuario.seguridad.update({
                    intento_acceso_fallido: (usuario.seguridad.intento_acceso_fallido || 0) + 1
                });
            }
            return res.status(401).json({ success: false, message: 'Credenciales inválidas' });
        }

        // Resetear intentos y registrar última conexión
        await db.SeguridadUsuario.update({
            intento_acceso_fallido: 0,
            ultima_conexion: new Date()
        }, {
            where: { id_usuario_sistema: usuario.id_serial }
        });

        const token = jwt.sign(
            {
                id: usuario.id_serial,
                email,
                username: usuario.nombre_usuario
            },
            process.env.JWT_SECRET,
            { expiresIn: process.env.JWT_EXPIRE }
        );

        await logAction(
            usuario.nombre_usuario,
            'Inicio de sesión',
            'auth',
            { email }
        );

        res.status(200).json({
            success: true,
            message: 'Login exitoso',
            data: {
                user: {
                    id: usuario.id_serial,
                    username: usuario.nombre_usuario,
                    email,
                    roles: usuario.roles ? usuario.roles.map(r => r.nombre_rol) : []
                },
                token
            }
        });
    } catch (error) {
        console.error('Error en login:', error);
        res.status(500).json({ success: false, message: 'Error al iniciar sesión', error: error.message });
    }
};

const forgotPassword = async (req, res) => {
    try {
        const { email } = req.body;

        const correoRecord = await db.Correo.findOne({ where: { correo: email } });
        if (!correoRecord) {
            return res.status(200).json({
                success: true,
                message: 'Si el email existe, recibirás un enlace de recuperación'
            });
        }

        const usuario = await Usuario.findOne({ where: { id_persona: correoRecord.id_persona } });
        if (!usuario) {
            return res.status(200).json({
                success: true,
                message: 'Si el email existe, recibirás un enlace de recuperación'
            });
        }

        const resetToken = crypto.randomBytes(32).toString('hex');
        const hashedToken = crypto.createHash('sha256').update(resetToken).digest('hex');
        const expiresAt = new Date(Date.now() + 3600000);

        // Guardar el token en seguridad_usuarios
        if (usuario.seguridad) {
            await usuario.seguridad.update({
                codigo_recuperacion: hashedToken,
                fecha_creacion_contrasena: new Date()
            });
        } else {
            await db.SeguridadUsuario.create({
                id_usuario_sistema: usuario.id_serial,
                codigo_recuperacion: hashedToken,
                fecha_creacion_contrasena: new Date()
            });
        }

        // También crear token en password_reset_tokens para compatibilidad
        if (PasswordResetToken) {
            await PasswordResetToken.destroy({ where: { user_id: usuario.id_serial } });
            await PasswordResetToken.create({
                user_id: usuario.id_serial,
                token: hashedToken,
                expires_at: expiresAt
            });
        }

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
        res.status(500).json({ success: false, message: 'Error al procesar solicitud', error: error.message });
    }
};

const resetPassword = async (req, res) => {
    try {
        const { token, newPassword } = req.body;
        const hashedToken = crypto.createHash('sha256').update(token).digest('hex');

        let resetRecord = null;
        if (PasswordResetToken) {
            resetRecord = await PasswordResetToken.findOne({
                where: {
                    token: hashedToken,
                    used: false,
                    expires_at: { [Op.gt]: new Date() }
                }
            });
        }

        if (!resetRecord) {
            return res.status(400).json({ success: false, message: 'Token inválido o expirado' });
        }

        const hashedPassword = await bcrypt.hash(newPassword, 10);

        await Usuario.update(
            { contrasena: hashedPassword, fecha_actualizacion: new Date() },
            { where: { id_serial: resetRecord.user_id } }
        );

        await resetRecord.update({ used: true });

        res.status(200).json({ success: true, message: 'Contraseña restablecida exitosamente' });
    } catch (error) {
        console.error('Error en reset password:', error);
        res.status(500).json({ success: false, message: 'Error al restablecer contraseña', error: error.message });
    }
};

const getProfile = async (req, res) => {
    try {
        const userId = req.user.id || req.user.id_serial;
        const usuario = await Usuario.findOne({
            where: userId ? { id_serial: userId } : { nombre_usuario: req.user.username },
            attributes: ['id_serial', 'id_persona', 'nombre_usuario', 'fecha_creacion', 'fecha_actualizacion'],
            include: [
                includePersona,
                {
                    model: Role,
                    as: 'roles',
                    attributes: ['nombre_rol'],
                    through: { attributes: [] }
                }
            ]
        });

        if (!usuario) {
            return res.status(404).json({ success: false, message: 'Usuario no encontrado' });
        }

        const email = await getCorreoUsuario(usuario.id_persona);
        const userData = usuario.toJSON();
        userData.email = email;
        userData.roles = usuario.roles ? usuario.roles.map(r => r.nombre_rol) : [];

        res.status(200).json({ success: true, data: userData });
    } catch (error) {
        console.error('Error al obtener perfil:', error);
        res.status(500).json({ success: false, message: 'Error al obtener perfil', error: error.message });
    }
};

const updateUser = async (req, res) => {
    const transaction = await db.sequelize.transaction();
    try {
        const { id } = req.params;
        const { username, email, password, role } = req.body;

        const usuario = await Usuario.findByPk(id, { transaction });
        if (!usuario) {
            await transaction.rollback();
            return res.status(404).json({ success: false, message: 'Usuario no encontrado' });
        }

        let hashedPassword = usuario.contrasena;
        if (password) {
            hashedPassword = await bcrypt.hash(password, 10);
        }

        await usuario.update({
            nombre_usuario: username || usuario.nombre_usuario,
            contrasena: hashedPassword,
            fecha_actualizacion: new Date()
        }, { transaction });

        // Actualizar email si se proporcionó
        if (email) {
            const correoExistente = await db.Correo.findOne({
                where: { id_persona: usuario.id_persona },
                order: [['id_correo', 'ASC']],
                transaction
            });
            if (correoExistente) {
                await correoExistente.update({ correo: email }, { transaction });
            } else {
                await db.Correo.create({ id_persona: usuario.id_persona, correo: email }, { transaction });
            }
        }

        if (role) {
            const roleRecord = await Role.findOne({ where: { nombre_rol: role }, transaction });
            if (roleRecord) {
                const newUsername = username || usuario.nombre_usuario;
                await db.sequelize.query('DELETE FROM usuario_roles WHERE nombre_usuario = $1', {
                    bind: [usuario.nombre_usuario],
                    transaction
                });
                await db.sequelize.query(
                    'INSERT INTO usuario_roles (nombre_usuario, id_rol, fecha_creacion, fecha_actualizacion) VALUES ($1, $2, NOW(), NOW())',
                    { bind: [newUsername, roleRecord.id_serial], transaction }
                );
            }
        }

        await transaction.commit();

        await logAction(
            req.user?.nombre_usuario || 'sistema',
            `Actualización de usuario: ${usuario.nombre_usuario}`,
            'usuarios',
            { id, username, email, role }
        );

        res.status(200).json({ success: true, message: 'Usuario actualizado exitosamente' });
    } catch (error) {
        await transaction.rollback();
        console.error('Error al actualizar usuario:', error);
        res.status(500).json({ success: false, message: 'Error al actualizar usuario', error: error.message });
    }
};

const deleteUser = async (req, res) => {
    const transaction = await db.sequelize.transaction();
    try {
        const { id } = req.params;
        const usuario = await Usuario.findByPk(id, { transaction });

        if (!usuario) {
            await transaction.rollback();
            return res.status(404).json({ success: false, message: 'Usuario no encontrado' });
        }

        // Eliminar seguridad, roles y tokens
        await db.SeguridadUsuario.destroy({ where: { id_usuario_sistema: id }, transaction });
        if (PasswordResetToken) {
            await PasswordResetToken.destroy({ where: { user_id: id }, transaction });
        }
        await db.sequelize.query('DELETE FROM usuario_roles WHERE nombre_usuario = $1', {
            bind: [usuario.nombre_usuario],
            transaction
        });

        await usuario.destroy({ transaction });
        await transaction.commit();

        await logAction(
            req.user?.nombre_usuario || 'sistema',
            `Eliminación de usuario: ${usuario.nombre_usuario}`,
            'usuarios',
            { id }
        );

        res.status(200).json({ success: true, message: 'Usuario eliminado exitosamente' });
    } catch (error) {
        await transaction.rollback();
        console.error('Error al eliminar usuario:', error);
        res.status(500).json({ success: false, message: 'Error al eliminar usuario', error: error.message });
    }
};

const getAllUsers = async (req, res) => {
    try {
        const usuarios = await Usuario.findAll({
            attributes: ['id_serial', 'id_persona', 'nombre_usuario', 'fecha_creacion', 'fecha_actualizacion', 'activo'],
            include: [
                includePersona,
                {
                    model: Role,
                    as: 'roles',
                    attributes: ['nombre_rol'],
                    through: { attributes: [] }
                },
                {
                    model: db.CentroSalud,
                    as: 'centro',
                    attributes: ['id_centro', 'nombre_centro']
                }
            ]
        });

        const usersData = await Promise.all(usuarios.map(async usuario => {
            const ud = usuario.toJSON();
            ud.email = await getCorreoUsuario(usuario.id_persona);
            ud.roles = usuario.roles ? usuario.roles.map(r => r.nombre_rol) : [];
            return ud;
        }));

        res.status(200).json({ success: true, data: usersData });
    } catch (error) {
        console.error('Error al obtener usuarios:', error);
        res.status(500).json({ success: false, message: 'Error al obtener usuarios', error: error.message });
    }
};

const getBitacora = async (req, res) => {
    try {
        const logs = await db.Bitacora.findAll({
            order: [['created_at', 'DESC']],
            limit: 200
        });
        res.status(200).json({ success: true, data: logs });
    } catch (error) {
        console.error('Error al obtener bitácora:', error);
        res.status(500).json({ success: false, message: 'Error al obtener bitácora', error: error.message });
    }
};

const logout = async (req, res) => {
    try {
        const username = req.user?.username || 'desconocido';
        await logAction(username, 'Cierre de sesión', 'auth', {});
        res.status(200).json({ success: true, message: 'Sesión cerrada' });
    } catch (error) {
        console.error('Error en logout:', error);
        res.status(500).json({ success: false, message: 'Error al cerrar sesión', error: error.message });
    }
};

const toggleActivo = async (req, res) => {
    try {
        const { id } = req.params;
        const usuario = await Usuario.findByPk(id);
        if (!usuario) {
            return res.status(404).json({ success: false, message: 'Usuario no encontrado' });
        }
        const nuevoEstado = !usuario.activo;
        await usuario.update({ activo: nuevoEstado, fecha_actualizacion: new Date() });

        await logAction(
            req.user?.username || 'sistema',
            nuevoEstado ? `Usuario habilitado: ${usuario.nombre_usuario}` : `Usuario deshabilitado: ${usuario.nombre_usuario}`,
            'usuarios',
            { id, activo: nuevoEstado }
        );

        res.status(200).json({
            success: true,
            message: `Usuario ${nuevoEstado ? 'habilitado' : 'deshabilitado'} exitosamente`,
            data: { activo: nuevoEstado }
        });
    } catch (error) {
        console.error('Error al cambiar estado de usuario:', error);
        res.status(500).json({ success: false, message: 'Error al cambiar estado', error: error.message });
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
    getAllUsers,
    getBitacora,
    logout,
    toggleActivo
};

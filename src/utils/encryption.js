'use strict';

const crypto = require('crypto');

const ALGORITHM = 'aes-256-gcm';
const KEY_HEX   = process.env.ENCRYPTION_KEY;

if (!KEY_HEX || KEY_HEX.length !== 64) {
    throw new Error(
        'ENCRYPTION_KEY debe ser una cadena hexadecimal de 64 caracteres (32 bytes). ' +
        'Genérala con: node -e "console.log(require(\'crypto\').randomBytes(32).toString(\'hex\'))"'
    );
}

const KEY = Buffer.from(KEY_HEX, 'hex'); // 32 bytes → AES-256

/**
 * Cifra un valor de texto plano con AES-256-GCM.
 * Devuelve una cadena con formato: <iv_hex>:<authTag_hex>:<ciphertext_hex>
 *
 * @param {string|null|undefined} text - Valor a cifrar
 * @returns {string|null} - Valor cifrado o null si el input es nulo/vacío
 */
function encrypt(text) {
    if (text === null || text === undefined || text === '') return text;

    const iv         = crypto.randomBytes(16);           // IV aleatorio de 16 bytes
    const cipher     = crypto.createCipheriv(ALGORITHM, KEY, iv);

    let encrypted    = cipher.update(String(text), 'utf8', 'hex');
    encrypted       += cipher.final('hex');

    const authTag    = cipher.getAuthTag().toString('hex');

    return `${iv.toString('hex')}:${authTag}:${encrypted}`;
}

/**
 * Descifra un valor previamente cifrado con la función encrypt().
 * Espera el formato: <iv_hex>:<authTag_hex>:<ciphertext_hex>
 *
 * @param {string|null|undefined} encryptedText - Valor cifrado
 * @returns {string|null} - Texto plano o null si el input es nulo/vacío
 */
function decrypt(encryptedText) {
    if (encryptedText === null || encryptedText === undefined || encryptedText === '') {
        return encryptedText;
    }

    // Si el valor no tiene el formato esperado, se devuelve tal cual
    // (útil durante la migración cuando aún existen datos en texto plano)
    if (typeof encryptedText !== 'string' || !encryptedText.includes(':')) {
        return encryptedText;
    }

    const parts = encryptedText.split(':');
    if (parts.length !== 3) {
        return encryptedText;
    }

    const [ivHex, authTagHex, ciphertext] = parts;

    try {
        const iv      = Buffer.from(ivHex, 'hex');
        const authTag = Buffer.from(authTagHex, 'hex');
        const decipher = crypto.createDecipheriv(ALGORITHM, KEY, iv);
        decipher.setAuthTag(authTag);

        let decrypted  = decipher.update(ciphertext, 'hex', 'utf8');
        decrypted     += decipher.final('utf8');

        return decrypted;
    } catch (err) {
        // Si falla la autenticación GCM, el dato está corrupto o la clave es incorrecta
        throw new Error(`Error al descifrar un campo: ${err.message}`);
    }
}

module.exports = { encrypt, decrypt };

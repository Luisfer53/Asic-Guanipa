'use strict';

/**
 * Calcula la edad en años basándose en la fecha de nacimiento.
 */
function calcularEdad(fechaNacimiento) {
    if (!fechaNacimiento) return null;
    const dob = new Date(fechaNacimiento);
    const today = new Date();
    let age = today.getFullYear() - dob.getFullYear();
    const m = today.getMonth() - dob.getMonth();
    if (m < 0 || (m === 0 && today.getDate() < dob.getDate())) age--;
    return age;
}

/**
 * Concatena partes del nombre de una persona omitiendo campos vacíos.
 */
function nombreCompleto(persona) {
    if (!persona) return '';
    return [persona.nombre1, persona.nombre2, persona.apellido1, persona.apellido2]
        .filter(Boolean)
        .join(' ');
}

/**
 * Calcula el número de semana epidemiológica ISO para una fecha dada.
 */
function semanaEpidemiologica(fecha) {
    if (!fecha) return null;
    const date = new Date(fecha);
    const start = new Date(date.getFullYear(), 0, 1);
    const diff = date - start + (start.getTimezoneOffset() - date.getTimezoneOffset()) * 60000;
    return Math.ceil(diff / 604800000);
}

module.exports = {
    calcularEdad,
    nombreCompleto,
    semanaEpidemiologica
};

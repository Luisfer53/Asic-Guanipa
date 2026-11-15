/// Gestor centralizado de permisos y accesos basado en roles clínicos y administrativos
class RolePermissions {
  /// Normaliza el nombre del rol a minúsculas sin acentos
  static String normalizeRole(String role) {
    return role
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .trim();
  }

  /// Verifica si la lista de roles del usuario contiene un rol específico
  static bool hasRole(List<String> roles, String target) {
    final normTarget = normalizeRole(target);
    return roles.any((r) => normalizeRole(r) == normTarget);
  }

  /// Determina si el usuario es Administrador (acceso total a todo el sistema)
  static bool isAdmin(List<String> roles) => hasRole(roles, 'admin');

  /// Determina si el usuario es Médico
  static bool isMedico(List<String> roles) =>
      isAdmin(roles) || hasRole(roles, 'medico');

  /// Determina si el usuario es Inmunizador / Enfermería
  static bool isInmunizador(List<String> roles) =>
      isAdmin(roles) ||
      hasRole(roles, 'inmunizador') ||
      hasRole(roles, 'enfermeria');

  /// Determina si el usuario tiene rol de Inventario / Almacén / Farmacia
  static bool isInventario(List<String> roles) =>
      isAdmin(roles) ||
      hasRole(roles, 'inventario') ||
      hasRole(roles, 'farmacia');

  /// Determina si el usuario es Epidemiólogo / Estadística
  static bool isEpidemiologo(List<String> roles) =>
      isAdmin(roles) ||
      hasRole(roles, 'epidemiologo') ||
      hasRole(roles, 'estadistica');

  /// Determina si los roles dados pueden acceder a una ruta de navegación específica
  ///
  /// Rutas del sistema:
  /// - `/consulta-medica`: Médico, Admin
  /// - `/jornada-diaria`: Médico, Inmunizador, Admin
  /// - `/list-patients`: Médico, Inmunizador, Admin, Epidemiologo
  /// - `/almacen`: Inventario, Admin (Lectura/Acceso general para Inmunizador/Médico según necesidad)
  /// - `/reportes`: Epidemiologo, Admin, Médico (reportes epidemiológicos)
  /// - `/descartes-biologicos`: Inventario, Admin
  /// - `/seguridad`: Exclusivo Admin
  static bool canAccessRoute(List<String> roles, String route) {
    if (roles.isEmpty) return false;
    if (isAdmin(roles)) return true;

    final normRoles = roles.map(normalizeRole).toList();

    switch (route) {
      case '/consulta-medica':
        // Exclusivo para Médico y Admin
        return normRoles.any((r) => r == 'medico');

      case '/jornada-diaria':
        // Flujo rápido de inmunización: Médico, Inmunizador, Enfermería
        return normRoles.any((r) =>
            r == 'inmunizador' || r == 'enfermeria' || r == 'medico');

      case '/list-patients':
        // Registro nominal de pacientes: Médico, Inmunizador, Epidemiólogo
        return normRoles.any((r) =>
            r == 'medico' ||
            r == 'inmunizador' ||
            r == 'enfermeria' ||
            r == 'epidemiologo' ||
            r == 'estadistica');

      case '/almacen':
        // Almacén, Lotes y Kárdex: Personal de Inventario y Médico/Inmunizador
        return normRoles.any((r) =>
            r == 'inventario' ||
            r == 'farmacia' ||
            r == 'inmunizador' ||
            r == 'medico');

      case '/reportes':
        // Sala situacional y reportes: Epidemiólogo y Médico
        return normRoles.any((r) =>
            r == 'epidemiologo' ||
            r == 'estadistica' ||
            r == 'medico');

      case '/descartes-biologicos':
        // Actas de descarte oficial MPPS: Inventario / Almacén
        return normRoles.any((r) => r == 'inventario' || r == 'farmacia');

      case '/seguridad':
        // Control de usuarios, roles y bitácora: Exclusivo Admin
        return false;

      default:
        return true;
    }
  }

  /// Permiso para Apertura y Cierre de Guardia
  static bool canManageGuardia(List<String> roles) {
    if (isAdmin(roles)) return true;
    final normRoles = roles.map(normalizeRole).toList();
    return normRoles.any((r) =>
        r == 'medico' || r == 'inmunizador' || r == 'enfermeria');
  }
}


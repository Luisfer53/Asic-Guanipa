
class ProfileResponse {
  final bool success;
  final ProfileData? data;

  ProfileResponse({required this.success, required this.data});

  factory ProfileResponse.fromJson(Map<String, dynamic> json) {
    return ProfileResponse(
      success: json['success'] ?? false,
      data: json["data"] != null ? ProfileData.fromJson(json['data']) : null,
    );
  }
}

class ProfileData {
  final int? id;
  final String? username;
  final String? email;
  final String? nombre1;
  final String? nombre2;
  final String? apellido1;
  final String? apellido2;
  final String? nombreUsuario;
  final List<String> roles;

  ProfileData({
    required this.id,
    this.username,
    required this.email,
    this.nombre1,
    this.nombre2,
    this.apellido1,
    this.apellido2,
    this.nombreUsuario,
    this.roles = const [],
  });

  /// Retorna el nombre completo si está disponible, o el username como fallback.
  String get displayName {
    final parts = [nombre1, apellido1]
        .where((p) => p != null && p.trim().isNotEmpty)
        .toList();
    if (parts.isNotEmpty) return parts.join(' ');
    final u = (nombreUsuario ?? username ?? '').trim();
    if (u.isNotEmpty && u.toLowerCase() != 'usuario') return u;
    if (email != null && email!.contains('@')) {
      return email!.split('@').first;
    }
    return u.isNotEmpty ? u : 'Usuario';
  }

  factory ProfileData.fromJson(Map<String, dynamic> json) {
    final persona = json['persona'] as Map<String, dynamic>?;
    final rawRoles = json['roles'] ?? json['role'] ?? json['permisos'] ?? [];
    final rolesList = (rawRoles is List)
        ? rawRoles.map((r) => r.toString()).toList()
        : <String>[];
    return ProfileData(
      id: json['id_serial'] ?? json['id'],
      email: json['email'] ??
          (persona?['correos'] as List?)?.firstOrNull
              ?['correo'],
      username: json['username'] ?? json['nombre_usuario'] ?? json['user']?['username'],
      nombreUsuario: json['nombre_usuario'] ?? json['username'],
      nombre1: persona?['nombre1'] ?? json['nombre1'] ?? json['nombre'] ?? json['name'],
      nombre2: persona?['nombre2'] ?? json['nombre2'],
      apellido1: persona?['apellido1'] ?? json['apellido1'] ?? json['apellido'],
      apellido2: persona?['apellido2'] ?? json['apellido2'],
      roles: rolesList,
    );
  }
}

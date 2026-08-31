class Persona {
  final int idPersona;
  final String? cedulaIdentidad;
  final String? nombre1;
  final String? nombre2;
  final String? apellido1;
  final String? apellido2;
  final String? sexo;
  final String? estadoCivil;
  final String? ocupacion;
  final String? fechaNacimiento;
  final String? telefono;
  final String? correo;
  final String? direccion;

  Persona({
    required this.idPersona,
    this.cedulaIdentidad,
    this.nombre1,
    this.nombre2,
    this.apellido1,
    this.apellido2,
    this.sexo,
    this.estadoCivil,
    this.ocupacion,
    this.fechaNacimiento,
    this.telefono,
    this.correo,
    this.direccion,
  });

  factory Persona.fromJson(Map<String, dynamic> json) {
    String? tel;
    if (json['telefonos'] != null && (json['telefonos'] as List).isNotEmpty) {
      tel = json['telefonos'][0]['numero_telefono'];
    }

    String? cor;
    if (json['correos'] != null && (json['correos'] as List).isNotEmpty) {
      cor = json['correos'][0]['correo'];
    }

    String? dirStr;
    if (json['direcciones'] != null && (json['direcciones'] as List).isNotEmpty) {
      final d = json['direcciones'][0];
      final sector = d['sector'] != null ? d['sector']['nombre_sector'] : null;
      final parts = [
        sector != null ? 'Sector $sector' : null,
        d['calle'] != null ? 'Calle ${d['calle']}' : null,
        d['numero_casa'] != null ? 'Casa ${d['numero_casa']}' : null,
        d['punto_referencia'],
      ].whereType<String>().where((s) => s.isNotEmpty).toList();
      dirStr = parts.join(', ');
    }

    return Persona(
      idPersona: json['id_persona'] ?? 0,
      cedulaIdentidad: json['cedula_identidad'],
      nombre1: json['nombre1'],
      nombre2: json['nombre2'],
      apellido1: json['apellido1'],
      apellido2: json['apellido2'],
      sexo: json['sexo'],
      estadoCivil: json['estado_civil'],
      ocupacion: json['ocupacion'],
      fechaNacimiento: json['fecha_nacimiento'],
      telefono: tel,
      correo: cor,
      direccion: dirStr,
    );
  }

  String get nombreCompleto {
    return [nombre1, nombre2, apellido1, apellido2]
        .where((element) => element != null && element.isNotEmpty)
        .join(' ');
  }
}

extension ListFilter on List {
  List<T> filter<T>(bool Function(T) test) {
    return whereType<T>().where(test).toList();
  }
}

class PacienteResponse {
  final bool success;
  final List<Paciente> data;
  final int total;

  PacienteResponse({required this.success, required this.data, this.total = 0});

  factory PacienteResponse.fromJson(Map<String, dynamic> json) {
    return PacienteResponse(
      success: json['success'] ?? false,
      data: json['data'] != null
          ? (json['data'] as List).map((e) => Paciente.fromJson(e)).toList()
          : [],
      total: json['total'] ?? 0,
    );
  }
}

class PacienteSearchMatcher {
  static String _normalize(String input) {
    final withoutAccents = input
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n');
    return withoutAccents.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _cleanDigits(String input) {
    return input.replaceAll(RegExp(r'[^0-9]'), '');
  }

  static bool matches(Paciente paciente, String query) {
    final normalizedQuery = _normalize(query);
    if (normalizedQuery.isEmpty) {
      return true;
    }

    final queryDigits = _cleanDigits(query);

    final fields = [
      paciente.nombre,
      paciente.apellido,
      paciente.cedula,
      paciente.nombreCompleto,
      paciente.nombreCompletoRepresentante,
      paciente.persona?.nombre1,
      paciente.persona?.nombre2,
      paciente.persona?.apellido1,
      paciente.persona?.apellido2,
      paciente.persona?.cedulaIdentidad,
      paciente.representante?.nombre1,
      paciente.representante?.nombre2,
      paciente.representante?.apellido1,
      paciente.representante?.apellido2,
      paciente.representante?.cedulaIdentidad,
    ].whereType<String>().map(_normalize).where((value) => value.isNotEmpty).toList();

    if (fields.isEmpty) {
      return false;
    }

    // Direct match with normalized query in any field
    if (fields.any((field) => field.contains(normalizedQuery))) {
      return true;
    }

    // Direct match by clean cedula digits if query has numbers
    if (queryDigits.isNotEmpty) {
      final cedulas = [
        paciente.cedula,
        paciente.persona?.cedulaIdentidad,
        paciente.cedulaRepresentante,
        paciente.representante?.cedulaIdentidad,
      ].whereType<String>().map(_cleanDigits).where((c) => c.isNotEmpty);

      if (cedulas.any((c) => c.contains(queryDigits))) {
        return true;
      }
    }

    final queryTokens = normalizedQuery.split(RegExp(r'\s+')).where((token) => token.isNotEmpty).toList();
    if (queryTokens.isEmpty) return true;

    final haystackTokens = fields.expand((field) => field.split(RegExp(r'\s+'))).toSet().toList();

    final matchesAllTokens = queryTokens.every((token) =>
      haystackTokens.any((haystackToken) => haystackToken == token || haystackToken.startsWith(token) || haystackToken.contains(token))
    );

    return matchesAllTokens;
  }
}

class Paciente {
  final int idPaciente;
  final int idPersona;
  final Persona? persona;
  final int? idRepresentante;
  final Persona? representante;
  final String? parentescoRepresentante;
  final String? fechaRegistro;
  final double? peso;
  final String? tipoSangre;
  final String? alergias;
  final String? enfermedadesCronicas;
  final String? vacunas;
  final String? discapacidad;
  final String? antecedentesFamiliares;

  Paciente({
    required this.idPaciente,
    required this.idPersona,
    this.persona,
    this.idRepresentante,
    this.representante,
    this.parentescoRepresentante,
    this.fechaRegistro,
    this.peso,
    this.tipoSangre,
    this.alergias,
    this.enfermedadesCronicas,
    this.vacunas,
    this.discapacidad,
    this.antecedentesFamiliares,
  });

  // Getters de compatibilidad con código Flutter anterior
  int get id => idPaciente;
  String get nombre => persona?.nombre1 ?? '';
  String get apellido => persona?.apellido1 ?? '';
  String get cedula => persona?.cedulaIdentidad ?? '';
  String get fechaNacimiento => persona?.fechaNacimiento ?? '';
  String get sexo => persona?.sexo ?? '';
  String? get telefono => persona?.telefono;
  String? get correo => persona?.correo;
  String? get direccion => persona?.direccion;
  String? get nombreRepresentante => representante?.nombre1;
  String? get apellidoRepresentante => representante?.apellido1;
  String? get cedulaRepresentante => representante?.cedulaIdentidad;
  String? get telefonoRepresentante => representante?.telefono;
  String? get direccionRepresentante => representante?.direccion;

  // Nombre completo del paciente
  String get nombreCompleto {
    return [
      persona?.nombre1,
      persona?.nombre2,
      persona?.apellido1,
      persona?.apellido2,
    ].where((e) => e != null && e.isNotEmpty).join(' ');
  }

  // Nombre completo del representante
  String get nombreCompletoRepresentante {
    if (representante == null) return '';
    return [
      representante!.nombre1,
      representante!.nombre2,
      representante!.apellido1,
      representante!.apellido2,
    ].where((e) => e != null && e.isNotEmpty).join(' ');
  }

  factory Paciente.fromJson(Map<String, dynamic> json) {
    return Paciente(
      idPaciente: json['id_paciente'] ?? json['id'] ?? 0,
      idPersona: json['id_persona'] ?? 0,
      persona: json['persona'] != null ? Persona.fromJson(json['persona']) : null,
      idRepresentante: json['id_representante'],
      representante: json['representante'] != null
          ? Persona.fromJson(json['representante'])
          : null,
      parentescoRepresentante: json['parentesco_representante'],
      fechaRegistro: json['fecha_registro'],
      peso: json['peso'] != null ? double.tryParse(json['peso'].toString()) : null,
      tipoSangre: json['tipo_sangre'],
      alergias: json['alergias'],
      enfermedadesCronicas: json['enfermedades_cronicas'],
      vacunas: json['vacunas'],
      discapacidad: json['discapacidad'],
      antecedentesFamiliares: json['antecedentes_familiares'],
    );
  }
}

class Usuario {
  final String username;

  Usuario({required this.username});

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(username: json['username'] ?? json['nombre_usuario'] ?? '');
  }
}


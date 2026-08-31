import 'dart:convert';
import 'package:asis_guanipa_frontend/storage/jwt_token.dart';
import 'package:http/http.dart' as http;
import '../response/login_response.dart';
import '../response/profile_response.dart';
import '../models/paciente.dart';

import 'package:flutter/foundation.dart';
// ignore: avoid_web_libraries_in_flutter
class ApiService {
  /// URL del túnel Cloudflare (se actualiza con la URL actual del túnel).
  /// Para Android: se usa la misma URL pública del túnel para que funcione
  /// desde cualquier IP fuera de la red local.
  static const String _tunnelUrl = String.fromEnvironment(
    'SERVER_URL',
    defaultValue: 'http://localhost:3000/api',
  );

  // URL obtenida en tiempo de ejecución desde el servidor (/config)
  static String? _runtimeServerUrl;

  // URL personalizada guardada por el usuario en el dispositivo
  static String? _customStoredUrl;
  static const String _storageKey = 'custom_server_url';

  /// Carga la configuración inicial desde el almacenamiento y consulta el servidor
  static Future<void> initialize() async {
    try {
      _customStoredUrl = await getCustomServerUrl();

      final current = baseUrl;
      final base = getBaseUrlWithoutApi(current);
      final uri = Uri.parse('$base/config');

      final response = await http.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final srv = data['server_url'] as String?;
        if (srv != null && srv.isNotEmpty) {
          _runtimeServerUrl = srv;
        }
      }
    } catch (_) {
      // Silenciar errores: se usará la URL guardada o por defecto
    }
  }

  /// Limpia la URL de api para obtener el host base
  static String getBaseUrlWithoutApi(String url) {
    return url.replaceAll(RegExp(r'/api/?$'), '');
  }

  /// Formatea e inteligentemente limpia cualquier URL pegada por el usuario
  static String formatCleanServerUrl(String rawUrl) {
    String text = rawUrl.trim();
    if (text.isEmpty) return text;

    final match = RegExp(r'https?://[a-zA-Z0-9\.-]+', caseSensitive: false).firstMatch(text);
    if (match != null) {
      String baseDomain = match.group(0)!;
      return '$baseDomain/api';
    }

    text = text.replaceAll(RegExp(r'/+$'), '');
    text = text.replaceAll(RegExp(r'/api$'), '');
    text = text.replaceAll(RegExp(r'/app.*$'), '');
    text = text.replaceAll(RegExp(r'/downloads.*$'), '');

    if (!text.startsWith('http://') && !text.startsWith('https://')) {
      text = 'https://$text';
    }
    return '$text/api';
  }

  /// Guarda una nueva URL introducida manualmente por el usuario
  static Future<bool> setCustomServerUrl(String rawUrl) async {
    final cleanUrl = formatCleanServerUrl(rawUrl);

    try {
      if (!kIsWeb) {
        await secureStorage.write(key: _storageKey, value: cleanUrl);
      }
      _customStoredUrl = cleanUrl;
      return true;
    } catch (e) {
      debugPrint('Error guardando URL personalizada: $e');
      return false;
    }
  }

  /// Obtiene la URL guardada previamente
  static Future<String?> getCustomServerUrl() async {
    if (kIsWeb) return _customStoredUrl;
    try {
      return await secureStorage.read(key: _storageKey);
    } catch (e) {
      return null;
    }
  }

  /// Restablece la URL a la configuración original de fábrica
  static Future<void> resetCustomServerUrl() async {
    _customStoredUrl = null;
    _runtimeServerUrl = null;
    if (!kIsWeb) {
      try {
        await secureStorage.delete(key: _storageKey);
      } catch (_) {}
    }
  }

  /// Prueba si un servidor responde correctamente
  static Future<bool> testConnection([String? testUrl]) async {
    try {
      final target = testUrl ?? baseUrl;
      String clean = target.trim();
      if (!clean.startsWith('http://') && !clean.startsWith('https://')) {
        clean = 'https://$clean';
      }
      final base = getBaseUrlWithoutApi(clean);
      final response = await http
          .get(Uri.parse('$base/config'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static String get baseUrl {
    if (_customStoredUrl != null && _customStoredUrl!.isNotEmpty) {
      return _customStoredUrl!;
    }

    if (_runtimeServerUrl != null && _runtimeServerUrl!.isNotEmpty) {
      return _runtimeServerUrl!;
    }

    if (kIsWeb) {
      try {
        final origin = Uri.base.origin;
        if (origin.contains('localhost') || origin.contains('127.0.0.1')) {
          return 'http://localhost:3000/api';
        }
        return '$origin/api';
      } catch (_) {
        return 'http://localhost:3000/api';
      }
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return _tunnelUrl;
    }
    return 'http://localhost:3000/api';
  }

  static const Map<String, String> headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // Obtnener el token de JWT
  Future<ProfileResponse> currentProfile(String? token) async {
    token = token ?? await getToken();
    http.Response response;

    try {
      response = await http.get(
        Uri.parse('$baseUrl/auth/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
    } catch (e) {
      return ProfileResponse.fromJson({
        'success': false,
        'message': 'Error de conexión, intente nuevamente',
        'data': null,
      });
    }

    if (response.statusCode == 401) {
      return ProfileResponse.fromJson({
        'success': false,
        'message': 'Token inválido o expirado',
      });
    }

    final Map<String, dynamic> responseData = json.decode(response.body);
    return ProfileResponse.fromJson(responseData);
  }

  // Enviar enlace de recuperación de contraseña
  Future<Map<String, dynamic>> sendPasswordResetLink(String email) async {
    http.Response response;

    try {
      response = await http.post(
        Uri.parse('$baseUrl/auth/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      );
    } catch (e) {
      return {
        'success': false,
        'message': 'Error de conexión, intente nuevamente',
      };
    }

    if (response.statusCode != 200) {
      return {
        'success': false,
        'message':
            'Error al enviar el enlace de recuperación, si el problema persiste contacte al administrador',
      };
    }

    return {'success': true, 'message': 'Enlace enviado correctamente'};
  }

  // Restablecer contraseña con token
  Future<Map<String, dynamic>> resetPassword({
    required String token,
    required String password,
    required String confirmPassword,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'token': token,
          'password': password,
          'password_confirmation': confirmPassword,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'message': 'Contraseña actualizada correctamente',
          'token': data['token'], // Si tu API devuelve un token
        };
      } else {
        return {
          'success': false,
          'message':
              json.decode(response.body)['message'] ??
              'Error al restablecer contraseña',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // Verificar token de recuperación
  Future<Map<String, dynamic>> verifyResetToken(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/verify-reset-token/$token'),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'valid': true};
      } else {
        return {
          'success': false,
          'valid': false,
          'message': 'Token inválido o expirado',
        };
      }
    } catch (e) {
      return {'success': false, 'valid': false, 'message': 'Error de conexión'};
    }
  }

  Future<LoginResponse> login(String email, String password) async {
    http.Response? response;
    try {
      final url = Uri.parse(
        '$baseUrl/auth/login',
      ); // Cambia la ruta según tu API
      response = await http.post(
        url,
        headers: headers,
        body: json.encode({'email': email, 'password': password}),
      );
    } catch (e) {
      return LoginResponse.fromJson({
        'success': false,
        'message': 'Error de conexión',
        'data': null,
      });
    }

    if (response.statusCode == 401) {
      return LoginResponse.fromJson({
        'success': false,
        'message': 'Usuario o contraseña incorrecta',
        'data': null,
      });
    }

    final Map<String, dynamic> responseData = json.decode(response.body);
    return LoginResponse.fromJson(responseData);
  }

  Future<PacienteResponse> getPacientes({
    int page = 1,
    String? cedula,
    String? fecha,
    String? search,
  }) async {
    final token = await getToken();
    if (token == null) {
      return PacienteResponse.fromJson({'success': false, 'data': []});
    }

    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': '100',
      };
      if (cedula != null && cedula.isNotEmpty) {
        queryParams['cedula'] = cedula;
      }
      if (fecha != null && fecha.isNotEmpty) {
        queryParams['fecha'] = fecha;
      }
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final uri = Uri.parse(
        '$baseUrl/pacientes/listado',
      ).replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 401) {
        return PacienteResponse.fromJson({'success': false, 'data': []});
      }

      final Map<String, dynamic> responseData = json.decode(response.body);
      return PacienteResponse.fromJson(responseData);
    } catch (e) {
      return PacienteResponse.fromJson({'success': false, 'data': []});
    }
  }

  Future<Map<String, dynamic>> crearPaciente({
    required String nombre,
    String? nombre2,
    required String apellido,
    String? apellido2,
    required String cedula,
    required String fechaNacimiento,
    required String sexo,
    String? estadoCivil,
    String? ocupacion,
    String? telefono,
    String? correo,
    // Dirección separada por campos
    String? calle,
    String? numeroCasa,
    String? puntoReferencia,
    String? sector,
    // Dirección como string (legado)
    String? direccion,
    // Representante
    String? nombreRepresentante,
    String? nombre2Representante,
    String? apellidoRepresentante,
    String? apellido2Representante,
    String? cedulaRepresentante,
    String? sexoRepresentante,
    String? estadoCivilRepresentante,
    String? ocupacionRepresentante,
    String? telefonoRepresentante,
    String? parentescoRepresentante,
    // Datos clínicos
    String? tipoSangre,
    double? peso,
    String? alergias,
    String? enfermedadesCronicas,
    String? vacunas,
    String? discapacidad,
    String? antecedentesFamiliares,
  }) async {
    final token = await getToken();
    if (token == null) {
      return {
        'success': false,
        'message': 'No se encontró el token de autenticación',
      };
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/pacientes'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'nombre1': nombre,
          'nombre2': nombre2,
          'apellido1': apellido,
          'apellido2': apellido2,
          'cedula_identidad': cedula.isNotEmpty ? cedula : null,
          'fecha_nacimiento': fechaNacimiento,
          'sexo': sexo,
          'estado_civil': estadoCivil,
          'ocupacion': ocupacion,
          'telefono': telefono,
          'correo': correo,
          // Dirección como campos separados
          'calle': calle,
          'numero_casa': numeroCasa,
          'punto_referencia': puntoReferencia,
          'sector': sector,
          'direccion': direccion,
          // Representante
          'nombre1_rep': nombreRepresentante,
          'nombre2_rep': nombre2Representante,
          'apellido1_rep': apellidoRepresentante,
          'apellido2_rep': apellido2Representante,
          'cedula_representante': cedulaRepresentante,
          'sexo_rep': sexoRepresentante,
          'estado_civil_rep': estadoCivilRepresentante,
          'ocupacion_rep': ocupacionRepresentante,
          'telefono_representante': telefonoRepresentante,
          'parentesco_representante': parentescoRepresentante,
          // Clínicos
          'tipo_sangre': tipoSangre,
          'peso': peso,
          'alergias': alergias,
          'enfermedades_cronicas': enfermedadesCronicas,
          'vacunas': vacunas,
          'discapacidad': discapacidad,
          'antecedentes_familiares': antecedentesFamiliares,
        }),
      );

      final Map<String, dynamic> responseData = json.decode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {
          'success': true,
          'message':
              responseData['message'] ?? 'Paciente registrado exitosamente',
          'data': responseData['data'],
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Error al registrar paciente',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }


  // === MÉTODOS DE INVENTARIO ===

  // Obtener inventario (lotes de insumos con stock y alertas)
  Future<Map<String, dynamic>> getInventario() async {
    final token = await getToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/inventario'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'success': false, 'message': 'Error al obtener inventario'};
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // Registrar artículo médico
  Future<Map<String, dynamic>> registrarArticulo(
    String nombreArticulo,
    String unidadMedida, {
    String tipo = 'Insumo',
    String? descripcion,
    int? stockMinimoAlerta,
  }) async {
    final token = await getToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/inventario/articulos'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'nombre_articulo': nombreArticulo,
          'unidad_medida': unidadMedida,
          'tipo': tipo,
          'descripcion': descripcion,
          'stock_minimo_alerta': stockMinimoAlerta,
        }),
      );
      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // Actualizar artículo médico
  Future<Map<String, dynamic>> actualizarArticulo({
    required int id,
    required String nombreArticulo,
    required String unidadMedida,
    String tipo = 'Insumo',
    String? descripcion,
    int? stockMinimoAlerta,
  }) async {
    final token = await getToken();
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/inventario/articulos/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'nombre_articulo': nombreArticulo,
          'unidad_medida': unidadMedida,
          'tipo': tipo,
          'descripcion': descripcion,
          'stock_minimo_alerta': stockMinimoAlerta,
        }),
      );
      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // Obtener historial completo del paciente por cédula o ID
  Future<Map<String, dynamic>> getHistorialPaciente(String cedula) async {
    final token = await getToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/pacientes/$cedula/historial'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'success': false, 'message': 'Error al obtener historial'};
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // Alias: obtener historial por ID numérico del paciente
  Future<Map<String, dynamic>> getHistorialPacienteById(String pacienteId) =>
      getHistorialPaciente(pacienteId);

  // Eliminar artículo médico
  Future<Map<String, dynamic>> eliminarArticulo(int id) async {
    final token = await getToken();
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/inventario/articulos/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // Registrar lote de insumo
  Future<Map<String, dynamic>> registrarLote({
    required int idArticulo,
    required String numeroLote,
    required int stockActual,
    required String fechaVencimiento,
    int? idProveedor,
    int? idCentro,
  }) async {
    final token = await getToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/inventario/lotes'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'id_articulo': idArticulo,
          'numero_lote': numeroLote,
          'stock_actual': stockActual,
          'fecha_vencimiento': fechaVencimiento,
          if (idProveedor != null) 'id_proveedor': idProveedor,
          if (idCentro != null) 'id_centro': idCentro,
        }),
      );
      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // Actualizar lote de insumo
  Future<Map<String, dynamic>> actualizarLote({
    required int id,
    int? idArticulo,
    required String numeroLote,
    required int stockActual,
    required String fechaVencimiento,
    int? idProveedor,
    int? idCentro,
  }) async {
    final token = await getToken();
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/inventario/lotes/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          if (idArticulo != null) 'id_articulo': idArticulo,
          'numero_lote': numeroLote,
          'stock_actual': stockActual,
          'fecha_vencimiento': fechaVencimiento,
          'id_proveedor': idProveedor,
          'id_centro': idCentro,
        }),
      );
      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // Eliminar lote de insumo
  Future<Map<String, dynamic>> eliminarLote(int id) async {
    final token = await getToken();
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/inventario/lotes/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // Registrar nuevo proveedor
  Future<Map<String, dynamic>> registrarProveedor({
    required String nombreProveedor,
    String? rif,
    String? telefono,
    String? direccion,
  }) async {
    final token = await getToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/inventario/proveedores'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'nombre_proveedor': nombreProveedor,
          'rif': rif,
          'telefono': telefono,
          'direccion': direccion,
        }),
      );
      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // Obtener proveedores
  Future<Map<String, dynamic>> getProveedores() async {
    final token = await getToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/inventario/proveedores'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'success': false, 'message': 'Error al obtener proveedores'};
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // Obtener centros de salud
  Future<Map<String, dynamic>> getCentros() async {
    final token = await getToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/atenciones/centros'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'success': false, 'message': 'Error al obtener centros'};
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // Obtener sectores de San José de Guanipa (68 sectores)
  Future<Map<String, dynamic>> getSectores() async {
    final token = await getToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/atenciones/sectores'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'success': false, 'message': 'Error al obtener sectores'};
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // Crear sector
  Future<Map<String, dynamic>> crearSector(String nombreSector) async {
    final token = await getToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/atenciones/sectores'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'nombre_sector': nombreSector}),
      );
      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }



  // Listar artículos médicos
  Future<Map<String, dynamic>> getArticulos() async {
    final token = await getToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/inventario/articulos'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'success': false, 'message': 'Error al obtener artículos'};
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // === ESQUEMAS DE DOSIFICACIÓN ===

  Future<Map<String, dynamic>> getEsquemas() async {
    final token = await getToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/inventario/esquemas'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'success': false, 'message': 'Error al obtener esquemas de dosificación'};
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  Future<Map<String, dynamic>> crearEsquema({
    required int idArticulo,
    required String numeroDosis,
    int? intervaloDiasPrevio,
    int? edadMinimaMeses,
    int? edadMaximaMeses,
  }) async {
    final token = await getToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/inventario/esquemas'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'id_articulo': idArticulo,
          'numero_dosis': numeroDosis,
          'intervalo_dias_previo': intervaloDiasPrevio,
          'edad_minima_meses': edadMinimaMeses,
          'edad_maxima_meses': edadMaximaMeses,
        }),
      );
      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  Future<Map<String, dynamic>> actualizarEsquema({
    required int id,
    required String numeroDosis,
    int? intervaloDiasPrevio,
    int? edadMinimaMeses,
    int? edadMaximaMeses,
  }) async {
    final token = await getToken();
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/inventario/esquemas/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'numero_dosis': numeroDosis,
          'intervalo_dias_previo': intervaloDiasPrevio,
          'edad_minima_meses': edadMinimaMeses,
          'edad_maxima_meses': edadMaximaMeses,
        }),
      );
      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  Future<Map<String, dynamic>> eliminarEsquema(int id) async {
    final token = await getToken();
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/inventario/esquemas/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // === MÉTODOS DE ATENCIONES / JORNADAS ===

  // Registrar atención completa (Hoja de campo)
  Future<Map<String, dynamic>> registrarAtencionCompleta({
    required Map<String, dynamic> paciente,
    required Map<String, dynamic> atencion,
    required List<Map<String, dynamic>> consumos,
    List<Map<String, dynamic>>? vacunaciones,
    String? cedula,
  }) async {
    final token = await getToken();
    try {
      final payload = <String, dynamic>{
        'persona': Map<String, dynamic>.from(paciente),
        'atencion': Map<String, dynamic>.from(atencion),
        'paciente_clinico': <String, dynamic>{
          'peso': paciente['peso'],
          'tipo_sangre': paciente['tipo_sangre'],
          'alergias': paciente['alergias'],
          'enfermedades_cronicas': paciente['enfermedades_cronicas'],
          'vacunas': paciente['vacunas'],
          'discapacidad': paciente['discapacidad'],
          'antecedentes_familiares': paciente['antecedentes_familiares'],
        },
        'consumos': consumos,
        if (vacunaciones != null) 'vacunaciones': vacunaciones,
      };

      if (cedula != null && cedula.isNotEmpty) {
        (payload['persona'] as Map<String, dynamic>)['cedula_identidad'] = cedula;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/atenciones/registrar-completo'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(payload),
      );
      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // === MÉTODOS DE SEGURIDAD / USUARIOS ===

  // Obtener lista de usuarios (Control de acceso y auditoría)
  Future<Map<String, dynamic>> getUsers() async {
    final token = await getToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/users'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'success': false, 'message': 'Error al obtener usuarios'};
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // Crear usuario admin/médico/etc
  Future<Map<String, dynamic>> registrarUsuario({
    required String username,
    required String email,
    required String password,
  }) async {
    final token = await getToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'username': username,
          'email': email,
          'password': password,
        }),
      );
      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // Actualizar usuario (incluyendo rol)
  Future<Map<String, dynamic>> updateUser({
    required int id,
    required String username,
    required String email,
    String? password,
    required String role,
  }) async {
    final token = await getToken();
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/auth/users/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'username': username,
          'email': email,
          if (password != null && password.isNotEmpty) 'password': password,
          'role': role,
        }),
      );
      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // Eliminar usuario
  Future<Map<String, dynamic>> deleteUser(int id) async {
    final token = await getToken();
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/auth/users/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // Cerrar sesión (registra en bitácora)
  Future<Map<String, dynamic>> logout() async {
    final token = await getToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/logout'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      return json.decode(response.body);
    } catch (_) {
      return {'success': false};
    }
  }

  // Habilitar / deshabilitar usuario
  Future<Map<String, dynamic>> toggleActivo(int id) async {
    final token = await getToken();
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/auth/users/$id/toggle-activo'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // === MÉTODOS DE REPORTES ===

  Future<Map<String, dynamic>> getReportesDaily({String? fecha, String? centro, String? sector}) async {
    final token = await getToken();
    try {
      final List<String> params = ['formato=json'];
      if (fecha != null && fecha.isNotEmpty) params.add('fecha=$fecha');
      if (centro != null && centro != 'Todos') params.add('centro=$centro');
      if (sector != null && sector != 'Todos') params.add('sector=$sector');
      final queryParams = '?${params.join('&')}';
      
      final response = await http.get(
        Uri.parse('$baseUrl/reportes/diario$queryParams'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'success': false, 'message': 'Error al obtener estadísticas'};
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // URLs de descarga de reportes Excel
  String getReporteDiarioExcelUrl({String? fecha, String? centro, String? sector}) {
    final params = ['formato=excel'];
    if (fecha != null) params.add('fecha=$fecha');
    if (centro != null && centro != 'Todos') params.add('centro=$centro');
    if (sector != null && sector != 'Todos') params.add('sector=$sector');
    return '$baseUrl/reportes/diario?${params.join('&')}';
  }

  String getReporteSemanalExcelUrl({required int semana, int? ano}) {
    final y = ano ?? DateTime.now().year;
    return '$baseUrl/reportes/semanal?semana=$semana&ano=$y';
  }

  String getReporteMensualExcelUrl({required String mes, int? ano}) {
    final y = ano ?? DateTime.now().year;
    return '$baseUrl/reportes/mensual?mes=$mes&ano=$y';
  }

  String getReporteInventarioExcelUrl() {
    return '$baseUrl/reportes/inventario';
  }

  // Obtener logs de bitácora
  Future<Map<String, dynamic>> getBitacora() async {
    final token = await getToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/bitacora'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // Descartar lotes vencidos con evidencia fotográfica y acta
  Future<Map<String, dynamic>> descartarLotes({
    required List<int> ids,
    required String metodoDisposicion,
    required String fechaRetiro,
    String? justificacion,
    String? numeroActaDescarte,
    String? fotoEvidencia,
  }) async {
    final token = await getToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/inventario/descartar'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'ids': ids,
          'metodo_disposicion': metodoDisposicion,
          'fecha_retiro': fechaRetiro,
          if (justificacion != null) 'justificacion': justificacion,
          if (numeroActaDescarte != null) 'numero_acta_descarte': numeroActaDescarte,
          if (fotoEvidencia != null) 'foto_evidencia': fotoEvidencia,
        }),
      );
      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  /// URL para descargar/visualizar la Nota de Salida en PDF para un movimiento
  Future<String> getNotaSalidaUrl(int idMovimiento) async {
    final token = await getToken();
    return '$baseUrl/inventario/movimientos/$idMovimiento/nota-salida?token=$token';
  }

  String getVerificarMovimientoUrl(int idMovimiento) {
    return '$baseUrl/inventario/movimientos/$idMovimiento/verificar';
  }

  // === MÉTODOS DE JORNADAS / OPERATIVOS DE SALUD Y CENTROS ===

  Future<Map<String, dynamic>> getOperativos({
    String? search,
    int? centroId,
    String? fechaInicio,
    String? fechaFin,
  }) async {
    final token = await getToken();
    try {
      final queryParams = <String, String>{};
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (centroId != null) queryParams['centro'] = centroId.toString();
      if (fechaInicio != null && fechaInicio.isNotEmpty) queryParams['fecha_inicio'] = fechaInicio;
      if (fechaFin != null && fechaFin.isNotEmpty) queryParams['fecha_fin'] = fechaFin;

      final uri = Uri.parse('$baseUrl/atenciones/operativos').replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'success': false, 'message': 'Error al obtener jornadas/operativos'};
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  Future<Map<String, dynamic>> crearOperativo({
    int? idCentroOrganizador,
    String? nombreOperativo,
    String? nombre,
    String? tipoJornada,
    String? fechaOperativo,
    String? fechaInicio,
    String? fechaFin,
    String? lugar,
    String? descripcion,
  }) async {
    final token = await getToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/atenciones/operativos'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          if (idCentroOrganizador != null) 'id_centro_organizador': idCentroOrganizador,
          'nombre_operativo': nombreOperativo ?? nombre,
          'fecha_operativo':  fechaOperativo ?? fechaInicio,
          if (fechaFin != null) 'fecha_fin': fechaFin,
          'tipo_jornada':     tipoJornada,
          'lugar':            lugar,
          'descripcion':      descripcion,
        }),
      );
      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  Future<Map<String, dynamic>> actualizarOperativo({
    required int id,
    String? nombreOperativo,
    String? fechaOperativo,
    String? fechaFin,
    String? descripcion,
    int? idCentroOrganizador,
  }) async {
    final token = await getToken();
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/atenciones/operativos/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          if (nombreOperativo != null) 'nombre_operativo': nombreOperativo,
          if (fechaOperativo != null) 'fecha_operativo': fechaOperativo,
          if (fechaFin != null) 'fecha_fin': fechaFin,
          if (descripcion != null) 'descripcion': descripcion,
          if (idCentroOrganizador != null) 'id_centro_organizador': idCentroOrganizador,
        }),
      );
      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  Future<Map<String, dynamic>> eliminarOperativo(int id) async {
    final token = await getToken();
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/atenciones/operativos/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  String getReporteOperativosExcelUrl({int? idOperativo, String? mes, int? ano}) {
    final List<String> params = [];
    if (idOperativo != null) params.add('id_operativo=$idOperativo');
    if (mes != null && mes != 'Todos') {
      const mesesMap = {
        'ENERO': 1, 'FEBRERO': 2, 'MARZO': 3, 'ABRIL': 4,
        'MAYO': 5, 'JUNIO': 6, 'JULIO': 7, 'AGOSTO': 8,
        'SEPTIEMBRE': 9, 'OCTUBRE': 10, 'NOVIEMBRE': 11, 'DICIEMBRE': 12
      };
      if (mesesMap.containsKey(mes)) {
        params.add('mes=${mesesMap[mes]}');
      }
    }
    if (ano != null) params.add('ano=$ano');
    final query = params.isNotEmpty ? '?${params.join('&')}' : '';
    return '$baseUrl/reportes/operativos$query';
  }

  Future<Map<String, dynamic>> getCentrosSalud() async {
    final token = await getToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/atenciones/centros'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'success': false, 'message': 'Error al obtener centros de salud'};
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // Actualizar datos del paciente

  Future<Map<String, dynamic>> updatePatient({
    required int id,
    required String nombre,
    String? nombre2,
    required String apellido,
    String? apellido2,
    String? cedula,
    required String fechaNacimiento,
    required String sexo,
    String? estadoCivil,
    String? ocupacion,
    String? telefono,
    String? correo,
    required String direccion,
    String? calle,
    String? numeroCasa,
    String? puntoReferencia,
    String? sector,
    // Representante
    String? nombreRepresentante,
    String? nombre2Representante,
    String? apellidoRepresentante,
    String? apellido2Representante,
    String? cedulaRepresentante,
    String? sexoRepresentante,
    String? estadoCivilRepresentante,
    String? ocupacionRepresentante,
    String? telefonoRepresentante,
    String? direccionRepresentante,
    String? parentescoRepresentante,
    // Datos clínicos
    String? tipoSangre,
    double? peso,
    String? alergias,
    String? enfermedadesCronicas,
    String? vacunas,
    String? discapacidad,
    String? antecedentesFamiliares,
  }) async {
    final token = await getToken();
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/pacientes/datos/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'nombre1': nombre,
          'nombre2': nombre2,
          'apellido1': apellido,
          'apellido2': apellido2,
          'cedula_identidad': cedula,
          'fecha_nacimiento': fechaNacimiento,
          'sexo': sexo,
          'estado_civil': estadoCivil,
          'ocupacion': ocupacion,
          'telefono': telefono,
          'correo': correo,
          'direccion': direccion,
          'calle': calle,
          'numero_casa': numeroCasa,
          'punto_referencia': puntoReferencia,
          'sector': sector,
          'nombre1_rep': nombreRepresentante,
          'nombre2_rep': nombre2Representante,
          'apellido1_rep': apellidoRepresentante,
          'apellido2_rep': apellido2Representante,
          'cedula_representante': cedulaRepresentante,
          'sexo_rep': sexoRepresentante,
          'estado_civil_rep': estadoCivilRepresentante,
          'ocupacion_rep': ocupacionRepresentante,
          'telefono_representante': telefonoRepresentante,
          'direccion_representante': direccionRepresentante,
          'parentesco_representante': parentescoRepresentante,
          'tipo_sangre': tipoSangre,
          'peso': peso,
          'alergias': alergias,
          'enfermedades_cronicas': enfermedadesCronicas,
          'vacunas': vacunas,
          'discapacidad': discapacidad,
          'antecedentes_familiares': antecedentesFamiliares,
        }),
      );
      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }
}


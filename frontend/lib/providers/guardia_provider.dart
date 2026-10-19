import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class GuardiaModel {
  final bool activa;
  final String modalidad; // 'intramural' o 'extramural'
  final String centroSalud;
  final String turno;
  final String supervisor;
  final String? sectorComunidad;
  final String? termoId;
  final String? liderJornada;
  final String? temperaturaInicialTermo;
  final DateTime fechaApertura;
  final int pacientesAtendidos;
  final int? idOperativo;
  final String? nombreJornada;
  final Map<String, dynamic>? jornadaData;

  GuardiaModel({
    required this.activa,
    required this.modalidad,
    required this.centroSalud,
    required this.turno,
    required this.supervisor,
    this.sectorComunidad,
    this.termoId,
    this.liderJornada,
    this.temperaturaInicialTermo,
    required this.fechaApertura,
    this.pacientesAtendidos = 0,
    this.idOperativo,
    this.nombreJornada,
    this.jornadaData,
  });

  bool get isExtramural => modalidad.toLowerCase() == 'extramural';

  Map<String, dynamic> toJson() => {
    'activa': activa,
    'modalidad': modalidad,
    'centroSalud': centroSalud,
    'turno': turno,
    'supervisor': supervisor,
    'sectorComunidad': sectorComunidad,
    'termoId': termoId,
    'liderJornada': liderJornada,
    'temperaturaInicialTermo': temperaturaInicialTermo,
    'fechaApertura': fechaApertura.toIso8601String(),
    'pacientesAtendidos': pacientesAtendidos,
    'idOperativo': idOperativo,
    'nombreJornada': nombreJornada,
    'jornadaData': jornadaData,
  };

  factory GuardiaModel.fromJson(Map<String, dynamic> json) => GuardiaModel(
    activa: json['activa'] == true,
    modalidad: json['modalidad'] ?? 'intramural',
    centroSalud: json['centroSalud'] ?? 'CDI Pedro Urbina',
    turno: json['turno'] ?? 'Mañana (7:00 AM - 1:00 PM)',
    supervisor: json['supervisor'] ?? 'Personal de Guardia',
    sectorComunidad: json['sectorComunidad'],
    termoId: json['termoId'],
    liderJornada: json['liderJornada'],
    temperaturaInicialTermo: json['temperaturaInicialTermo'],
    fechaApertura: json['fechaApertura'] != null
        ? DateTime.tryParse(json['fechaApertura']) ?? DateTime.now()
        : DateTime.now(),
    pacientesAtendidos: json['pacientesAtendidos'] ?? 0,
    idOperativo: json['idOperativo'],
    nombreJornada: json['nombreJornada'],
    jornadaData: json['jornadaData'] != null ? Map<String, dynamic>.from(json['jornadaData']) : null,
  );

  GuardiaModel copyWith({
    bool? activa,
    String? modalidad,
    String? centroSalud,
    String? turno,
    String? supervisor,
    String? sectorComunidad,
    String? termoId,
    String? liderJornada,
    String? temperaturaInicialTermo,
    DateTime? fechaApertura,
    int? pacientesAtendidos,
    int? idOperativo,
    String? nombreJornada,
    Map<String, dynamic>? jornadaData,
  }) {
    return GuardiaModel(
      activa: activa ?? this.activa,
      modalidad: modalidad ?? this.modalidad,
      centroSalud: centroSalud ?? this.centroSalud,
      turno: turno ?? this.turno,
      supervisor: supervisor ?? this.supervisor,
      sectorComunidad: sectorComunidad ?? this.sectorComunidad,
      termoId: termoId ?? this.termoId,
      liderJornada: liderJornada ?? this.liderJornada,
      temperaturaInicialTermo: temperaturaInicialTermo ?? this.temperaturaInicialTermo,
      fechaApertura: fechaApertura ?? this.fechaApertura,
      pacientesAtendidos: pacientesAtendidos ?? this.pacientesAtendidos,
      idOperativo: idOperativo ?? this.idOperativo,
      nombreJornada: nombreJornada ?? this.nombreJornada,
      jornadaData: jornadaData ?? this.jornadaData,
    );
  }
}

class GuardiaProvider extends ChangeNotifier {
  static const String _storageKey = 'asic_guardia_activa';
  final _storage = const FlutterSecureStorage();

  GuardiaModel? _guardia;
  bool _isLoading = true;

  GuardiaModel? get guardia => _guardia;
  bool get hasGuardiaActiva => _guardia != null && _guardia!.activa;
  bool get isLoading => _isLoading;

  /// Cargar estado de la guardia almacenado
  Future<void> loadFromStorage() async {
    _isLoading = true;
    notifyListeners();

    try {
      final raw = await _storage.read(key: _storageKey);
      if (raw != null && raw.isNotEmpty) {
        final Map<String, dynamic> data = json.decode(raw);
        _guardia = GuardiaModel.fromJson(data);
      }
    } catch (e) {
      debugPrint('Error loading guardia state: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Abrir una nueva guardia / despliegue
  Future<void> abrirGuardia({
    required String modalidad,
    String centroSalud = 'CDI Pedro Urbina',
    required String turno,
    required String supervisor,
    String? sectorComunidad,
    String? termoId,
    String? liderJornada,
    String? temperaturaInicialTermo,
    int? idOperativo,
    String? nombreJornada,
    Map<String, dynamic>? jornadaData,
  }) async {
    _guardia = GuardiaModel(
      activa: true,
      modalidad: modalidad,
      centroSalud: centroSalud,
      turno: turno,
      supervisor: supervisor,
      sectorComunidad: sectorComunidad,
      termoId: termoId,
      liderJornada: liderJornada,
      temperaturaInicialTermo: temperaturaInicialTermo,
      fechaApertura: DateTime.now(),
      pacientesAtendidos: 0,
      idOperativo: idOperativo,
      nombreJornada: nombreJornada,
      jornadaData: jornadaData,
    );

    await _persist();
    notifyListeners();
  }

  /// Cerrar la guardia actual
  Future<void> cerrarGuardia() async {
    _guardia = null;
    try {
      await _storage.delete(key: _storageKey);
    } catch (_) {}
    notifyListeners();
  }

  /// Incrementar contador de pacientes atendidos en la guardia activa
  Future<void> registrarAtencion() async {
    if (_guardia != null && _guardia!.activa) {
      _guardia = _guardia!.copyWith(
        pacientesAtendidos: _guardia!.pacientesAtendidos + 1,
      );
      await _persist();
      notifyListeners();
    }
  }

  Future<void> _persist() async {
    if (_guardia == null) return;
    try {
      final raw = json.encode(_guardia!.toJson());
      await _storage.write(key: _storageKey, value: raw);
    } catch (e) {
      debugPrint('Error saving guardia state: $e');
    }
  }
}

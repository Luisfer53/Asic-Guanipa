import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:asis_guanipa_frontend/services/api_service.dart';
import 'package:asis_guanipa_frontend/models/paciente.dart';
import 'package:asis_guanipa_frontend/providers/guardia_provider.dart';
import 'package:asis_guanipa_frontend/providers/auth_providers.dart';
import 'package:asis_guanipa_frontend/components/apertura_guardia_dialog.dart';
import 'nominal_register/create_patient_dialog.dart';
import 'nominal_register/quick_patient_dialog.dart';
import 'nominal_register/carnet_vacunacion_dialog.dart';
import 'nominal_register/constancia_atencion_dialog.dart';
import 'nominal_register/crear_jornada_dialog.dart';
import 'nominal_register/gestionar_jornadas_dialog.dart';

class _InsumoItem {
  Map<String, dynamic>? lote;
  int cantidad;
  _InsumoItem({this.lote, this.cantidad = 1});
}

class JornadaDiariaScreen extends StatefulWidget {
  const JornadaDiariaScreen({super.key});

  @override
  State<JornadaDiariaScreen> createState() => _JornadaDiariaScreenState();
}

class _JornadaDiariaScreenState extends State<JornadaDiariaScreen> {
  final ApiService _api = ApiService();

  // Jornada de Vacunación vinculada (con stock bloqueado)
  Map<String, dynamic>? _jornadaActiva;

  // Flujo en 2 Pasos: 0 = Buscar Paciente, 1 = Vacunar (< 45 seg)
  int _step = 0;

  // Paso 0: Búsqueda
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  Timer? _searchDebounce;
  bool _searchLoading = false;
  List<Paciente> _searchResults = [];
  Paciente? _selectedPaciente;

  // Paso 1: Vacunación
  final _formKey = GlobalKey<FormState>();
  bool _savingAtencion = false;

  // Biológico y aplicación
  Map<String, dynamic>? _selectedLoteVacuna;
  String _dosisAplicada = '1ra Dosis';
  String _viaAdministracion = 'Intramuscular';
  String _sitioAdministracion = 'Brazo izquierdo';

  // Triaje Mínimo Rápido
  final _tempCtrl = TextEditingController(text: '36.5');
  final _pesoCtrl = TextEditingController();
  final _tallaCtrl = TextEditingController();

  // Alerta fiebre
  bool get _tieneAlertaFiebre {
    final t = double.tryParse(_tempCtrl.text.trim());
    return t != null && t >= 38.0;
  }

  // Insumos complementarios (opcional)
  List<_InsumoItem> _insumosUsados = [];
  List<Map<String, dynamic>> _lotesVacunas = [];
  List<Map<String, dynamic>> _lotesInsumos = [];
  bool _loadingInventario = false;

  static const _primary = Color(0xFF1565C0);
  static const _teal = Color(0xFF00897B);
  static const _green = Color(0xFF2E7D32);

  static const List<String> _dosisOpciones = [
    '1ra Dosis',
    '2da Dosis',
    '3ra Dosis',
    'Única',
    'Refuerzo 1',
    'Refuerzo 2',
    'Refuerzo Anual',
  ];

  static const List<String> _viasOpciones = [
    'Intramuscular',
    'Subcutánea',
    'Oral',
    'Intradérmica',
  ];

  static const List<String> _sitiosOpciones = [
    'Brazo izquierdo',
    'Brazo derecho',
    'Muslo izquierdo',
    'Muslo derecho',
    'Oral',
    'Glúteo',
  ];

  @override
  void initState() {
    super.initState();
    _loadInventario();
    _buscarPaciente(explicitQuery: '');
    // Listener para actualizar alerta de fiebre en tiempo real
    _tempCtrl.addListener(() {
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final guardia = context.read<GuardiaProvider>().guardia;
      if (_jornadaActiva == null && guardia?.jornadaData != null) {
        _onSeleccionarJornada(guardia!.jornadaData!);
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _tempCtrl.dispose();
    _pesoCtrl.dispose();
    _tallaCtrl.dispose();
    super.dispose();
  }

  // ─── Carga de Inventario ──────────────────────────────────────────────────
  Future<void> _loadInventario() async {
    setState(() => _loadingInventario = true);
    try {
      final invRes = await _api.getInventario();
      if (invRes['success'] == true) {
        final List data = invRes['data'] ?? [];
        final today = DateTime.now();

        final valid = data
            .where((l) {
              final exp = DateTime.tryParse(l['fecha_vencimiento'] ?? '');
              return exp != null && exp.isAfter(today);
            })
            .map((l) => Map<String, dynamic>.from(l))
            .toList();

        _lotesVacunas = valid.where((l) {
          final art = l['articulo'] ?? {};
          final n = (art['nombre_articulo'] ?? l['nombre_articulo'] ?? '')
              .toString()
              .toLowerCase();
          final t = (art['tipo'] ?? l['tipo'] ?? '').toString().toLowerCase();
          return t == 'vacuna' ||
              n.contains('vacun') ||
              n.contains('biol') ||
              n.contains('covid') ||
              n.contains('pentavalente') ||
              n.contains('bcg') ||
              n.contains('srp') ||
              n.contains('polio') ||
              n.contains('hepat') ||
              n.contains('toxoide') ||
              n.contains('influenza') ||
              n.contains('fiebre') ||
              n.contains('vph');
        }).toList();
        if (_lotesVacunas.isEmpty) _lotesVacunas = List.from(valid);

        _lotesInsumos = valid.where((l) {
          final art = l['articulo'] ?? {};
          final t = (art['tipo'] ?? l['tipo'] ?? '').toString().toLowerCase();
          return t != 'vacuna';
        }).toList();

        // Auto-seleccionar primer lote si aún no hay uno elegido
        if (_selectedLoteVacuna == null && _lotesVacunas.isNotEmpty) {
          _selectedLoteVacuna = _lotesVacunas.first;
        }
        _reordenarLotesPorJornada();
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingInventario = false);
  }

  dynamic _extractLoteId(Map<String, dynamic> lote) {
    return lote['id_lote_insumo'] ?? lote['id_lote'] ?? lote['id'];
  }

  // ─── Búsqueda Rápida de Pacientes ─────────────────────────────────────────
  void _onSearchChanged(String val) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) _buscarPaciente(explicitQuery: val.trim());
    });
  }

  Future<void> _buscarPaciente({String? explicitQuery}) async {
    final q = (explicitQuery ?? _searchController.text).trim();
    setState(() => _searchLoading = true);

    try {
      final res = await _api.getPacientes(page: 1, search: q.isEmpty ? null : q);
      if (!mounted) return;
      setState(() {
        _searchLoading = false;
        _searchResults = res.success ? res.data : [];
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _searchLoading = false;
          _searchResults = [];
        });
      }
    }
  }

  void _selectPaciente(Paciente p) {
    setState(() {
      _selectedPaciente = p;
      _step = 1;
      // Pre-cargar signos vitales previos si existen
      if (p.peso != null && p.peso! > 0) {
        _pesoCtrl.text = p.peso.toString();
      } else {
        _pesoCtrl.clear();
      }
      _tallaCtrl.clear();
      _tempCtrl.text = '36.5';
    });
  }

  bool _isPediatrico(Paciente? p) {
    if (p == null || p.fechaNacimiento.isEmpty) return false;
    final fn = DateTime.tryParse(p.fechaNacimiento);
    if (fn == null) return false;
    final now = DateTime.now();
    final diffYears = now.difference(fn).inDays / 365.25;
    return diffYears < 5.0;
  }

  String _calcularEdadTexto(String fechaNac) {
    final fn = DateTime.tryParse(fechaNac);
    if (fn == null) return 'Edad desconocida';
    final now = DateTime.now();
    final dias = now.difference(fn).inDays;
    final meses = (dias / 30.44).floor();
    final anios = (dias / 365.25).floor();

    if (anios >= 1) {
      return '$anios año${anios > 1 ? "s" : ""}';
    } else if (meses >= 1) {
      return '$meses mes${meses > 1 ? "es" : ""}';
    } else {
      return '$dias día${dias > 1 ? "s" : ""}';
    }
  }

  // ─── Guardar Vacunación Rápida ────────────────────────────────────────────
  Future<void> _guardarVacunacion() async {
    if (_selectedPaciente == null) return;
    if (_selectedLoteVacuna == null) {
      _showError('Seleccione la vacuna o lote a aplicar');
      return;
    }

    // Validar autorización de usuario si hay jornada vinculada
    if (_jornadaActiva != null && !_isUsuarioAutorizadoEnJornada(_jornadaActiva)) {
      final user = context.read<AuthProvider>().getCurrentUser()?.username ?? '';
      _showError('Acceso denegado: El usuario "@$user" no está asignado como participante en esta jornada. Solo el personal asignado puede registrar en ella.');
      return;
    }

    final guardiaProv = context.read<GuardiaProvider>();
    final guardia = guardiaProv.guardia;

    setState(() => _savingAtencion = true);

    final loteId = _extractLoteId(_selectedLoteVacuna!);
    final double? tempVal = double.tryParse(_tempCtrl.text.trim());
    final double? pesoVal = double.tryParse(_pesoCtrl.text.trim());
    final double? tallaVal = double.tryParse(_tallaCtrl.text.trim());

    final vacunaciones = [
      {
        'id_lote': loteId,
        'dosis_aplicada': _dosisAplicada,
        'via_administracion': _viaAdministracion,
        'sitio_administracion': _sitioAdministracion,
        'temperatura': tempVal,
        'peso': pesoVal,
        'talla': tallaVal,
        'modalidad': guardia?.modalidad ?? 'intramural',
      }
    ];

    final consumos = <Map<String, dynamic>>[];
    if (loteId != null) {
      consumos.add({'id_lote_insumo': loteId, 'cantidad_usada': 1});
    }
    for (final ins in _insumosUsados) {
      if (ins.lote != null && ins.cantidad > 0) {
        final idIns = _extractLoteId(ins.lote!);
        if (idIns != null) {
          consumos.add({'id_lote_insumo': idIns, 'cantidad_usada': ins.cantidad});
        }
      }
    }

    final atencionPayload = {
      'fecha_visita': DateTime.now().toIso8601String().split('T')[0],
      'diagnostico_general': 'Inmunización preventiva',
      'temperatura_c': tempVal,
      'peso_kg': pesoVal,
      'talla_cm': tallaVal,
      'id_operativo': _jornadaActiva?['id_operativo'],
      'guardia_modalidad': _jornadaActiva?['modalidad'] ?? guardia?.modalidad ?? 'intramural',
      'guardia_centro': guardia?.centroSalud,
      'guardia_sector': _jornadaActiva?['sector_comunidad'] ?? guardia?.sectorComunidad,
    };

    final personaPayload = {
      'nombre1': _selectedPaciente!.nombre,
      'apellido1': _selectedPaciente!.apellido,
      'cedula_identidad': _selectedPaciente!.cedula.isNotEmpty ? _selectedPaciente!.cedula : null,
      'fecha_nacimiento': _selectedPaciente!.fechaNacimiento,
      'sexo': _selectedPaciente!.sexo,
      'telefono': _selectedPaciente!.telefono ?? '',
      'correo': _selectedPaciente!.correo,
      'direccion': _selectedPaciente!.direccion ?? '',
      'peso': pesoVal,
    };

    final res = await _api.registrarAtencionCompleta(
      paciente: personaPayload,
      atencion: atencionPayload,
      consumos: consumos,
      vacunaciones: vacunaciones,
      cedula: _selectedPaciente!.cedula,
    );

    setState(() => _savingAtencion = false);

    if (res['success'] == true) {
      final Paciente pacienteGuardado = _selectedPaciente!;
      await guardiaProv.registrarAtencion();

      // Si hay una jornada activa, actualizar localmente el stock remanente
      if (_jornadaActiva != null && _jornadaActiva!['stockBloqueado'] != null) {
        final List stList = _jornadaActiva!['stockBloqueado'];
        for (final st in stList) {
          final idLoteSt = st['id_lote_insumo'];
          if (idLoteSt == loteId) {
            st['cantidad_usada'] = (st['cantidad_usada'] ?? 0) + 1;
            st['cantidad_remanente'] = ((st['cantidad_remanente'] ?? 1) - 1).clamp(0, 999999);
          }
        }
      }
      _loadInventario();
      setState(() {
        _step = 0;
        _selectedPaciente = null;
        _pesoCtrl.clear();
        _tallaCtrl.clear();
        _tempCtrl.text = '36.5';
        _insumosUsados = [];
      });

      _searchController.clear();
      _buscarPaciente(explicitQuery: '');
      _searchFocusNode.requestFocus();

      _showSuccessWithCarnet(pacienteGuardado);
      _mostrarDialogoCarnetGenerado(pacienteGuardado);
    } else {
      _showError(res['message'] ?? 'Error al registrar vacunación');
    }
  }

  String _getVacunadorActual() {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final user = auth.getCurrentUser();
      if (user != null) {
        if (user.displayName.isNotEmpty && user.displayName != 'Usuario') {
          return user.displayName;
        }
        final uname = (user.username ?? '').trim();
        if (uname.isNotEmpty) return uname;
      }
    } catch (_) {}
    return 'Personal de Inmunización CDI';
  }

  void _showSuccessWithCarnet(Paciente paciente) {
    final vacunador = _getVacunadorActual();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text('Vacunación de ${paciente.nombreCompleto} registrada exitosamente')),
          ],
        ),
        action: SnackBarAction(
          label: 'VER CARNET',
          textColor: Colors.amberAccent,
          onPressed: () => CarnetVacunacionDialog.show(context, paciente: paciente, vacunadorNombre: vacunador),
        ),
        backgroundColor: _green,
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _mostrarDialogoCarnetGenerado(Paciente paciente) {
    final vacunador = _getVacunadorActual();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.verified_rounded, color: Color(0xFF2E7D32), size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                '¡Vacunación Registrada!',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'La dosis para ${paciente.nombreCompleto} ha sido asentada en el sistema.',
                  style: const TextStyle(fontSize: 14, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.badge_rounded, color: Color(0xFF1D4ED8), size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Carnet Digital Oficial MPPS',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E3A8A)),
                            ),
                            Text(
                              'Generado con QR de autenticidad para control y entrega inmediata',
                              style: TextStyle(fontSize: 11, color: Colors.blue.shade800),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Documentos Oficiales Disponibles para este Paciente:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    ConstanciaAtencionDialog.show(context, paciente: paciente);
                  },
                  icon: const Icon(Icons.verified_rounded, size: 20),
                  label: const Text('Emitir Constancia Médica (QR)', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1565C0),
                    side: const BorderSide(color: Color(0xFF1565C0)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    CarnetVacunacionDialog.show(context, paciente: paciente, vacunadorNombre: vacunador);
                  },
                  icon: const Icon(Icons.badge_outlined, size: 20),
                  label: const Text('Ver / Imprimir Carnet Digital', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar / Siguiente paciente'),
          ),
        ],
      ),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
        backgroundColor: _green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ─── Builder Principal ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final guardiaProv = context.watch<GuardiaProvider>();
    final tieneGuardia = guardiaProv.hasGuardiaActiva;
    final guardiaJornada = guardiaProv.guardia?.jornadaData;

    if (tieneGuardia && guardiaJornada != null && _jornadaActiva == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _jornadaActiva == null) {
          _onSeleccionarJornada(guardiaJornada);
        }
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: SafeArea(
        child: Column(
          children: [
            _buildGuardiaTopBanner(guardiaProv),
            if (_jornadaActiva != null)
              _buildJornadaActivaBanner(),
            if (!tieneGuardia)
              Expanded(child: _buildBloqueoSinGuardia())
            else
              Expanded(
                child: _step == 0 ? _buildPaso0BuscarPaciente() : _buildPaso1VacunacionRapida(),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Banner Superior de Guardia Activa ────────────────────────────────────
  Widget _buildGuardiaTopBanner(GuardiaProvider prov) {
    final g = prov.guardia;
    final activa = prov.hasGuardiaActiva;

    if (!activa) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.amber.shade100,
          border: Border(bottom: BorderSide(color: Colors.amber.shade400)),
        ),
        child: Row(
          children: [
            // Botón volver al inicio
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.amber.shade900,
                side: BorderSide(color: Colors.amber.shade700),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.arrow_back_rounded, size: 15),
              label: const Text('Inicio', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              onPressed: () => context.canPop() ? context.pop() : context.go('/'),
            ),
            const SizedBox(width: 10),
            Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'No hay una guardia activa. Inicie la guardia para registrar atenciones.',
                style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade900,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: const Text('Abrir Guardia', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              onPressed: () => AperturaGuardiaDialog.show(context),
            ),
          ],
        ),
      );
    }

    final isExtramural = g!.isExtramural;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          // Botón volver al inicio
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1565C0),
              side: const BorderSide(color: Color(0xFFBFDBFE)),
              backgroundColor: const Color(0xFFEFF6FF),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.arrow_back_rounded, size: 15),
            label: const Text('Inicio', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            onPressed: () => context.canPop() ? context.pop() : context.go('/'),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isExtramural ? Colors.deepPurple.shade50 : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isExtramural ? Colors.deepPurple.shade200 : Colors.blue.shade200,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isExtramural ? Icons.terrain_rounded : Icons.local_hospital_rounded,
                  color: isExtramural ? Colors.deepPurple.shade700 : _primary,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  isExtramural ? 'EXTRAMURAL' : 'INTRAMURAL',
                  style: TextStyle(
                    color: isExtramural ? Colors.deepPurple.shade800 : _primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isExtramural
                      ? 'Sector: ${g.sectorComunidad ?? "Comunidad"}'
                      : g.centroSalud,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Turno: ${g.turno}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _green.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.vaccines_rounded, color: _green, size: 16),
                const SizedBox(width: 6),
                Text(
                  '${g.pacientesAtendidos} Atendidos',
                  style: const TextStyle(color: _green, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Botón Gestionar Jornadas
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1565C0),
              side: const BorderSide(color: Color(0xFFBFDBFE)),
              backgroundColor: const Color(0xFFEFF6FF),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.event_note_rounded, size: 15),
            label: Text(
              _jornadaActiva != null ? 'Jornada Activa' : 'Jornadas',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            onPressed: () => GestionarJornadasDialog.show(
              context,
              jornadaActivaActual: _jornadaActiva,
              onSeleccionarJornadaActiva: _onSeleccionarJornada,
            ),
          ),
          const SizedBox(width: 8),
          // Botón Crear Nueva Jornada
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Nueva Jornada', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            onPressed: () async {
              final ok = await CrearJornadaDialog.show(context);
              if (ok == true) {
                _loadInventario();
                GestionarJornadasDialog.show(
                  context,
                  jornadaActivaActual: _jornadaActiva,
                  onSeleccionarJornadaActiva: _onSeleccionarJornada,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _onSeleccionarJornada(Map<String, dynamic> j) {
    setState(() {
      _jornadaActiva = j;
    });
    _reordenarLotesPorJornada();
    final esAutorizado = _isUsuarioAutorizadoEnJornada(j);
    if (!esAutorizado) {
      _showToast('Jornada vinculada en modo lectura: No estás en el personal asignado.');
    } else {
      _showToast('Jornada vinculada: ${j['nombre_operativo'] ?? "Jornada"}');
    }
  }

  void _reordenarLotesPorJornada() {
    if (_jornadaActiva == null || _lotesVacunas.isEmpty) return;
    final stBloq = _jornadaActiva?['stockBloqueado'] as List?;
    if (stBloq == null || stBloq.isEmpty) return;

    final Set<int> idsBloqueados = stBloq
        .map((s) => (s['id_lote_insumo'] as num?)?.toInt())
        .whereType<int>()
        .toSet();

    setState(() {
      _lotesVacunas.sort((a, b) {
        final idA = (_extractLoteId(a) as num?)?.toInt() ?? 0;
        final idB = (_extractLoteId(b) as num?)?.toInt() ?? 0;
        final aBloq = idsBloqueados.contains(idA);
        final bBloq = idsBloqueados.contains(idB);
        if (aBloq && !bBloq) return -1;
        if (!aBloq && bBloq) return 1;
        return 0;
      });

      // Si el lote actual no es de la jornada y hay lotes de la jornada, preseleccionar el primero
      final idSel = (_extractLoteId(_selectedLoteVacuna ?? {}) as num?)?.toInt();
      if (idSel == null || !idsBloqueados.contains(idSel)) {
        final primerLoteJornada = _lotesVacunas.firstWhere(
          (l) => idsBloqueados.contains((_extractLoteId(l) as num?)?.toInt()),
          orElse: () => _selectedLoteVacuna ?? _lotesVacunas.first,
        );
        _selectedLoteVacuna = primerLoteJornada;
      }
    });
  }

  bool _isUsuarioAutorizadoEnJornada(Map<String, dynamic>? jornada) {
    if (jornada == null) return true;
    final auth = context.read<AuthProvider>();
    final user = auth.getCurrentUser();
    final username = user?.username?.toLowerCase() ?? '';
    final roles = user?.roles ?? [];

    // Admins siempre autorizados
    if (roles.contains('Admin')) return true;

    final resp = (jornada['responsable'] ?? '').toString().toLowerCase();
    if (resp == username) return true;

    final rawPersonal = jornada['personal_participante'];
    List parts = [];
    if (rawPersonal is List) {
      parts = rawPersonal;
    } else if (rawPersonal is String && rawPersonal.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawPersonal);
        if (decoded is List) parts = decoded;
      } catch (_) {
        parts = rawPersonal.split(',').map((s) => s.trim()).toList();
      }
    }

    for (final p in parts) {
      final u = (p is Map ? (p['username'] ?? '') : p.toString()).toLowerCase();
      if (u == username) return true;
    }

    return false;
  }

  void _desvincularJornada() {
    setState(() {
      _jornadaActiva = null;
    });
    _showToast('Jornada desvinculada. Trabajando en atención general del CDI.');
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ─── Banner Informativo de Jornada Activa ─────────────────────────────────
  Widget _buildJornadaActivaBanner() {
    if (_jornadaActiva == null) return const SizedBox.shrink();

    final nombre = _jornadaActiva!['nombre_operativo'] ?? 'Jornada';
    final mod = (_jornadaActiva!['modalidad'] ?? 'intramural').toString().toUpperCase();
    final isExt = mod == 'EXTRAMURAL';
    final resp = _jornadaActiva!['responsable'] ?? 'Sin asignar';
    final rawPersonal = _jornadaActiva!['personal_participante'];
    final sector = _jornadaActiva!['sector_comunidad'] ?? 'CDI Central';
    final List stockBloqueado = _jornadaActiva!['stockBloqueado'] ?? [];

    final bool esAutorizado = _isUsuarioAutorizadoEnJornada(_jornadaActiva);

    // Formatear participantes
    String personalStr = '';
    if (rawPersonal is List) {
      personalStr = rawPersonal.map((p) => p is Map ? (p['username'] ?? '') : p.toString()).join(', ');
    } else if (rawPersonal is String && rawPersonal.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawPersonal);
        if (decoded is List) {
          personalStr = decoded.map((p) => p is Map ? (p['username'] ?? '') : p.toString()).join(', ');
        } else {
          personalStr = rawPersonal;
        }
      } catch (_) {
        personalStr = rawPersonal;
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isExt ? const Color(0xFFFAF5FF) : const Color(0xFFF0FDF4),
        border: Border(
          bottom: BorderSide(color: isExt ? const Color(0xFFE9D5FF) : const Color(0xFFBBF7D0)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: isExt ? const Color(0xFF7B1FA2) : const Color(0xFF16A34A),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.campaign_rounded, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  'Jornada: $nombre',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isExt ? const Color(0xFFF3E8FF) : const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isExt ? const Color(0xFFD8B4FE) : const Color(0xFF86EFAC)),
                  ),
                  child: Text(
                    mod,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isExt ? const Color(0xFF7B1FA2) : const Color(0xFF15803D),
                    ),
                  ),
                ),
                Text(
                  isExt ? 'Sector: $sector' : 'Sede: CDI Central',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                ),
                Text(
                  '• Responsable: $resp',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F766E)),
                ),
                if (personalStr.isNotEmpty)
                  Text(
                    '• Participantes: $personalStr',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                if (!esAutorizado)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.red.shade400),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_rounded, size: 12, color: Colors.red),
                        SizedBox(width: 4),
                        Text(
                          'No estás asignado a esta jornada (Sin permiso de registro)',
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                if (stockBloqueado.isNotEmpty) ...[
                  ...stockBloqueado.map<Widget>((st) {
                    final lote = st['lote'] ?? {};
                    final art = lote['articulo'] ?? {};
                    final nomArt = art['nombre_articulo'] ?? 'Vacuna';
                    final rem = st['cantidad_remanente'] ?? 0;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Text(
                        '$nomArt: $rem disp.',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: rem > 0 ? const Color(0xFF15803D) : Colors.red,
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
            tooltip: 'Desvincular jornada',
            onPressed: _desvincularJornada,
          ),
        ],
      ),
    );
  }

  // ─── Pantalla Bloqueada si no hay Guardia ──────────────────────────────────
  Widget _buildBloqueoSinGuardia() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.shield_outlined, size: 64, color: Colors.amber.shade800),
            ),
            const SizedBox(height: 20),
            const Text(
              'Apertura de Guardia Requerida',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 8),
            Text(
              'Para garantizar la trazabilidad epidemiológica oficial de cada dosis aplicada,\nes obligatorio abrir la guardia o despliegue del turno.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
              icon: const Icon(Icons.meeting_room_rounded),
              label: const Text('Abrir Guardia Ahora', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              onPressed: () => AperturaGuardiaDialog.show(context),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Paso 0: Búsqueda Rápida de Pacientes ─────────────────────────────────
  Widget _buildPaso0BuscarPaciente() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Inmunización — Buscar Paciente',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          'Escriba cédula o nombres para seleccionar al paciente en segundos',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.flash_on_rounded, size: 18),
                    label: const Text('+ Alta Rápida', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      QuickPatientDialog.show(
                        context,
                        onPatientCreated: (paciente) {
                          _selectPaciente(paciente);
                        },
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                autofocus: true,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Cédula de identidad, nombre o apellido...',
                  prefixIcon: const Icon(Icons.search_rounded, color: _primary),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            _buscarPaciente(explicitQuery: '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
        ),
        if (_searchLoading)
          const LinearProgressIndicator(minHeight: 2, color: _primary),
        Expanded(
          child: _searchResults.isEmpty && !_searchLoading
              ? _buildEstadoVacio()
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _searchResults.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final p = _searchResults[i];
                    final edad = _calcularEdadTexto(p.fechaNacimiento);
                    final esPed = _isPediatrico(p);

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _selectPaciente(p),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: esPed ? Colors.orange.shade100 : Colors.blue.shade100,
                                child: Icon(
                                  esPed ? Icons.child_care_rounded : (p.sexo == 'F' ? Icons.face_3_rounded : Icons.face_rounded),
                                  color: esPed ? Colors.orange.shade800 : _primary,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            p.nombreCompleto,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                                          ),
                                        ),
                                        if (esPed)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.shade50,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: Colors.orange.shade200),
                                            ),
                                            child: Text(
                                              '< 5 años',
                                              style: TextStyle(fontSize: 10, color: Colors.orange.shade900, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          p.cedula.isNotEmpty ? 'V-${p.cedula}' : 'Sin Cédula (Dependiente)',
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          '•  Edad: $edad',
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _primary.withOpacity(0.1),
                                  foregroundColor: _primary,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                onPressed: () => _selectPaciente(p),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('Vacunar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    SizedBox(width: 4),
                                    Icon(Icons.arrow_forward_rounded, size: 14),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEstadoVacio() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_search_rounded, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            _searchController.text.isEmpty
                ? 'No hay pacientes recientes en pantalla'
                : 'No se encontraron pacientes para "${_searchController.text}"',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.flash_on_rounded),
            label: const Text('Alta Rápida de Paciente'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _teal,
              side: const BorderSide(color: _teal),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              QuickPatientDialog.show(
                context,
                onPatientCreated: (paciente) {
                  _selectPaciente(paciente);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  void _volverBusqueda() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.arrow_back_rounded, color: Color(0xFF1565C0)),
            SizedBox(width: 8),
            Text('¿Volver al buscador?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Se perderán los datos ingresados en el formulario de vacunación. ¿Desea continuar?',
          style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: const Text('Sí, volver'),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _step = 0;
                _selectedPaciente = null;
                _insumosUsados = [];
                _tempCtrl.text = '36.5';
                _pesoCtrl.clear();
                _tallaCtrl.clear();
              });
            },
          ),
        ],
      ),
    );
  }

  // ─── Paso 1: Formulario de Vacunación Rápida (< 45 seg) ────────────────────
  Widget _buildPaso1VacunacionRapida() {
    final p = _selectedPaciente!;
    final esPed = _isPediatrico(p);
    final edad = _calcularEdadTexto(p.fechaNacimiento);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Botón volver + título
            Row(
              children: [
                // Botón de retroceso prominente
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1565C0),
                    side: const BorderSide(color: Color(0xFF1565C0)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: const Text('Volver', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  onPressed: _volverBusqueda,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Registro Rápido de Dosis',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Tarjeta Paciente
            Card(
              elevation: 0,
              color: Colors.blue.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.blue.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: _primary,
                      child: const Icon(Icons.person_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.nombreCompleto,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${p.cedula.isNotEmpty ? "Cédula: V-" + p.cedula : "Sin Cédula (Dependiente)"}  •  Edad: $edad  •  Sexo: ${p.sexo}',
                            style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                          ),
                        ],
                      ),
                    ),
                    if (esPed)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade300),
                        ),
                        child: Text(
                          'PEDIÁTRICO (< 5 AÑOS)',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange.shade900),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Documentos Oficiales de Salida Rápida (Récipe & Constancia)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.assignment_outlined, color: Color(0xFF475569), size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Documentos del Paciente:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1E3A8A),
                          side: const BorderSide(color: Color(0xFFBFDBFE)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          ConstanciaAtencionDialog.show(
                            context,
                            paciente: p,
                            profesionalNombre: _getVacunadorActual(),
                            motivoAtencion: 'Inmunización / Atención Sanitaria Preventiva',
                          );
                        },
                        icon: const Icon(Icons.verified_rounded, size: 15),
                        label: const Text('Emitir Constancia Médica (QR)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0284C7),
                          side: const BorderSide(color: Color(0xFFBAE6FD)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          ConstanciaAtencionDialog.show(context, paciente: p);
                        },
                        icon: const Icon(Icons.verified_rounded, size: 15),
                        label: const Text('Constancia Oficial (QR)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Card 1: Biológico y Aplicación
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.vaccines_rounded, color: _primary, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Vacuna y Dosis',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    // Selector de Lote / Vacuna
                    DropdownButtonFormField<Map<String, dynamic>>(
                      value: _selectedLoteVacuna,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Biológico / Lote Disponible *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      items: _lotesVacunas.map((l) {
                        final art = l['articulo'] ?? {};
                        final nombre = art['nombre_articulo'] ?? l['nombre_articulo'] ?? 'Biológico';
                        final numLote = l['numero_lote'] ?? l['lote'] ?? 'S/L';
                        final stock = l['stock_actual'] ?? l['stock'] ?? 0;

                        final stBloq = _jornadaActiva?['stockBloqueado'] as List?;
                        final matchSt = stBloq?.firstWhere(
                          (s) => s['id_lote_insumo'] == _extractLoteId(l),
                          orElse: () => null,
                        );
                        final String stockTexto = matchSt != null
                            ? '⭐ JORNADA: ${matchSt['cantidad_remanente'] ?? 0} disp.'
                            : 'Stock: $stock';

                        return DropdownMenuItem<Map<String, dynamic>>(
                          value: l,
                          child: Text(
                            '$nombre — Lote: $numLote ($stockTexto)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: matchSt != null ? FontWeight.bold : FontWeight.normal,
                              color: matchSt != null ? const Color(0xFF1565C0) : null,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedLoteVacuna = val;
                          // Autosugestión de vía y sitio según vacuna
                          if (val != null) {
                            final art = val['articulo'] ?? {};
                            final nombre = (art['nombre_articulo'] ?? val['nombre_articulo'] ?? '')
                                .toString().toLowerCase();
                            if (nombre.contains('polio') || nombre.contains('oral') || nombre.contains('vop') || nombre.contains('vpv')) {
                              _viaAdministracion = 'Oral';
                              _sitioAdministracion = 'Oral';
                            } else if (nombre.contains('bcg') || nombre.contains('intrader')) {
                              _viaAdministracion = 'Intradérmica';
                              _sitioAdministracion = 'Brazo derecho';
                            } else if (nombre.contains('srp') || nombre.contains('sarampion') || nombre.contains('mmr') || nombre.contains('varicela')) {
                              _viaAdministracion = 'Subcutánea';
                              _sitioAdministracion = 'Brazo izquierdo';
                            } else if (nombre.contains('penta') || nombre.contains('hepat') || nombre.contains('meningoc') || nombre.contains('neumococ') || nombre.contains('influenza') || nombre.contains('covid') || nombre.contains('toxoide')) {
                              _viaAdministracion = 'Intramuscular';
                              final esPed = _isPediatrico(_selectedPaciente);
                              _sitioAdministracion = esPed ? 'Muslo izquierdo' : 'Brazo izquierdo';
                            } else {
                              _viaAdministracion = 'Intramuscular';
                              _sitioAdministracion = 'Brazo izquierdo';
                            }
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 14),

                    // Dosis Aplicada
                    const Text('Dosis / Esquema:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _dosisOpciones.map((d) {
                        final isSel = _dosisAplicada == d;
                        return ChoiceChip(
                          label: Text(d),
                          selected: isSel,
                          onSelected: (sel) {
                            if (sel) setState(() => _dosisAplicada = d);
                          },
                          selectedColor: _primary,
                          labelStyle: TextStyle(
                            color: isSel ? Colors.white : const Color(0xFF334155),
                            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Vía de Administración y Sitio Anatómico
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _viaAdministracion,
                            decoration: InputDecoration(
                              labelText: 'Vía de Administración',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            items: _viasOpciones.map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 12)))).toList(),
                            onChanged: (v) => setState(() => _viaAdministracion = v ?? 'Intramuscular'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _sitioAdministracion,
                            decoration: InputDecoration(
                              labelText: 'Sitio Anatómico',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            items: _sitiosOpciones.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))).toList(),
                            onChanged: (s) => setState(() => _sitioAdministracion = s ?? 'Brazo izquierdo'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Card 2: Triaje Mínimo Rápido
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.thermostat_rounded, color: Colors.orange, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Screening Rápido',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _tempCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^d*.?d?'))],
                            decoration: InputDecoration(
                              labelText: 'Temperatura (°C)',
                              suffixText: '°C',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ),
                        if (esPed) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _pesoCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^d*.?d?'))],
                              decoration: InputDecoration(
                                labelText: 'Peso (kg)',
                                suffixText: 'kg',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _tallaCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^d*.?d?'))],
                              decoration: InputDecoration(
                                labelText: 'Talla (cm)',
                                suffixText: 'cm',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (esPed)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Peso y talla son opcionales pero recomendados en menores de 5 años.',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // ⚠️ Alerta de fiebre
            if (_tieneAlertaFiebre)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade300, width: 1.5),
                ),
                child: Row(
                  children: [
                    Icon(Icons.thermostat_rounded, color: Colors.red.shade700, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '⚠️  Alerta de Fiebre — ${_tempCtrl.text.trim()} °C',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade800,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            'Temperatura elevada detectada. Evalúe la postergación de la vacuna según protocolo clínico.',
                            style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            // Botón de Confirmación Principal
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                icon: _savingAtencion
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline_rounded, size: 22),
                label: Text(
                  _savingAtencion ? 'REGISTRANDO...' : 'REGISTRAR VACUNACIÓN',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
                onPressed: _savingAtencion ? null : _guardarVacunacion,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

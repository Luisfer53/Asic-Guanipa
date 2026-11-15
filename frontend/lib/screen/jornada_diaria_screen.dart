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

class _VacunaItem {
  Map<String, dynamic>? lote;
  String? dosis;
  String? via;
  String? sitio;
  int? idEsquema;
  _VacunaItem();
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

  // Historial de vacunas del paciente seleccionado (para cálculo inteligente de dosis)
  List<Map<String, dynamic>> _historialVacunasPaciente = [];
  bool _cargandoHistorial = false;

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

  // Lista de vacunas a aplicar en esta visita (hasta 6)
  static const int _maxVacunasPorVisita = 6;
  List<_VacunaItem> _vacunasAplicar = [_VacunaItem()];

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
  List<Map<String, dynamic>> _esquemasPai = [];
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
              return (exp == null || exp.isAfter(today)) &&
                  ((l['stock_actual'] ?? 0) > 0 || (l['stock_reservado'] ?? 0) > 0);
            })
            .map((l) => Map<String, dynamic>.from(l))
            .toList();

        _lotesVacunas = valid.where((l) {
          final art = l['articulo'] ?? {};
          final t = (art['tipo'] ?? l['tipo'] ?? '').toString().toLowerCase().trim();
          final n = (art['nombre_articulo'] ?? l['nombre_articulo'] ?? '').toString().toLowerCase();
          // Excluir tajantemente cualquier equipo médico o insumo descartable
          if (t.contains('equipo') || t.contains('cava') || t.contains('termo') || t == 'insumo' ||
              n.contains('cava') || n.contains('termo') || n.contains('guante') || n.contains('jeringa')) {
            return false;
          }
          return t == 'vacuna' || t == 'biologico' || t == 'biológico' ||
              n.contains('vacun') || n.contains('biol') || n.contains('toxoide') ||
              n.contains('pentavalente') || n.contains('bcg') || n.contains('srp') ||
              n.contains('polio') || n.contains('hepat') || n.contains('influenza') ||
              n.contains('fiebre') || n.contains('vph') || n.contains('rotavirus');
        }).toList();

        _lotesInsumos = valid.where((l) {
          final art = l['articulo'] ?? {};
          final t = (art['tipo'] ?? l['tipo'] ?? '').toString().toLowerCase().trim();
          final n = (art['nombre_articulo'] ?? l['nombre_articulo'] ?? '').toString().toLowerCase();
          // Excluir vacunas y excluir equipos médicos / cadena de frío reutilizables
          if (t == 'vacuna' || t.contains('equipo') || t.contains('cava') || t.contains('termo') ||
              n.contains('vacun') || n.contains('biol') || n.contains('cava') || n.contains('termo') ||
              n.contains('balanza') || n.contains('tensiomet') || n.contains('fonendo') || n.contains('tallimetro')) {
            return false;
          }
          return t == 'insumo' || t.contains('descart') || t.contains('material') || t == 'medicamento' ||
              n.contains('jeringa') || n.contains('inyect') || n.contains('aguja') || n.contains('guante') ||
              n.contains('algodon') || n.contains('alcohol') || n.contains('gasa') || n.contains('adhesiv') ||
              n.contains('curita') || n.contains('baja lengua') || n.contains('bajalengua');
        }).toList();

        _reordenarLotesPorJornada();
      }

      try {
        final esqRes = await _api.getEsquemas();
        if (esqRes['success'] == true && mounted) {
          _esquemasPai = List<Map<String, dynamic>>.from(esqRes['data'] ?? []);
        }
      } catch (_) {}
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
      _historialVacunasPaciente = [];
      // Pre-cargar signos vitales previos si existen
      if (p.peso != null && p.peso! > 0) {
        _pesoCtrl.text = p.peso.toString();
      } else {
        _pesoCtrl.clear();
      }
      _tallaCtrl.clear();
      _tempCtrl.text = '36.5';
    });
    _cargarHistorialPaciente(p);
  }

  Future<void> _cargarHistorialPaciente(Paciente p) async {
    setState(() => _cargandoHistorial = true);
    try {
      final ident = p.cedula.isNotEmpty ? p.cedula : p.idPaciente.toString();
      final res = await _api.getHistorialPaciente(ident);
      if (res['success'] == true && res['atenciones'] != null) {
        final List atenciones = res['atenciones'] as List;
        final List<Map<String, dynamic>> vacs = [];
        for (final a in atenciones) {
          final fecha = (a['fecha_visita'] ?? '').toString();
          final vacunaciones = a['vacunaciones'] as List? ?? [];
          for (final v in vacunaciones) {
            final lote = v['lote'] as Map<String, dynamic>? ?? {};
            final art = lote['articulo'] as Map<String, dynamic>? ?? {};
            final nombreArt = (art['nombre_articulo'] ?? lote['nombre_articulo'] ?? '').toString();
            final dosis = (v['dosis_aplicada'] ?? '').toString();
            vacs.add({
              'fecha': fecha,
              'nombre_articulo': nombreArt,
              'id_articulo': art['id_articulo'] ?? lote['id_articulo'],
              'id_lote': lote['id_lote_insumo'] ?? lote['id_lote'],
              'dosis_aplicada': dosis,
            });
          }
        }
        if (mounted) {
          setState(() {
            _historialVacunasPaciente = vacs;
            // Si ya hay vacunas seleccionadas en los renglones, aplicar la dosis correspondiente
            for (final v in _vacunasAplicar) {
              if (v.lote != null) {
                _autoSugerirDosis(v);
              }
            }
          });
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _cargandoHistorial = false);
    }
  }

  String _normalizarNombreVacuna(String raw) {
    var s = raw.toLowerCase().trim();
    s = s.replaceAll('á', 'a').replaceAll('é', 'e').replaceAll('í', 'i').replaceAll('ó', 'o').replaceAll('ú', 'u');
    s = s.replaceAll('vacuna', '').replaceAll('biologico', '').trim();
    return s;
  }

  bool _esMismoBiologico(Map<String, dynamic>? lote, Map<String, dynamic> regHistorial) {
    if (lote == null) return false;
    final art = lote['articulo'] as Map<String, dynamic>? ?? {};
    final idArtLote = art['id_articulo'] ?? lote['id_articulo'];
    final idArtHist = regHistorial['id_articulo'];
    if (idArtLote != null && idArtHist != null && idArtLote.toString() == idArtHist.toString()) {
      return true;
    }

    final nomLote = _normalizarNombreVacuna((art['nombre_articulo'] ?? lote['nombre_articulo'] ?? '').toString());
    final nomHist = _normalizarNombreVacuna((regHistorial['nombre_articulo'] ?? '').toString());

    if (nomLote.isEmpty || nomHist.isEmpty) return false;
    if (nomLote == nomHist) return true;

    const keywords = [
      'bcg', 'pentavalente', 'polio', 'vop', 'ipv', 'srp', 'sarampion',
      'hepatitis b', 'hepatitis a', 'toxoide', 'antiamaril', 'fiebre amarilla',
      'influenza', 'neumococo', 'rotavirus', 'vph', 'covid'
    ];
    for (final k in keywords) {
      if (nomLote.contains(k) && nomHist.contains(k)) {
        return true;
      }
    }

    return nomLote.contains(nomHist) || nomHist.contains(nomLote);
  }

  List<String> _obtenerDosisPrevias(Map<String, dynamic>? lote, {required _VacunaItem renglonActual}) {
    if (lote == null) return [];
    final dosisList = <String>[];
    for (final reg in _historialVacunasPaciente) {
      if (_esMismoBiologico(lote, reg)) {
        final d = (reg['dosis_aplicada'] ?? '').toString().trim();
        if (d.isNotEmpty && !dosisList.contains(d)) {
          dosisList.add(d);
        }
      }
    }
    for (final otro in _vacunasAplicar) {
      if (identical(otro, renglonActual)) break;
      if (otro.lote != null && otro.dosis != null) {
        final artOtro = otro.lote!['articulo'] ?? {};
        if (_esMismoBiologico(lote, {'nombre_articulo': artOtro['nombre_articulo'] ?? otro.lote!['nombre_articulo'], 'id_articulo': artOtro['id_articulo']})) {
          if (!dosisList.contains(otro.dosis!)) {
            dosisList.add(otro.dosis!);
          }
        }
      }
    }
    return dosisList;
  }

  String _calcularSiguienteDosis(List<String> dosisPrevias, String nombreBiologico) {
    final lower = nombreBiologico.toLowerCase();
    final esUnica = lower.contains('bcg') || lower.contains('fiebre amarilla') || lower.contains('antiamaril');

    bool tiene(String keyword) {
      final kw = keyword.toLowerCase().trim();
      return dosisPrevias.any((d) {
        final dl = d.toLowerCase().trim();
        return dl == kw || dl.contains(kw);
      });
    }

    if (esUnica && !tiene('única') && !tiene('unica')) {
      return 'Única';
    }

    if (!tiene('1ra') && !tiene('primera') && !tiene('1')) {
      return '1ra Dosis';
    }
    if (!tiene('2da') && !tiene('segunda') && !tiene('2')) {
      return '2da Dosis';
    }
    if (!tiene('3ra') && !tiene('tercera') && !tiene('3')) {
      return '3ra Dosis';
    }
    if (!tiene('refuerzo 1') && !tiene('1er refuerzo') && !tiene('primer refuerzo')) {
      return 'Refuerzo 1';
    }
    if (!tiene('refuerzo 2') && !tiene('2do refuerzo') && !tiene('segundo refuerzo')) {
      return 'Refuerzo 2';
    }
    return 'Refuerzo Anual';
  }

  void _autoSugerirDosis(_VacunaItem item) {
    if (item.lote == null) return;
    final art = item.lote!['articulo'] ?? {};
    final nombreArt = (art['nombre_articulo'] ?? item.lote!['nombre_articulo'] ?? '').toString();
    final previas = _obtenerDosisPrevias(item.lote, renglonActual: item);
    item.dosis = _calcularSiguienteDosis(previas, nombreArt);
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

  int? _pacienteEdadEnMeses() {
    if (_selectedPaciente == null || _selectedPaciente!.fechaNacimiento.isEmpty) return null;
    final fn = DateTime.tryParse(_selectedPaciente!.fechaNacimiento);
    if (fn == null) return null;
    return (DateTime.now().difference(fn).inDays / 30.44).floor();
  }

  /// Encuentra la regla de esquema PAI para el biológico y dosis seleccionados
  Map<String, dynamic>? _buscarReglaEsquema(_VacunaItem item) {
    if (item.lote == null) return null;
    final art = item.lote!['articulo'] ?? {};
    final idArt = art['id_articulo'] ?? item.lote!['id_articulo'];
    final nomArt = (art['nombre_articulo'] ?? item.lote!['nombre_articulo'] ?? '').toString().toLowerCase();

    final esquemasVacuna = _esquemasPai.where((e) {
      if (idArt != null && e['id_articulo'] == idArt) return true;
      final nomEsq = (e['vacuna']?['nombre_articulo'] ?? '').toString().toLowerCase();
      if (nomEsq.isEmpty) return false;
      return nomArt.contains(nomEsq) || nomEsq.contains(nomArt.split(' ')[0]);
    }).toList();

    if (esquemasVacuna.isEmpty) return null;

    final dl = (item.dosis ?? '').toLowerCase().trim();
    return esquemasVacuna.firstWhere((e) {
      final nd = (e['numero_dosis'] ?? '').toString().toLowerCase().trim();
      return nd == dl || nd.contains(dl) || dl.contains(nd);
    }, orElse: () => esquemasVacuna.first);
  }

  /// Retorna la cantidad total de dosis necesarias para el esquema completo de este biológico
  int _obtenerTotalDosisEsquema(_VacunaItem item) {
    if (item.lote == null) return 1;
    final art = item.lote!['articulo'] ?? {};
    final idArt = art['id_articulo'] ?? item.lote!['id_articulo'];
    final nomArt = (art['nombre_articulo'] ?? item.lote!['nombre_articulo'] ?? '').toString().toLowerCase();

    final esquemasVacuna = _esquemasPai.where((e) {
      if (idArt != null && e['id_articulo'] == idArt) return true;
      final nomEsq = (e['vacuna']?['nombre_articulo'] ?? '').toString().toLowerCase();
      if (nomEsq.isEmpty) return false;
      return nomArt.contains(nomEsq) || nomEsq.contains(nomArt.split(' ')[0]);
    }).toList();

    return esquemasVacuna.isNotEmpty ? esquemasVacuna.length : 1;
  }

  /// Calcula la fecha sugerida de la próxima cita/aplicación si hay siguiente dosis
  Map<String, dynamic>? _calcularSiguienteCita(_VacunaItem item) {
    if (item.lote == null || item.dosis == null) return null;
    final art = item.lote!['articulo'] ?? {};
    final idArt = art['id_articulo'] ?? item.lote!['id_articulo'];
    final nomArt = (art['nombre_articulo'] ?? item.lote!['nombre_articulo'] ?? '').toString().toLowerCase();

    final esquemasVacuna = _esquemasPai.where((e) {
      if (idArt != null && e['id_articulo'] == idArt) return true;
      final nomEsq = (e['vacuna']?['nombre_articulo'] ?? '').toString().toLowerCase();
      if (nomEsq.isEmpty) return false;
      return nomArt.contains(nomEsq) || nomEsq.contains(nomArt.split(' ')[0]);
    }).toList();

    if (esquemasVacuna.isEmpty) return null;

    final dl = item.dosis!.toLowerCase().trim();
    final idxActual = esquemasVacuna.indexWhere((e) {
      final nd = (e['numero_dosis'] ?? '').toString().toLowerCase().trim();
      return nd == dl || nd.contains(dl) || dl.contains(nd);
    });

    if (idxActual >= 0 && idxActual + 1 < esquemasVacuna.length) {
      final sigRegla = esquemasVacuna[idxActual + 1];
      final intervalo = sigRegla['intervalo_dias_previo'] as int? ?? 60;
      final proxFecha = DateTime.now().add(Duration(days: intervalo));
      final dia = proxFecha.day.toString().padLeft(2, '0');
      final mes = proxFecha.month.toString().padLeft(2, '0');
      return {
        'siguienteDosis': sigRegla['numero_dosis'],
        'intervaloDias': intervalo,
        'fechaTexto': '$dia/$mes/${proxFecha.year}',
        'esUltima': false,
      };
    } else {
      return {
        'esUltima': true,
      };
    }
  }

  // ─── Guardar Vacunación Rápida ────────────────────────────────────────────
  Future<void> _guardarVacunacion() async {
    if (_selectedPaciente == null) return;

    // Validar que al menos una vacuna esté completa
    final vacunasValidas = _vacunasAplicar
        .where((v) => v.lote != null && v.dosis != null && v.via != null && v.sitio != null)
        .toList();

    if (vacunasValidas.isEmpty) {
      _showError('Complete al menos una vacuna con lote, dosis, vía y sitio');
      return;
    }

    // Validar que ningún renglón esté incompleto (parcialmente lleno)
    for (int i = 0; i < _vacunasAplicar.length; i++) {
      final v = _vacunasAplicar[i];
      final camposLlenos = [v.lote, v.dosis, v.via, v.sitio].where((c) => c != null).length;
      if (camposLlenos > 0 && camposLlenos < 4) {
        _showError('El renglón ${i + 1} está incompleto. Complete todos sus campos o elimínelo.');
        return;
      }
    }

    // Validar autorización de usuario si hay jornada vinculada
    if (_jornadaActiva != null && !_isUsuarioAutorizadoEnJornada(_jornadaActiva)) {
      final user = context.read<AuthProvider>().getCurrentUser()?.username ?? '';
      _showError('Acceso denegado: El usuario "@$user" no está asignado como participante en esta jornada. Solo el personal asignado puede registrar en ella.');
      return;
    }

    // Validar si el usuario seleccionó una dosis ya registrada previamente en el historial
    final vacunasDuplicadas = <String>[];
    for (final v in vacunasValidas) {
      final prev = _obtenerDosisPrevias(v.lote, renglonActual: v);
      if (prev.any((p) {
        final pl = p.toLowerCase().trim();
        final vl = (v.dosis ?? '').toLowerCase().trim();
        return pl == vl || pl.contains(vl) || vl.contains(pl);
      })) {
        final art = v.lote!['articulo'] ?? {};
        final n = (art['nombre_articulo'] ?? v.lote!['nombre_articulo'] ?? 'Vacuna').toString();
        vacunasDuplicadas.add('$n (${v.dosis})');
      }
    }

    if (vacunasDuplicadas.isNotEmpty) {
      final bool? confirmar = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 26),
              SizedBox(width: 10),
              Expanded(
                child: Text('Posible Dosis Duplicada', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'El paciente ya tiene registrada(s) en su historial la(s) siguiente(s) dosis:',
                style: TextStyle(fontSize: 13, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFCD34D)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: vacunasDuplicadas.map((d) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text('• $d', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF92400E))),
                  )).toList(),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '¿Desea corregir la dosis o registrar el duplicado de todos modos?',
                style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
              ),
            ],
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Corregir Dosis'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Registrar de todos modos'),
            ),
          ],
        ),
      );
      if (confirmar != true) return;
    }

    final guardiaProv = context.read<GuardiaProvider>();
    final guardia = guardiaProv.guardia;

    setState(() => _savingAtencion = true);

    final double? tempVal = double.tryParse(_tempCtrl.text.trim());
    final double? pesoVal = double.tryParse(_pesoCtrl.text.trim());
    final double? tallaVal = double.tryParse(_tallaCtrl.text.trim());

    final vacunaciones = vacunasValidas.map((v) {
      final loteId = _extractLoteId(v.lote!);
      final regla = _buscarReglaEsquema(v);
      return {
        'id_lote': loteId,
        'id_esquema': v.idEsquema ?? regla?['id_esquema'],
        'dosis_aplicada': v.dosis!,
        'via_administracion': v.via!,
        'sitio_administracion': v.sitio!,
        'temperatura': tempVal,
        'peso': pesoVal,
        'talla': tallaVal,
        'modalidad': guardia?.modalidad ?? 'intramural',
      };
    }).toList();

    final Map<dynamic, int> consumosMap = {};
    for (final v in vacunasValidas) {
      final loteId = _extractLoteId(v.lote!);
      if (loteId != null) {
        consumosMap[loteId] = (consumosMap[loteId] ?? 0) + 1;
      }
    }
    for (final ins in _insumosUsados) {
      if (ins.lote != null && ins.cantidad > 0) {
        final idIns = _extractLoteId(ins.lote!);
        if (idIns != null) {
          consumosMap[idIns] = (consumosMap[idIns] ?? 0) + ins.cantidad;
        }
      }
    }
    final consumos = consumosMap.entries
        .map((e) => {'id_lote_insumo': e.key, 'cantidad_usada': e.value})
        .toList();

    final atencionPayload = {
      'fecha_visita': DateTime.now().toIso8601String().split('T')[0],
      'diagnostico_general': vacunasValidas.length > 1 ? 'Inmunización preventiva — ${vacunasValidas.length} vacunas' : 'Inmunización preventiva',
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

      // Actualizar stock remanente local para cada vacuna registrada
      if (_jornadaActiva != null && _jornadaActiva!['stockBloqueado'] != null) {
        final List stList = _jornadaActiva!['stockBloqueado'];
        for (final v in vacunasValidas) {
          final loteId = _extractLoteId(v.lote!);
          for (final st in stList) {
            if (st['id_lote_insumo'] == loteId) {
              st['cantidad_usada'] = (st['cantidad_usada'] ?? 0) + 1;
              st['cantidad_remanente'] = ((st['cantidad_remanente'] ?? 1) - 1).clamp(0, 999999);
            }
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
        _vacunasAplicar = [_VacunaItem()];
      });

      _searchController.clear();
      _buscarPaciente(explicitQuery: '');
      _searchFocusNode.requestFocus();

      _showSuccessWithCarnet(pacienteGuardado, vacunasValidas.length);
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

  void _showSuccessWithCarnet(Paciente paciente, [int numVacunas = 1]) {
    final vacunador = _getVacunadorActual();
    final msg = numVacunas > 1
        ? '$numVacunas vacunas de ${paciente.nombreCompleto} registradas exitosamente'
        : 'Vacunación de ${paciente.nombreCompleto} registrada exitosamente';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
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
    final isMobile = MediaQuery.of(context).size.width < 700;

    if (!activa) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.amber.shade100,
          border: Border(bottom: BorderSide(color: Colors.amber.shade400)),
        ),
        child: isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No hay guardia activa.',
                          style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.amber.shade900,
                          side: BorderSide(color: Colors.amber.shade700),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        icon: const Icon(Icons.arrow_back_rounded, size: 13),
                        label: const Text('Inicio', style: TextStyle(fontSize: 11)),
                        onPressed: () => context.canPop() ? context.pop() : context.go('/'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade900,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('Abrir Guardia Ahora', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () => AperturaGuardiaDialog.show(context),
                  ),
                ],
              )
            : Row(
                children: [
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
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: 8),
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
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1565C0),
                        side: const BorderSide(color: Color(0xFFBFDBFE)),
                        backgroundColor: const Color(0xFFEFF6FF),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      icon: const Icon(Icons.arrow_back_rounded, size: 13),
                      label: const Text('Inicio', style: TextStyle(fontSize: 11)),
                      onPressed: () => context.canPop() ? context.pop() : context.go('/'),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: isExtramural ? Colors.deepPurple.shade50 : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isExtramural ? Colors.deepPurple.shade200 : Colors.blue.shade200),
                      ),
                      child: Text(
                        isExtramural ? 'EXTRAMURAL' : 'INTRAMURAL',
                        style: TextStyle(
                          color: isExtramural ? Colors.deepPurple.shade800 : _primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 9.5,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _green.withOpacity(0.3)),
                      ),
                      child: Text(
                        '${g.pacientesAtendidos} Atendidos',
                        style: const TextStyle(color: _green, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      isExtramural ? 'Sector: ${g.sectorComunidad ?? "Comunidad"}' : g.centroSalud,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E293B)),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF1565C0),
                            side: const BorderSide(color: Color(0xFFBFDBFE)),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            minimumSize: const Size(0, 28),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          onPressed: () => GestionarJornadasDialog.show(
                            context,
                            jornadaActivaActual: _jornadaActiva,
                            onSeleccionarJornadaActiva: _onSeleccionarJornada,
                          ),
                          child: const Text('Jornadas', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 6),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            minimumSize: const Size(0, 28),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
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
                          child: const Text('+ Nueva', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            )
          : Row(
              children: [
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

      // Ordenamiento completado sin forzar selección automática
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
                _vacunasAplicar = [_VacunaItem()];
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
    final isMobile = MediaQuery.of(context).size.width < 700;

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
                          foregroundColor: const Color(0xFF0D9488),
                          side: const BorderSide(color: Color(0xFF99F6E4)),
                          backgroundColor: const Color(0xFFF0FDFA),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          CarnetVacunacionDialog.show(
                            context,
                            paciente: p,
                            vacunadorNombre: _getVacunadorActual(),
                          );
                        },
                        icon: const Icon(Icons.qr_code_2_rounded, size: 15),
                        label: const Text('Ver Carnet de Vacunación (QR)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                      // [CONSTANCIA OCULTA] OutlinedButton 'Constancia Oficial de Atención (QR)' removido
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Card 1: Vacunas a Aplicar (hasta 6 en una visita)
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
                    // Encabezado de la sección
                    Row(
                      children: [
                        const Icon(Icons.vaccines_rounded, color: _primary, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Vacunas a Aplicar',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                              ),
                              Text(
                                'Puede registrar hasta 6 vacunas en una sola visita',
                                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        if (_vacunasAplicar.length < _maxVacunasPorVisita)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Agregar Vacuna', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            onPressed: () {
                              setState(() {
                                _vacunasAplicar.add(_VacunaItem());
                              });
                            },
                          ),
                      ],
                    ),
                    const Divider(height: 20),

                    // Lista de renglones de vacunas
                    ...List.generate(_vacunasAplicar.length, (idx) {
                      final item = _vacunasAplicar[idx];
                      return _buildVacunaRenglon(idx, item, isMobile);
                    }),

                    if (_vacunasAplicar.length >= _maxVacunasPorVisita)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded, color: Colors.amber.shade800, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'Límite máximo de $_maxVacunasPorVisita vacunas por visita alcanzado.',
                              style: TextStyle(fontSize: 12, color: Colors.amber.shade900, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
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
                    isMobile && esPed
                        ? Column(
                            children: [
                              TextFormField(
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
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
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
                                  const SizedBox(width: 10),
                                  Expanded(
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
                              ),
                            ],
                          )
                        : Row(
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
            const SizedBox(height: 16),

            // Card 3: Insumos Médicos Descartables Utilizados
            _buildInsumosCard(isMobile),
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
                  _savingAtencion
                      ? 'REGISTRANDO...'
                      : _vacunasAplicar.where((v) => v.lote != null).length > 1
                          ? 'REGISTRAR ${_vacunasAplicar.where((v) => v.lote != null).length} VACUNAS'
                          : 'REGISTRAR VACUNACIÓN',
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

  // ─── Card 3: Insumos Médicos Descartables Utilizados ─────────────────────────
  Widget _buildInsumosCard(bool isMobile) {
    return Card(
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
            Row(
              children: [
                const Icon(Icons.medical_services_outlined, color: _primary, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Insumos Médicos Descartables Utilizados',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      Text(
                        'Jeringas descartables, agujas, torundas de algodón o guantes utilizados',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary.withOpacity(0.1),
                    foregroundColor: _primary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    setState(() {
                      _insumosUsados.add(_InsumoItem());
                    });
                  },
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                  label: const Text('+ Agregar Insumo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_insumosUsados.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 20, color: Colors.grey.shade400),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'No se han registrado insumos adicionales (opcional). Si utilizó jeringas descartables, agujas o algodón, haga clic en "+ Agregar Insumo" para descargarlos del inventario.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...List.generate(_insumosUsados.length, (idx) {
                final item = _insumosUsados[idx];
                final int stockMax = (item.lote?['stock_actual'] is num) ? (item.lote!['stock_actual'] as num).toInt() : 999;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: isMobile
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DropdownButtonFormField<Map<String, dynamic>>(
                              value: item.lote,
                              isExpanded: true,
                              hint: const Text('Seleccionar insumo / lote disponible', style: TextStyle(fontSize: 12)),
                              items: _lotesInsumos.map((l) {
                                final art = l['articulo'] ?? {};
                                final nom = art['nombre_articulo'] ?? l['nombre_articulo'] ?? 'Insumo';
                                final lot = l['numero_lote'] ?? '';
                                final stock = l['stock_actual'] ?? 0;
                                return DropdownMenuItem(
                                  value: l,
                                  child: Text(
                                    '$nom ($lot) — Disp: $stock',
                                    style: const TextStyle(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() {
                                  item.lote = val;
                                  final s = (val?['stock_actual'] is num) ? (val!['stock_actual'] as num).toInt() : 999;
                                  if (item.cantidad > s && s > 0) item.cantidad = s;
                                });
                              },
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Text('Cantidad:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                                  onPressed: item.cantidad > 1
                                      ? () => setState(() => item.cantidad--)
                                      : null,
                                ),
                                Text('${item.cantidad}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, size: 20),
                                  onPressed: item.cantidad < stockMax
                                      ? () => setState(() => item.cantidad++)
                                      : null,
                                ),
                                const Spacer(),
                                IconButton(
                                  tooltip: 'Eliminar insumo',
                                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
                                  onPressed: () {
                                    setState(() {
                                      _insumosUsados.removeAt(idx);
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: DropdownButtonFormField<Map<String, dynamic>>(
                                value: item.lote,
                                isExpanded: true,
                                hint: const Text('Seleccionar insumo / lote disponible', style: TextStyle(fontSize: 12)),
                                items: _lotesInsumos.map((l) {
                                  final art = l['articulo'] ?? {};
                                  final nom = art['nombre_articulo'] ?? l['nombre_articulo'] ?? 'Insumo';
                                  final lot = l['numero_lote'] ?? '';
                                  final stock = l['stock_actual'] ?? 0;
                                  return DropdownMenuItem(
                                    value: l,
                                    child: Text(
                                      '$nom ($lot) — Disp: $stock',
                                      style: const TextStyle(fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setState(() {
                                    item.lote = val;
                                    final s = (val?['stock_actual'] is num) ? (val!['stock_actual'] as num).toInt() : 999;
                                    if (item.cantidad > s && s > 0) item.cantidad = s;
                                  });
                                },
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, size: 20, color: Color(0xFF64748B)),
                              onPressed: item.cantidad > 1
                                  ? () => setState(() => item.cantidad--)
                                  : null,
                            ),
                            SizedBox(
                              width: 60,
                              child: TextFormField(
                                key: ValueKey('insumo_${idx}_${item.cantidad}'),
                                initialValue: item.cantidad.toString(),
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                onChanged: (val) {
                                  final parsed = int.tryParse(val) ?? 1;
                                  item.cantidad = parsed > stockMax ? stockMax : (parsed < 1 ? 1 : parsed);
                                },
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, size: 20, color: Color(0xFF64748B)),
                              onPressed: item.cantidad < stockMax
                                  ? () => setState(() => item.cantidad++)
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: 'Eliminar insumo',
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                              onPressed: () {
                                setState(() {
                                  _insumosUsados.removeAt(idx);
                                });
                              },
                            ),
                          ],
                        ),
                );
              }),
          ],
        ),
      ),
    );
  }

  // ─── Renglón individual de vacuna (dentro del listado multi-vacuna) ────────
  Widget _buildVacunaRenglon(int idx, _VacunaItem item, bool isMobile) {
    final esUnico = _vacunasAplicar.length == 1;
    final numero = idx + 1;
    final dosisPrevias = _obtenerDosisPrevias(item.lote, renglonActual: item);

    void autoSugerirViaSitio(_VacunaItem v) {
      if (v.lote == null) return;
      final art = v.lote!['articulo'] ?? {};
      final nombre = (art['nombre_articulo'] ?? v.lote!['nombre_articulo'] ?? '').toString().toLowerCase();
      if (nombre.contains('polio') || nombre.contains('oral') || nombre.contains('vop')) {
        v.via = 'Oral';
        v.sitio = 'Oral';
      } else if (nombre.contains('bcg') || nombre.contains('intrader')) {
        v.via = 'Intradérmica';
        v.sitio = 'Brazo derecho';
      } else if (nombre.contains('srp') || nombre.contains('sarampion') || nombre.contains('mmr') || nombre.contains('varicela')) {
        v.via = 'Subcutánea';
        v.sitio = 'Brazo izquierdo';
      } else {
        v.via = 'Intramuscular';
        v.sitio = _isPediatrico(_selectedPaciente) ? 'Muslo izquierdo' : 'Brazo izquierdo';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: item.lote != null ? const Color(0xFF93C5FD) : const Color(0xFFCBD5E1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Vacuna #$numero',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
              const Spacer(),
              if (!esUnico)
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.red, size: 20),
                  tooltip: 'Eliminar esta vacuna',
                  onPressed: () => setState(() => _vacunasAplicar.removeAt(idx)),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Selector de Biológico / Lote
          DropdownButtonFormField<Map<String, dynamic>>(
            value: item.lote,
            isExpanded: true,
            hint: const Text('Seleccionar Biológico / Lote...', style: TextStyle(fontSize: 12)),
            decoration: InputDecoration(
              labelText: 'Biológico / Lote *',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
              final stockTexto = matchSt != null
                  ? '⭐ JORNADA: ${matchSt['cantidad_remanente'] ?? 0} disp.'
                  : 'Stock: $stock';
              return DropdownMenuItem<Map<String, dynamic>>(
                value: l,
                child: Text(
                  '$nombre — Lote: $numLote ($stockTexto)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: matchSt != null ? FontWeight.bold : FontWeight.normal,
                    color: matchSt != null ? const Color(0xFF1565C0) : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (val) {
              setState(() {
                item.lote = val;
                autoSugerirViaSitio(item);
                _autoSugerirDosis(item);
              });
            },
          ),
          if (item.lote != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: dosisPrevias.isNotEmpty ? const Color(0xFFEFF6FF) : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: dosisPrevias.isNotEmpty ? const Color(0xFF93C5FD) : const Color(0xFFBBF7D0),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    dosisPrevias.isNotEmpty ? Icons.history_edu_rounded : Icons.fiber_new_rounded,
                    size: 16,
                    color: dosisPrevias.isNotEmpty ? const Color(0xFF1D4ED8) : const Color(0xFF16A34A),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: dosisPrevias.isNotEmpty
                        ? Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(
                                  text: 'Dosis previas registradas: ',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF1E3A8A)),
                                ),
                                TextSpan(
                                  text: '${dosisPrevias.join(", ")}  ➔  ',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF1E40AF)),
                                ),
                                TextSpan(
                                  text: 'Asignada: ${item.dosis ?? "Por asignar"}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF15803D)),
                                ),
                              ],
                            ),
                          )
                        : Text(
                            'Sin dosis previas registradas de esta vacuna. Se asignó automáticamente: ${item.dosis ?? "1ra Dosis"}.',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF166534)),
                          ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),

          // Dosis (chips)
          const Text('Dosis / Esquema:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _dosisOpciones.map((d) {
              final isSel = item.dosis == d;
              final yaAplicada = dosisPrevias.any((dp) {
                final dpl = dp.toLowerCase().trim();
                final dl = d.toLowerCase().trim();
                return dpl == dl || dpl.contains(dl) || dl.contains(dpl);
              });
              return ChoiceChip(
                avatar: yaAplicada
                    ? const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF047857))
                    : null,
                label: Text(
                  yaAplicada ? '$d (Ya aplicada)' : d,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                    color: isSel
                        ? Colors.white
                        : (yaAplicada ? const Color(0xFF047857) : const Color(0xFF334155)),
                  ),
                ),
                selected: isSel,
                onSelected: (sel) {
                  if (sel) {
                    if (yaAplicada) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('⚠️ Nota: El paciente ya tiene registrada la "$d" de este biológico.'),
                          backgroundColor: const Color(0xFFD97706),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                    setState(() => item.dosis = d);
                  }
                },
                selectedColor: yaAplicada ? const Color(0xFFD97706) : _primary,
                backgroundColor: yaAplicada ? const Color(0xFFECFDF5) : null,
              );
            }).toList(),
          ),
          // Información biomédica del Esquema PAI para esta vacuna y dosis
          if (item.lote != null && item.dosis != null) ...[
            Builder(builder: (context) {
              final regla = _buscarReglaEsquema(item);
              if (regla != null) {
                item.idEsquema = regla['id_esquema'];
              }
              final totalDosis = _obtenerTotalDosisEsquema(item);
              final sigCita = _calcularSiguienteCita(item);
              final edadMin = regla?['edad_minima_meses'] as int?;
              final edadMesesPac = _pacienteEdadEnMeses();
              final bool alertaEdad = (edadMin != null && edadMesesPac != null && edadMesesPac < edadMin);

              String edadTextoMin = 'Al nacer (0 meses)';
              if (edadMin != null && edadMin > 0) {
                if (edadMin < 12) {
                  edadTextoMin = '$edadMin meses';
                } else {
                  final a = edadMin ~/ 12;
                  final r = edadMin % 12;
                  edadTextoMin = r == 0 ? '$a año${a > 1 ? "s" : ""}' : '$a año${a > 1 ? "s" : ""} $r m';
                }
              }

              return Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: alertaEdad ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: alertaEdad ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          alertaEdad ? Icons.warning_amber_rounded : Icons.verified_user_rounded,
                          size: 16,
                          color: alertaEdad ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Esquema PAI: $totalDosis dosis requeridas en total',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: alertaEdad ? const Color(0xFF991B1B) : const Color(0xFF166534),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '• Edad mínima recomendada: $edadTextoMin' +
                                (alertaEdad ? ' (⚠️ El paciente tiene $edadMesesPac meses)' : ''),
                            style: TextStyle(
                              fontSize: 11,
                              color: alertaEdad ? const Color(0xFFB91C1C) : const Color(0xFF1E293B),
                              fontWeight: alertaEdad ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    if (sigCita != null)
                      Text(
                        sigCita['esUltima'] == true
                            ? '• Próxima fecha: No requerida (¡Esta dosis completa el esquema PAI de este biológico!)'
                            : '• Próxima fecha sugerida: ${sigCita['fechaTexto']} (Dosis: ${sigCita['siguienteDosis']}, en ${sigCita['intervaloDias']} días)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: sigCita['esUltima'] == true ? const Color(0xFF15803D) : const Color(0xFF7C3AED),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],
          const SizedBox(height: 10),

          // Vía y Sitio
          isMobile
              ? Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: item.via,
                      hint: const Text('Vía...', style: TextStyle(fontSize: 12)),
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Vía de Administración *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: _viasOpciones.map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 12)))).toList(),
                      onChanged: (v) => setState(() => item.via = v),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: item.sitio,
                      hint: const Text('Sitio...', style: TextStyle(fontSize: 12)),
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Sitio Anatómico *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: _sitiosOpciones.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))).toList(),
                      onChanged: (s) => setState(() => item.sitio = s),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: item.via,
                        hint: const Text('Vía de Administración...', style: TextStyle(fontSize: 12)),
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Vía de Administración *',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: _viasOpciones.map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 12)))).toList(),
                        onChanged: (v) => setState(() => item.via = v),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: item.sitio,
                        hint: const Text('Sitio Anatómico...', style: TextStyle(fontSize: 12)),
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Sitio Anatómico *',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: _sitiosOpciones.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))).toList(),
                        onChanged: (s) => setState(() => item.sitio = s),
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }
}

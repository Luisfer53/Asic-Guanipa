import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:asis_guanipa_frontend/services/api_service.dart';
import 'package:asis_guanipa_frontend/models/paciente.dart';
import 'package:asis_guanipa_frontend/providers/guardia_provider.dart';
import 'package:asis_guanipa_frontend/components/apertura_guardia_dialog.dart';
import 'nominal_register/quick_patient_dialog.dart';
import 'nominal_register/constancia_atencion_dialog.dart';

class _InsumoItem {
  Map<String, dynamic>? lote;
  int cantidad;
  _InsumoItem({this.lote, this.cantidad = 1});
}

class ConsultaMedicaScreen extends StatefulWidget {
  const ConsultaMedicaScreen({super.key});

  @override
  State<ConsultaMedicaScreen> createState() => _ConsultaMedicaScreenState();
}

class _ConsultaMedicaScreenState extends State<ConsultaMedicaScreen> {
  final ApiService _api = ApiService();

  // Flujo en 2 Pasos: 0 = Buscar / Seleccionar Paciente, 1 = Consulta Clínica
  int _step = 0;

  // Paso 0: Búsqueda
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  Timer? _searchDebounce;
  bool _searchLoading = false;
  List<Paciente> _searchResults = [];
  Paciente? _selectedPaciente;

  // Paso 1: Formulario Clínico
  final _formKey = GlobalKey<FormState>();
  bool _savingConsulta = false;

  // Signos Vitales
  final _paSistolicaCtrl = TextEditingController(text: '120');
  final _paDiastolicaCtrl = TextEditingController(text: '80');
  final _fcCtrl = TextEditingController(text: '75');
  final _frCtrl = TextEditingController(text: '18');
  final _tempCtrl = TextEditingController(text: '36.5');
  final _spo2Ctrl = TextEditingController(text: '98');
  final _pesoCtrl = TextEditingController();
  final _tallaCtrl = TextEditingController();

  // Evaluación y Diagnóstico
  final _motivoConsultaCtrl = TextEditingController();
  final _diagnosticoCtrl = TextEditingController();
  final _observacionesCtrl = TextEditingController();

  // Tratamiento
  final _tratamientoCtrl = TextEditingController();

  // Insumos/Medicamentos suministrados del almacén
  List<_InsumoItem> _medicamentosSuministrados = [];
  List<Map<String, dynamic>> _lotesDisponibles = [];
  bool _loadingInventario = false;

  static const _primary = Color(0xFF1565C0);
  static const _blueDark = Color(0xFF0D47A1);
  static const _teal = Color(0xFF00897B);
  static const _green = Color(0xFF2E7D32);

  // Cálculo de IMC
  double? get _imc {
    final peso = double.tryParse(_pesoCtrl.text.trim());
    final tallaCm = double.tryParse(_tallaCtrl.text.trim());
    if (peso != null && tallaCm != null && tallaCm > 0) {
      final tallaM = tallaCm / 100.0;
      return peso / (tallaM * tallaM);
    }
    return null;
  }

  String get _clasificacionImc {
    final imc = _imc;
    if (imc == null) return '';
    if (imc < 18.5) return 'Bajo peso';
    if (imc < 25.0) return 'Normopeso';
    if (imc < 30.0) return 'Sobrepeso';
    if (imc < 35.0) return 'Obesidad Grado I';
    return 'Obesidad Grado II+';
  }

  Color get _colorImc {
    final imc = _imc;
    if (imc == null) return Colors.grey;
    if (imc < 18.5) return Colors.orange;
    if (imc < 25.0) return _green;
    if (imc < 30.0) return Colors.amber.shade800;
    return Colors.red.shade700;
  }

  // Alerta fiebre
  bool get _tieneAlertaFiebre {
    final t = double.tryParse(_tempCtrl.text.trim());
    return t != null && t >= 38.0;
  }

  // Alerta hipertensión
  bool get _tieneAlertaPresion {
    final sis = int.tryParse(_paSistolicaCtrl.text.trim());
    final dia = int.tryParse(_paDiastolicaCtrl.text.trim());
    return (sis != null && sis >= 140) || (dia != null && dia >= 90);
  }

  @override
  void initState() {
    super.initState();
    _loadInventario();
    _buscarPaciente(explicitQuery: '');
    _tempCtrl.addListener(() {
      if (mounted) setState(() {});
    });
    _paSistolicaCtrl.addListener(() {
      if (mounted) setState(() {});
    });
    _paDiastolicaCtrl.addListener(() {
      if (mounted) setState(() {});
    });
    _pesoCtrl.addListener(() {
      if (mounted) setState(() {});
    });
    _tallaCtrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _paSistolicaCtrl.dispose();
    _paDiastolicaCtrl.dispose();
    _fcCtrl.dispose();
    _frCtrl.dispose();
    _tempCtrl.dispose();
    _spo2Ctrl.dispose();
    _pesoCtrl.dispose();
    _tallaCtrl.dispose();
    _motivoConsultaCtrl.dispose();
    _diagnosticoCtrl.dispose();
    _observacionesCtrl.dispose();
    _tratamientoCtrl.dispose();
    super.dispose();
  }

  // ─── Carga de Medicamentos / Insumos del Almacén ────────────────────────────
  Future<void> _loadInventario() async {
    setState(() => _loadingInventario = true);
    try {
      final invRes = await _api.getInventario();
      if (invRes['success'] == true) {
        final List data = invRes['data'] ?? [];
        final today = DateTime.now();
        _lotesDisponibles = data
            .where((l) {
              final exp = DateTime.tryParse(l['fecha_vencimiento'] ?? '');
              return exp != null && exp.isAfter(today) && (l['stock_actual'] ?? 0) > 0;
            })
            .map((l) => Map<String, dynamic>.from(l))
            .toList();
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingInventario = false);
  }

  int? _extractLoteId(Map<String, dynamic> lote) {
    return lote['id_lote_insumo'] ?? lote['id_lote'] ?? lote['id'];
  }

  // ─── Búsqueda de Pacientes ────────────────────────────────────────────────
  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _buscarPaciente(explicitQuery: query);
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

  void _seleccionarPaciente(Paciente p) {
    setState(() {
      _selectedPaciente = p;
      _step = 1;
      // Prellenar peso si el paciente ya tiene
      if (p.peso != null && p.peso! > 0) {
        _pesoCtrl.text = p.peso.toString();
      }
    });
  }

  // ─── Guardar Consulta Médica ──────────────────────────────────────────────
  Future<void> _guardarConsulta() async {
    if (_selectedPaciente == null) return;
    if (!_formKey.currentState!.validate()) return;

    final guardiaProv = context.read<GuardiaProvider>();
    final guardia = guardiaProv.guardia;

    setState(() => _savingConsulta = true);

    final paText = '${_paSistolicaCtrl.text.trim()}/${_paDiastolicaCtrl.text.trim()}';
    final double? tempVal = double.tryParse(_tempCtrl.text.trim());
    final double? pesoVal = double.tryParse(_pesoCtrl.text.trim());
    final double? tallaVal = double.tryParse(_tallaCtrl.text.trim());
    final int? fcVal = int.tryParse(_fcCtrl.text.trim());
    final int? frVal = int.tryParse(_frCtrl.text.trim());
    final int? spo2Val = int.tryParse(_spo2Ctrl.text.trim());

    final consumos = <Map<String, dynamic>>[];
    for (final med in _medicamentosSuministrados) {
      if (med.lote != null && med.cantidad > 0) {
        final idLot = _extractLoteId(med.lote!);
        if (idLot != null) {
          consumos.add({'id_lote_insumo': idLot, 'cantidad_usada': med.cantidad});
        }
      }
    }

    final atencionPayload = {
      'fecha_visita': DateTime.now().toIso8601String().split('T')[0],
      'tipo_atencion': 'consulta_medica',
      'diagnostico_general': _diagnosticoCtrl.text.trim(),
      'motivo_consulta': _motivoConsultaCtrl.text.trim(),
      'presion_arterial': paText,
      'frecuencia_cardiaca': fcVal,
      'frecuencia_respiratoria': frVal,
      'saturacion_oxigeno': spo2Val,
      'temperatura': tempVal,
      'peso': pesoVal,
      'talla': tallaVal,
      'tratamiento_indicado': _tratamientoCtrl.text.trim(),
      'observaciones': _observacionesCtrl.text.trim(),
      'guardia_modalidad': guardia?.modalidad ?? 'intramural',
      'guardia_centro': guardia?.centroSalud,
      'guardia_sector': guardia?.sectorComunidad,
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
      vacunaciones: null, // Consulta médica no incluye vacunas en este flujo
      cedula: _selectedPaciente!.cedula,
    );

    setState(() => _savingConsulta = false);

    if (res['success'] == true) {
      await guardiaProv.registrarAtencion();
      final pacienteAtendido = _selectedPaciente!;
      final diagTexto = _diagnosticoCtrl.text.isNotEmpty ? _diagnosticoCtrl.text : _motivoConsultaCtrl.text;

      // Limpiar y regresar al buscador para atender al siguiente paciente
      setState(() {
        _step = 0;
        _selectedPaciente = null;
        _motivoConsultaCtrl.clear();
        _diagnosticoCtrl.clear();
        _observacionesCtrl.clear();
        _tratamientoCtrl.clear();
        _paSistolicaCtrl.text = '120';
        _paDiastolicaCtrl.text = '80';
        _fcCtrl.text = '75';
        _frCtrl.text = '18';
        _tempCtrl.text = '36.5';
        _spo2Ctrl.text = '98';
        _pesoCtrl.clear();
        _tallaCtrl.clear();
        _medicamentosSuministrados = [];
      });

      _searchController.clear();
      _buscarPaciente(explicitQuery: '');
      _searchFocusNode.requestFocus();

      _showSuccessWithRecipe(pacienteAtendido, diagTexto);

      // Diálogo de documentos oficiales con botones destacados
      if (mounted) {
        showDialog(
          context: context,
          builder: (dlgCtx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 28),
                SizedBox(width: 10),
                Expanded(child: Text('¡Consulta Registrada!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
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
                      'La consulta médica de ${pacienteAtendido.nombreCompleto} ha sido guardada con éxito.',
                      style: const TextStyle(fontSize: 14, color: Color(0xFF334155), height: 1.3),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.verified_rounded, color: Color(0xFF0284C7), size: 24),
                          SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Constancia de Asistencia Disponible',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0284C7)),
                                ),
                                Text(
                                  'Emita la constancia médica oficial con código QR de verificación para trámites escolares, laborales e institucionales.',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF0369A1)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Documentos para este Paciente:',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 10),
                    // BOTÓN PRINCIPAL: CONSTANCIA MÉDICA CON QR
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 1,
                      ),
                      onPressed: () {
                        Navigator.pop(dlgCtx);
                        ConstanciaAtencionDialog.show(
                          context,
                          paciente: pacienteAtendido,
                          motivoAtencion: diagTexto,
                        );
                      },
                      icon: const Icon(Icons.verified_rounded, size: 20),
                      label: const Text(
                        'Emitir Constancia Médica (QR)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dlgCtx),
                child: const Text('Cerrar / Siguiente Paciente'),
              ),
            ],
          ),
        );
      }
    } else {
      _showError(res['message'] ?? 'Error al registrar consulta médica');
    }
  }

  void _showSuccessWithRecipe(Paciente paciente, String diag) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text('Consulta de ${paciente.nombreCompleto} registrada exitosamente')),
          ],
        ),
        action: SnackBarAction(
          label: 'VER CONSTANCIA',
          textColor: Colors.amberAccent,
          onPressed: () => ConstanciaAtencionDialog.show(
            context,
            paciente: paciente,
            motivoAtencion: diag,
          ),
        ),
        backgroundColor: const Color(0xFF16A34A),
        duration: const Duration(seconds: 7),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ─── BUILD PRINCIPAL ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final guardiaProv = context.watch<GuardiaProvider>();
    final g = guardiaProv.guardia;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Consulta Médica General & Triaje',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white),
            ),
            Text(
              'ASIC Guanipa / CDI Pedro Urbina',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: _blueDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () {
            if (_step == 1) {
              setState(() => _step = 0);
            } else {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/');
              }
            }
          },
        ),
      ),
      body: Column(
        children: [
          _buildGuardiaBar(guardiaProv, g),
          Expanded(
            child: _step == 0 ? _buildPaso0Buscador() : _buildPaso1FormularioClinico(),
          ),
        ],
      ),
    );
  }

  // ─── Barra de Estado de Guardia ───────────────────────────────────────────
  Widget _buildGuardiaBar(GuardiaProvider prov, dynamic g) {
    if (g == null) {
      return Container(
        color: Colors.amber.shade50,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: Colors.amber.shade900, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No hay una guardia activa. Inicie guardia para vincular la atención.',
                style: TextStyle(color: Colors.amber.shade900, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: () => AperturaGuardiaDialog.show(context),
              child: const Text('Abrir Guardia', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Text(
              'GUARDIA ACTIVA',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
            ),
          ),
          const SizedBox(width: 12),
          Icon(Icons.business_rounded, size: 15, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(g.centroSalud ?? 'CDI Pedro Urbina', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          Icon(Icons.access_time_rounded, size: 15, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(g.turno ?? 'Mañana', style: const TextStyle(fontSize: 12)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.people_alt_rounded, size: 14, color: _green),
                const SizedBox(width: 6),
                Text(
                  '${g.pacientesAtendidos} atendidos',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _green),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── PASO 0: Buscador y Selección de Paciente ─────────────────────────────
  Widget _buildPaso0Buscador() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 820),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Buscar por Cédula, Nombre o Apellido...',
                      prefixIcon: const Icon(Icons.search_rounded, color: _primary),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => QuickPatientDialog(
                        onPatientCreated: (p) {
                          _seleccionarPaciente(p);
                        },
                      ),
                    );
                  },
                  icon: const Icon(Icons.flash_on_rounded, size: 18),
                  label: const Text('⚡ Alta Rápida', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Seleccione el paciente para iniciar la consulta médica:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _searchLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _searchResults.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_search_rounded, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(
                                'No se encontraron pacientes con ese criterio.',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => QuickPatientDialog(
                                      onPatientCreated: (p) => _seleccionarPaciente(p),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: _teal, foregroundColor: Colors.white),
                                child: const Text('+ Dar de Alta al Vuelo'),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: _searchResults.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final p = _searchResults[i];
                            return Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(color: Colors.grey.shade300),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: _primary.withOpacity(0.12),
                                          child: Icon(Icons.person_rounded, color: _primary),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                p.nombreCompleto,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                              ),
                                              Text(
                                                'Cédula: ${p.cedula.isNotEmpty ? p.cedula : "Sin cédula"}  |  Sexo: ${p.sexo}  |  Edad: ${p.edad != null ? "${p.edad} años" : "—"}',
                                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        ElevatedButton.icon(
                                          onPressed: () => ConstanciaAtencionDialog.show(context, paciente: p),
                                          icon: const Icon(Icons.verified_rounded, size: 15, color: Colors.white),
                                          label: const Text('Constancia Médica (QR)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF0284C7),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                        ),
                                        ElevatedButton.icon(
                                          onPressed: () => _seleccionarPaciente(p),
                                          icon: const Icon(Icons.medical_services_rounded, size: 15),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _primary,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          label: const Text('Atender en Consulta', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── PASO 1: Formulario Clínico de Consulta ───────────────────────────────
  Widget _buildPaso1FormularioClinico() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildPacienteCard(),
                const SizedBox(height: 16),
                _buildTriajeCard(),
                const SizedBox(height: 16),
                _buildEvaluacionCard(),
                const SizedBox(height: 16),
                _buildTratamientoCard(),
                const SizedBox(height: 24),
                _buildBotonesAccion(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Card Paciente
  Widget _buildPacienteCard() {
    final p = _selectedPaciente!;
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: _primary.withOpacity(0.12),
              child: const Icon(Icons.person_rounded, color: _primary, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.nombreCompleto,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'C.I.: ${p.cedula.isNotEmpty ? p.cedula : "Sin Cédula"}  •  Edad: ${p.edad != null ? "${p.edad} años" : "—"}  •  Sexo: ${p.sexo}  •  Dirección: ${p.direccion ?? "—"}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => setState(() => _step = 0),
              icon: const Icon(Icons.swap_horiz_rounded, size: 16),
              label: const Text('Cambiar', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
                side: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Card 1: Triaje Clínico & Signos Vitales
  Widget _buildTriajeCard() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.monitor_heart_rounded, color: Colors.red.shade700, size: 22),
                const SizedBox(width: 8),
                const Text(
                  '1. Triaje Clínico & Signos Vitales',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
              ],
            ),
            const Divider(height: 24),
            // Alertas visuales
            if (_tieneAlertaPresion)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade400),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '⚠️ Alerta de Presión Arterial Elevada (≥ 140/90 mmHg). Se sugiere reposo y rechequeo.',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            if (_tieneAlertaFiebre)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.thermostat_rounded, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '⚠️ Paciente Febril (Temperatura ≥ 38.0 °C). Priorizar antipirético y examen foco infeccioso.',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red.shade800),
                      ),
                    ),
                  ],
                ),
              ),

            // Campos de signos vitales en fila responsiva
            Wrap(
              spacing: 16,
              runSpacing: 14,
              children: [
                // Presión Arterial
                SizedBox(
                  width: 220,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Presión Arterial (PA)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _paSistolicaCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: const InputDecoration(
                                hintText: '120',
                                suffixText: '/',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: TextFormField(
                              controller: _paDiastolicaCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: const InputDecoration(
                                hintText: '80',
                                suffixText: 'mmHg',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Frecuencia Cardíaca
                SizedBox(
                  width: 140,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Frec. Cardíaca (FC)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _fcCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(
                          hintText: '75',
                          suffixText: 'lpm',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),

                // Frecuencia Respiratoria
                SizedBox(
                  width: 140,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Frec. Resp. (FR)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _frCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(
                          hintText: '18',
                          suffixText: 'rpm',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),

                // Temperatura
                SizedBox(
                  width: 140,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Temperatura', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _tempCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          hintText: '36.5',
                          suffixText: '°C',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),

                // Saturación SpO2
                SizedBox(
                  width: 140,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Sat. Oxígeno (SpO2)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _spo2Ctrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(
                          hintText: '98',
                          suffixText: '%',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),

                // Peso
                SizedBox(
                  width: 140,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Peso', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _pesoCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          hintText: 'Ej. 70.5',
                          suffixText: 'kg',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),

                // Talla
                SizedBox(
                  width: 140,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Talla / Altura', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _tallaCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          hintText: 'Ej. 170',
                          suffixText: 'cm',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Badge de IMC si se han ingresado peso y talla
            if (_imc != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _colorImc.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _colorImc.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.accessibility_new_rounded, size: 18, color: _colorImc),
                    const SizedBox(width: 8),
                    Text(
                      'IMC: ${_imc!.toStringAsFixed(1)} kg/m²  (${_clasificacionImc})',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _colorImc),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Card 2: Anamnesis y Diagnóstico
  Widget _buildEvaluacionCard() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.medical_information_rounded, color: _primary, size: 22),
                const SizedBox(width: 8),
                const Text(
                  '2. Motivo de Consulta & Diagnóstico Clínico',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
              ],
            ),
            const Divider(height: 24),
            // Motivo de consulta
            TextFormField(
              controller: _motivoConsultaCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Motivo de Consulta / Anamnesis *',
                hintText: 'Describa los síntomas y tiempo de evolución referidos por el paciente...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'El motivo de consulta es obligatorio';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Diagnóstico
            TextFormField(
              controller: _diagnosticoCtrl,
              decoration: const InputDecoration(
                labelText: 'Diagnóstico Principal *',
                hintText: 'Ej. Hipertensión arterial estadio 1, Faringitis aguda, Cefalea tensional...',
                prefixIcon: Icon(Icons.assignment_turned_in_rounded, color: _primary),
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'El diagnóstico es obligatorio';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Observaciones
            TextFormField(
              controller: _observacionesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Examen Físico / Observaciones (Opcional)',
                hintText: 'Hallazgos relevantes al examen físico, antecedentes o conductas a seguir...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Card 3: Plan Terapéutico y Despacho de Insumos
  Widget _buildTratamientoCard() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 10,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.medication_liquid_rounded, color: _teal, size: 22),
                    const SizedBox(width: 8),
                    const Text(
                      '3. Plan Terapéutico & Despacho de Farmacia (CDI)',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0284C7),
                        side: const BorderSide(color: Color(0xFFBAE6FD)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        if (_selectedPaciente != null) {
                          ConstanciaAtencionDialog.show(
                            context,
                            paciente: _selectedPaciente!,
                          );
                        } else {
                          _showError('Seleccione un paciente primero');
                        }
                      },
                      icon: const Icon(Icons.verified_rounded, size: 16),
                      label: const Text('Constancia Oficial (QR)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        if (_selectedPaciente != null) {
                          ConstanciaAtencionDialog.show(
                            context,
                            paciente: _selectedPaciente!,
                            motivoAtencion: _diagnosticoCtrl.text.isNotEmpty
                                ? _diagnosticoCtrl.text
                                : _motivoConsultaCtrl.text,
                          );
                        } else {
                          _showError('Seleccione un paciente primero');
                        }
                      },
                      icon: const Icon(Icons.verified_rounded, size: 16),
                      label: const Text('Emitir Constancia Médica (QR)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            TextFormField(
              controller: _tratamientoCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Tratamiento Indicado / Indicaciones Médicas *',
                hintText: '1. Medicamento, dosis, vía y horario...\n2. Medidas no farmacológicas...\n3. Pauta de alarma y control.',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'El tratamiento e indicaciones son obligatorios';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            // Banner de Acceso Rápido a la Constancia Médica
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_rounded, color: Color(0xFF0284C7), size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Constancia Médica Oficial (MPPS / CDI)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0284C7)),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Genere la constancia de asistencia con fecha, diagnóstico y código QR verificable.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF0369A1)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      if (_selectedPaciente != null) {
                        ConstanciaAtencionDialog.show(
                          context,
                          paciente: _selectedPaciente!,
                          motivoAtencion: _diagnosticoCtrl.text.isNotEmpty
                              ? _diagnosticoCtrl.text
                              : _motivoConsultaCtrl.text,
                        );
                      } else {
                        _showError('Seleccione un paciente primero');
                      }
                    },
                    icon: const Icon(Icons.verified_rounded, size: 16),
                    label: const Text('Emitir Constancia Médica', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Sección de Medicamentos e Insumos suministrados del Almacén
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Medicamentos o Insumos Suministrados en el CDI (Opcional):',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _medicamentosSuministrados.add(_InsumoItem());
                    });
                  },
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                  label: const Text('Agregar Fármaco / Insumo'),
                ),
              ],
            ),

            if (_medicamentosSuministrados.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No se ha suministrado medicación de farmacia en esta consulta (solo indicaciones médicas).',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                ),
              )
            else
              ...List.generate(_medicamentosSuministrados.length, (idx) {
                final item = _medicamentosSuministrados[idx];
                return Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<Map<String, dynamic>>(
                          value: item.lote,
                          isExpanded: true,
                          hint: const Text('Seleccionar fármaco / lote disponible', style: TextStyle(fontSize: 12)),
                          items: _lotesDisponibles.map((l) {
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
                            setState(() => item.lote = val);
                          },
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 90,
                        child: TextFormField(
                          initialValue: item.cantidad.toString(),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(
                            labelText: 'Cant.',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          ),
                          onChanged: (val) {
                            item.cantidad = int.tryParse(val) ?? 1;
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            _medicamentosSuministrados.removeAt(idx);
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

  // Botones de Acción
  Widget _buildBotonesAccion() {
    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 10,
      children: [
        OutlinedButton(
          onPressed: () => setState(() => _step = 0),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Cancelar / Regresar'),
        ),
        OutlinedButton.icon(
          onPressed: () {
            if (_selectedPaciente != null) {
              ConstanciaAtencionDialog.show(context, paciente: _selectedPaciente!);
            } else {
              _showError('Seleccione un paciente primero');
            }
          },
          icon: const Icon(Icons.verified_rounded, size: 18, color: Color(0xFF0284C7)),
          label: const Text('Constancia Oficial (QR)', style: TextStyle(color: Color(0xFF0284C7), fontWeight: FontWeight.bold)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFF0284C7)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),

        ElevatedButton.icon(
          onPressed: _savingConsulta ? null : _guardarConsulta,
          icon: _savingConsulta
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.check_circle_outline_rounded, size: 20),
          label: Text(
            _savingConsulta ? 'Guardando...' : 'Finalizar Consulta Médica',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }
}

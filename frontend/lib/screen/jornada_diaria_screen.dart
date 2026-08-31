import 'dart:async';

import 'package:flutter/material.dart';
import 'package:asis_guanipa_frontend/services/api_service.dart';
import 'package:asis_guanipa_frontend/models/paciente.dart';
import 'nominal_register/create_patient_dialog.dart';
import 'package:asis_guanipa_frontend/utils/upper_case_text_formatter.dart';
import 'package:responsive_framework/responsive_framework.dart';

class JornadaDiariaScreen extends StatefulWidget {
  const JornadaDiariaScreen({super.key});
  @override
  State<JornadaDiariaScreen> createState() => _JornadaDiariaScreenState();
}

class _JornadaDiariaScreenState extends State<JornadaDiariaScreen> {
  final ApiService _api = ApiService();

  // Stepper
  int _step = 0;

  // Step 0: Búsqueda / Registro de Paciente
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  bool _searchLoading = false;
  List<Paciente> _searchResults = [];
  Paciente? _selectedPaciente;

  // Step 1: Registro de Atención
  final _atencionFormKey = GlobalKey<FormState>();
  bool _esJornada = false;

  // Operativo / Centro
  List<Map<String, dynamic>> _operativos = [];
  List<Map<String, dynamic>> _centros = [];
  Map<String, dynamic>? _selectedOperativo;
  Map<String, dynamic>? _selectedCentroMap;
  bool _loadingCatalogos = false;

  // Crear operativo inline
  bool _mostrarCrearOperativo = false;
  final _nomOperativoCtrl = TextEditingController();
  final _lugarOperativoCtrl = TextEditingController();
  String _tipoJornadaSel = 'Jornada Externa Comunitaria';
  DateTime _fechaOperativo = DateTime.now();

  static const _tiposJornada = [
    'Jornada Externa Comunitaria',
    'CDI Principal / ASIC Guanipa',
    'CPT 1 (Consultorio Popular Tipo 1)',
    'CPT 2 (Consultorio Popular Tipo 2)',
    'CPT 3 (Consultorio Popular Tipo 3)',
    'Barrio Adentro / Barrio Nuevo',
  ];

  // Datos atención
  final _motivoCtrl = TextEditingController();
  final _diagnosticoCtrl = TextEditingController();
  final _observacionesCtrl = TextEditingController();
  final _tratamientoCtrl = TextEditingController();
  final _telefonoPacienteCtrl = TextEditingController();
  final _correoPacienteCtrl = TextEditingController();
  final _callePacienteCtrl = TextEditingController();
  final _numeroCasaCtrl = TextEditingController();
  final _puntoReferenciaCtrl = TextEditingController();
  DateTime _fechaVisita = DateTime.now();

  // Signos vitales
  final _pesoCtrl = TextEditingController();
  final _tallaCtrl = TextEditingController();
  final _tempCtrl = TextEditingController();
  final _presionCtrl = TextEditingController();
  final _frqCardCtrl = TextEditingController();
  final _frqRespCtrl = TextEditingController();
  final _satO2Ctrl = TextEditingController();

  // Biológico e insumos (Biológico es 100% opcional)
  Map<String, dynamic>? _selectedLoteVacuna;
  String _dosisAplicada = '1ra Dosis';
  List<Map<String, dynamic>> _esquemasGuardados = [];
  Map<String, dynamic>? _selectedEsquemaMap;
  bool _usarDosisManual = false;
  final _dosisManualCtrl = TextEditingController(text: '1ra Dosis');

  List<_InsumoItem> _insumosUsados = [];
  List<Map<String, dynamic>> _lotesVacunas = [];
  List<Map<String, dynamic>> _lotesInsumos = [];
  bool _loadingInventario = false;
  bool _savingAtencion = false;

  static const _primary = Color(0xFF1565C0);
  static const _green = Color(0xFF2E7D32);

  @override
  void initState() {
    super.initState();
    _cargarCatalogos();
    _buscarPaciente(explicitQuery: '');
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _nomOperativoCtrl.dispose();
    _lugarOperativoCtrl.dispose();
    _motivoCtrl.dispose();
    _diagnosticoCtrl.dispose();
    _observacionesCtrl.dispose();
    _tratamientoCtrl.dispose();
    _telefonoPacienteCtrl.dispose();
    _correoPacienteCtrl.dispose();
    _callePacienteCtrl.dispose();
    _numeroCasaCtrl.dispose();
    _puntoReferenciaCtrl.dispose();
    _pesoCtrl.dispose();
    _tallaCtrl.dispose();
    _tempCtrl.dispose();
    _presionCtrl.dispose();
    _frqCardCtrl.dispose();
    _frqRespCtrl.dispose();
    _satO2Ctrl.dispose();
    _dosisManualCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarCatalogos() async {
    setState(() => _loadingCatalogos = true);
    try {
      final opRes = await _api.getOperativos();
      final cRes = await _api.getCentrosSalud();
      final esqRes = await _api.getEsquemas();
      setState(() {
        if (opRes['success'] == true) {
          _operativos = List<Map<String, dynamic>>.from(opRes['data'] ?? []);
        }
        if (cRes['success'] == true) {
          _centros = List<Map<String, dynamic>>.from(cRes['data'] ?? []);
          if (_centros.isNotEmpty && _selectedCentroMap == null) {
            _selectedCentroMap = _centros.first;
          }
        }
        if (esqRes['success'] == true) {
          _esquemasGuardados = List<Map<String, dynamic>>.from(
            esqRes['data'] ?? [],
          );
        }
      });
    } catch (_) {}
    setState(() => _loadingCatalogos = false);
  }

  Future<void> _dialogNuevoEsquema(
    int idArticulo,
    String nombreArticulo,
  ) async {
    final dosisCtrl = TextEditingController(text: _dosisManualCtrl.text);
    final minMesesCtrl = TextEditingController();
    final maxMesesCtrl = TextEditingController();
    final intDiasCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.playlist_add_rounded, color: _primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Guardar Esquema para $nombreArticulo',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: dosisCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre / Número de Dosis * (ej: 1ra Dosis)',
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: minMesesCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Edad Mín. (Meses)',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: maxMesesCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Edad Máx. (Meses)',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: intDiasCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Días Mínimos desde Dosis Previa',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (dosisCtrl.text.trim().isEmpty) return;
              final res = await _api.crearEsquema(
                idArticulo: idArticulo,
                numeroDosis: dosisCtrl.text.trim(),
                edadMinimaMeses: int.tryParse(minMesesCtrl.text),
                edadMaximaMeses: int.tryParse(maxMesesCtrl.text),
                intervaloDiasPrevio: int.tryParse(intDiasCtrl.text),
              );
              if (res['success'] == true && ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Esquema guardado en el catálogo'),
                    backgroundColor: Colors.green,
                  ),
                );
                _cargarCatalogos();
              }
            },
            child: const Text('Guardar Esquema'),
          ),
        ],
      ),
    );
  }

  void _scheduleSearchPatientQuery(String value) {
    final q = value.trim();
    if (_searchDebounce?.isActive ?? false) {
      _searchDebounce!.cancel();
    }
    setState(() {});
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        _buscarPaciente(explicitQuery: q);
      }
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
        if (!res.success) {
          _searchResults = [];
          return;
        }
        final list = res.data;
        if (q.isEmpty) {
          _searchResults = list;
        } else {
          // El backend ya filtró los resultados con SQL. Aplicamos matcher como refinamiento si es necesario
          final clientFiltered = list.where((p) => PacienteSearchMatcher.matches(p, q)).toList();
          _searchResults = clientFiltered.isNotEmpty ? clientFiltered : list;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searchLoading = false;
        _searchResults = [];
      });
    }
  }

  Future<void> _clearPatientSearch() async {
    if (_searchDebounce?.isActive ?? false) {
      _searchDebounce!.cancel();
    }
    _searchController.clear();
    await _buscarPaciente(explicitQuery: '');
  }

  void _selectPaciente(Paciente p) {
    final direccion = p.direccion ?? '';
    final partesDireccion = direccion
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    _telefonoPacienteCtrl.text = p.telefono ?? '';
    _correoPacienteCtrl.text = p.correo ?? '';
    _callePacienteCtrl.text = partesDireccion.isNotEmpty
        ? partesDireccion.first
        : '';
    _numeroCasaCtrl.text = partesDireccion.length > 1 ? partesDireccion[1] : '';
    _puntoReferenciaCtrl.text = partesDireccion.length > 2
        ? partesDireccion.sublist(2).join(', ')
        : '';

    setState(() {
      _selectedPaciente = p;
      _searchResults = [];
      _step = 1;
    });
    _loadInventario();
  }

  void _showCreatePatientDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => CreatePatientDialog(
        onPatientCreated: ([searchKey]) {
          if (searchKey != null && searchKey.trim().isNotEmpty) {
            _searchController.text = searchKey.trim();
            _buscarPaciente();
          } else if (_searchController.text.trim().isNotEmpty) {
            _buscarPaciente();
          }
        },
      ),
    );
  }

  DateTime? _fechaFinOperativo;

  Future<void> _crearOperativo() async {
    if (_nomOperativoCtrl.text.trim().isEmpty) {
      _showError('Ingrese el nombre de la jornada/operativo');
      return;
    }
    final res = await _api.crearOperativo(
      nombre: _nomOperativoCtrl.text.trim(),
      tipoJornada: _tipoJornadaSel,
      lugar: _lugarOperativoCtrl.text.trim(),
      fechaInicio: _fechaOperativo.toIso8601String().split('T')[0],
      fechaFin: _fechaFinOperativo?.toIso8601String().split('T')[0],
      idCentroOrganizador: _selectedCentroMap != null
          ? _selectedCentroMap!['id_centro']
          : null,
    );
    if (res['success'] == true) {
      await _cargarCatalogos();
      setState(() {
        _mostrarCrearOperativo = false;
        _selectedOperativo = _operativos.isNotEmpty ? _operativos.last : null;
        _nomOperativoCtrl.clear();
        _lugarOperativoCtrl.clear();
        _fechaFinOperativo = null;
      });
      _showSuccess('Jornada / Operativo creado correctamente');
    } else {
      _showError(res['message'] ?? 'Error al crear operativo');
    }
  }

  Future<void> _mostrarDialogoEditarOperativo(Map<String, dynamic> op) async {
    final nombreCtrl = TextEditingController(
      text: op['nombre_operativo'] ?? op['nombre'] ?? '',
    );
    final descCtrl = TextEditingController(text: op['descripcion'] ?? '');
    DateTime fInicio =
        DateTime.tryParse(op['fecha_operativo'] ?? '') ?? DateTime.now();
    DateTime? fFin = op['fecha_fin'] != null
        ? DateTime.tryParse(op['fecha_fin'])
        : null;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.edit_calendar_rounded, color: Color(0xFF1B6FE8)),
              SizedBox(width: 10),
              Text(
                'Editar Jornada / Extender Plazo',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [UpperCaseTextFormatter()],
                  controller: nombreCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la Jornada',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [UpperCaseTextFormatter()],
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Descripción / Detalles',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                ListTile(
                  title: Text(
                    'Fecha Inicio: ${fInicio.toIso8601String().split('T')[0]}',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: fInicio,
                      firstDate: DateTime(2024),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d != null) setDlgState(() => fInicio = d);
                  },
                ),
                ListTile(
                  title: Text(
                    fFin == null
                        ? 'Fecha Fin: Sin definir (Extender plazo)'
                        : 'Fecha Fin: ${fFin!.toIso8601String().split('T')[0]}',
                  ),
                  subtitle: const Text(
                    'Asigna una fecha fin para cerrar o extender el plazo',
                  ),
                  trailing: const Icon(Icons.event_available),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate:
                          fFin ?? DateTime.now().add(const Duration(days: 7)),
                      firstDate: DateTime(2024),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                    );
                    if (d != null) setDlgState(() => fFin = d);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B6FE8),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final idOp = op['id_operativo'] ?? op['id'];
                if (idOp != null) {
                  final res = await _api.actualizarOperativo(
                    id: idOp,
                    nombreOperativo: nombreCtrl.text.trim(),
                    fechaOperativo: fInicio.toIso8601String().split('T')[0],
                    fechaFin: fFin?.toIso8601String().split('T')[0],
                    descripcion: descCtrl.text.trim(),
                  );
                  if (res['success'] == true) {
                    Navigator.pop(ctx);
                    await _cargarCatalogos();
                    _showSuccess('Jornada actualizada correctamente');
                  } else {
                    _showError(res['message'] ?? 'Error al actualizar jornada');
                  }
                }
              },
              child: const Text('Guardar Cambios'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _eliminarOperativo(Map<String, dynamic> op) async {
    final idOp = op['id_operativo'] ?? op['id'];
    if (idOp == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar Jornada?'),
        content: Text(
          '¿Está seguro de eliminar la jornada "${op['nombre_operativo'] ?? op['nombre']}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final res = await _api.eliminarOperativo(idOp);
      if (res['success'] == true) {
        await _cargarCatalogos();
        setState(() => _selectedOperativo = null);
        _showSuccess('Jornada eliminada');
      } else {
        _showError(res['message'] ?? 'Error al eliminar');
      }
    }
  }

  Future<void> _loadInventario() async {
    setState(() => _loadingInventario = true);
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
            n.contains('vph');
      }).toList();
      if (_lotesVacunas.isEmpty) _lotesVacunas = List.from(valid);

      _lotesInsumos = valid.where((l) {
        final art = l['articulo'] ?? {};
        final t = (art['tipo'] ?? l['tipo'] ?? '').toString().toLowerCase();
        return t != 'vacuna';
      }).toList();
      if (_lotesInsumos.isEmpty) _lotesInsumos = List.from(valid);
    }
    setState(() => _loadingInventario = false);
  }

  dynamic _extractLoteId(Map<String, dynamic> lote) {
    return lote['id_lote_insumo'] ?? lote['id_lote'] ?? lote['id'];
  }

  Future<void> _guardarAtencion() async {
    if (!_atencionFormKey.currentState!.validate()) return;
    if (_selectedCentroMap == null) {
      _showError('Seleccione un centro de salud');
      return;
    }
    if (_esJornada && _selectedOperativo == null) {
      _showError('Seleccione o cree una jornada u operativo');
      return;
    }

    setState(() => _savingAtencion = true);

    final consumos = <Map<String, dynamic>>[];
    List<Map<String, dynamic>>? vacunaciones;

    // Biológico (OPCIONAL)
    String dosisFinal = _dosisAplicada;
    int? esquemaIdFinal;

    if (_usarDosisManual) {
      dosisFinal = _dosisManualCtrl.text.trim().isEmpty
          ? '1ra Dosis'
          : _dosisManualCtrl.text.trim();
      esquemaIdFinal = null;
    } else if (_selectedEsquemaMap != null) {
      dosisFinal = _selectedEsquemaMap!['numero_dosis'] ?? '1ra Dosis';
      esquemaIdFinal = _selectedEsquemaMap!['id_esquema'];
    }

    if (_selectedLoteVacuna != null) {
      final loteId = _extractLoteId(_selectedLoteVacuna!);
      if (loteId != null) {
        vacunaciones = [
          {
            'id_lote': loteId,
            'dosis_aplicada': dosisFinal,
            'id_esquema': esquemaIdFinal,
          },
        ];
        consumos.add({'id_lote_insumo': loteId, 'cantidad_usada': 1});
      }
    }

    // Insumos (OPCIONAL)
    for (final item in _insumosUsados) {
      if (item.lote != null && item.cantidad > 0) {
        final loteId = _extractLoteId(item.lote!);
        if (loteId != null) {
          consumos.add({
            'id_lote_insumo': loteId,
            'cantidad_usada': item.cantidad,
          });
        }
      }
    }

    final Map<String, dynamic> atencionPayload = {
      'diagnostico_general': _diagnosticoCtrl.text.trim(),
      'motivo_consulta': _motivoCtrl.text.trim(),
      'observaciones': _observacionesCtrl.text.trim(),
      'tratamiento_indicado': _tratamientoCtrl.text.trim(),
      'fecha_visita': _fechaVisita.toIso8601String().split('T')[0],
      'dosis': _selectedLoteVacuna != null ? dosisFinal : null,
      'id_centro': _selectedCentroMap!['id_centro'],
    };

    final String telefonoPaciente = _telefonoPacienteCtrl.text.trim();
    final String correoPaciente = _correoPacienteCtrl.text.trim();
    final String callePaciente = _callePacienteCtrl.text.trim();
    final String numeroCasaPaciente = _numeroCasaCtrl.text.trim();
    final String puntoReferenciaPaciente = _puntoReferenciaCtrl.text.trim();

    if (_esJornada && _selectedOperativo != null) {
      atencionPayload['id_operativo'] = _selectedOperativo!['id_operativo'];
    }

    if (_pesoCtrl.text.trim().isNotEmpty)
      atencionPayload['peso_kg'] = double.tryParse(_pesoCtrl.text.trim());
    if (_tallaCtrl.text.trim().isNotEmpty)
      atencionPayload['talla_cm'] = double.tryParse(_tallaCtrl.text.trim());
    if (_tempCtrl.text.trim().isNotEmpty)
      atencionPayload['temperatura_c'] = double.tryParse(_tempCtrl.text.trim());
    if (_presionCtrl.text.trim().isNotEmpty)
      atencionPayload['presion_arterial'] = _presionCtrl.text.trim();
    if (_frqCardCtrl.text.trim().isNotEmpty)
      atencionPayload['frecuencia_cardiaca'] = int.tryParse(
        _frqCardCtrl.text.trim(),
      );
    if (_frqRespCtrl.text.trim().isNotEmpty)
      atencionPayload['frecuencia_respiratoria'] = int.tryParse(
        _frqRespCtrl.text.trim(),
      );
    if (_satO2Ctrl.text.trim().isNotEmpty)
      atencionPayload['saturacion_o2'] = double.tryParse(
        _satO2Ctrl.text.trim(),
      );

    final personaPayload = {
      'nombre1': _selectedPaciente!.nombre,
      'apellido1': _selectedPaciente!.apellido,
      'cedula_identidad': _selectedPaciente!.cedula.isNotEmpty
          ? _selectedPaciente!.cedula
          : null,
      'fecha_nacimiento': _selectedPaciente!.fechaNacimiento,
      'sexo': _selectedPaciente!.sexo,
      'telefono': telefonoPaciente.isNotEmpty
          ? telefonoPaciente
          : (_selectedPaciente!.telefono ?? ''),
      'correo': correoPaciente.isNotEmpty
          ? correoPaciente
          : (_selectedPaciente!.correo),
      'direccion': {
        if (callePaciente.isNotEmpty) 'calle': callePaciente,
        if (numeroCasaPaciente.isNotEmpty) 'numero_casa': numeroCasaPaciente,
        if (puntoReferenciaPaciente.isNotEmpty)
          'punto_referencia': puntoReferenciaPaciente,
      },
      'calle': callePaciente,
      'numero_casa': numeroCasaPaciente,
      'punto_referencia': puntoReferenciaPaciente,
      'peso': _pesoCtrl.text.trim().isNotEmpty
          ? double.tryParse(_pesoCtrl.text.trim())
          : null,
      'nombre1_rep': _selectedPaciente!.nombreRepresentante ?? '',
      'apellido1_rep': _selectedPaciente!.apellidoRepresentante ?? '',
      'cedula_representante': _selectedPaciente!.cedulaRepresentante ?? '',
      'telefono_representante': _selectedPaciente!.telefonoRepresentante ?? '',
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
      _showSuccess('Atención registrada correctamente');
      setState(() {
        _step = 0;
        _selectedPaciente = null;
        _diagnosticoCtrl.clear();
        _motivoCtrl.clear();
        _observacionesCtrl.clear();
        _tratamientoCtrl.clear();
        _telefonoPacienteCtrl.clear();
        _correoPacienteCtrl.clear();
        _callePacienteCtrl.clear();
        _numeroCasaCtrl.clear();
        _puntoReferenciaCtrl.clear();
        _pesoCtrl.clear();
        _tallaCtrl.clear();
        _tempCtrl.clear();
        _presionCtrl.clear();
        _frqCardCtrl.clear();
        _frqRespCtrl.clear();
        _satO2Ctrl.clear();
        _selectedLoteVacuna = null;
        _insumosUsados = [];
        _fechaVisita = DateTime.now();
        _esJornada = false;
      });
    } else {
      _showError(res['message'] ?? 'Error al guardar la atención');
    }
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
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
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: const Color(0xFFD32F2F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
            color: Color(0xFF37474F),
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.calendar_today_rounded,
                color: _green,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Jornada / Atención Diaria',
                    style: TextStyle(
                      color: Color(0xFF1A237E),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Registro de atenciones médicas',
                    style: TextStyle(color: Color(0xFF90A4AE), fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Builder(
        builder: (context) {
          final isMobile = ResponsiveBreakpoints.of(context).isMobile;
          return Column(
            children: [
              _buildStepIndicator(),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isMobile ? 12 : 20),
                  child: _step == 0 ? _buildStep0() : _buildStep1(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          _StepBadge(
            number: 1,
            label: 'Paciente',
            active: _step == 0,
            done: _step > 0,
          ),
          Expanded(
            child: Divider(
              color: _step > 0 ? _primary : Colors.grey.shade300,
              thickness: 1.5,
            ),
          ),
          _StepBadge(
            number: 2,
            label: 'Atención',
            active: _step == 1,
            done: false,
          ),
        ],
      ),
    );
  }

  // STEP 0
  Widget _buildStep0() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionCard(
          icon: Icons.search_rounded,
          iconColor: _primary,
          title: 'Buscar Paciente',
          subtitle: 'Busca por cédula, nombre o apellido',
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(fontSize: 13),
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.search,
                      onChanged: (value) => _scheduleSearchPatientQuery(value),
                      onSubmitted: (_) {
                        if (_searchDebounce?.isActive ?? false) {
                          _searchDebounce!.cancel();
                        }
                        _buscarPaciente(
                          explicitQuery: _searchController.text.trim(),
                        );
                      },
                      decoration:
                          _deco(
                            'Cédula, Nombre o Apellido',
                            Icons.person_search_rounded,
                          ).copyWith(
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: _clearPatientSearch,
                                  )
                                : null,
                          ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _ActionButton(
                    label: 'Buscar',
                    icon: Icons.search_rounded,
                    color: _primary,
                    loading: _searchLoading,
                    onTap: () {
                      if (_searchDebounce?.isActive ?? false) {
                        _searchDebounce!.cancel();
                      }
                      _buscarPaciente(
                        explicitQuery: _searchController.text.trim(),
                      );
                    },
                  ),
                ],
              ),
              if (_searchResults.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'Resultados:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Color(0xFF546E7A),
                  ),
                ),
                const SizedBox(height: 8),
                ..._searchResults.map(
                  (p) => _PatientResultTile(
                    paciente: p,
                    onSelect: () => _selectPaciente(p),
                  ),
                ),
              ] else if (!_searchLoading) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: Colors.amber.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _searchController.text.trim().isEmpty
                              ? 'No hay pacientes registrados. Presiona Buscar para recargar la lista.'
                              : 'No se encontró ningún paciente con esa búsqueda. Puedes registrarlo con el botón inferior.',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () => _showCreatePatientDialog(context),
          icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
          label: const Text('Registrar Nuevo Paciente'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  // STEP 1
  Widget _buildStep1() {
    if (_loadingInventario) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(color: _primary),
        ),
      );
    }

    return Form(
      key: _atencionFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Paciente seleccionado
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: _primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedPaciente!.nombreCompleto,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Color(0xFF1A237E),
                        ),
                      ),
                      Text(
                        'Cédula / ID: ${_selectedPaciente!.cedula}  ·  Sexo: ${_selectedPaciente!.sexo == 'M' ? 'Masculino' : 'Femenino'}',
                        style: const TextStyle(
                          color: Color(0xFF546E7A),
                          fontSize: 12,
                        ),
                      ),
                      if (_selectedPaciente!
                          .nombreCompletoRepresentante
                          .isNotEmpty)
                        Text(
                          'Rep: ${_selectedPaciente!.nombreCompletoRepresentante} (C.I: ${_selectedPaciente!.cedulaRepresentante})',
                          style: TextStyle(
                            color: Colors.purple.shade800,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _step = 0;
                    _selectedPaciente = null;
                  }),
                  child: const Text('Cambiar', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tipo de atención
          _SectionCard(
            icon: Icons.category_rounded,
            iconColor: const Color(0xFF6A1B9A),
            title: 'Modalidad de Atención',
            subtitle:
                'Seleccione si es Consulta Regular en Centro o Jornada Médica Externa',
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _TipoAtencionCard(
                        icono: Icons.local_hospital_rounded,
                        titulo: 'Atención Regular en Centro',
                        subtitulo: 'Consulta médica en CDI / CPT',
                        seleccionado: !_esJornada,
                        color: _primary,
                        onTap: () => setState(() => _esJornada = false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TipoAtencionCard(
                        icono: Icons.groups_rounded,
                        titulo: 'Jornada Médica / Operativo',
                        subtitulo: 'Despliegue comunitario o en terreno',
                        seleccionado: _esJornada,
                        color: _green,
                        onTap: () => setState(() => _esJornada = true),
                      ),
                    ),
                  ],
                ),
                if (_esJornada) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<Map<String, dynamic>>(
                    decoration: _deco(
                      'Seleccionar Jornada / Operativo *',
                      Icons.event_note_rounded,
                    ),
                    initialValue: _selectedOperativo,
                    items: _operativos
                        .map(
                          (o) => DropdownMenuItem(
                            value: o,
                            child: Text(
                              '${o['nombre_operativo'] ?? o['nombre'] ?? 'Jornada'} — ${o['descripcion'] ?? o['lugar'] ?? ''}',
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _selectedOperativo = v),
                    validator: (v) => _esJornada && v == null
                        ? 'Seleccione o cree una jornada'
                        : null,
                  ),
                  if (_selectedOperativo != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () => _mostrarDialogoEditarOperativo(
                            _selectedOperativo!,
                          ),
                          icon: const Icon(
                            Icons.edit_calendar_rounded,
                            size: 16,
                          ),
                          label: const Text(
                            'Editar / Extender Plazo',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: _primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () =>
                              _eliminarOperativo(_selectedOperativo!),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 16,
                          ),
                          label: const Text(
                            'Eliminar',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setState(
                        () => _mostrarCrearOperativo = !_mostrarCrearOperativo,
                      ),
                      icon: Icon(
                        _mostrarCrearOperativo
                            ? Icons.remove_circle_outline
                            : Icons.add_circle_outline,
                        size: 16,
                      ),
                      label: Text(
                        _mostrarCrearOperativo
                            ? 'Ocultar formulario'
                            : 'Registrar Nueva Jornada / Operativo',
                      ),
                      style: TextButton.styleFrom(foregroundColor: _green),
                    ),
                  ),
                  if (_mostrarCrearOperativo) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Registrar Nueva Jornada Médica',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _green,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildValidatedInput(
                            _nomOperativoCtrl,
                            'Nombre de la Jornada / Operativo *',
                            Icons.event_rounded,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _tipoJornadaSel,
                            decoration: _deco(
                              'Tipo de Jornada / Pertenencia *',
                              Icons.domain_rounded,
                            ),
                            items: _tiposJornada
                                .map(
                                  (t) => DropdownMenuItem(
                                    value: t,
                                    child: Text(
                                      t,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _tipoJornadaSel = v!),
                          ),
                          const SizedBox(height: 12),
                          _buildValidatedInput(
                            _lugarOperativoCtrl,
                            'Lugar / Sector de la Jornada',
                            Icons.location_on_rounded,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final d = await showDatePicker(
                                      context: context,
                                      initialDate: _fechaOperativo,
                                      firstDate: DateTime(2024),
                                      lastDate: DateTime.now().add(
                                        const Duration(days: 365),
                                      ),
                                    );
                                    if (d != null)
                                      setState(() => _fechaOperativo = d);
                                  },
                                  child: InputDecorator(
                                    decoration: _deco(
                                      'Fecha Inicio',
                                      Icons.calendar_today_rounded,
                                    ),
                                    child: Text(
                                      _fmt(_fechaOperativo),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final d = await showDatePicker(
                                      context: context,
                                      initialDate:
                                          _fechaFinOperativo ??
                                          _fechaOperativo.add(
                                            const Duration(days: 7),
                                          ),
                                      firstDate: DateTime(2024),
                                      lastDate: DateTime.now().add(
                                        const Duration(days: 730),
                                      ),
                                    );
                                    if (d != null)
                                      setState(() => _fechaFinOperativo = d);
                                  },
                                  child: InputDecorator(
                                    decoration: _deco(
                                      'Fecha Fin (Plazo)',
                                      Icons.event_available_rounded,
                                    ),
                                    child: Text(
                                      _fechaFinOperativo != null
                                          ? _fmt(_fechaFinOperativo!)
                                          : 'Sin definir',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _crearOperativo,
                              icon: const Icon(
                                Icons.check_circle_outline_rounded,
                                size: 18,
                              ),
                              label: const Text(
                                'Guardar y Seleccionar Jornada',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _green,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Centro de salud y fecha
          _SectionCard(
            icon: Icons.local_hospital_rounded,
            iconColor: _green,
            title: 'Centro de Salud Evaluador y Fecha',
            subtitle: 'Establecimiento responsable y fecha de atención',
            child: Column(
              children: [
                _loadingCatalogos
                    ? const Center(child: CircularProgressIndicator())
                    : DropdownButtonFormField<Map<String, dynamic>>(
                        decoration: _deco(
                          'Centro de Salud *',
                          Icons.local_hospital_rounded,
                        ),
                        initialValue: _selectedCentroMap,
                        items: _centros
                            .map(
                              (c) => DropdownMenuItem(
                                value: c,
                                child: Text(
                                  c['nombre_centro'] ?? c['nombre'] ?? 'Centro',
                                  style: const TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedCentroMap = v),
                        validator: (v) =>
                            v == null ? 'Seleccione un centro' : null,
                      ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _fechaVisita,
                      firstDate: DateTime(2025),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d != null) setState(() => _fechaVisita = d);
                  },
                  child: InputDecorator(
                    decoration: _deco(
                      'Fecha de la Visita',
                      Icons.event_rounded,
                    ),
                    child: Text(
                      _fmt(_fechaVisita),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Datos clínicos
          _SectionCard(
            icon: Icons.medical_information_rounded,
            iconColor: const Color(0xFF0288D1),
            title: 'Datos Clínicos',
            subtitle: 'Motivo, diagnóstico, tratamiento y observaciones',
            child: Column(
              children: [
                TextFormField(
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [UpperCaseTextFormatter()],
                  controller: _motivoCtrl,
                  decoration: _deco(
                    'Motivo de Consulta *',
                    Icons.help_outline_rounded,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Ingrese el motivo de consulta'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [UpperCaseTextFormatter()],
                  controller: _diagnosticoCtrl,
                  maxLines: 3,
                  decoration: _deco(
                    'Diagnóstico General *',
                    Icons.medical_information_rounded,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Ingrese el diagnóstico'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [UpperCaseTextFormatter()],
                  controller: _tratamientoCtrl,
                  maxLines: 2,
                  decoration: _deco(
                    'Tratamiento Indicado',
                    Icons.medication_rounded,
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [UpperCaseTextFormatter()],
                  controller: _observacionesCtrl,
                  maxLines: 2,
                  decoration: _deco('Observaciones', Icons.notes_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Contacto y dirección del paciente
          _SectionCard(
            icon: Icons.contact_phone_rounded,
            iconColor: const Color(0xFF1976D2),
            title: 'Contacto y Dirección',
            subtitle: 'Teléfono, correo y dirección del paciente',
            child: Column(
              children: [
                _buildRow([
                  _buildValidatedInput(
                    _telefonoPacienteCtrl,
                    'Teléfono',
                    Icons.phone_rounded,
                  ),
                  _buildValidatedInput(
                    _correoPacienteCtrl,
                    'Correo Electrónico',
                    Icons.email_rounded,
                  ),
                ]),
                const SizedBox(height: 14),
                TextFormField(
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [UpperCaseTextFormatter()],
                  controller: _callePacienteCtrl,
                  decoration: _deco('Calle', Icons.location_city_rounded),
                ),
                const SizedBox(height: 14),
                _buildRow([
                  _buildValidatedInput(
                    _numeroCasaCtrl,
                    'Número / Casa',
                    Icons.home_rounded,
                  ),
                  _buildValidatedInput(
                    _puntoReferenciaCtrl,
                    'Punto de Referencia',
                    Icons.place_rounded,
                  ),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Signos vitales
          _SectionCard(
            icon: Icons.monitor_heart_rounded,
            iconColor: const Color(0xFFD32F2F),
            title: 'Signos Vitales',
            subtitle: 'Medidas tomadas durante la consulta (opcionales)',
            child: Column(
              children: [
                _buildRow([
                  _buildValidatedInput(
                    _pesoCtrl,
                    'Peso (kg)',
                    Icons.scale_rounded,
                  ),
                  _buildValidatedInput(
                    _tallaCtrl,
                    'Talla (cm)',
                    Icons.height_rounded,
                  ),
                ]),
                const SizedBox(height: 14),
                _buildRow([
                  _buildValidatedInput(
                    _tempCtrl,
                    'Temp. (°C)',
                    Icons.thermostat_rounded,
                  ),
                  _buildValidatedInput(
                    _presionCtrl,
                    'Presión Art. (mmHg)',
                    Icons.bloodtype_rounded,
                  ),
                ]),
                const SizedBox(height: 14),
                _buildRow([
                  _buildValidatedInput(
                    _frqCardCtrl,
                    'Frec. Cardíaca (lpm)',
                    Icons.favorite_rounded,
                  ),
                  _buildValidatedInput(
                    _frqRespCtrl,
                    'Frec. Resp. (rpm)',
                    Icons.air_rounded,
                  ),
                ]),
                const SizedBox(height: 14),
                _buildValidatedInput(
                  _satO2Ctrl,
                  'Saturación O₂ (%)',
                  Icons.bubble_chart_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Biológico (OPCIONAL)
          _SectionCard(
            icon: Icons.vaccines_rounded,
            iconColor: const Color(0xFF0288D1),
            title: 'Biológico / Vacunación (OPCIONAL)',
            subtitle:
                'Seleccione solo si se administró alguna vacuna en la consulta',
            child: Column(
              children: [
                DropdownButtonFormField<Map<String, dynamic>?>(
                  decoration: _deco(
                    'Biológico / Vacuna (Opcional)',
                    Icons.vaccines_rounded,
                  ),
                  initialValue: _selectedLoteVacuna,
                  items: [
                    const DropdownMenuItem<Map<String, dynamic>?>(
                      value: null,
                      child: Text(
                        '-- Ninguna / No Aplica Vacunación --',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ),
                    ..._lotesVacunas.map((l) {
                      final String nom =
                          l['articulo']?['nombre_articulo'] ??
                          l['nombre_articulo'] ??
                          'Vacuna / Biológico';
                      return DropdownMenuItem<Map<String, dynamic>?>(
                        value: l,
                        child: Text(
                          '$nom · Lote ${l['numero_lote']} (Stock: ${l['stock_actual']})',
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }),
                  ],
                  onChanged: (v) => setState(() => _selectedLoteVacuna = v),
                ),
                if (_selectedLoteVacuna != null) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text(
                          'Elegir del Catálogo Guardado',
                          style: TextStyle(fontSize: 12),
                        ),
                        selected: !_usarDosisManual,
                        onSelected: (val) =>
                            setState(() => _usarDosisManual = !val),
                        selectedColor: _primary.withValues(alpha: 0.15),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text(
                          'Configurar Dosis Manualmente',
                          style: TextStyle(fontSize: 12),
                        ),
                        selected: _usarDosisManual,
                        onSelected: (val) =>
                            setState(() => _usarDosisManual = val),
                        selectedColor: Colors.orange.withValues(alpha: 0.15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (!_usarDosisManual) ...[
                    Builder(
                      builder: (context) {
                        final idArt =
                            _selectedLoteVacuna!['id_articulo'] ??
                            _selectedLoteVacuna!['articulo']?['id_articulo'];
                        final esquemasVac = _esquemasGuardados
                            .where(
                              (e) =>
                                  e['id_articulo'] == idArt ||
                                  e['vacuna']?['id_articulo'] == idArt,
                            )
                            .toList();

                        if (esquemasVac.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber.shade200),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.amber,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Sin esquemas guardados para esta vacuna. Puedes ingresar la dosis manualmente abajo.',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return DropdownButtonFormField<Map<String, dynamic>>(
                          decoration: _deco(
                            'Esquema Guardado *',
                            Icons.format_list_numbered_rounded,
                          ),
                          initialValue: _selectedEsquemaMap,
                          items: esquemasVac.map((e) {
                            String desc = e['numero_dosis'] ?? 'Dosis';
                            if (e['edad_minima_meses'] != null)
                              desc += ' (Min ${e['edad_minima_meses']}m)';
                            if (e['intervalo_dias_previo'] != null)
                              desc +=
                                  ' [Intervalo: ${e['intervalo_dias_previo']}d]';
                            return DropdownMenuItem<Map<String, dynamic>>(
                              value: e,
                              child: Text(
                                desc,
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (v) => setState(() {
                            _selectedEsquemaMap = v;
                            if (v != null)
                              _dosisAplicada =
                                  v['numero_dosis'] ?? _dosisAplicada;
                          }),
                        );
                      },
                    ),
                  ] else ...[
                    TextFormField(
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [UpperCaseTextFormatter()],
                      controller: _dosisManualCtrl,
                      decoration: _deco(
                        'Nombre de Dosis Manual * (ej: 1ra Dosis, Dosis Campaña)',
                        Icons.edit_note_rounded,
                      ),
                      onChanged: (v) => _dosisAplicada = v,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        final idArt =
                            _selectedLoteVacuna!['id_articulo'] ??
                            _selectedLoteVacuna!['articulo']?['id_articulo'] ??
                            0;
                        final nomArt =
                            _selectedLoteVacuna!['articulo']?['nombre_articulo'] ??
                            _selectedLoteVacuna!['nombre_articulo'] ??
                            'Vacuna';
                        _dialogNuevoEsquema(idArt, nomArt);
                      },
                      icon: const Icon(Icons.bookmark_add_outlined, size: 16),
                      label: const Text(
                        'Guardar nuevo esquema en catálogo',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Insumos (OPCIONAL)
          _SectionCard(
            icon: Icons.inventory_2_rounded,
            iconColor: const Color(0xFFE65100),
            title: 'Insumos Utilizados (OPCIONAL)',
            subtitle: 'Agrega los insumos consumidos en esta atención',
            child: Column(
              children: [
                if (_insumosUsados.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: const Text(
                      'No se han agregado insumos adicionales.',
                      style: TextStyle(color: Color(0xFF90A4AE), fontSize: 13),
                    ),
                  ),
                ..._insumosUsados.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _InsumoRow(
                      item: item,
                      lotes: _lotesInsumos,
                      onRemove: () =>
                          setState(() => _insumosUsados.removeAt(idx)),
                      onChanged: () => setState(() {}),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () =>
                      setState(() => _insumosUsados.add(_InsumoItem())),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text(
                    'Agregar Insumo',
                    style: TextStyle(fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFE65100),
                    side: const BorderSide(color: Color(0xFFE65100)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: _ActionButton(
              label: 'Registrar Atención',
              icon: Icons.save_alt_rounded,
              color: _green,
              loading: _savingAtencion,
              onTap: _guardarAtencion,
              fullWidth: true,
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  InputDecoration _deco(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 13),
      prefixIcon: Icon(icon, size: 18, color: const Color(0xFF78909C)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _primary, width: 1.5),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Widget _buildValidatedInput(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    bool required = false,
  }) {
    return TextFormField(
      textCapitalization: TextCapitalization.characters,
      inputFormatters: [UpperCaseTextFormatter()],
      controller: ctrl,
      style: const TextStyle(fontSize: 13),
      decoration: _deco(label, icon),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null
          : null,
    );
  }

  Widget _buildRow(List<Widget> children) {
    return Builder(
      builder: (context) {
        if (ResponsiveBreakpoints.of(context).isMobile) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                children[i],
              ],
            ],
          );
        }
        return Row(
          children: [
            for (int i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: children[i]),
            ],
          ],
        );
      },
    );
  }
}

// Tarjeta tipo atención
class _TipoAtencionCard extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String subtitulo;
  final bool seleccionado;
  final Color color;
  final VoidCallback onTap;
  const _TipoAtencionCard({
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.seleccionado,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: seleccionado
              ? color.withValues(alpha: 0.08)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: seleccionado ? color : Colors.grey.shade200,
            width: seleccionado ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icono,
              color: seleccionado ? color : Colors.grey.shade400,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              titulo,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: seleccionado ? color : Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitulo,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
            if (seleccionado) ...[
              const SizedBox(height: 8),
              Icon(Icons.check_circle_rounded, color: color, size: 16),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget child;
  const _SectionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              border: Border(
                bottom: BorderSide(color: iconColor.withValues(alpha: 0.1)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 16),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: iconColor,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF90A4AE),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }
}

class _StepBadge extends StatelessWidget {
  final int number;
  final String label;
  final bool active;
  final bool done;
  const _StepBadge({
    required this.number,
    required this.label,
    required this.active,
    required this.done,
  });
  static const _primary = Color(0xFF1565C0);

  @override
  Widget build(BuildContext context) {
    final Color bg = done
        ? _primary
        : active
        ? _primary
        : Colors.grey.shade200;
    final Color fg = (done || active) ? Colors.white : Colors.grey.shade500;
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          child: Center(
            child: done
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                : Text(
                    '$number',
                    style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: (active || done) ? _primary : Colors.grey.shade500,
            fontWeight: active ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

class _PatientResultTile extends StatelessWidget {
  final Paciente paciente;
  final VoidCallback onSelect;
  const _PatientResultTile({required this.paciente, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF1565C0).withValues(alpha: 0.1),
          child: Text(
            paciente.nombre.isNotEmpty ? paciente.nombre[0].toUpperCase() : '?',
            style: const TextStyle(
              color: Color(0xFF1565C0),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        title: Text(
          paciente.nombreCompleto,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          'Cédula / ID: ${paciente.cedula}  ·  Sexo: ${paciente.sexo == 'M' ? 'Masculino' : 'Femenino'}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: ElevatedButton(
          onPressed: onSelect,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1565C0),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            textStyle: const TextStyle(fontSize: 12),
          ),
          child: const Text('Seleccionar'),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool loading;
  final VoidCallback onTap;
  final bool fullWidth;
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.loading,
    required this.onTap,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: loading ? null : onTap,
      icon: loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : Icon(icon, size: 17),
      label: Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        minimumSize: fullWidth ? const Size(double.infinity, 48) : null,
      ),
    );
  }
}

class _InsumoItem {
  Map<String, dynamic>? lote;
  int cantidad = 1;
}

class _InsumoRow extends StatelessWidget {
  final _InsumoItem item;
  final List<Map<String, dynamic>> lotes;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  const _InsumoRow({
    required this.item,
    required this.lotes,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: Builder(
        builder: (context) {
          final isSmall = ResponsiveBreakpoints.of(context).isMobile;
          final dropdown = DropdownButtonFormField<Map<String, dynamic>>(
            decoration: InputDecoration(
              labelText: 'Insumo',
              labelStyle: const TextStyle(fontSize: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 10,
              ),
              isDense: true,
            ),
            initialValue: item.lote,
            items: lotes.map((l) {
              final nom =
                  l['articulo']?['nombre_articulo'] ??
                  l['nombre_articulo'] ??
                  'Insumo';
              return DropdownMenuItem(
                value: l,
                child: Text(
                  '$nom · Lote ${l['numero_lote'] ?? ''} (Stock: ${l['stock_actual']})',
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (v) {
              item.lote = v;
              onChanged();
            },
          );

          final cantInput = SizedBox(
            width: isSmall ? 100 : 80,
            child: TextFormField(
              initialValue: item.cantidad.toString(),
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Cant.',
                labelStyle: const TextStyle(fontSize: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                isDense: true,
              ),
              onChanged: (v) {
                item.cantidad = int.tryParse(v) ?? 1;
                onChanged();
              },
            ),
          );

          final deleteBtn = IconButton(
            onPressed: onRemove,
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Color(0xFFD32F2F),
              size: 20,
            ),
            tooltip: 'Eliminar',
          );

          if (isSmall) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                dropdown,
                const SizedBox(height: 10),
                Row(children: [cantInput, const Spacer(), deleteBtn]),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: dropdown),
              const SizedBox(width: 10),
              cantInput,
              const SizedBox(width: 6),
              deleteBtn,
            ],
          );
        },
      ),
    );
  }
}

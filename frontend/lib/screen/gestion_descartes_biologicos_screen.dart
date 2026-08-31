import 'package:flutter/material.dart';
import 'package:asis_guanipa_frontend/services/api_service.dart';
import 'package:asis_guanipa_frontend/utils/upper_case_text_formatter.dart';
import 'package:responsive_framework/responsive_framework.dart';

class GestionDescartesBiologicosScreen extends StatefulWidget {
  const GestionDescartesBiologicosScreen({super.key});

  @override
  State<GestionDescartesBiologicosScreen> createState() =>
      _GestionDescartesBiologicosScreenState();
}

class _GestionDescartesBiologicosScreenState
    extends State<GestionDescartesBiologicosScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();

  // === ESTADO TAB 1: ESQUEMAS DE VACUNACIÓN ===
  List<Map<String, dynamic>> _esquemas = [];
  List<Map<String, dynamic>> _articulos = [];
  bool _loadingEsquemas = false;

  // === ESTADO TAB 2: DESCARTES ===
  String _procesoDisposicion = 'Incineración';
  DateTime _fechaRetiro = DateTime.now();
  List<Map<String, dynamic>> _lotesVencidos = [];
  bool _loadingDescartes = false;
  bool _isDiscarding = false;

  static const Color _primary = Color(0xFF1B6FE8);
  static const Color _green = Color(0xFF2E7D32);
  static const Color _bg = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchEsquemas();
    _fetchLotesVencidos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // === SELECCIONAR FECHA DE RETIRO ===
  Future<void> _selectFechaRetiro(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _fechaRetiro,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _fechaRetiro) {
      setState(() {
        _fechaRetiro = picked;
      });
    }
  }

  // === CARGA DE ESQUEMAS Y ARTÍCULOS ===
  Future<void> _fetchEsquemas() async {
    setState(() => _loadingEsquemas = true);
    try {
      final resEsquemas = await _apiService.getEsquemas();
      final resArticulos = await _apiService.getArticulos();

      if (mounted) {
        setState(() {
          if (resEsquemas['success'] == true) {
            _esquemas = List<Map<String, dynamic>>.from(
              resEsquemas['data'] ?? [],
            );
          }
          if (resArticulos['success'] == true) {
            _articulos = List<Map<String, dynamic>>.from(
              resArticulos['data'] ?? [],
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Error al cargar esquemas: $e', Colors.red);
      }
    } finally {
      if (mounted) setState(() => _loadingEsquemas = false);
    }
  }

  // === CARGA DE BIOLÓGICOS VENCIDOS ===
  Future<void> _fetchLotesVencidos() async {
    setState(() => _loadingDescartes = true);
    try {
      final res = await _apiService.getInventario();
      if (res['success'] == true && mounted) {
        final List data = res['data'] ?? [];
        final today = DateTime.now();
        _lotesVencidos = [];
        for (var item in data) {
          final expStr = item['fecha_vencimiento'];
          if (expStr != null) {
            final expDate = DateTime.tryParse(expStr);
            if (expDate != null && expDate.isBefore(today)) {
              _lotesVencidos.add(Map<String, dynamic>.from(item));
            }
          }
        }
      }
    } catch (e) {
      if (mounted) _showSnack('Error al cargar lotes vencidos: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _loadingDescartes = false);
    }
  }

  // === CREAR / EDITAR ESQUEMA DIÁLOGO ===
  Future<void> _mostrarDialogoEsquema([
    Map<String, dynamic>? esquemaEditar,
  ]) async {
    Map<String, dynamic>? articuloSeleccionado;
    if (esquemaEditar != null && esquemaEditar['vacuna'] != null) {
      final idArt = esquemaEditar['vacuna']['id_articulo'];
      articuloSeleccionado = _articulos.firstWhere(
        (a) => a['id_articulo'] == idArt,
        orElse: () => Map<String, dynamic>.from(esquemaEditar['vacuna']),
      );
    } else if (_articulos.isNotEmpty) {
      articuloSeleccionado = _articulos.first;
    }

    final nombreVacunaNuevaCtrl = TextEditingController();
    final dosisCtrl = TextEditingController(
      text: esquemaEditar?['numero_dosis'] ?? '',
    );
    final intervaloCtrl = TextEditingController(
      text: esquemaEditar?['intervalo_dias_previo']?.toString() ?? '',
    );
    final edadMinCtrl = TextEditingController(
      text: esquemaEditar?['edad_minima_meses']?.toString() ?? '',
    );
    final edadMaxCtrl = TextEditingController(
      text: esquemaEditar?['edad_maxima_meses']?.toString() ?? '',
    );
    bool esCrearNuevaVacuna = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                esquemaEditar == null
                    ? Icons.add_circle_outline_rounded
                    : Icons.edit_note_rounded,
                color: _primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  esquemaEditar == null ? 'Nuevo Esquema' : 'Editar Esquema',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (esquemaEditar == null) ...[
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Vacuna Existente'),
                        selected: !esCrearNuevaVacuna,
                        onSelected: (v) =>
                            setDlgState(() => esCrearNuevaVacuna = false),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('+ Nueva Vacuna'),
                        selected: esCrearNuevaVacuna,
                        onSelected: (v) =>
                            setDlgState(() => esCrearNuevaVacuna = true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                if (esCrearNuevaVacuna) ...[
                  TextField(
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [UpperCaseTextFormatter()],
                    controller: nombreVacunaNuevaCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de la Vacuna / Biológico *',
                      hintText: 'Ej: Fiebre Amarilla',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ] else ...[
                  DropdownButtonFormField<Map<String, dynamic>>(
                    initialValue: articuloSeleccionado,
                    decoration: const InputDecoration(
                      labelText: 'Biológico / Vacuna *',
                      border: OutlineInputBorder(),
                    ),
                    items: _articulos.map((a) {
                      return DropdownMenuItem(
                        value: a,
                        child: Text(a['nombre_articulo'] ?? 'Vacuna'),
                      );
                    }).toList(),
                    onChanged: (v) =>
                        setDlgState(() => articuloSeleccionado = v),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: dosisCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Número / Nombre de Dosis *',
                    hintText: 'Ej: 1ra Dosis (2 Meses), Refuerzo',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: intervaloCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Intervalo de Días Previo (Opcional)',
                    hintText: 'Ej: 60',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: edadMinCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Mín. Meses',
                          hintText: '2',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: edadMaxCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Máx. Meses',
                          hintText: '12',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
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
                backgroundColor: _primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (dosisCtrl.text.trim().isEmpty) {
                  _showSnack(
                    'Ingrese el número o nombre de dosis',
                    Colors.orange,
                  );
                  return;
                }

                int? idArt;
                if (esCrearNuevaVacuna) {
                  if (nombreVacunaNuevaCtrl.text.trim().isEmpty) {
                    _showSnack(
                      'Ingrese el nombre de la nueva vacuna',
                      Colors.orange,
                    );
                    return;
                  }
                  final resArt = await _apiService.registrarArticulo(
                    nombreVacunaNuevaCtrl.text.trim(),
                    'Dosis',
                    descripcion: 'Vacuna de inmunización PAI',
                  );
                  if (resArt['success'] == true && resArt['data'] != null) {
                    idArt = resArt['data']['id_articulo'];
                  } else {
                    _showSnack(
                      resArt['message'] ?? 'Error al crear vacuna',
                      Colors.red,
                    );
                    return;
                  }
                } else {
                  idArt = articuloSeleccionado?['id_articulo'];
                }

                if (idArt == null && esquemaEditar == null) {
                  _showSnack('Seleccione o cree una vacuna', Colors.orange);
                  return;
                }

                Map<String, dynamic> res;
                if (esquemaEditar == null) {
                  res = await _apiService.crearEsquema(
                    idArticulo: idArt!,
                    numeroDosis: dosisCtrl.text.trim(),
                    intervaloDiasPrevio: int.tryParse(
                      intervaloCtrl.text.trim(),
                    ),
                    edadMinimaMeses: int.tryParse(edadMinCtrl.text.trim()),
                    edadMaximaMeses: int.tryParse(edadMaxCtrl.text.trim()),
                  );
                } else {
                  res = await _apiService.actualizarEsquema(
                    id: esquemaEditar['id_esquema'],
                    numeroDosis: dosisCtrl.text.trim(),
                    intervaloDiasPrevio: int.tryParse(
                      intervaloCtrl.text.trim(),
                    ),
                    edadMinimaMeses: int.tryParse(edadMinCtrl.text.trim()),
                    edadMaximaMeses: int.tryParse(edadMaxCtrl.text.trim()),
                  );
                }

                if (res['success'] == true) {
                  Navigator.pop(ctx);
                  await _fetchEsquemas();
                  _showSnack(
                    esquemaEditar == null
                        ? 'Esquema guardado correctamente'
                        : 'Esquema actualizado correctamente',
                    _green,
                  );
                } else {
                  _showSnack(
                    res['message'] ?? 'Error al guardar esquema',
                    Colors.red,
                  );
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  // === ELIMINAR ESQUEMA ===
  Future<void> _eliminarEsquema(
    int idEsquema,
    String vacunaNombre,
    String dosis,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar Esquema?'),
        content: Text(
          '¿Está seguro de eliminar la dosis "$dosis" de "$vacunaNombre"?',
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
      final res = await _apiService.eliminarEsquema(idEsquema);
      if (res['success'] == true) {
        await _fetchEsquemas();
        _showSnack('Esquema eliminado correctamente', _green);
      } else {
        _showSnack(res['message'] ?? 'Error al eliminar esquema', Colors.red);
      }
    }
  }

  // === EJECUTAR DESCARTE ===
  Future<void> _ejecutarDescarte() async {
    if (_lotesVencidos.isEmpty) {
      _showSnack('No hay biológicos vencidos para descartar.', Colors.orange);
      return;
    }

    setState(() => _isDiscarding = true);
    try {
      final ids = _lotesVencidos
          .map<int>((l) => (l['id_lote_insumo'] ?? l['id']) as int)
          .toList();
      final fechaStr = _fechaRetiro.toIso8601String().split('T')[0];

      final res = await _apiService.descartarLotes(
        ids: ids,
        metodoDisposicion: _procesoDisposicion,
        fechaRetiro: fechaStr,
      );

      if (res['success'] == true) {
        _showSnack('Descarte ejecutado exitosamente.', _green);
        await _fetchLotesVencidos();
      } else {
        _showSnack(
          res['message'] ?? 'Error al procesar el descarte.',
          Colors.red,
        );
      }
    } catch (e) {
      _showSnack('Error de conexión: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isDiscarding = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('Biológicos, Vacunas y Esquemas PAI'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: _primary,
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: _primary,
          tabs: const [
            Tab(icon: Icon(Icons.vaccines_rounded), text: 'Esquemas PAI'),
            Tab(icon: Icon(Icons.delete_sweep_rounded), text: 'Descartes'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildEsquemasTab(), _buildDescartesTab()],
      ),
    );
  }

  // ─── TAB 1: ESQUEMAS DE VACUNACIÓN ───────────────────────────────────────────
  Widget _buildEsquemasTab() {
    final bool isMobile = ResponsiveBreakpoints.of(context).isMobile;

    return _loadingEsquemas
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _fetchEsquemas,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(isMobile ? 12 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  isMobile
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Esquemas de Dosificación PAI',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Dosis, esquemas por edad e intervalos',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _mostrarDialogoEsquema(),
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: const Text('+ Registrar Esquema'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Esquemas de Dosificación PAI',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Configuración de dosis, esquemas por edad e intervalos',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                            ElevatedButton.icon(
                              onPressed: () => _mostrarDialogoEsquema(),
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('+ Registrar Esquema'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                  const SizedBox(height: 16),
                  if (_esquemas.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Column(
                        children: [
                          Icon(
                            Icons.vaccines_outlined,
                            size: 48,
                            color: Color(0xFF94A3B8),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'No hay esquemas de vacunación registrados',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _esquemas.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (ctx, index) {
                        final esq = _esquemas[index];
                        final vacNombre =
                            esq['vacuna']?['nombre_articulo'] ?? 'Biológico';
                        final dosis = esq['numero_dosis'] ?? 'Dosis';
                        final intervalo = esq['intervalo_dias_previo'];
                        final edadMin = esq['edad_minima_meses'];
                        final edadMax = esq['edad_maxima_meses'];

                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(isMobile ? 12 : 16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  padding: EdgeInsets.all(isMobile ? 8 : 12),
                                  decoration: BoxDecoration(
                                    color: _primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.vaccines_rounded,
                                    color: _primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        vacNombre,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: isMobile ? 14 : 16,
                                          color: const Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Dosis: $dosis',
                                        style: TextStyle(
                                          fontSize: isMobile ? 12 : 14,
                                          fontWeight: FontWeight.w600,
                                          color: _primary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          if (intervalo != null)
                                            Chip(
                                              avatar: const Icon(
                                                Icons.timer_outlined,
                                                size: 12,
                                              ),
                                              label: Text(
                                                '$intervalo días',
                                                style: TextStyle(
                                                  fontSize: isMobile ? 10 : 11,
                                                ),
                                              ),
                                              visualDensity:
                                                  VisualDensity.compact,
                                              materialTapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
                                          if (edadMin != null ||
                                              edadMax != null)
                                            Chip(
                                              avatar: const Icon(
                                                Icons.child_care_rounded,
                                                size: 12,
                                              ),
                                              label: Text(
                                                '${edadMin ?? 0}-${edadMax ?? "N/A"} meses',
                                                style: TextStyle(
                                                  fontSize: isMobile ? 10 : 11,
                                                ),
                                              ),
                                              visualDensity:
                                                  VisualDensity.compact,
                                              materialTapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(4),
                                      icon: const Icon(
                                        Icons.edit_note_rounded,
                                        color: Color(0xFF475569),
                                        size: 20,
                                      ),
                                      onPressed: () =>
                                          _mostrarDialogoEsquema(esq),
                                      tooltip: 'Editar Esquema',
                                    ),
                                    IconButton(
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(4),
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                      onPressed: () => _eliminarEsquema(
                                        esq['id_esquema'],
                                        vacNombre,
                                        dosis,
                                      ),
                                      tooltip: 'Eliminar Esquema',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          );
  }

  // ─── TAB 2: DESCARTES DE BIOLÓGICOS ──────────────────────────────────────────
  Widget _buildDescartesTab() {
    final bool isMobile = ResponsiveBreakpoints.of(context).isMobile;

    return _loadingDescartes
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 12 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(isMobile ? 14 : 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.amber,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Registro de Acta de Descarte Legal (RF-10)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: _procesoDisposicion,
                          decoration: const InputDecoration(
                            labelText: 'Método de Disposición',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Incineración',
                              child: Text('Incineración'),
                            ),
                            DropdownMenuItem(
                              value: 'Autoclavado',
                              child: Text('Autoclavado'),
                            ),
                            DropdownMenuItem(
                              value: 'Desactivación Química',
                              child: Text('Desactivación Química'),
                            ),
                            DropdownMenuItem(
                              value: 'Retiro Sanitizante Especial',
                              child: Text('Retiro Sanitizante Especial'),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _procesoDisposicion = v!),
                        ),
                        const SizedBox(height: 12),
                        ListTile(
                          dense: isMobile,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          title: Text(
                            'Fecha de Retiro: ${_fechaRetiro.toIso8601String().split('T')[0]}',
                          ),
                          trailing: const Icon(
                            Icons.calendar_today_rounded,
                            size: 20,
                          ),
                          onTap: () => _selectFechaRetiro(context),
                        ),
                        const SizedBox(height: 16),
                        isMobile
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Lotes Vencidos Detectados: ${_lotesVencidos.length}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed:
                                          _isDiscarding ||
                                              _lotesVencidos.isEmpty
                                          ? null
                                          : _ejecutarDescarte,
                                      icon: _isDiscarding
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.delete_forever_rounded,
                                            ),
                                      label: Text(
                                        _isDiscarding
                                            ? 'Procesando...'
                                            : 'Ejecutar Descarte Legal',
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Lotes Vencidos Detectados: ${_lotesVencidos.length}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed:
                                        _isDiscarding || _lotesVencidos.isEmpty
                                        ? null
                                        : _ejecutarDescarte,
                                    icon: _isDiscarding
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.delete_forever_rounded,
                                          ),
                                    label: Text(
                                      _isDiscarding
                                          ? 'Procesando...'
                                          : 'Ejecutar Descarte Legal',
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 18,
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_lotesVencidos.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Column(
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          color: Colors.green,
                          size: 44,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'No hay biológicos ni vacunas vencidas actualmente.',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF475569),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _lotesVencidos.length,
                    itemBuilder: (ctx, index) {
                      final item = _lotesVencidos[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          dense: isMobile,
                          leading: const Icon(
                            Icons.biotech_rounded,
                            color: Colors.red,
                          ),
                          title: Text(
                            item['articulo']?['nombre_articulo'] ?? 'Biológico',
                          ),
                          subtitle: Text(
                            'Lote: ${item['numero_lote']} — Stock: ${item['stock_actual']}',
                          ),
                          trailing: Text(
                            'Venció:\n${item['fecha_vencimiento']}',
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                            textAlign: TextAlign.end,
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
  }
}

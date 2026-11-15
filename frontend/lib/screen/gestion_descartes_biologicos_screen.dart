import 'package:flutter/material.dart';
import 'package:asis_guanipa_frontend/services/api_service.dart';
import 'package:asis_guanipa_frontend/utils/upper_case_text_formatter.dart';
import 'package:asis_guanipa_frontend/components/modulo_app_bar.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:url_launcher/url_launcher.dart';

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
  String? _procesoDisposicion;
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
                    value: articuloSeleccionado,
                    hint: const Text('Seleccionar Biológico / Vacuna...'),
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

    if (_procesoDisposicion == null) {
      _showSnack('Seleccione el método de disposición final.', Colors.orange);
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
        metodoDisposicion: _procesoDisposicion!,
        fechaRetiro: fechaStr,
      );

      if (res['success'] == true) {
        _showSnack('Descarte ejecutado exitosamente.', _green);
        await _fetchLotesVencidos();
        final primerMovId = res['primer_movimiento_id'] as int?;
        if (mounted) _mostrarDialogoExitoDescarte(primerMovId);
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

  // === DESCARGAR REPORTE EXCEL DE DESCARTES ===
  Future<void> _descargarReporteDescartes() async {
    try {
      final url = await _apiService.getReporteDescartesExcelUrl();
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        _showSnack('Descargando reporte oficial de descartes (RF-10)...', _green);
      } else {
        _showSnack('No se pudo abrir el enlace de descarga.', Colors.red);
      }
    } catch (e) {
      _showSnack('Error al descargar reporte: $e', Colors.red);
    }
  }

  // === DIÁLOGO DE ÉXITO CON DESCARGA DE ACTA / REPORTE ===
  void _mostrarDialogoExitoDescarte(int? primerMovimientoId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: _green, size: 28),
            SizedBox(width: 10),
            Text('¡Descarte Completado!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Los biológicos vencidos han sido retirados del inventario y la acción ha quedado asentada bajo la norma RF-10.',
              style: TextStyle(fontSize: 13, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 16),
            const Text('Documentos oficiales disponibles:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            if (primerMovimientoId != null && primerMovimientoId > 0)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFEBEE),
                  foregroundColor: Colors.red,
                  child: Icon(Icons.picture_as_pdf, size: 20),
                ),
                title: const Text('Acta Oficial de Descarte (PDF)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: const Text('Formato legal con código QR institucional', style: TextStyle(fontSize: 11)),
                trailing: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                  onPressed: () async {
                    final url = await _apiService.getNotaSalidaUrl(primerMovimientoId);
                    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                  },
                  icon: const Icon(Icons.download, size: 14),
                  label: const Text('PDF', style: TextStyle(fontSize: 11)),
                ),
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE8F5E9),
                foregroundColor: _green,
                child: Icon(Icons.table_chart_rounded, size: 20),
              ),
              title: const Text('Reporte Consolidado (Excel MPPS)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: const Text('Historial y trazabilidad de descartes', style: TextStyle(fontSize: 11)),
              trailing: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: _green, foregroundColor: Colors.white),
                onPressed: () {
                  Navigator.pop(ctx);
                  _descargarReporteDescartes();
                },
                icon: const Icon(Icons.file_download, size: 14),
                label: const Text('Excel', style: TextStyle(fontSize: 11)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
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
      appBar: ModuloAppBar(
        titulo: 'Biológicos, Vacunas y Esquemas PAI',
        subtitulo: 'Descartes, Esquemas PAI · CDI Pedro Urbina',
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
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

  // ─── Helpers de texto de edad ────────────────────────────────────────────────
  String _edadTexto(int? meses) {
    if (meses == null) return 'Sin límite';
    if (meses == 0) return 'Al nacer';
    if (meses < 12) return '$meses ${meses == 1 ? "mes" : "meses"}';
    final anios = meses ~/ 12;
    final resto = meses % 12;
    if (resto == 0) return '$anios ${anios == 1 ? "año" : "años"}';
    return '$anios ${anios == 1 ? "año" : "años"} $resto ${resto == 1 ? "mes" : "meses"}';
  }

  String _intervaloTexto(int? dias) {
    if (dias == null) return 'Primera dosis (no requiere intervalo)';
    if (dias < 30) return '$dias días después de la dosis anterior';
    if (dias < 365) {
      final meses = (dias / 30).round();
      return '$meses ${meses == 1 ? "mes" : "meses"} después de la dosis anterior';
    }
    final anios = (dias / 365).round();
    return '$anios ${anios == 1 ? "año" : "años"} después de la dosis anterior';
  }

  /// Calcula la fecha de próxima dosis dado la fecha de última aplicación e intervalo
  String _proximaFechaTexto(int? intervaloDias) {
    if (intervaloDias == null) return '';
    final proxima = DateTime.now().add(Duration(days: intervaloDias));
    final dia = proxima.day.toString().padLeft(2, '0');
    final mes = proxima.month.toString().padLeft(2, '0');
    return '$dia/$mes/${proxima.year}';
  }

  // ─── TAB 1: ESQUEMAS DE VACUNACIÓN ───────────────────────────────────────────
  Widget _buildEsquemasTab() {
    final bool isMobile = ResponsiveBreakpoints.of(context).isMobile;

    // ── Agrupar esquemas por vacuna ──────────────────────────────────────────
    final Map<String, List<Map<String, dynamic>>> agrupados = {};
    for (final esq in _esquemas) {
      final vacNombre = esq['vacuna']?['nombre_articulo'] ?? 'Biológico';
      agrupados.putIfAbsent(vacNombre, () => []).add(esq);
    }
    // Ordenar dosis dentro de cada vacuna por id_esquema
    for (final key in agrupados.keys) {
      agrupados[key]!.sort((a, b) =>
          ((a['id_esquema'] ?? 0) as int).compareTo((b['id_esquema'] ?? 0) as int));
    }
    final vacunas = agrupados.keys.toList()..sort();

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
                  // ── Encabezado ────────────────────────────────────────────
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
                              'Programa Ampliado de Inmunizaciones — MPPS Venezuela',
                              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
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
                                      borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                                  'Programa Ampliado de Inmunizaciones — MPPS Venezuela\nTotal de dosis, edad mínima y próxima cita por biológico',
                                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
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
                                    borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                  const SizedBox(height: 16),

                  // ── Resumen de vacunas en el PAI ─────────────────────────
                  if (_esquemas.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              size: 18, color: Color(0xFF1D4ED8)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${vacunas.length} biológicos · ${_esquemas.length} dosis totales en el esquema PAI vigente',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E3A8A),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // ── Lista agrupada por vacuna ─────────────────────────────
                  if (agrupados.isEmpty)
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
                          Icon(Icons.vaccines_outlined, size: 48, color: Color(0xFF94A3B8)),
                          SizedBox(height: 12),
                          Text(
                            'No hay esquemas de vacunación registrados',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: vacunas.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (ctx, vIdx) {
                        final vacNombre = vacunas[vIdx];
                        final dosisLista = agrupados[vacNombre]!;
                        final totalDosis = dosisLista.length;

                        // Edad mínima del esquema completo = la menor edad mínima entre sus dosis
                        final edadMinGlobal = dosisLista
                            .map((d) => d['edad_minima_meses'] as int? ?? 0)
                            .reduce((a, b) => a < b ? a : b);

                        // Color según tipo de biológico
                        final esUnica = totalDosis == 1;
                        final cardColor = esUnica
                            ? const Color(0xFFF0FDF4)
                            : const Color(0xFFF8FAFC);
                        final borderColor = esUnica
                            ? const Color(0xFFBBF7D0)
                            : const Color(0xFFE2E8F0);
                        final accentColor = esUnica
                            ? const Color(0xFF16A34A)
                            : _primary;

                        return Card(
                          elevation: 0,
                          color: cardColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(color: borderColor),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(isMobile ? 12 : 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ── Cabecera de la vacuna ─────────────────
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: accentColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(Icons.vaccines_rounded,
                                          color: accentColor, size: 22),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            vacNombre,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: isMobile ? 15 : 17,
                                              color: const Color(0xFF0F172A),
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            children: [
                                              // Badge: Total de dosis
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: accentColor,
                                                  borderRadius: BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  '$totalDosis ${totalDosis == 1 ? "dosis" : "dosis en total"}',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              // Badge: Edad mínima
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFE0F2FE),
                                                  borderRadius: BorderRadius.circular(20),
                                                  border: Border.all(
                                                      color: const Color(0xFF7DD3FC)),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.child_care_rounded,
                                                        size: 12,
                                                        color: Color(0xFF0369A1)),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'Desde: ${_edadTexto(edadMinGlobal)}',
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w600,
                                                        color: Color(0xFF0369A1),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                                const SizedBox(height: 8),

                                // ── Tabla de dosis ────────────────────────
                                // Encabezado
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 2),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'DOSIS',
                                          style: TextStyle(
                                            fontSize: isMobile ? 9 : 10,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF64748B),
                                            letterSpacing: 0.6,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'EDAD MÍNIMA',
                                          style: TextStyle(
                                            fontSize: isMobile ? 9 : 10,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF64748B),
                                            letterSpacing: 0.6,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'INTERVALO',
                                          style: TextStyle(
                                            fontSize: isMobile ? 9 : 10,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF64748B),
                                            letterSpacing: 0.6,
                                          ),
                                        ),
                                      ),
                                      if (!isMobile)
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            'PRÓXIMA CITA (DESDE HOY)',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF64748B),
                                              letterSpacing: 0.6,
                                            ),
                                          ),
                                        ),
                                      const SizedBox(width: 48), // acciones
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),

                                // Filas de dosis
                                ...dosisLista.asMap().entries.map((entry) {
                                  final idx = entry.key;
                                  final esq = entry.value;
                                  final dosisNombre = esq['numero_dosis'] ?? 'Dosis';
                                  final intervalo = esq['intervalo_dias_previo'] as int?;
                                  final edadMin = esq['edad_minima_meses'] as int?;
                                  final edadMax = esq['edad_maxima_meses'] as int?;
                                  final esPar = idx % 2 == 0;

                                  String edadRangoTexto;
                                  if (edadMin != null && edadMax != null) {
                                    edadRangoTexto =
                                        '${_edadTexto(edadMin)} – ${_edadTexto(edadMax)}';
                                  } else if (edadMin != null) {
                                    edadRangoTexto = 'A partir de ${_edadTexto(edadMin)}';
                                  } else {
                                    edadRangoTexto = 'Sin restricción de edad';
                                  }

                                  return Container(
                                    decoration: BoxDecoration(
                                      color: esPar
                                          ? Colors.white.withValues(alpha: 0.6)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 6),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          // Nº + nombre de dosis
                                          Expanded(
                                            flex: 2,
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 22,
                                                  height: 22,
                                                  alignment: Alignment.center,
                                                  decoration: BoxDecoration(
                                                    color: accentColor,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Text(
                                                    '${idx + 1}',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Flexible(
                                                  child: Text(
                                                    dosisNombre,
                                                    style: TextStyle(
                                                      fontSize: isMobile ? 11 : 12,
                                                      fontWeight: FontWeight.w600,
                                                      color: const Color(0xFF1E293B),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Edad mínima
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              edadRangoTexto,
                                              style: TextStyle(
                                                fontSize: isMobile ? 10 : 11,
                                                color: const Color(0xFF0369A1),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          // Intervalo
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              _intervaloTexto(intervalo),
                                              style: TextStyle(
                                                fontSize: isMobile ? 10 : 11,
                                                color: intervalo == null
                                                    ? const Color(0xFF16A34A)
                                                    : const Color(0xFF92400E),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          // Próxima cita (solo desktop)
                                          if (!isMobile)
                                            Expanded(
                                              flex: 2,
                                              child: intervalo != null
                                                  ? Row(
                                                      children: [
                                                        const Icon(
                                                          Icons.event_available_rounded,
                                                          size: 13,
                                                          color: Color(0xFF7C3AED),
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          _proximaFechaTexto(intervalo),
                                                          style: const TextStyle(
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.bold,
                                                            color: Color(0xFF7C3AED),
                                                          ),
                                                        ),
                                                      ],
                                                    )
                                                  : const Text(
                                                      '— Primera vez',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Color(0xFF64748B),
                                                      ),
                                                    ),
                                            ),
                                          // Acciones
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                constraints: const BoxConstraints(),
                                                padding: const EdgeInsets.all(4),
                                                icon: const Icon(
                                                  Icons.edit_note_rounded,
                                                  color: Color(0xFF475569),
                                                  size: 18,
                                                ),
                                                onPressed: () =>
                                                    _mostrarDialogoEsquema(esq),
                                                tooltip: 'Editar dosis',
                                              ),
                                              IconButton(
                                                constraints: const BoxConstraints(),
                                                padding: const EdgeInsets.all(4),
                                                icon: const Icon(
                                                  Icons.delete_outline_rounded,
                                                  color: Colors.red,
                                                  size: 18,
                                                ),
                                                onPressed: () => _eliminarEsquema(
                                                  esq['id_esquema'],
                                                  vacNombre,
                                                  dosisNombre,
                                                ),
                                                tooltip: 'Eliminar dosis',
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),

                                // En móvil: mostrar próxima cita de la última dosis del esquema
                                if (isMobile) ...[
                                  const SizedBox(height: 8),
                                  Builder(builder: (_) {
                                    // Última dosis que tiene intervalo
                                    final ultimaConIntervalo = dosisLista
                                        .where((d) =>
                                            d['intervalo_dias_previo'] != null)
                                        .lastOrNull;
                                    if (ultimaConIntervalo == null) return const SizedBox.shrink();
                                    final proxFecha = _proximaFechaTexto(
                                        ultimaConIntervalo['intervalo_dias_previo'] as int);
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF3E8FF),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: const Color(0xFFD8B4FE)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.event_available_rounded,
                                              size: 14, color: Color(0xFF7C3AED)),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              'Próxima cita referencial (desde hoy): $proxFecha',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF6D28D9),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
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
                        Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Registro de Acta de Descarte Legal (RF-10)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _descargarReporteDescartes,
                              icon: const Icon(Icons.file_download_outlined, size: 16, color: _green),
                              label: const Text(
                                'Reporte Excel',
                                style: TextStyle(fontSize: 12, color: _green, fontWeight: FontWeight.bold),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: _green),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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

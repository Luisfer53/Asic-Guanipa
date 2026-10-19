import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:asis_guanipa_frontend/services/api_service.dart';
import 'package:asis_guanipa_frontend/utils/upper_case_text_formatter.dart';
import 'package:asis_guanipa_frontend/components/modulo_app_bar.dart';
import 'package:url_launcher/url_launcher.dart';

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class AlmacenScreen extends StatefulWidget {
  const AlmacenScreen({super.key});

  @override
  State<AlmacenScreen> createState() => _AlmacenScreenState();
}

class _AlmacenScreenState extends State<AlmacenScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();

  // Datos principales
  List<Map<String, dynamic>> _articulos = [];
  List<Map<String, dynamic>> _lotes = [];
  List<Map<String, dynamic>> _movimientos = [];
  List<Map<String, dynamic>> _proveedores = [];
  List<Map<String, dynamic>> _centros = [];

  bool _isLoading = false;
  bool _isLoadingMovimientos = false;

  // Filtros Tab 1: Lotes
  final _searchLotesCtrl = TextEditingController();
  String _filtroTipoLote = 'Todos';
  String _filtroSemaforoLote = 'Todos'; // 'Todos', 'optimo', 'bajo', 'proximo', 'vencido'

  // Filtros Tab 2: Artículos
  final _searchArticulosCtrl = TextEditingController();
  String _filtroTipoArticulo = 'Todos';

  // Filtros Tab 3: Movimientos / Kárdex
  String _filtroTipoMovimiento = 'Todos';

  // Paleta de colores oficial
  static const _primary = Color(0xFF0D47A1);
  static const _primaryLight = Color(0xFF1E88E5);
  static const _teal = Color(0xFF00897B);
  static const _green = Color(0xFF2E7D32);
  static const _amber = Color(0xFFF57F17);
  static const _red = Color(0xFFC62828);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 2 && _movimientos.isEmpty) {
        _fetchMovimientos();
      }
    });
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchLotesCtrl.dispose();
    _searchArticulosCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _apiService.getArticulos(),
        _apiService.getInventario(),
        _apiService.getProveedores(),
        _apiService.getCentros(),
      ]);

      if (mounted) {
        setState(() {
          if (results[0]['success'] == true) {
            _articulos = List<Map<String, dynamic>>.from(results[0]['data'] ?? []);
          }
          if (results[1]['success'] == true) {
            _lotes = List<Map<String, dynamic>>.from(results[1]['data'] ?? []);
          }
          if (results[2]['success'] == true) {
            _proveedores = List<Map<String, dynamic>>.from(results[2]['data'] ?? []);
          }
          if (results[3]['success'] == true) {
            _centros = List<Map<String, dynamic>>.from(results[3]['data'] ?? []);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al sincronizar inventario: $e'),
            backgroundColor: _red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchMovimientos() async {
    setState(() => _isLoadingMovimientos = true);
    try {
      final res = await _apiService.getMovimientosInventario(
        tipo: _filtroTipoMovimiento == 'Todos' ? null : _filtroTipoMovimiento,
      );
      if (res['success'] == true && mounted) {
        setState(() {
          _movimientos = List<Map<String, dynamic>>.from(res['data'] ?? []);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar Kárdex: $e'), backgroundColor: _red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingMovimientos = false);
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // CALCULOS Y KPIS
  // ───────────────────────────────────────────────────────────────────────────

  int get _totalStockDosis {
    int total = 0;
    for (final l in _lotes) {
      total += (l['stock_actual'] as num? ?? 0).toInt();
    }
    return total;
  }

  int get _stockVacunas {
    int total = 0;
    for (final l in _lotes) {
      final tipo = l['articulo']?['tipo'] ?? '';
      if (tipo == 'Vacuna') {
        total += (l['stock_actual'] as num? ?? 0).toInt();
      }
    }
    return total;
  }

  int get _countStockCritico {
    int count = 0;
    for (final l in _lotes) {
      final alertas = l['alertas'] as Map<String, dynamic>?;
      if (alertas?['stock_bajo'] == true) count++;
    }
    return count;
  }

  int get _countFefoAlertas {
    int count = 0;
    for (final l in _lotes) {
      final alertas = l['alertas'] as Map<String, dynamic>?;
      if (alertas?['proximo_vencer'] == true || alertas?['vencido'] == true) {
        count++;
      }
    }
    return count;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // FILTRADO DE LOTES
  // ───────────────────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> get _lotesFiltrados {
    final query = _searchLotesCtrl.text.trim().toLowerCase();

    return _lotes.where((lote) {
      final numLote = (lote['numero_lote'] ?? '').toString().toLowerCase();
      final artNombre = (lote['articulo']?['nombre_articulo'] ?? '').toString().toLowerCase();
      final provNombre = (lote['proveedor']?['nombre_proveedor'] ?? '').toString().toLowerCase();
      final tipo = (lote['articulo']?['tipo'] ?? 'Insumo').toString();

      // Filtro de búsqueda
      if (query.isNotEmpty) {
        final matches = numLote.contains(query) ||
            artNombre.contains(query) ||
            provNombre.contains(query);
        if (!matches) return false;
      }

      // Filtro por tipo
      if (_filtroTipoLote != 'Todos' && tipo != _filtroTipoLote) {
        return false;
      }

      // Filtro por semáforo
      final alertas = lote['alertas'] as Map<String, dynamic>? ?? {};
      final bool esVencido = alertas['vencido'] == true;
      final bool esProximo = alertas['proximo_vencer'] == true;
      final bool esBajo = alertas['stock_bajo'] == true;

      if (_filtroSemaforoLote == 'vencido' && !esVencido) return false;
      if (_filtroSemaforoLote == 'proximo' && !esProximo) return false;
      if (_filtroSemaforoLote == 'bajo' && !esBajo) return false;
      if (_filtroSemaforoLote == 'optimo' && (esVencido || esProximo || esBajo)) return false;

      return true;
    }).toList();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // EXPORTACIÓN A CSV CON BOM UTF-8
  // ───────────────────────────────────────────────────────────────────────────

  void _exportarLotesCsv() {
    final lotes = _lotesFiltrados;
    if (lotes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay lotes para exportar'), backgroundColor: _amber),
      );
      return;
    }

    final buffer = StringBuffer();
    // UTF-8 BOM para Excel
    buffer.write('\uFEFF');
    buffer.writeln('Artículo,Tipo,N° Lote,Stock Actual,Unidad Medida,Fecha Vencimiento,Días Restantes,Estado Semáforo,Proveedor,Centro de Salud');

    final now = DateTime.now();

    for (final l in lotes) {
      final art = l['articulo'] ?? {};
      final nombreArt = (art['nombre_articulo'] ?? 'N/A').toString().replaceAll('"', '""');
      final tipo = (art['tipo'] ?? 'Insumo').toString();
      final numLote = (l['numero_lote'] ?? 'N/A').toString().replaceAll('"', '""');
      final stock = l['stock_actual'] ?? 0;
      final unidad = (art['unidad_medida'] ?? 'Unidades').toString();
      final fechaVenc = (l['fecha_vencimiento'] ?? '').toString();

      int diasRestantes = 0;
      String estadoSemaforo = 'ÓPTIMO';
      if (fechaVenc.isNotEmpty) {
        final dt = DateTime.tryParse(fechaVenc);
        if (dt != null) {
          diasRestantes = dt.difference(now).inDays;
          if (dt.isBefore(now)) {
            estadoSemaforo = 'VENCIDO';
          } else if (diasRestantes <= 60) {
            estadoSemaforo = 'PRÓXIMO A VENCER (FEFO)';
          }
        }
      }

      final alertas = l['alertas'] as Map<String, dynamic>? ?? {};
      if (alertas['stock_bajo'] == true && estadoSemaforo == 'ÓPTIMO') {
        estadoSemaforo = 'STOCK BAJO';
      }

      final prov = (l['proveedor']?['nombre_proveedor'] ?? 'No especificado').toString().replaceAll('"', '""');
      final centro = (l['centro']?['nombre_centro'] ?? 'CDI Pedro Urbina').toString().replaceAll('"', '""');

      buffer.writeln('"$nombreArt","$tipo","$numLote",$stock,"$unidad","$fechaVenc",$diasRestantes,"$estadoSemaforo","$prov","$centro"');
    }

    final bytes = utf8.encode(buffer.toString());
    final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', 'inventario_almacen_cdi_pedro_urbina_${DateTime.now().toString().substring(0, 10)}.csv')
      ..click();
    html.Url.revokeObjectUrl(url);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ Se exportaron ${lotes.length} lotes a formato Excel/CSV'),
        backgroundColor: _green,
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // DIÁLOGOS DE REGISTRO / EDICIÓN
  // ───────────────────────────────────────────────────────────────────────────

  void _showLoteDialog({Map<String, dynamic>? lote}) {
    if (_articulos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primero registre al menos un artículo médico o biológico'),
          backgroundColor: _amber,
        ),
      );
      return;
    }

    final isEdit = lote != null;
    final int? loteId = lote?['id_lote_insumo'] ?? lote?['id'];

    final formKey = GlobalKey<FormState>();
    final numeroLoteCtrl = TextEditingController(text: lote?['numero_lote'] ?? '');
    final stockCtrl = TextEditingController(text: (lote?['stock_actual'] ?? 100).toString());

    int? selectedArtId = lote?['id_articulo'] ?? (lote?['articulo']?['id_articulo']);
    selectedArtId ??= _articulos.first['id_articulo'];

    int? selectedProvId = lote?['id_proveedor'] ?? (lote?['proveedor']?['id_proveedor']);
    int? selectedCentroId = lote?['id_centro'] ?? (lote?['centro']?['id_centro']);

    DateTime? fechaVenc;
    if (lote?['fecha_vencimiento'] != null) {
      fechaVenc = DateTime.tryParse(lote!['fecha_vencimiento'].toString());
    } else {
      fechaVenc = DateTime.now().add(const Duration(days: 365));
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(isEdit ? Icons.edit_note : Icons.add_box_outlined, color: _primary),
                const SizedBox(width: 10),
                Text(
                  isEdit ? 'Actualizar Lote' : 'Registrar Nuevo Lote / Entrada',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primary),
                ),
              ],
            ),
          ),
          content: SizedBox(
            width: 500,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Artículo / Biológico *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                      initialValue: selectedArtId,
                      items: _articulos.map((a) {
                        final int id = a['id_articulo'] ?? a['id'];
                        final tipo = a['tipo'] ?? 'Insumo';
                        return DropdownMenuItem<int>(
                          value: id,
                          child: Text('[${tipo.toUpperCase()}] ${a['nombre_articulo']}'),
                        );
                      }).toList(),
                      onChanged: (val) => setDialogState(() => selectedArtId = val),
                      validator: (val) => val == null ? 'Seleccione un artículo' : null,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('N° de Lote *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: numeroLoteCtrl,
                                textCapitalization: TextCapitalization.characters,
                                inputFormatters: [UpperCaseTextFormatter()],
                                decoration: const InputDecoration(
                                  hintText: 'Ej: LOT-2026-X4',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                validator: (val) => val == null || val.trim().isEmpty ? 'Requerido' : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Stock Inicial *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: stockCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) return 'Requerido';
                                  if (int.tryParse(val.trim()) == null) return 'Inválido';
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text('Fecha de Vencimiento *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: fechaVenc ?? DateTime.now().add(const Duration(days: 365)),
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 3650)),
                        );
                        if (picked != null) {
                          setDialogState(() => fechaVenc = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month, color: _primary, size: 20),
                            const SizedBox(width: 10),
                            Text(
                              fechaVenc != null
                                  ? '${fechaVenc!.day.toString().padLeft(2, '0')}/${fechaVenc!.month.toString().padLeft(2, '0')}/${fechaVenc!.year}'
                                  : 'Seleccione fecha',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('Proveedor / Ente de Despacho', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int?>(
                      decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                      initialValue: selectedProvId,
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('No especificado / MPPS Central')),
                        ..._proveedores.map((p) => DropdownMenuItem<int?>(
                          value: p['id_proveedor'] ?? p['id'],
                          child: Text(p['nombre_proveedor'] ?? 'N/A'),
                        )),
                      ],
                      onChanged: (val) => setDialogState(() => selectedProvId = val),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                if (fechaVenc == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Seleccione la fecha de vencimiento')),
                  );
                  return;
                }

                final nav = Navigator.of(ctx);
                final numLote = numeroLoteCtrl.text.trim();
                final stock = int.parse(stockCtrl.text.trim());
                final fVencStr = fechaVenc!.toIso8601String().split('T')[0];

                Map<String, dynamic> res;
                if (isEdit && loteId != null) {
                  res = await _apiService.actualizarLote(
                    id: loteId,
                    idArticulo: selectedArtId,
                    numeroLote: numLote,
                    stockActual: stock,
                    fechaVencimiento: fVencStr,
                    idProveedor: selectedProvId,
                    idCentro: selectedCentroId,
                  );
                } else {
                  res = await _apiService.registrarLote(
                    idArticulo: selectedArtId!,
                    numeroLote: numLote,
                    stockActual: stock,
                    fechaVencimiento: fVencStr,
                    idProveedor: selectedProvId,
                    idCentro: selectedCentroId,
                  );
                }

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(res['message'] ?? 'Operación procesada'),
                      backgroundColor: res['success'] == true ? _green : _red,
                    ),
                  );
                  if (res['success'] == true) {
                    nav.pop();
                    _fetchData();
                  }
                }
              },
              icon: const Icon(Icons.check, color: Colors.white),
              label: Text(isEdit ? 'Guardar Cambios' : 'Registrar Lote', style: const TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: _primary),
            ),
          ],
        ),
      ),
    );
  }

  void _showDescarteDialog(Map<String, dynamic> lote) {
    final formKey = GlobalKey<FormState>();
    final numLote = lote['numero_lote'] ?? 'N/A';
    final artNombre = lote['articulo']?['nombre_articulo'] ?? 'Biológico / Insumo';
    final stockActual = (lote['stock_actual'] as num? ?? 0).toInt();
    final loteId = lote['id_lote_insumo'] ?? lote['id'];

    final actaCtrl = TextEditingController(
      text: 'ACTA-DESCARTE-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
    );
    final justificacionCtrl = TextEditingController(
      text: 'Descarte oficial por caducidad / pérdida de cadena de frío conforme a normativa MPPS.',
    );
    String metodoDisposicion = 'Incineración';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.delete_forever, color: _red),
                SizedBox(width: 10),
                Text(
                  'Acta de Descarte Oficial MPPS',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _red),
                ),
              ],
            ),
          ),
          content: SizedBox(
            width: 520,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Biológico: $artNombre', style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('N° Lote: $numLote  |  Cantidad a descartar: $stockActual dosis/unidades'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('N° de Acta Oficial / Registro *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: actaCtrl,
                      decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 14),
                    const Text('Método de Disposición Final *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: metodoDisposicion,
                      decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                      items: const [
                        DropdownMenuItem(value: 'Incineración', child: Text('Incineración Térmica')),
                        DropdownMenuItem(value: 'Inactivación Química', child: Text('Inactivación Química (Autoclave / Hipoclorito)')),
                        DropdownMenuItem(value: 'Envío a Nivel Central', child: Text('Retorno / Envío a Nivel Central Barcelona')),
                      ],
                      onChanged: (val) => setDState(() => metodoDisposicion = val ?? 'Incineración'),
                    ),
                    const SizedBox(height: 14),
                    const Text('Justificación Técnica / Causal *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: justificacionCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Causal MPPS: Vencimiento, Frasco abierto >6h, Rotura de cadena de frío...',
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Ingrese la justificación' : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton.icon(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final nav = Navigator.of(ctx);

                final res = await _apiService.descartarLotes(
                  ids: [loteId],
                  metodoDisposicion: metodoDisposicion,
                  fechaRetiro: DateTime.now().toIso8601String().split('T')[0],
                  justificacion: justificacionCtrl.text.trim(),
                  numeroActaDescarte: actaCtrl.text.trim(),
                );

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(res['message'] ?? 'Descarte procesado con éxito'),
                      backgroundColor: res['success'] == true ? _green : _red,
                    ),
                  );
                  if (res['success'] == true) {
                    nav.pop();
                    _fetchData();
                    if (_tabController.index == 2) _fetchMovimientos();
                    final primerMovId = res['primer_movimiento_id'] as int?;
                    if (mounted) _mostrarDialogoExitoDescarte(primerMovId);
                  }
                }
              },
              icon: const Icon(Icons.delete_forever, color: Colors.white),
              label: const Text('Confirmar y Emitir Acta', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: _red),
            ),
          ],
        ),
      ),
    );
  }

  // Diálogo de éxito con descarga de acta PDF y reporte Excel tras descarte oficial
  void _mostrarDialogoExitoDescarte(int? primerMovimientoId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: _green, size: 28),
            SizedBox(width: 10),
            Text('¡Descarte Procesado con Éxito!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'El lote ha sido retirado formalmente del stock y el movimiento de descarte quedó asentado en el kárdex institucional (Norma RF-10 MPPS).',
              style: TextStyle(fontSize: 13, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 16),
            const Text('Documentación oficial generada:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                subtitle: const Text('Comprobante institucional con QR', style: TextStyle(fontSize: 11)),
                trailing: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                  onPressed: () async {
                    final url = await _apiService.getNotaSalidaUrl(primerMovimientoId);
                    final uri = Uri.parse(url);
                    if (await canLaunchUrl(uri)) {
                      launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
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
              title: const Text('Reporte Excel de Descartes (RF-10)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: const Text('Trazabilidad consolidada MPPS', style: TextStyle(fontSize: 11)),
              trailing: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: _green, foregroundColor: Colors.white),
                onPressed: () async {
                  Navigator.pop(ctx);
                  final url = await _apiService.getReporteDescartesExcelUrl();
                  final uri = Uri.parse(url);
                  if (await canLaunchUrl(uri)) {
                    launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
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

  // Diálogo para inspeccionar lotes de un artículo específico y descartarlos directamente
  void _showLotesDeArticuloDialog(Map<String, dynamic> art) {
    final artId = art['id_articulo'] ?? art['id'];
    final artNombre = art['nombre_articulo'] ?? 'Insumo';
    final unidad = art['unidad_medida'] ?? 'Unidades';
    final tipo = art['tipo'] ?? 'Insumo';
    final lotesDelArt = _lotes.where((l) => (l['id_articulo'] ?? l['articulo']?['id_articulo']) == artId).toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: _getTipoColor(tipo).withValues(alpha: 0.15),
              foregroundColor: _getTipoColor(tipo),
              child: Icon(_getTipoIcon(tipo), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(artNombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('Lotes registrados para este insumo', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 600,
          child: lotesDelArt.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 10),
                      const Text(
                        'No hay lotes registrados para este insumo.',
                        style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add_box, size: 16, color: Colors.white),
                        label: const Text('Registrar Entrada de Lote', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(backgroundColor: _primary),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showLoteDialog();
                        },
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: lotesDelArt.map((lote) {
                      final numLote = lote['numero_lote'] ?? 'N/A';
                      final stock = (lote['stock_actual'] as num? ?? 0).toInt();
                      final venc = lote['fecha_vencimiento'] ?? 'N/A';
                      final alertas = lote['alertas'] as Map<String, dynamic>? ?? {};
                      final bool esVencido = alertas['vencido'] == true;
                      final bool esProximo = alertas['proximo_vencer'] == true;

                      Color estadoColor = _green;
                      String estadoTexto = 'En Regla';
                      if (esVencido) {
                        estadoColor = _red;
                        estadoTexto = 'VENCIDO';
                      } else if (esProximo) {
                        estadoColor = _amber;
                        estadoTexto = 'Próx. Vencer';
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: esVencido ? _red.withValues(alpha: 0.05) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: esVencido ? _red.withValues(alpha: 0.3) : Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Lote: $numLote',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 13),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: estadoColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          estadoTexto,
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: estadoColor),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Stock: $stock $unidad  |  Vence: $venc',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Botón directo para descartar lote de este insumo
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              icon: const Icon(Icons.delete_sweep, size: 16),
                              label: const Text('Descartar Lote'),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _showDescarteDialog(lote);
                              },
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
          if (lotesDelArt.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Nuevo Lote'),
              onPressed: () {
                Navigator.pop(ctx);
                _showLoteDialog();
              },
            ),
        ],
      ),
    );
  }

  void _showArticuloDialog({Map<String, dynamic>? articulo}) {
    final formKey = GlobalKey<FormState>();
    final nombreCtrl = TextEditingController(text: articulo?['nombre_articulo'] ?? '');
    final unidadCtrl = TextEditingController(text: articulo?['unidad_medida'] ?? 'Dosis');
    final descCtrl = TextEditingController(text: articulo?['descripcion'] ?? '');
    final stockMinCtrl = TextEditingController(text: (articulo?['stock_minimo_alerta'] ?? 15).toString());
    String selectedTipo = articulo?['tipo'] ?? 'Vacuna';

    final isEdit = articulo != null;
    final int? artId = articulo?['id_articulo'] ?? articulo?['id'];
    const tipos = ['Vacuna', 'Medicamento', 'Insumo', 'Equipo'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(isEdit ? 'Editar Artículo / Biológico' : 'Registrar Nuevo Artículo / Biológico'),
          content: SizedBox(
            width: 480,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedTipo,
                      decoration: const InputDecoration(labelText: 'Tipo de Artículo *', border: OutlineInputBorder()),
                      items: tipos.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (val) => setDState(() => selectedTipo = val ?? 'Vacuna'),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: nombreCtrl,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [UpperCaseTextFormatter()],
                      decoration: const InputDecoration(labelText: 'Nombre Oficial *', border: OutlineInputBorder()),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: unidadCtrl,
                            decoration: const InputDecoration(labelText: 'Unidad de Medida *', border: OutlineInputBorder()),
                            validator: (val) => val == null || val.trim().isEmpty ? 'Requerido' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: stockMinCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Stock Mínimo Alerta', border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Descripción / Presentación (Opcional)', border: OutlineInputBorder()),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final nav = Navigator.of(ctx);
                final nombre = nombreCtrl.text.trim();
                final unidad = unidadCtrl.text.trim();
                final desc = descCtrl.text.trim();
                final stockMin = int.tryParse(stockMinCtrl.text.trim()) ?? 10;

                Map<String, dynamic> res;
                if (isEdit && artId != null) {
                  res = await _apiService.actualizarArticulo(
                    id: artId,
                    nombreArticulo: nombre,
                    unidadMedida: unidad,
                    tipo: selectedTipo,
                    descripcion: desc.isEmpty ? null : desc,
                    stockMinimoAlerta: stockMin,
                  );
                } else {
                  res = await _apiService.registrarArticulo(
                    nombre,
                    unidad,
                    tipo: selectedTipo,
                    descripcion: desc.isEmpty ? null : desc,
                    stockMinimoAlerta: stockMin,
                  );
                }

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(res['message'] ?? 'Guardado'),
                      backgroundColor: res['success'] == true ? _green : _red,
                    ),
                  );
                  if (res['success'] == true) {
                    nav.pop();
                    _fetchData();
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white),
              child: Text(isEdit ? 'Actualizar' : 'Registrar'),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // UI BUILD
  // ───────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: ModuloAppBar(
        titulo: 'Almacén Clínico & Control de Biológicos',
        subtitulo: 'ASIC San José de Guanipa · CDI Pedro Urbina',
        backgroundColor: _primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Exportar Existencias (CSV / Excel)',
            onPressed: _exportarLotesCsv,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar Datos',
            onPressed: () {
              _fetchData();
              if (_tabController.index == 2) _fetchMovimientos();
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.amber,
          indicatorWeight: 3,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Lotes y Existencias'),
            Tab(icon: Icon(Icons.category_outlined), text: 'Catálogo de Artículos'),
            Tab(icon: Icon(Icons.history_edu_outlined), text: 'Kárdex & Movimientos'),
            Tab(icon: Icon(Icons.local_shipping_outlined), text: 'Proveedores'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildKpiRibbon(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildLotesTab(),
                      _buildArticulosTab(),
                      _buildKardexTab(),
                      _buildProveedoresTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // KPI RIBBON SUPERIOR
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildKpiRibbon() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 800;
          return Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            children: [
              _buildKpiCard(
                title: 'Total Existencias',
                value: '$_totalStockDosis',
                subtitle: '${_lotes.length} lotes activos',
                icon: Icons.inventory,
                color: _primaryLight,
                isWide: isWide,
                onTap: () => setState(() {
                  _filtroSemaforoLote = 'Todos';
                  _filtroTipoLote = 'Todos';
                  _tabController.animateTo(0);
                }),
              ),
              _buildKpiCard(
                title: 'Vacunas / Biológicos',
                value: '$_stockVacunas',
                subtitle: 'Dosis en cadena de frío',
                icon: Icons.vaccines,
                color: _teal,
                isWide: isWide,
                onTap: () => setState(() {
                  _filtroTipoLote = 'Vacuna';
                  _tabController.animateTo(0);
                }),
              ),
              _buildKpiCard(
                title: 'Stock Bajo / Crítico',
                value: '$_countStockCritico',
                subtitle: 'Bajo umbral mínimo',
                icon: Icons.warning_amber_rounded,
                color: _amber,
                isWide: isWide,
                onTap: () => setState(() {
                  _filtroSemaforoLote = 'bajo';
                  _tabController.animateTo(0);
                }),
              ),
              _buildKpiCard(
                title: 'Alertas FEFO / Venc.',
                value: '$_countFefoAlertas',
                subtitle: 'Vencen en <60d o vencidos',
                icon: Icons.event_busy,
                color: _red,
                isWide: isWide,
                onTap: () => setState(() {
                  _filtroSemaforoLote = 'proximo';
                  _tabController.animateTo(0);
                }),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isWide,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: isWide ? 230 : 160,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: color.withValues(alpha: 0.2),
              foregroundColor: color,
              child: Icon(icon, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                  Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
                  Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TAB 1: LOTES Y EXISTENCIAS (DATA GRID)
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildLotesTab() {
    final lotes = _lotesFiltrados;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Barra de Filtros y Acciones
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Wrap(
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  // Buscador
                  SizedBox(
                    width: 260,
                    child: TextField(
                      controller: _searchLotesCtrl,
                      decoration: InputDecoration(
                        hintText: 'Buscar lote, vacuna, proveedor...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  // Filtro Tipo
                  SizedBox(
                    width: 170,
                    child: DropdownButtonFormField<String>(
                      initialValue: _filtroTipoLote,
                      decoration: const InputDecoration(
                        labelText: 'Tipo',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Todos', child: Text('Todos los Tipos')),
                        DropdownMenuItem(value: 'Vacuna', child: Text('💉 Vacunas')),
                        DropdownMenuItem(value: 'Medicamento', child: Text('💊 Medicamentos')),
                        DropdownMenuItem(value: 'Insumo', child: Text('📦 Insumos')),
                        DropdownMenuItem(value: 'Equipo', child: Text('🩺 Equipos')),
                      ],
                      onChanged: (val) => setState(() => _filtroTipoLote = val ?? 'Todos'),
                    ),
                  ),
                  // Filtro Semáforo
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String>(
                      initialValue: _filtroSemaforoLote,
                      decoration: const InputDecoration(
                        labelText: 'Semáforo',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Todos', child: Text('Todos los Estados')),
                        DropdownMenuItem(value: 'optimo', child: Text('🟢 Stock Óptimo')),
                        DropdownMenuItem(value: 'bajo', child: Text('🟡 Stock Bajo')),
                        DropdownMenuItem(value: 'proximo', child: Text('🟠 Próximo Vencer')),
                        DropdownMenuItem(value: 'vencido', child: Text('🔴 Vencido')),
                      ],
                      onChanged: (val) => setState(() => _filtroSemaforoLote = val ?? 'Todos'),
                    ),
                  ),
                  // Botón Agregar Lote
                  ElevatedButton.icon(
                    onPressed: () => _showLoteDialog(),
                    icon: const Icon(Icons.add_box, color: Colors.white),
                    label: const Text('Entrada / Lote', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Tabla de Lotes
          Expanded(
            child: lotes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        const Text('No se encontraron lotes con los filtros seleccionados', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowHeight: 44,
                          dataRowMinHeight: 48,
                          dataRowMaxHeight: 52,
                          headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                          columns: const [
                            DataColumn(label: Text('Artículo / Biológico', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                            DataColumn(label: Text('N° Lote', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                            DataColumn(label: Text('Stock Actual', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                            DataColumn(label: Text('Vencimiento (FEFO)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                            DataColumn(label: Text('Proveedor / Origen', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                            DataColumn(label: Text('Acciones', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                          ],
                          rows: lotes.map((lote) {
                            final art = lote['articulo'] ?? {};
                            final artNombre = art['nombre_articulo'] ?? 'N/A';
                            final tipo = art['tipo'] ?? 'Insumo';
                            final numLote = lote['numero_lote'] ?? 'N/A';
                            final stock = (lote['stock_actual'] as num? ?? 0).toInt();
                            final unidad = art['unidad_medida'] ?? 'Unidades';
                            final fechaVenc = lote['fecha_vencimiento'] ?? 'N/A';
                            final provNombre = lote['proveedor']?['nombre_proveedor'] ?? 'MPPS Central';

                            final alertas = lote['alertas'] as Map<String, dynamic>? ?? {};
                            final bool esVencido = alertas['vencido'] == true;
                            final bool esProximo = alertas['proximo_vencer'] == true;
                            final bool esBajo = alertas['stock_bajo'] == true;

                            Color badgeColor = _green;
                            String badgeText = 'Óptimo';
                            if (esVencido) {
                              badgeColor = _red;
                              badgeText = 'Vencido';
                            } else if (esProximo) {
                              badgeColor = _amber;
                              badgeText = 'Próx. Vencer';
                            } else if (esBajo) {
                              badgeColor = Colors.orange;
                              badgeText = 'Stock Bajo';
                            }

                            return DataRow(
                              cells: [
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: _getTipoColor(tipo).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          tipo,
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _getTipoColor(tipo)),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(artNombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    child: Text(
                                      numLote,
                                      style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('$stock $unidad', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: esBajo ? _red : Colors.black87)),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: badgeColor.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          badgeText,
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    fechaVenc,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: esVencido ? _red : (esProximo ? _amber : Colors.black87),
                                    ),
                                  ),
                                ),
                                DataCell(Text(provNombre, style: const TextStyle(fontSize: 12))),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 18, color: _primary),
                                        tooltip: 'Editar Lote',
                                        onPressed: () => _showLoteDialog(lote: lote),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_sweep, size: 20, color: _red),
                                        tooltip: 'Descartar este Lote (Acta Oficial RF-10)',
                                        onPressed: () => _showDescarteDialog(lote),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TAB 2: CATÁLOGO DE ARTÍCULOS
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildArticulosTab() {
    final query = _searchArticulosCtrl.text.trim().toLowerCase();
    final articulosFiltrados = _articulos.where((a) {
      final nombre = (a['nombre_articulo'] ?? '').toString().toLowerCase();
      final tipo = (a['tipo'] ?? 'Insumo').toString();
      if (query.isNotEmpty && !nombre.contains(query)) return false;
      if (_filtroTipoArticulo != 'Todos' && tipo != _filtroTipoArticulo) return false;
      return true;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  SizedBox(
                    width: 280,
                    child: TextField(
                      controller: _searchArticulosCtrl,
                      decoration: InputDecoration(
                        hintText: 'Buscar artículo o biológico...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String>(
                      initialValue: _filtroTipoArticulo,
                      decoration: const InputDecoration(
                        labelText: 'Tipo',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Todos', child: Text('Todos los Tipos')),
                        DropdownMenuItem(value: 'Vacuna', child: Text('💉 Vacunas')),
                        DropdownMenuItem(value: 'Medicamento', child: Text('💊 Medicamentos')),
                        DropdownMenuItem(value: 'Insumo', child: Text('📦 Insumos')),
                        DropdownMenuItem(value: 'Equipo', child: Text('🩺 Equipos')),
                      ],
                      onChanged: (val) => setState(() => _filtroTipoArticulo = val ?? 'Todos'),
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () => _showArticuloDialog(),
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text('Nuevo Artículo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              clipBehavior: Clip.antiAlias,
              child: ListView.separated(
                itemCount: articulosFiltrados.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final art = articulosFiltrados[index];
                  final artId = art['id_articulo'] ?? art['id'] ?? 0;
                  final nombre = art['nombre_articulo'] ?? 'N/A';
                  final tipo = art['tipo'] ?? 'Insumo';
                  final unidad = art['unidad_medida'] ?? 'Unidades';
                  final stockMin = art['stock_minimo_alerta'] ?? 10;
                  final desc = art['descripcion'];

                  // Sumar stock de todos los lotes de este artículo
                  int stockConsolidado = 0;
                  for (final l in _lotes) {
                    final lArtId = l['id_articulo'] ?? l['articulo']?['id_articulo'];
                    if (lArtId == artId) {
                      stockConsolidado += (l['stock_actual'] as num? ?? 0).toInt();
                    }
                  }

                  final bool alertaBajo = stockConsolidado < stockMin;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    leading: CircleAvatar(
                      backgroundColor: _getTipoColor(tipo).withValues(alpha: 0.15),
                      foregroundColor: _getTipoColor(tipo),
                      child: Icon(_getTipoIcon(tipo)),
                    ),
                    title: Row(
                      children: [
                        Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getTipoColor(tipo).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(tipo, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _getTipoColor(tipo))),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 2),
                        Text('Unidad: $unidad · Umbral Mínimo: $stockMin $unidad', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        if (desc != null && desc.toString().isNotEmpty)
                          Text('Descripción: $desc', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: alertaBajo ? _red.withValues(alpha: 0.12) : _green.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: alertaBajo ? _red.withValues(alpha: 0.3) : _green.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            '$stockConsolidado $unidad en stock',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: alertaBajo ? _red : _green,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Tooltip(
                          message: 'Inspeccionar lotes de este insumo y descartar si aplica',
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _red,
                              side: BorderSide(color: _red.withValues(alpha: 0.5)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            icon: const Icon(Icons.delete_sweep, size: 16, color: _red),
                            label: const Text('Lotes / Descartar'),
                            onPressed: () => _showLotesDeArticuloDialog(art),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: _primary),
                          tooltip: 'Editar Insumo',
                          onPressed: () => _showArticuloDialog(articulo: art),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TAB 3: KÁRDEX & MOVIMIENTOS
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildKardexTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  const Icon(Icons.history_edu, color: _primary),
                  const SizedBox(width: 8),
                  const Text('Historial de Movimientos & Auditoría', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const Spacer(),
                  SizedBox(
                    width: 200,
                    child: DropdownButtonFormField<String>(
                      initialValue: _filtroTipoMovimiento,
                      decoration: const InputDecoration(
                        labelText: 'Filtrar por Tipo',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Todos', child: Text('Todos los Movimientos')),
                        DropdownMenuItem(value: 'Entrada', child: Text('🟢 Entrada')),
                        DropdownMenuItem(value: 'Despacho', child: Text('🔵 Despacho')),
                        DropdownMenuItem(value: 'Descarte', child: Text('🔴 Descarte')),
                        DropdownMenuItem(value: 'Salida Asistencial', child: Text('🟣 Salida Asistencial')),
                        DropdownMenuItem(value: 'Ajuste', child: Text('🟠 Ajuste')),
                      ],
                      onChanged: (val) {
                        setState(() => _filtroTipoMovimiento = val ?? 'Todos');
                        _fetchMovimientos();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Recargar Kárdex',
                    onPressed: _fetchMovimientos,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _isLoadingMovimientos
                ? const Center(child: CircularProgressIndicator())
                : _movimientos.isEmpty
                    ? const Center(child: Text('No hay movimientos registrados'))
                    : Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ListView.separated(
                          itemCount: _movimientos.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final m = _movimientos[index];
                            final idMov = m['id_movimiento'] ?? 0;
                            final tipoMov = m['tipo_movimiento'] ?? 'Movimiento';
                            final cant = m['cantidad'] ?? 0;
                            final fMov = m['fecha_movimiento'] != null
                                ? DateTime.tryParse(m['fecha_movimiento'].toString())?.toLocal().toString().substring(0, 16)
                                : 'N/A';
                            final numActa = m['numero_acta_descarte'];
                            final just = m['justificacion'] ?? 'Sin justificación';
                            final artNombre = m['lote']?['articulo']?['nombre_articulo'] ?? 'Insumo';
                            final numLote = m['lote']?['numero_lote'] ?? 'N/A';

                            Color movColor = _primary;
                            if (tipoMov == 'Entrada') movColor = _green;
                            if (tipoMov == 'Descarte') movColor = _red;
                            if (tipoMov == 'Despacho') movColor = _teal;

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: movColor.withValues(alpha: 0.15),
                                foregroundColor: movColor,
                                child: Icon(
                                  tipoMov == 'Entrada'
                                      ? Icons.arrow_downward
                                      : (tipoMov == 'Descarte' ? Icons.delete_forever : Icons.arrow_upward),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: movColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      tipoMov.toUpperCase(),
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: movColor),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '$artNombre (Lote: $numLote)',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                  ),
                                  Text(
                                    '${tipoMov == 'Entrada' ? '+' : '-'}$cant',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: movColor,
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text('Fecha: $fMov  ·  $just', style: const TextStyle(fontSize: 12)),
                                  if (numActa != null)
                                    Text('N° Acta Oficial: $numActa', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _red)),
                                ],
                              ),
                              trailing: (tipoMov == 'Descarte' && idMov > 0)
                                  ? OutlinedButton.icon(
                                      onPressed: () async {
                                        final url = await _apiService.getNotaSalidaUrl(idMov);
                                        launchUrl(Uri.parse(url));
                                      },
                                      icon: const Icon(Icons.picture_as_pdf, size: 16, color: _red),
                                      label: const Text('Acta PDF', style: TextStyle(fontSize: 12, color: _red)),
                                    )
                                  : null,
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TAB 4: PROVEEDORES
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildProveedoresTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Directorio de Proveedores y Despachos MPPS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ElevatedButton.icon(
                onPressed: _showNuevoProveedorDialog,
                icon: const Icon(Icons.add_business, color: Colors.white),
                label: const Text('Nuevo Proveedor', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: _primary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _proveedores.isEmpty
                ? const Center(child: Text('No hay proveedores registrados'))
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 380,
                      mainAxisExtent: 140,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: _proveedores.length,
                    itemBuilder: (context, index) {
                      final prov = _proveedores[index];
                      final nombre = prov['nombre_proveedor'] ?? 'N/A';
                      final rif = prov['rif'] ?? 'Sin RIF';
                      final tlf = prov['telefono'] ?? 'Sin teléfono';
                      final dir = prov['direccion'] ?? 'Sin dirección';

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: _primary.withValues(alpha: 0.1),
                                    foregroundColor: _primary,
                                    child: const Icon(Icons.local_shipping, size: 18),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      nombre,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Text('RIF / Código: $rif', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                              Text('Teléfono: $tlf', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                              Text('Dirección: $dir', style: TextStyle(fontSize: 11, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showNuevoProveedorDialog() {
    final formKey = GlobalKey<FormState>();
    final nombreCtrl = TextEditingController();
    final rifCtrl = TextEditingController();
    final tlfCtrl = TextEditingController();
    final dirCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Registrar Proveedor / Distribuidor'),
        content: SizedBox(
          width: 440,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nombreCtrl,
                    decoration: const InputDecoration(labelText: 'Nombre del Proveedor / Ente *', border: OutlineInputBorder()),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: rifCtrl,
                    decoration: const InputDecoration(labelText: 'RIF / Código Institucional', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: tlfCtrl,
                    decoration: const InputDecoration(labelText: 'Teléfono de Contacto', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: dirCtrl,
                    decoration: const InputDecoration(labelText: 'Dirección / Ubicación', border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final nav = Navigator.of(ctx);
              final res = await _apiService.registrarProveedor(
                nombreProveedor: nombreCtrl.text.trim(),
                rif: rifCtrl.text.trim().isEmpty ? null : rifCtrl.text.trim(),
                telefono: tlfCtrl.text.trim().isEmpty ? null : tlfCtrl.text.trim(),
                direccion: dirCtrl.text.trim().isEmpty ? null : dirCtrl.text.trim(),
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res['message'] ?? 'Proveedor registrado'),
                    backgroundColor: res['success'] == true ? _green : _red,
                  ),
                );
                if (res['success'] == true) {
                  nav.pop();
                  _fetchData();
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // HELPERS VISUALES
  // ───────────────────────────────────────────────────────────────────────────

  Color _getTipoColor(String tipo) {
    switch (tipo) {
      case 'Vacuna':
        return _green;
      case 'Medicamento':
        return _primaryLight;
      case 'Equipo':
        return _amber;
      default:
        return _teal;
    }
  }

  IconData _getTipoIcon(String tipo) {
    switch (tipo) {
      case 'Vacuna':
        return Icons.vaccines;
      case 'Medicamento':
        return Icons.medication;
      case 'Equipo':
        return Icons.medical_information;
      default:
        return Icons.inventory_2_outlined;
    }
  }
}

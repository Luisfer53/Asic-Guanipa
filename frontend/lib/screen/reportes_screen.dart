import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:asis_guanipa_frontend/services/api_service.dart';
import 'package:asis_guanipa_frontend/storage/jwt_token.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

// ─────────────────────────────────────────────────────────────────
// MODELO
// ─────────────────────────────────────────────────────────────────
class _TipoReporte {
  final String id;
  final String titulo;
  final String descripcion;
  final IconData icono;
  final Color color;
  final List<String> configs;

  _TipoReporte(
    this.id,
    this.titulo,
    this.descripcion,
    this.icono,
    this.color,
    this.configs,
  );

  @override
  bool operator ==(Object other) => other is _TipoReporte && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

// ─────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────
class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  final ApiService _api = ApiService();

  static const _primary = Color(0xFF1B6FE8);
  static const _bg = Color(0xFFF8FAFC);

  // Lista de tipos de reporte
  late final List<_TipoReporte> _tipos;

  _TipoReporte? _tipoSel;

  // Filtros
  DateTime _fecha = DateTime.now();
  String _centro = 'Todos';
  String _sector = 'Todos';
  int _semana = _calcSemana();
  String _mes = _calcMes();
  int _ano = DateTime.now().year;

  List<String> _centrosNombres = ['Todos'];
  int? _jornadaSelId;
  String _mesOperativo = 'Todos';
  List<Map<String, dynamic>> _jornadasLista = [];

  bool _loadingPreview = false;
  bool _previewListo = false;
  Map<String, dynamic>? _previewData;

  static const _meses = [
    'ENERO',
    'FEBRERO',
    'MARZO',
    'ABRIL',
    'MAYO',
    'JUNIO',
    'JULIO',
    'AGOSTO',
    'SEPTIEMBRE',
    'OCTUBRE',
    'NOVIEMBRE',
    'DICIEMBRE',
  ];

  static const _sectores = [
    'Todos',
    'Sector Centro',
    'Sector Vista Al Sol',
    'Sector La Floresta',
    'Sector San José',
    'Sector Guanipa Norte',
  ];

  static int _calcSemana() {
    final n = DateTime.now();
    return ((n.difference(DateTime(n.year, 1, 1)).inDays) / 7).ceil().clamp(
      1,
      52,
    );
  }

  static String _calcMes() {
    const m = [
      'ENERO',
      'FEBRERO',
      'MARZO',
      'ABRIL',
      'MAYO',
      'JUNIO',
      'JULIO',
      'AGOSTO',
      'SEPTIEMBRE',
      'OCTUBRE',
      'NOVIEMBRE',
      'DICIEMBRE',
    ];
    return m[DateTime.now().month - 1];
  }

  @override
  void initState() {
    super.initState();
    _tipos = [
      _TipoReporte(
        'diario',
        'Reporte Diario Nominal',
        'Listado paciente a paciente con diagnóstico, edad, sexo y dirección.',
        Icons.assignment_rounded,
        const Color(0xFF1565C0),
        ['fecha', 'centro', 'sector'],
      ),
      _TipoReporte(
        'semanal',
        'Rutina Semanal ASIC Guanipa (SE)',
        'Vacunación intramural y extramural desglosada por biológico y edad.',
        Icons.vaccines_rounded,
        const Color(0xFF2E7D32),
        ['semana', 'ano'],
      ),
      _TipoReporte(
        'mensual',
        'Rutina Mensual ASIC Guanipa',
        'Coberturas mensuales, puestos notificantes y total de dosis administradas.',
        Icons.calendar_month_rounded,
        const Color(0xFF6A1B9A),
        ['mes', 'ano'],
      ),
      _TipoReporte(
        'inventario',
        'Almacén e Inventario',
        'Stock actual, vencimientos y alertas de todos los insumos y medicamentos.',
        Icons.inventory_2_rounded,
        const Color(0xFFE65100),
        [],
      ),
      _TipoReporte(
        'operativos',
        'Jornadas y Operativos de Salud',
        'Detalle de jornadas médicas, fechas de inicio/fin y atenciones en campo.',
        Icons.event_available_rounded,
        const Color(0xFF00838F),
        ['jornada', 'mes', 'ano'],
      ),
    ];
    _cargarCentros();
    _cargarOperativosLista();
  }

  Future<void> _cargarOperativosLista() async {
    try {
      final r = await _api.getOperativos();
      if (r['success'] == true && mounted) {
        final List list = r['data'] is List ? r['data'] : [];
        setState(() {
          _jornadasLista = list
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error cargando lista de jornadas: $e');
    }
  }

  Future<void> _cargarCentros() async {
    try {
      final r = await _api.getCentrosSalud();
      if (r['success'] == true && mounted) {
        final List list = r['data'] is List ? r['data'] : [];
        final Set<String> nombres = {'Todos'};
        for (var item in list) {
          if (item is Map && item['nombre_centro'] != null) {
            final str = item['nombre_centro'].toString().trim();
            if (str.isNotEmpty) nombres.add(str);
          }
        }
        setState(() {
          _centrosNombres = nombres.toList();
        });
      }
    } catch (e) {
      debugPrint('Error cargando centros: $e');
    }
  }

  Future<void> _previsualizar() async {
    if (_tipoSel == null) return;
    setState(() {
      _loadingPreview = true;
      _previewListo = false;
      _previewData = null;
    });
    try {
      switch (_tipoSel!.id) {
        case 'diario':
          final r = await _api.getReportesDaily(
            fecha: _fecha.toIso8601String().split('T')[0],
            centro: _centro == 'Todos' ? null : _centro,
            sector: _sector == 'Todos' ? null : _sector,
          );
          if (r['success'] == true && mounted) {
            setState(() {
              _previewData = Map<String, dynamic>.from(r);
              _previewListo = true;
            });
          } else if (mounted) {
            _err(r['message']?.toString() ?? 'Error al previsualizar');
          }
          break;
        case 'inventario':
          final r = await _api.getInventario();
          if (r['success'] == true && mounted) {
            setState(() {
              _previewData = Map<String, dynamic>.from(r);
              _previewListo = true;
            });
          } else if (mounted) {
            _err(r['message']?.toString() ?? 'Error en inventario');
          }
          break;
        case 'semanal':
          if (mounted) {
            setState(() {
              _previewData = {
                'resumen':
                    'Rutina Semanal SE-${_semana.toString().padLeft(2, "0")} / Año $_ano',
                'info':
                    'El Excel incluirá vacunaciones intramurales y extramurales desglosadas por biológico (BCG, Hepatitis B, Pentavalente, IPV, BOPV, SRP/SR, Fiebre Amarilla, Toxoide) y grupos de edad para la SE-$_semana del año $_ano.',
                'columnas': [
                  'BCG',
                  'Hepatitis B',
                  'Pentavalente',
                  'IPV',
                  'BOPV',
                  'SRP/SR',
                  'Fiebre Amarilla',
                  'Toxoide',
                  'Grupos de Edad',
                ],
              };
              _previewListo = true;
            });
          }
          break;
        case 'mensual':
          if (mounted) {
            setState(() {
              _previewData = {
                'resumen': 'Rutina Mensual - $_mes $_ano',
                'info':
                    'El Excel consolidará puestos activos, puestos notificantes, nacidos vivos y total de dosis por biológico para $_mes $_ano.',
                'columnas': [
                  'Puestos Activos',
                  'Puestos Notificantes',
                  'Nacidos Vivos',
                  'BCG',
                  'Hepatitis B',
                  'Pentavalente',
                  'Polio Oral',
                  'Neumococo',
                  'Influenza',
                  'SRP/SR',
                  'VPH',
                  'Toxoide',
                  'Coberturas',
                ],
              };
              _previewListo = true;
            });
          }
          break;
        case 'operativos':
          final r = await _api.getOperativos();
          if (r['success'] == true && mounted) {
            List<dynamic> data = r['data'] is List
                ? List<dynamic>.from(r['data'])
                : [];
            // Filtrar por jornada individual si está seleccionada
            if (_jornadaSelId != null) {
              data = data
                  .where(
                    (item) =>
                        item is Map && item['id_operativo'] == _jornadaSelId,
                  )
                  .toList();
            }
            // Filtrar por mes si está seleccionado
            if (_mesOperativo != 'Todos') {
              final int mesIdx = _meses.indexOf(_mesOperativo) + 1;
              data = data.where((item) {
                if (item is! Map || item['fecha_operativo'] == null) {
                  return false;
                }
                final DateTime? d = DateTime.tryParse(
                  item['fecha_operativo'].toString(),
                );
                return d != null && d.month == mesIdx && d.year == _ano;
              }).toList();
            }
            setState(() {
              _previewData = {'success': true, 'data': data};
              _previewListo = true;
            });
          } else if (mounted) {
            _err(r['message']?.toString() ?? 'Error al obtener jornadas');
          }
          break;
      }
    } catch (e) {
      if (mounted) _err('Error de conexión: $e');
    }
    if (mounted) setState(() => _loadingPreview = false);
  }

  Future<void> _descargar() async {
    if (_tipoSel == null) return;
    final token = await getToken();
    if (token == null) {
      _err('Sesión expirada.');
      return;
    }

    String url;
    switch (_tipoSel!.id) {
      case 'diario':
        url = _api.getReporteDiarioExcelUrl(
          fecha: _fecha.toIso8601String().split('T')[0],
          centro: _centro == 'Todos' ? null : _centro,
          sector: _sector == 'Todos' ? null : _sector,
        );
        break;
      case 'semanal':
        url = _api.getReporteSemanalExcelUrl(semana: _semana, ano: _ano);
        break;
      case 'mensual':
        url = _api.getReporteMensualExcelUrl(mes: _mes, ano: _ano);
        break;
      case 'inventario':
        url = _api.getReporteInventarioExcelUrl();
        break;
      case 'operativos':
        url = _api.getReporteOperativosExcelUrl(
          idOperativo: _jornadaSelId,
          mes: _mesOperativo == 'Todos' ? null : _mesOperativo,
          ano: _ano,
        );
        break;
      default:
        return;
    }

    final sep = url.contains('?') ? '&' : '?';
    final fullUrl = '$url${sep}token=$token';

    if (kIsWeb) {
      // En web: abrir directamente en nueva pestaña
      final uri = Uri.parse(fullUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        _ok('Descarga iniciada: ${_tipoSel!.titulo}');
      } else {
        _err('No se pudo abrir el enlace de descarga.');
      }
    } else {
      // En Android: descargar con http y abrir con open_file
      try {
        _ok('Descargando ${_tipoSel!.titulo}...');
        final response = await http.get(
          Uri.parse(fullUrl),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (response.statusCode == 200) {
          final dir = await getTemporaryDirectory();
          final fileName =
              'reporte_${_tipoSel!.id}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
          final file = File('${dir.path}/$fileName');
          await file.writeAsBytes(response.bodyBytes);
          final result = await OpenFile.open(file.path);
          if (result.type != ResultType.done) {
            _err('No se pudo abrir el archivo. Instala un visor de Excel.');
          } else {
            _ok('Reporte abierto: ${_tipoSel!.titulo}');
          }
        } else {
          _err('Error al descargar: código ${response.statusCode}');
        }
      } catch (e) {
        _err('Error al descargar: $e');
      }
    }
  }

  void _err(String m) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(m),
      backgroundColor: Colors.red.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );

  void _ok(String m) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(m),
      backgroundColor: Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  // ─────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isSmall = constraints.maxWidth < 500;
          final pad = isSmall ? 12.0 : 20.0;
          return SingleChildScrollView(
            padding: EdgeInsets.all(pad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // PASO 1: SELECCIONAR TIPO DE REPORTE
                _paso(
                  '1',
                  'Seleccionar Tipo de Reporte',
                  Icons.list_alt_rounded,
                  _primary,
                ),
                const SizedBox(height: 12),
                _buildSelector(),
                const SizedBox(height: 24),

                if (_tipoSel != null) ...[
                  // PASO 2: ANALÍTICA DEL REPORTE
                  _paso(
                    '2',
                    'Analítica del Reporte',
                    Icons.analytics_rounded,
                    const Color(0xFF0288D1),
                  ),
                  const SizedBox(height: 12),
                  _buildAnalyticsWidget(),
                  const SizedBox(height: 24),

                  // PASO 3: CONFIGURAR PARÁMETROS Y BOTÓN PREVISUALIZAR
                  _paso(
                    '3',
                    'Configurar & Previsualizar',
                    Icons.tune_rounded,
                    const Color(0xFF6A1B9A),
                  ),
                  const SizedBox(height: 12),
                  _buildConfig(),
                  const SizedBox(height: 14),
                  _btnPreview(),
                  const SizedBox(height: 24),
                ],

                // PASO 4: VISTA PREVIA
                if (_previewListo && _previewData != null) ...[
                  _paso(
                    '4',
                    'Vista Previa Excel',
                    Icons.table_chart_rounded,
                    const Color(0xFF16A34A),
                  ),
                  const SizedBox(height: 12),
                  _buildPreviewTableContainer(),
                  const SizedBox(height: 20),
                  _btnDescargar(),
                  const SizedBox(height: 30),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Row(
        children: [
          Icon(Icons.analytics_rounded, color: Colors.white, size: 24),
          SizedBox(width: 10),
          Flexible(
            child: Text(
              'Reportes & Analítica ASIC Guanipa',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: _primary,
      elevation: 0,
    );
  }

  Widget _paso(String num, String titulo, IconData icon, Color col) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: col, shape: BoxShape.circle),
          child: Center(
            child: Text(
              num,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, color: col, size: 20),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            titulo,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: col,
            ),
          ),
        ),
      ],
    );
  }

  // ── Selector ─────────────────────────────────────────────────────
  Widget _buildSelector() {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            decoration: _deco(
              'Tipo de reporte a generar',
              Icons.description_rounded,
            ),
            initialValue: _tipoSel?.id,
            hint: const Text(
              '-- Elige un tipo de reporte --',
              style: TextStyle(fontSize: 13),
            ),
            items: _tipos
                .map(
                  (t) => DropdownMenuItem<String>(
                    value: t.id,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(t.icono, color: t.color, size: 17),
                        const SizedBox(width: 10),
                        Text(t.titulo, style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() {
              _tipoSel = v == null ? null : _tipos.firstWhere((t) => t.id == v);
              _previewListo = false;
              _previewData = null;
            }),
          ),
          if (_tipoSel != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _tipoSel!.color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _tipoSel!.color.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(_tipoSel!.icono, color: _tipoSel!.color, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _tipoSel!.descripcion,
                      style: TextStyle(fontSize: 12, color: _tipoSel!.color),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Config ───────────────────────────────────────────────────────
  Widget _buildConfig() {
    final cfg = _tipoSel!.configs;
    if (cfg.isEmpty) {
      return _infoBox('Este reporte no requiere parámetros adicionales.');
    }

    final centroValid = _centrosNombres.contains(_centro) ? _centro : 'Todos';

    return _card(
      Column(
        children: [
          if (cfg.contains('fecha')) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Fecha: ${_fmt(_fecha)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _fecha,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (d != null) {
                      setState(() {
                        _fecha = d;
                        _previewListo = false;
                      });
                    }
                  },
                  icon: const Icon(Icons.calendar_month_rounded, size: 16),
                  label: const Text(
                    'Cambiar Fecha',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          if (cfg.contains('centro')) ...[
            DropdownButtonFormField<String>(
              decoration: _deco(
                'Centro de Salud',
                Icons.local_hospital_rounded,
              ),
              initialValue: centroValid,
              items: _centrosNombres
                  .map(
                    (c) => DropdownMenuItem<String>(
                      value: c,
                      child: Text(
                        c == 'Todos' ? 'Todos los Centros' : c,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() {
                _centro = v ?? 'Todos';
                _previewListo = false;
              }),
            ),
            const SizedBox(height: 14),
          ],
          if (cfg.contains('sector')) ...[
            DropdownButtonFormField<String>(
              decoration: _deco('Sector', Icons.map_rounded),
              initialValue: _sectores.contains(_sector) ? _sector : 'Todos',
              items: _sectores
                  .map(
                    (s) => DropdownMenuItem<String>(
                      value: s,
                      child: Text(
                        s == 'Todos' ? 'Todos los Sectores' : s,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() {
                _sector = v ?? 'Todos';
                _previewListo = false;
              }),
            ),
            const SizedBox(height: 14),
          ],
          if (cfg.contains('semana'))
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    decoration: _deco(
                      'Semana Epidemiológica',
                      Icons.calendar_view_week_rounded,
                    ),
                    initialValue: _semana,
                    items: List.generate(52, (i) => i + 1)
                        .map(
                          (s) => DropdownMenuItem<int>(
                            value: s,
                            child: Text(
                              'SE-${s.toString().padLeft(2, "0")}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() {
                      _semana = v ?? _semana;
                      _previewListo = false;
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    decoration: _deco('Año', Icons.today_rounded),
                    initialValue: _ano,
                    items: [2024, 2025, 2026, 2027]
                        .map(
                          (a) => DropdownMenuItem<int>(
                            value: a,
                            child: Text(
                              '$a',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() {
                      _ano = v ?? _ano;
                      _previewListo = false;
                    }),
                  ),
                ),
              ],
            ),
          if (cfg.contains('jornada')) ...[
            DropdownButtonFormField<int?>(
              decoration: _deco('Seleccionar Jornada', Icons.event_rounded),
              initialValue: _jornadaSelId,
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text(
                    'Todas las Jornadas',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
                ..._jornadasLista.map(
                  (j) => DropdownMenuItem<int?>(
                    value: j['id_operativo'] as int?,
                    child: Text(
                      '${j['nombre_operativo'] ?? 'Jornada'} (${j['fecha_operativo'] ?? ''})',
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (v) => setState(() {
                _jornadaSelId = v;
                _previewListo = false;
              }),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: _deco(
                      'Mes (Opcional)',
                      Icons.calendar_month_rounded,
                    ),
                    initialValue: _mesOperativo,
                    items: ['Todos', ..._meses]
                        .map(
                          (m) => DropdownMenuItem<String>(
                            value: m,
                            child: Text(
                              m == 'Todos' ? 'Todos los Meses' : m,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() {
                      _mesOperativo = v ?? 'Todos';
                      _previewListo = false;
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    decoration: _deco('Año', Icons.today_rounded),
                    initialValue: _ano,
                    items: [2024, 2025, 2026, 2027]
                        .map(
                          (a) => DropdownMenuItem<int>(
                            value: a,
                            child: Text(
                              '$a',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() {
                      _ano = v ?? _ano;
                      _previewListo = false;
                    }),
                  ),
                ),
              ],
            ),
          ],
          if (cfg.contains('mes') && !cfg.contains('jornada'))
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: _deco('Mes', Icons.calendar_month_rounded),
                    initialValue: _meses.contains(_mes) ? _mes : _meses.first,
                    items: _meses
                        .map(
                          (m) => DropdownMenuItem<String>(
                            value: m,
                            child: Text(
                              m,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() {
                      _mes = v ?? _mes;
                      _previewListo = false;
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    decoration: _deco('Año', Icons.today_rounded),
                    initialValue: _ano,
                    items: [2024, 2025, 2026, 2027]
                        .map(
                          (a) => DropdownMenuItem<int>(
                            value: a,
                            child: Text(
                              '$a',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() {
                      _ano = v ?? _ano;
                      _previewListo = false;
                    }),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ── WIDGETS DE ANALÍTICA PERSONALIZADOS (Se muestran al seleccionar el reporte) ───
  Widget _buildAnalyticsWidget() {
    if (_tipoSel == null) return const SizedBox.shrink();

    switch (_tipoSel!.id) {
      case 'diario':
        return _analyticsDiario();
      case 'semanal':
        return _analyticsSemanal();
      case 'mensual':
        return _analyticsMensual();
      case 'inventario':
        return _analyticsInventario();
      case 'operativos':
        return _analyticsOperativos();
      default:
        return const SizedBox.shrink();
    }
  }

  // ── 1. Analítica para Reporte Diario ────────────────────────────
  Widget _analyticsDiario() {
    final stats = _previewData?['stats'] is Map
        ? _previewData!['stats'] as Map
        : {};
    final int total = (stats['total'] is num)
        ? (stats['total'] as num).toInt()
        : 0;
    final int hombres = (stats['hombres'] is num)
        ? (stats['hombres'] as num).toInt()
        : 0;
    final int mujeres = (stats['mujeres'] is num)
        ? (stats['mujeres'] as num).toInt()
        : 0;
    final int menores = (stats['menores'] is num)
        ? (stats['menores'] as num).toInt()
        : 0;
    final int mayores = (stats['mayores'] is num)
        ? (stats['mayores'] as num).toInt()
        : 0;

    final double pctMujeres = total > 0 ? (mujeres / total) : 0.5;
    final double pctHombres = total > 0 ? (hombres / total) : 0.5;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.badge_rounded,
                  color: _primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Analítica Demográfica y Morbilidad Diaria',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                    Text(
                      'Desglose preliminar de pacientes atendidos según los filtros seleccionados',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _kpiGrid([
            _kpiCard(
              'Atenciones Hoy',
              total > 0 ? '$total' : 'Listo',
              'Pacientes registrados',
              _primary,
              Icons.people_alt_rounded,
            ),
            _kpiCard(
              'Distribución Género',
              total > 0
                  ? '${(pctMujeres * 100).toStringAsFixed(0)}% ♀ / ${(pctHombres * 100).toStringAsFixed(0)}% ♂'
                  : 'Femenino / Masc.',
              '$mujeres Mujeres · $hombres Hombres',
              Colors.pink.shade700,
              Icons.pie_chart_rounded,
            ),
            _kpiCard(
              'Población Vulnerable',
              total > 0 ? '$menores <18 | $mayores ≥60' : '<18 & ≥60',
              'Menores & Adultos Mayores',
              Colors.teal.shade700,
              Icons.health_and_safety_rounded,
            ),
          ]),
          if (total > 0) ...[
            const SizedBox(height: 16),
            const Text(
              'Proporción Femenina vs Masculina:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 12,
                child: Row(
                  children: [
                    Expanded(
                      flex: (pctMujeres * 100).round().clamp(1, 99),
                      child: Container(color: Colors.pink.shade400),
                    ),
                    Expanded(
                      flex: (pctHombres * 100).round().clamp(1, 99),
                      child: Container(color: Colors.indigo.shade400),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    '♀ Mujeres: $mujeres (${(pctMujeres * 100).toStringAsFixed(1)}%)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.pink.shade700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '♂ Hombres: $hombres (${(pctHombres * 100).toStringAsFixed(1)}%)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.indigo.shade700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── 2. Analítica para Rutina Semanal ─────────────────────────────
  Widget _analyticsSemanal() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.vaccines_rounded,
                  color: Color(0xFF16A34A),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Analítica Epidemiológica Semanal (SE-${_semana.toString().padLeft(2, '0')})',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: Color(0xFF065F46),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                    Text(
                      'Monitoreo de esquemas de inmunización intramural y jornadas extramurales',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF047857),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _kpiGrid([
            _kpiCard(
              'Período Epidemiológico',
              'SE-${_semana.toString().padLeft(2, '0')}',
              'Año $_ano',
              const Color(0xFF16A34A),
              Icons.calendar_view_week_rounded,
            ),
            _kpiCard(
              'Biológicos Monitoreados',
              '8 Esquemas',
              'BCG, Polio, Penta, SRP...',
              Colors.teal.shade800,
              Icons.medication_liquid_rounded,
            ),
            _kpiCard(
              'Cobertura SE',
              '94.2%',
              'Estimado territorial',
              Colors.amber.shade900,
              Icons.verified_rounded,
            ),
          ]),
          const SizedBox(height: 16),
          const Text(
            'Cobertura de Inmunización Estimada para la Semana:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF065F46),
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: const LinearProgressIndicator(
              value: 0.942,
              minHeight: 12,
              backgroundColor: Color(0xFFDCFCE7),
              color: Color(0xFF16A34A),
            ),
          ),
        ],
      ),
    );
  }

  // ── 3. Analítica para Rutina Mensual ─────────────────────────────
  Widget _analyticsMensual() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF5FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9D5FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF9333EA).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: Color(0xFF9333EA),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Analítica Consolidada Mensual ($_mes $_ano)',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: Color(0xFF6B21A8),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                    Text(
                      'Consolidado de cobertura general de salud pública y nacidos vivos asistidos',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7E22CE),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _kpiGrid([
            _kpiCard(
              'Mes Consolidado',
              _mes,
              'Año $_ano',
              const Color(0xFF9333EA),
              Icons.calendar_today_rounded,
            ),
            _kpiCard(
              'Puestos Notificantes',
              '12 / 12 Centros',
              '100% Notificación a tiempo',
              Colors.indigo.shade800,
              Icons.domain_rounded,
            ),
            _kpiCard(
              'Cumplimiento Plan',
              '98.5%',
              'Cobertura mensual ASIC',
              Colors.deepPurple.shade800,
              Icons.task_alt_rounded,
            ),
          ]),
          const SizedBox(height: 16),
          const Text(
            'Nivel de Notificación Mensual Consolidada:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B21A8),
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: const LinearProgressIndicator(
              value: 0.985,
              minHeight: 12,
              backgroundColor: Color(0xFFF3E8FF),
              color: Color(0xFF9333EA),
            ),
          ),
        ],
      ),
    );
  }

  // ── 4. Analítica para Almacén e Inventario ───────────────────────
  Widget _analyticsInventario() {
    final rows = _previewData?['data'] is List
        ? List<dynamic>.from(_previewData!['data'])
        : [];
    final int totalLotes = rows.length;
    int stockOptimo = 0;
    int stockBajo = 0;

    for (var item in rows) {
      if (item is Map) {
        final stock = (item['stock_actual'] is num)
            ? (item['stock_actual'] as num).toInt()
            : 0;
        if (stock < 20) {
          stockBajo++;
        } else {
          stockOptimo++;
        }
      }
    }

    final double pctOptimo = totalLotes > 0 ? (stockOptimo / totalLotes) : 1.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAF0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEA580C).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.inventory_2_rounded,
                  color: Color(0xFFEA580C),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Analítica de Almacén e Inventario de Insumos',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: Color(0xFF9A3412),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                    Text(
                      'Evaluación del nivel de stock, lotes activos y alertas de reabastecimiento',
                      style: TextStyle(fontSize: 12, color: Color(0xFFC2410C)),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _kpiGrid([
            _kpiCard(
              'Lotes Registrados',
              totalLotes > 0 ? '$totalLotes Lotes' : 'Depósito',
              'Artículos en depósito',
              const Color(0xFFEA580C),
              Icons.inventory_rounded,
            ),
            _kpiCard(
              'Stock Óptimo',
              totalLotes > 0 ? '$stockOptimo Lotes' : 'Óptimo',
              '> 20 unidades disponibles',
              Colors.green.shade800,
              Icons.check_box_rounded,
            ),
            _kpiCard(
              'Alertas Reabastecimiento',
              totalLotes > 0 ? '$stockBajo Lotes' : 'Alertas',
              'Stock crítico (< 20 un)',
              Colors.red.shade800,
              Icons.warning_amber_rounded,
            ),
          ]),
          const SizedBox(height: 16),
          const Text(
            'Salud del Inventario (% Lotes Óptimos):',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF9A3412),
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: pctOptimo,
              minHeight: 12,
              backgroundColor: const Color(0xFFFEE2E2),
              color: stockBajo > 0
                  ? Colors.amber.shade700
                  : Colors.green.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // ── KPI grid responsivo (3 cols en ancho, 2 cols en móvil) ──────
  Widget _kpiGrid(List<Widget> cards) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final isSmall = constraints.maxWidth < 480;
        if (isSmall) {
          final w = (constraints.maxWidth - 8) / 2;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: cards.map((c) => SizedBox(width: w, child: c)).toList(),
          );
        }
        return Row(
          children:
              cards
                  .expand(
                    (c) => [Expanded(child: c), const SizedBox(width: 10)],
                  )
                  .toList()
                ..removeLast(),
        );
      },
    );
  }

  Widget _kpiCard(
    String title,
    String mainVal,
    String subVal,
    Color c,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: c),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            mainVal,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: c,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
          const SizedBox(height: 2),
          Text(
            subVal,
            style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  // ── Contenedor de la Vista Previa de la Tabla Excel ───────────────
  Widget _buildPreviewTableContainer() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _tipoSel!.color.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _tipoSel!.color.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(_tipoSel!.icono, color: _tipoSel!.color, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Vista Previa de la Tabla Excel: ${_tipoSel!.titulo}',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: _tipoSel!.color,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: Colors.green,
                        size: 14,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Tabla lista para Excel',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildPreviewBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewBody() {
    if (_tipoSel!.id == 'diario') {
      return _previewDiario();
    } else if (_tipoSel!.id == 'inventario') {
      return _previewInventario();
    } else if (_tipoSel!.id == 'operativos') {
      return _previewOperativos();
    } else {
      return _previewInfo();
    }
  }

  Widget _previewDiario() {
    final stats = _previewData?['stats'] is Map
        ? _previewData!['stats'] as Map
        : {};
    final rows = _previewData?['data'] is List
        ? List<dynamic>.from(_previewData!['data'])
        : [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fecha: ${_fmt(_fecha)}  •  Centro: $_centro  •  Sector: $_sector',
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _chip(
              'Total',
              '${stats['total'] ?? 0}',
              _primary,
              Icons.people_rounded,
            ),
            _chip(
              'Hombres',
              '${stats['hombres'] ?? 0}',
              Colors.indigo,
              Icons.male_rounded,
            ),
            _chip(
              'Mujeres',
              '${stats['mujeres'] ?? 0}',
              Colors.pink,
              Icons.female_rounded,
            ),
            _chip(
              '<18',
              '${stats['menores'] ?? 0}',
              Colors.teal,
              Icons.child_care_rounded,
            ),
            _chip(
              '≥60',
              '${stats['mayores'] ?? 0}',
              Colors.orange,
              Icons.elderly_rounded,
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (rows.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Sin atenciones para los filtros seleccionados.',
                style: TextStyle(color: Color(0xFF94A3B8)),
              ),
            ),
          )
        else ...[
          const Text(
            'Primeros registros que se incluirán en el Excel:',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          _tabla(
            cols: const ['Nombre', 'Cédula', 'Edad', 'Sexo', 'Diagnóstico'],
            rows: rows.take(8).map((item) {
              if (item is! Map) return ['-', '-', '-', '-', '-'];
              final pac = item['paciente'] is Map
                  ? item['paciente'] as Map
                  : {};
              final p = pac['persona'] is Map ? pac['persona'] as Map : {};
              return [
                '${p['nombre1'] ?? ''} ${p['apellido1'] ?? ''}'.trim(),
                p['cedula_identidad']?.toString() ?? 'S/C',
                _edad(p['fecha_nacimiento']?.toString()),
                p['sexo'] == 'M' ? '♂ Masc.' : '♀ Fem.',
                _trunca(item['diagnostico_general']?.toString() ?? 'N/A', 30),
              ];
            }).toList(),
          ),
          if (rows.length > 8)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '... y ${rows.length - 8} registros más en el Excel',
                style: const TextStyle(
                  color: Color(0xFF78909C),
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _previewInventario() {
    final rows = _previewData?['data'] is List
        ? List<dynamic>.from(_previewData!['data'])
        : [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lotes en inventario: ${rows.length}',
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Sin lotes registrados.',
                style: TextStyle(color: Color(0xFF94A3B8)),
              ),
            ),
          )
        else
          _tabla(
            cols: const ['Artículo', 'Lote', 'Stock', 'Vencimiento'],
            rows: rows.take(8).map((item) {
              if (item is! Map) return ['-', '-', '-', '-'];
              final art = item['articulo'] is Map
                  ? item['articulo'] as Map
                  : {};
              return [
                art['nombre_articulo']?.toString() ?? 'N/A',
                item['numero_lote']?.toString() ?? 'N/A',
                item['stock_actual']?.toString() ?? '0',
                item['fecha_vencimiento']?.toString() ?? 'N/A',
              ];
            }).toList(),
          ),
      ],
    );
  }

  // ── Analítica Jornadas y Operativos ─────────────────────────────
  Widget _analyticsOperativos() {
    final rows = _previewData?['data'] is List
        ? List<dynamic>.from(_previewData!['data'])
        : <dynamic>[];
    final int totalJornadas = rows.length;

    int totalAtendidos = 0;
    int hombres = 0;
    int mujeres = 0;
    int menor1 = 0;
    int e1_4 = 0;
    int e5_14 = 0;
    int e15_59 = 0;
    int mayor60 = 0;
    int dosisAplicadasCount = 0;
    int insumosEntregadosCount = 0;

    for (var op in rows) {
      if (op is Map && op['atenciones'] is List) {
        final atenciones = op['atenciones'] as List;
        totalAtendidos += atenciones.length;
        for (var at in atenciones) {
          if (at is Map) {
            final p =
                at['paciente'] is Map &&
                    (at['paciente'] as Map)['persona'] is Map
                ? (at['paciente'] as Map)['persona'] as Map
                : {};
            final sexo = (p['sexo'] ?? '').toString().toUpperCase();
            if (sexo == 'M') hombres++;
            if (sexo == 'F') mujeres++;

            if (p['fecha_nacimiento'] != null) {
              final DateTime? nac = DateTime.tryParse(
                p['fecha_nacimiento'].toString(),
              );
              if (nac != null) {
                final hoy = DateTime.now();
                int edad = hoy.year - nac.year;
                if (hoy.month < nac.month ||
                    (hoy.month == nac.month && hoy.day < nac.day)) {
                  edad--;
                }
                if (edad < 1) {
                  menor1++;
                } else if (edad >= 1 && edad <= 4)
                  e1_4++;
                else if (edad >= 5 && edad <= 14)
                  e5_14++;
                else if (edad >= 15 && edad <= 59)
                  e15_59++;
                else if (edad >= 60)
                  mayor60++;
              }
            }

            if (at['vacunaciones'] is List) {
              dosisAplicadasCount += (at['vacunaciones'] as List).length;
            }
            if (at['consumos'] is List) {
              for (var c in at['consumos'] as List) {
                if (c is Map) {
                  final cant = (c['cantidad_usada'] is num)
                      ? (c['cantidad_usada'] as num).toInt()
                      : 1;
                  insumosEntregadosCount += cant;
                }
              }
            }
          }
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFECFEFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF67E8F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00838F).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.event_available_rounded,
                  color: Color(0xFF00838F),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Analítica Demográfica y Recursos de Jornadas',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: Color(0xFF164E63),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                    Text(
                      'Desglose por grupos de edad, sexo, dosis aplicadas e insumos entregados',
                      style: TextStyle(fontSize: 12, color: Color(0xFF0E7490)),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _kpiGrid([
            _kpiCard(
              'Total Atendidos',
              '$totalAtendidos Pacientes',
              'En $totalJornadas jornada(s)',
              const Color(0xFF00838F),
              Icons.people_alt_rounded,
            ),
            _kpiCard(
              'Dosis & Insumos',
              '$dosisAplicadasCount Dosis Aplicadas · $insumosEntregadosCount Insumos Entregados',
              'Total de intervenciones',
              Colors.green.shade700,
              Icons.vaccines_rounded,
            ),
            _kpiCard(
              'Distribución Género',
              '$hombres ♂ Hombres | $mujeres ♀ Mujeres',
              'Total según registro',
              Colors.indigo.shade700,
              Icons.pie_chart_rounded,
            ),
            _kpiCard(
              'Rangos de Edad',
              '<1a: $menor1  |  1-4a: $e1_4  |  5-14a: $e5_14  |  15-59a: $e15_59  |  ≥60a: $mayor60',
              'Consolidado por grupos etarios',
              Colors.teal.shade700,
              Icons.health_and_safety_rounded,
            ),
          ]),
        ],
      ),
    );
  }

  // ── Vista previa tabla Operativos ────────────────────────────────
  Widget _previewOperativos() {
    final rows = _previewData?['data'] is List
        ? List<dynamic>.from(_previewData!['data'])
        : <dynamic>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Jornadas analizadas: ${rows.length}',
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Sin jornadas registradas para los filtros seleccionados.',
                style: TextStyle(color: Color(0xFF94A3B8)),
              ),
            ),
          )
        else
          _tabla(
            cols: const [
              'Jornada',
              'Fecha',
              'Atendidos',
              'Dosis Aplicadas',
              'Insumos Entregados',
              '♂ Homb.',
              '♀ Muj.',
              '<1a',
              '1-4a',
              '5-14a',
              '15-59a',
              '≥60a',
            ],
            rows: rows.map((item) {
              if (item is! Map) {
                return [
                  '-',
                  '-',
                  '-',
                  '-',
                  '-',
                  '-',
                  '-',
                  '-',
                  '-',
                  '-',
                  '-',
                  '-',
                ];
              }
              final atenciones = item['atenciones'] is List
                  ? item['atenciones'] as List
                  : [];
              int h = 0,
                  m = 0,
                  menor1 = 0,
                  e1_4 = 0,
                  e5_14 = 0,
                  e15_59 = 0,
                  mayor60 = 0;
              int dosisAplicadas = 0;
              int insumosEntregados = 0;

              for (var at in atenciones) {
                if (at is Map) {
                  final p =
                      at['paciente'] is Map &&
                          (at['paciente'] as Map)['persona'] is Map
                      ? (at['paciente'] as Map)['persona'] as Map
                      : {};
                  final sexo = (p['sexo'] ?? '').toString().toUpperCase();
                  if (sexo == 'M') h++;
                  if (sexo == 'F') m++;

                  if (p['fecha_nacimiento'] != null) {
                    final DateTime? nac = DateTime.tryParse(
                      p['fecha_nacimiento'].toString(),
                    );
                    if (nac != null) {
                      final hoy = DateTime.now();
                      int edad = hoy.year - nac.year;
                      if (hoy.month < nac.month ||
                          (hoy.month == nac.month && hoy.day < nac.day)) {
                        edad--;
                      }
                      if (edad < 1) {
                        menor1++;
                      } else if (edad >= 1 && edad <= 4)
                        e1_4++;
                      else if (edad >= 5 && edad <= 14)
                        e5_14++;
                      else if (edad >= 15 && edad <= 59)
                        e15_59++;
                      else if (edad >= 60)
                        mayor60++;
                    }
                  }

                  if (at['vacunaciones'] is List) {
                    dosisAplicadas += (at['vacunaciones'] as List).length;
                  }
                  if (at['consumos'] is List) {
                    for (var c in at['consumos'] as List) {
                      if (c is Map) {
                        final cant = (c['cantidad_usada'] is num)
                            ? (c['cantidad_usada'] as num).toInt()
                            : 1;
                        insumosEntregados += cant;
                      }
                    }
                  }
                }
              }

              final fechaStr = item['fecha_operativo']?.toString() ?? '';
              String fecha = fechaStr;
              try {
                if (fechaStr.isNotEmpty) {
                  final d = DateTime.parse(fechaStr);
                  fecha =
                      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
                }
              } catch (_) {}

              return [
                item['nombre_operativo']?.toString() ?? 'N/A',
                fecha,
                '${atenciones.length}',
                '$dosisAplicadas',
                '$insumosEntregados',
                '$h',
                '$m',
                '$menor1',
                '$e1_4',
                '$e5_14',
                '$e15_59',
                '$mayor60',
              ];
            }).toList(),
          ),
      ],
    );
  }

  Widget _previewInfo() {
    final cols = _previewData?['columnas'] is List
        ? List<String>.from(_previewData!['columnas'])
        : <String>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _previewData?['resumen']?.toString() ?? '',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF1565C0),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _previewData?['info']?.toString() ?? '',
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
        if (cols.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text(
            'Columnas configuradas en el documento Excel:',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: cols
                .map(
                  (c) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Text(
                      c,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF1565C0),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  // ── Botones ──────────────────────────────────────────────────────
  Widget _btnPreview() => SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      onPressed: _loadingPreview ? null : _previsualizar,
      icon: _loadingPreview
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.preview_rounded, size: 18),
      label: Text(
        _loadingPreview
            ? 'Generando previsualización de tabla Excel...'
            : 'Previsualizar Tabla Excel',
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: _primary,
        side: const BorderSide(color: _primary),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
  );

  Widget _btnDescargar() => SizedBox(
    width: double.infinity,
    child: ElevatedButton.icon(
      onPressed: _descargar,
      icon: const Icon(Icons.download_rounded, size: 20),
      label: const Text(
        'Descargar Reporte Excel',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF16A34A),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    ),
  );

  // ── Helpers ──────────────────────────────────────────────────────
  Widget _card(Widget child) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE2E8F0)),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.03),
          blurRadius: 10,
        ),
      ],
    ),
    padding: const EdgeInsets.all(16),
    child: child,
  );

  Widget _infoBox(String msg) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFFFFBEB),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFFDE68A)),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.info_outline_rounded,
          color: Color(0xFFD97706),
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            msg,
            style: const TextStyle(fontSize: 13, color: Color(0xFF92400E)),
          ),
        ),
      ],
    ),
  );

  Widget _chip(String label, String val, Color c, IconData icon) => Container(
    width: 70,
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
    decoration: BoxDecoration(
      color: c.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: c.withValues(alpha: 0.25)),
    ),
    child: Column(
      children: [
        Icon(icon, color: c, size: 16),
        const SizedBox(height: 3),
        Text(
          val,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: c),
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );

  Widget _tabla({
    required List<String> cols,
    required List<List<String>> rows,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 400),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Container(
                color: const Color(0xFFF1F5F9),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: cols
                      .map(
                        (c) => SizedBox(
                          width: 90,
                          child: Text(
                            c,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              ...rows.map(
                (row) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    children: row
                        .map(
                          (v) => SizedBox(
                            width: 90,
                            child: Text(
                              v,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF475569),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _edad(String? fec) {
    if (fec == null) return 'N/A';
    final d = DateTime.tryParse(fec);
    if (d == null) return 'N/A';
    final n = DateTime.now();
    int a = n.year - d.year;
    if (n.month < d.month || (n.month == d.month && n.day < d.day)) a--;
    return '$a a';
  }

  String _trunca(String s, int max) =>
      s.length > max ? '${s.substring(0, max)}...' : s;

  InputDecoration _deco(String label, IconData icon) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
    prefixIcon: Icon(icon, size: 18, color: const Color(0xFF64748B)),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
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

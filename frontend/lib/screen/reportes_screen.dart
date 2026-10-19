import 'package:flutter/material.dart';
import 'package:asis_guanipa_frontend/services/api_service.dart';
import 'package:asis_guanipa_frontend/components/modulo_app_bar.dart';
import 'package:url_launcher/url_launcher.dart';

class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _api = ApiService();

  // Paleta de colores oficial
  static const _primary = Color(0xFF0D47A1);
  static const _teal = Color(0xFF00897B);
  static const _green = Color(0xFF2E7D32);
  static const _amber = Color(0xFFF57F17);
  static const _red = Color(0xFFC62828);

  // Estado Sala Situacional
  bool _loadingStats = false;
  Map<String, dynamic> _statsGenerales = {
    'totalPacientes': 0,
    'totalAtenciones': 0,
    'totalVacunas': 0,
    'totalCentros': 0,
  };

  // Datos para gráficos de morbilidad y sectores
  List<Map<String, dynamic>> _atencionesRecientes = [];
  Map<String, int> _diagnosticosCount = {};
  Map<String, int> _sectoresCount = {};
  int _hombresCount = 0;
  int _mujeresCount = 0;
  int _menoresCount = 0;
  int _adultosMayoresCount = 0;

  // Estado Generador de Reportes
  String _reporteSeleccionado = 'diario';
  DateTime _fechaReporte = DateTime.now();
  int _semanaReporte = _calcSemana();
  String _mesReporte = _calcMes();
  int _anoReporte = DateTime.now().year;
  String _centroSeleccionado = 'Todos';
  String _sectorSeleccionado = 'Todos';

  List<String> _centrosNombres = ['Todos'];
  List<String> _sectoresNombres = ['Todos'];

  bool _loadingPreview = false;
  List<Map<String, dynamic>> _previewAttentions = [];
  Map<String, dynamic>? _previewStats;

  static const _meses = [
    'ENERO', 'FEBRERO', 'MARZO', 'ABRIL', 'MAYO', 'JUNIO',
    'JULIO', 'AGOSTO', 'SEPTIEMBRE', 'OCTUBRE', 'NOVIEMBRE', 'DICIEMBRE'
  ];

  static int _calcSemana() {
    final now = DateTime.now();
    final firstDayOfYear = DateTime(now.year, 1, 1);
    final days = now.difference(firstDayOfYear).inDays;
    return ((days / 7).ceil()).clamp(1, 52);
  }

  static String _calcMes() {
    return _meses[DateTime.now().month - 1];
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarDatosIniciales();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosIniciales() async {
    setState(() => _loadingStats = true);
    try {
      final results = await Future.wait([
        _api.getReportStats(),
        _api.getReportesDaily(),
        _api.getCentros(),
        _api.getSectores(),
      ]);

      if (mounted) {
        setState(() {
          if (results[0]['success'] == true) {
            _statsGenerales = Map<String, dynamic>.from(results[0]['data'] ?? {});
          }

          if (results[1]['success'] == true) {
            _atencionesRecientes = List<Map<String, dynamic>>.from(results[1]['data'] ?? []);
            _previewAttentions = _atencionesRecientes;
            _previewStats = results[1]['stats'];
            _procesarEstadisticasSalud(_atencionesRecientes);
          }

          if (results[2]['success'] == true) {
            final list = results[2]['data'] as List? ?? [];
            _centrosNombres = ['Todos', ...list.map((c) => (c['nombre_centro'] ?? '').toString()).where((s) => s.isNotEmpty)];
          }

          if (results[3]['success'] == true) {
            final list = results[3]['data'] as List? ?? [];
            _sectoresNombres = ['Todos', ...list.map((s) => (s['nombre_sector'] ?? '').toString()).where((s) => s.isNotEmpty)];
          }
        });
      }
    } catch (e) {
      debugPrint('Error al cargar datos epidemiológicos: $e');
    } finally {
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  void _procesarEstadisticasSalud(List<Map<String, dynamic>> atenciones) {
    _diagnosticosCount.clear();
    _sectoresCount.clear();
    _hombresCount = 0;
    _mujeresCount = 0;
    _menoresCount = 0;
    _adultosMayoresCount = 0;

    for (final att in atenciones) {
      final diag = (att['diagnostico_general'] ?? att['motivo_consulta'] ?? 'Control de Salud').toString();
      _diagnosticosCount[diag] = (_diagnosticosCount[diag] ?? 0) + 1;

      final persona = att['paciente']?['persona'];
      if (persona != null) {
        final sexo = (persona['sexo'] ?? '').toString().toUpperCase();
        if (sexo == 'M') _hombresCount++;
        if (sexo == 'F') _mujeresCount++;

        final fNac = persona['fecha_nacimiento'];
        if (fNac != null) {
          final dob = DateTime.tryParse(fNac.toString());
          if (dob != null) {
            final age = DateTime.now().year - dob.year;
            if (age < 18) _menoresCount++;
            if (age >= 60) _adultosMayoresCount++;
          }
        }

        final direcciones = persona['direcciones'] as List?;
        if (direcciones != null && direcciones.isNotEmpty) {
          final sectorNom = direcciones[0]?['sector']?['nombre_sector'] ?? 'Guanipa Centro';
          _sectoresCount[sectorNom] = (_sectoresCount[sectorNom] ?? 0) + 1;
        }
      }
    }
  }

  Future<void> _ejecutarPrevisualizacion() async {
    setState(() => _loadingPreview = true);
    try {
      final fStr = _fechaReporte.toIso8601String().split('T')[0];
      final res = await _api.getReportesDaily(
        fecha: _reporteSeleccionado == 'diario' ? fStr : null,
        centro: _centroSeleccionado == 'Todos' ? null : _centroSeleccionado,
        sector: _sectorSeleccionado == 'Todos' ? null : _sectorSeleccionado,
      );

      if (mounted && res['success'] == true) {
        setState(() {
          _previewAttentions = List<Map<String, dynamic>>.from(res['data'] ?? []);
          _previewStats = res['stats'];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al previsualizar: $e'), backgroundColor: _red),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingPreview = false);
    }
  }

  void _descargarReporteExcel() async {
    String url = '';
    final fStr = _fechaReporte.toIso8601String().split('T')[0];

    switch (_reporteSeleccionado) {
      case 'diario':
        url = await _api.getReporteDiarioExcelUrl(
          fecha: fStr,
          centro: _centroSeleccionado == 'Todos' ? null : _centroSeleccionado,
          sector: _sectorSeleccionado == 'Todos' ? null : _sectorSeleccionado,
        );
        break;
      case 'semanal':
        url = await _api.getReporteSemanalExcelUrl(semana: _semanaReporte, ano: _anoReporte);
        break;
      case 'mensual':
        url = await _api.getReporteMensualExcelUrl(mes: _mesReporte, ano: _anoReporte);
        break;
      case 'inventario':
        url = await _api.getReporteInventarioExcelUrl();
        break;
      case 'descartes':
        url = await _api.getReporteDescartesExcelUrl();
        break;
      case 'operativos':
        url = await _api.getReporteOperativosExcelUrl(ano: _anoReporte);
        break;
    }

    if (url.isNotEmpty) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✓ Descargando reporte en Excel...'), backgroundColor: _green),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al iniciar la descarga'), backgroundColor: _red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: ModuloAppBar(
        titulo: 'Sala Situacional & Informes Epidemiológicos',
        subtitulo: 'ASIC San José de Guanipa · MPPS Anzoátegui',
        backgroundColor: _primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar Estadísticas',
            onPressed: _cargarDatosIniciales,
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.amber,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.analytics_outlined), text: 'Sala Situacional en Vivo'),
            Tab(icon: Icon(Icons.description_outlined), text: 'Generador de Informes MPPS'),
          ],
        ),
      ),
      body: _loadingStats
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildSalaSituacionalTab(),
                _buildGeneradorReportesTab(),
              ],
            ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TAB 1: SALA SITUACIONAL EN VIVO
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildSalaSituacionalTab() {
    final totalAtenciones = _statsGenerales['totalAtenciones'] ?? 0;
    final totalVacunas = _statsGenerales['totalVacunas'] ?? 0;
    final totalPacientes = _statsGenerales['totalPacientes'] ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ribbon de KPIs
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildKpiCard(
                title: 'Total Pacientes Registrados',
                value: '$totalPacientes',
                subtitle: 'Filiación nominal completa',
                icon: Icons.people_alt,
                color: _primary,
              ),
              _buildKpiCard(
                title: 'Consultas Médicas',
                value: '$totalAtenciones',
                subtitle: 'Triajes y consultas realizadas',
                icon: Icons.medical_services,
                color: _teal,
              ),
              _buildKpiCard(
                title: 'Inmunizaciones Aplicadas',
                value: '$totalVacunas',
                subtitle: 'Dosis administradas',
                icon: Icons.vaccines,
                color: _green,
              ),
              _buildKpiCard(
                title: 'Población Pediátrica (<18)',
                value: '$_menoresCount',
                subtitle: 'Menores de edad atendidos',
                icon: Icons.child_care,
                color: _amber,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Gráficos de Morbilidad y Geo-Salud en Guanipa
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildMorbilidadCard()),
                    const SizedBox(width: 16),
                    Expanded(child: _buildGeoSaludCard()),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildMorbilidadCard(),
                    const SizedBox(height: 16),
                    _buildGeoSaludCard(),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 20),

          // Pirámide Demográfica y Cobertura
          _buildDemografiaCard(),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: color.withValues(alpha: 0.15),
            foregroundColor: color,
            child: Icon(icon, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
                Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMorbilidadCard() {
    final sortedDiags = _diagnosticosCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topDiags = sortedDiags.take(5).toList();
    final maxVal = topDiags.isEmpty ? 1 : topDiags.first.value;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.local_hospital, color: _red, size: 20),
                SizedBox(width: 8),
                Text('Causas de Morbilidad Frecuentes (EPI)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 12),
            if (topDiags.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('No hay diagnósticos suficientes registrados')),
              )
            else
              ...topDiags.map((entry) {
                final ratio = entry.value / maxVal;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                          Text('${entry.value} casos', style: const TextStyle(fontWeight: FontWeight.bold, color: _primary)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: const AlwaysStoppedAnimation<Color>(_primary),
                          minHeight: 8,
                        ),
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

  Widget _buildGeoSaludCard() {
    final sortedSectores = _sectoresCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topSectores = sortedSectores.take(5).toList();
    final maxVal = topSectores.isEmpty ? 1 : topSectores.first.value;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.location_on, color: _teal, size: 20),
                SizedBox(width: 8),
                Text('Geo-Salud: Distribución por Sectores (Guanipa)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 12),
            if (topSectores.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('No hay datos de sectores registrados aún')),
              )
            else
              ...topSectores.map((entry) {
                final ratio = entry.value / maxVal;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                          Text('${entry.value} pacientes', style: const TextStyle(fontWeight: FontWeight.bold, color: _teal)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: const AlwaysStoppedAnimation<Color>(_teal),
                          minHeight: 8,
                        ),
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

  Widget _buildDemografiaCard() {
    final total = _hombresCount + _mujeresCount;
    final pctH = total > 0 ? (_hombresCount / total * 100).toStringAsFixed(1) : '0';
    final pctM = total > 0 ? (_mujeresCount / total * 100).toStringAsFixed(1) : '0';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Perfil Demográfico Atendido', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          child: Icon(Icons.male, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Masculino', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text('$_hombresCount ($pctH%)', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.pink.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.pink,
                          foregroundColor: Colors.white,
                          child: Icon(Icons.female, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Femenino', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text('$_mujeresCount ($pctM%)', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _green.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 18,
                          backgroundColor: _green,
                          foregroundColor: Colors.white,
                          child: Icon(Icons.elderly, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Adultos Mayores (60+)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text('$_adultosMayoresCount pacientes', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TAB 2: GENERADOR DE INFORMES OFICIALES MPPS
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildGeneradorReportesTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Configuración del Reporte
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Parámetros del Informe Oficial', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Tipo de reporte
                      SizedBox(
                        width: 250,
                        child: DropdownButtonFormField<String>(
                          initialValue: _reporteSeleccionado,
                          decoration: const InputDecoration(labelText: 'Tipo de Informe MPPS', border: OutlineInputBorder(), isDense: true),
                          items: const [
                            DropdownMenuItem(value: 'diario', child: Text('📋 Reporte Diario Nominal (EPI)')),
                            DropdownMenuItem(value: 'semanal', child: Text('💉 Rutina Semanal (SE-XX)')),
                            DropdownMenuItem(value: 'mensual', child: Text('📅 Rutina Mensual ASIC')),
                            DropdownMenuItem(value: 'inventario', child: Text('📦 Inventario de Biológicos')),
                            DropdownMenuItem(value: 'descartes', child: Text('🗑️ Descartes Biológicos (RF-10)')),
                            DropdownMenuItem(value: 'operativos', child: Text('🩺 Jornadas Comunitarias')),
                          ],
                          onChanged: (val) => setState(() => _reporteSeleccionado = val ?? 'diario'),
                        ),
                      ),

                      // Filtro Fecha (si es diario)
                      if (_reporteSeleccionado == 'diario')
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _fechaReporte,
                              firstDate: DateTime.now().subtract(const Duration(days: 365)),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) setState(() => _fechaReporte = picked);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.calendar_today, size: 18, color: _primary),
                                const SizedBox(width: 8),
                                Text(
                                  'Fecha: ${_fechaReporte.day.toString().padLeft(2, '0')}/${_fechaReporte.month.toString().padLeft(2, '0')}/${_fechaReporte.year}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Filtro Semana (si es semanal)
                      if (_reporteSeleccionado == 'semanal')
                        SizedBox(
                          width: 180,
                          child: DropdownButtonFormField<int>(
                            initialValue: _semanaReporte,
                            decoration: const InputDecoration(labelText: 'Semana Epidemiológica', border: OutlineInputBorder(), isDense: true),
                            items: List.generate(52, (i) => i + 1).map((s) => DropdownMenuItem(
                              value: s,
                              child: Text('Semana SE-$s'),
                            )).toList(),
                            onChanged: (val) => setState(() => _semanaReporte = val ?? 1),
                          ),
                        ),

                      // Filtro Mes (si es mensual)
                      if (_reporteSeleccionado == 'mensual')
                        SizedBox(
                          width: 170,
                          child: DropdownButtonFormField<String>(
                            initialValue: _mesReporte,
                            decoration: const InputDecoration(labelText: 'Mes', border: OutlineInputBorder(), isDense: true),
                            items: _meses.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                            onChanged: (val) => setState(() => _mesReporte = val ?? 'ENERO'),
                          ),
                        ),

                      // Filtro Centro
                      if (_reporteSeleccionado == 'diario') ...[
                        SizedBox(
                          width: 200,
                          child: DropdownButtonFormField<String>(
                            initialValue: _centroSeleccionado,
                            decoration: const InputDecoration(labelText: 'Centro de Salud', border: OutlineInputBorder(), isDense: true),
                            items: _centrosNombres.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                            onChanged: (val) => setState(() => _centroSeleccionado = val ?? 'Todos'),
                          ),
                        ),
                        SizedBox(
                          width: 200,
                          child: DropdownButtonFormField<String>(
                            initialValue: _sectorSeleccionado,
                            decoration: const InputDecoration(labelText: 'Sector / Comunidad', border: OutlineInputBorder(), isDense: true),
                            items: _sectoresNombres.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                            onChanged: (val) => setState(() => _sectorSeleccionado = val ?? 'Todos'),
                          ),
                        ),
                      ],

                      // Botón Previsualizar
                      ElevatedButton.icon(
                        onPressed: _ejecutarPrevisualizacion,
                        icon: const Icon(Icons.preview_outlined, color: Colors.white),
                        label: const Text('Previsualizar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(backgroundColor: _teal, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                      ),

                      // Botón Descargar Excel Oficial
                      ElevatedButton.icon(
                        onPressed: _descargarReporteExcel,
                        icon: const Icon(Icons.file_download, color: Colors.white),
                        label: const Text('Descargar Excel MPPS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(backgroundColor: _green, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Tabla de Previsualización
          Expanded(
            child: _loadingPreview
                ? const Center(child: CircularProgressIndicator())
                : _previewAttentions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.assignment_outlined, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 8),
                            const Text('Haga clic en "Previsualizar" para consultar los datos del período seleccionado.', style: TextStyle(color: Colors.grey)),
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
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              color: const Color(0xFFF1F5F9),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Previsualización: ${_previewAttentions.length} registros encontrados',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  if (_previewStats != null)
                                    Text(
                                      'M: ${_previewStats!['hombres'] ?? 0}  |  F: ${_previewStats!['mujeres'] ?? 0}  |  <18: ${_previewStats!['menores'] ?? 0}  |  60+: ${_previewStats!['mayores'] ?? 0}',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                                    ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.vertical,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    headingRowHeight: 40,
                                    dataRowMinHeight: 48,
                                    dataRowMaxHeight: 56,
                                    columns: const [
                                      DataColumn(label: Text('Tipo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                      DataColumn(label: Text('Fecha', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                      DataColumn(label: Text('Cédula', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                      DataColumn(label: Text('Paciente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                      DataColumn(label: Text('Signos Vitales', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                      DataColumn(label: Text('Diagnóstico / Motivo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                      DataColumn(label: Text('Tratamiento', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                      DataColumn(label: Text('Sector', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                      DataColumn(label: Text('Acción', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                    ],
                                    rows: _previewAttentions.map((att) {
                                      final persona = att['paciente']?['persona'];
                                      final fVisita = att['fecha_visita'] ?? 'N/A';
                                      final ci = persona?['cedula_identidad'] ?? 'S/C';
                                      final nom = persona != null ? '${persona['nombre1'] ?? ''} ${persona['apellido1'] ?? ''}' : 'N/A';
                                      final tipo = (att['tipo_atencion'] ?? 'inmunizacion').toString().toLowerCase();
                                      final diag = att['diagnostico_general'] ?? att['motivo_consulta'] ?? 'Consulta';
                                      final trat = att['tratamiento_indicado'] ?? 'N/A';
                                      
                                      // Signos vitales resumidos
                                      final pa = att['presion_arterial'];
                                      final fc = att['frecuencia_cardiaca'];
                                      final temp = att['temperatura'];
                                      final svList = <String>[];
                                      if (pa != null && pa.toString().isNotEmpty) svList.add('PA: $pa');
                                      if (fc != null) svList.add('FC: $fc');
                                      if (temp != null) svList.add('$temp°C');
                                      final svStr = svList.isNotEmpty ? svList.join(' | ') : 'N/A';

                                      final dir = persona?['direcciones'] as List?;
                                      final sectorNom = dir != null && dir.isNotEmpty
                                          ? (dir[0]?['sector']?['nombre_sector'] ?? 'Guanipa')
                                          : 'Guanipa';

                                      return DataRow(
                                        cells: [
                                          DataCell(
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: tipo.contains('consulta') ? Colors.purple.shade50 : Colors.blue.shade50,
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: tipo.contains('consulta') ? Colors.purple.shade200 : Colors.blue.shade200),
                                              ),
                                              child: Text(
                                                tipo.contains('consulta') ? 'CONSULTA' : 'VACUNA',
                                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: tipo.contains('consulta') ? Colors.purple.shade800 : _primary),
                                              ),
                                            ),
                                          ),
                                          DataCell(Text(fVisita, style: const TextStyle(fontSize: 12))),
                                          DataCell(Text(ci, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 12))),
                                          DataCell(Text(nom, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                          DataCell(Text(svStr, style: const TextStyle(fontSize: 11, color: Colors.black87))),
                                          DataCell(SizedBox(width: 140, child: Text(diag, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)))),
                                          DataCell(SizedBox(width: 130, child: Text(trat, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)))),
                                          DataCell(Text(sectorNom, style: const TextStyle(fontSize: 12))),
                                          DataCell(
                                            IconButton(
                                              icon: const Icon(Icons.visibility_outlined, color: _primary, size: 20),
                                              tooltip: 'Ver Detalle Clínico',
                                              onPressed: () => _mostrarDetalleClinico(att),
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  void _mostrarDetalleClinico(Map<String, dynamic> att) {
    final persona = att['paciente']?['persona'];
    final fVisita = att['fecha_visita'] ?? 'N/A';
    final ci = persona?['cedula_identidad'] ?? 'S/C';
    final nom = persona != null 
        ? '${persona['nombre1'] ?? ''} ${persona['nombre2'] ?? ''} ${persona['apellido1'] ?? ''} ${persona['apellido2'] ?? ''}'.trim()
        : 'N/A';
    final sexo = persona?['sexo'] ?? 'N/A';
    final tel = (persona?['telefonos'] as List?)?.isNotEmpty == true ? persona!['telefonos'][0]['numero_telefono'] : 'N/A';
    final correo = (persona?['correos'] as List?)?.isNotEmpty == true ? persona!['correos'][0]['correo'] : 'N/A';
    
    final dir = (persona?['direcciones'] as List?)?.isNotEmpty == true ? persona!['direcciones'][0] : null;
    final sectorNom = dir?['sector']?['nombre_sector'] ?? 'Guanipa';
    final dirDetallada = dir != null 
        ? [dir['parroquia'], dir['calle'], dir['numero_casa'], dir['punto_referencia']].where((e) => e != null && e.toString().isNotEmpty).join(', ')
        : 'No especificada';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.medical_information, color: _primary),
            const SizedBox(width: 10),
            Text('Ficha de Atención # ${att['id_atencion'] ?? ''}'),
          ],
        ),
        content: SizedBox(
          width: 580,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Info Paciente
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Paciente: $nom ($sexo)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text('Cédula: $ci | Teléfono: $tel | Correo: $correo', style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 4),
                      Text('Sector: $sectorNom | Dirección: $dirDetallada', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Signos Vitales
                const Text('Signos Vitales y Triaje', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _primary)),
                const Divider(),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _chipVital('Presión Art.', att['presion_arterial'] ?? 'N/A'),
                    _chipVital('F. Cardíaca', att['frecuencia_cardiaca'] != null ? '${att['frecuencia_cardiaca']} lpm' : 'N/A'),
                    _chipVital('F. Respirat.', att['frecuencia_respiratoria'] != null ? '${att['frecuencia_respiratoria']} rpm' : 'N/A'),
                    _chipVital('SpO2', att['saturacion_oxigeno'] != null ? '${att['saturacion_oxigeno']}%' : 'N/A'),
                    _chipVital('Temperatura', att['temperatura'] != null ? '${att['temperatura']} °C' : 'N/A'),
                    _chipVital('Peso', att['peso'] != null ? '${att['peso']} kg' : 'N/A'),
                    _chipVital('Talla', att['talla'] != null ? '${att['talla']} cm' : 'N/A'),
                  ],
                ),
                const SizedBox(height: 12),

                // Consulta y Diagnóstico
                const Text('Evaluación Médica', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _primary)),
                const Divider(),
                Text('Motivo de Consulta: ${att['motivo_consulta'] ?? 'N/A'}', style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 6),
                Text('Diagnóstico CIE-10: ${att['diagnostico_general'] ?? 'N/A'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text('Tratamiento / Récipe: ${att['tratamiento_indicado'] ?? 'N/A'}', style: const TextStyle(fontSize: 13, color: _green)),
                const SizedBox(height: 6),
                Text('Observaciones: ${att['observaciones'] ?? 'Ninguna'}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
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

  Widget _chipVital(String label, String val) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text('$label: $val', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

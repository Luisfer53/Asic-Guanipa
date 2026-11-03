import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:asis_guanipa_frontend/models/paciente.dart';
import 'package:asis_guanipa_frontend/services/api_service.dart';
import 'package:asis_guanipa_frontend/screen/nominal_register/create_patient_dialog.dart';
import 'package:asis_guanipa_frontend/screen/nominal_register/quick_patient_dialog.dart';
import 'package:asis_guanipa_frontend/screen/nominal_register/carnet_vacunacion_dialog.dart';
import 'package:asis_guanipa_frontend/screen/nominal_register/constancia_atencion_dialog.dart';
import 'package:asis_guanipa_frontend/screen/nominal_register/patient_history_screen.dart';

import 'package:asis_guanipa_frontend/utils/web_helper.dart' as webHelper;

/// ─────────────────────────────────────────────────────────────────────────────
/// REGISTRO NOMINAL DE PACIENTES — DATA GRID COMPACTO Y PROFESIONAL (FASE 4)
/// ─────────────────────────────────────────────────────────────────────────────
class ListPatients extends StatefulWidget {
  const ListPatients({super.key});

  @override
  State<ListPatients> createState() => _ListPatientsState();
}

class _ListPatientsState extends State<ListPatients> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  List<Paciente> _allPacientes = [];
  List<Paciente> _filteredPacientes = [];
  bool _isLoading = false;
  bool _hasError = false;
  String? _errorMessage;

  // ─── Filtros avanzados ───────────────────────────────────────────────────────
  String _activeSearch = '';
  String? _filtroSector;
  String? _filtroGrupoEtario; // 'todos', 'lactante_menor', 'lactante_mayor', 'preescolar', 'escolar', 'adolescente', 'adulto', 'adulto_mayor'
  String? _filtroSexo; // 'todos', 'M', 'F'

  // Paginación local del data grid
  int _filasPorPagina = 15;
  int _paginaActual = 1;

  // Sectores para el dropdown
  static const List<String> _sectoresGuanipa = [
    'San José de Guanipa Centro',
    '12 de Octubre',
    '19 de Marzo',
    '23 de Enero',
    'Alberto Ravell',
    'Andrés Bello',
    'Barrio Blanco',
    'Bella Vista',
    'Bicentenario I',
    'Bicentenario II',
    'Bicentenario III',
    'California',
    'Campo Oficina',
    'Cantaura',
    'Central',
    'Colinas de Guanipa',
    'Cristóbal Colón',
    'El Basquero I',
    'El Basquero II',
    'El Carmen I',
    'El Carmen II',
    'El Mirador',
    'El Palmar',
    'Ezequiel Zamora',
    'Francisco de Miranda',
    'Girardot',
    'Guayabal',
    'Inam',
    'José Antonio Anzoátegui',
    'La Ceiba',
    'La Charneca',
    'La Espinal I',
    'La Espinal II',
    'La Floresta',
    'La Perla',
    'La Victoria',
    'Las Malvinas',
    'Las Mercedes',
    'Las Torres',
    'Los Claveles',
    'Los Laureles',
    'Los Olivos',
    'Los Pinos',
    'Los Rosales',
    'Monte Verde',
    'Nueve de Diciembre',
    'Rómulo Gallegos',
    'Sabana de Guanipa',
    'San Francisco',
    'San José I',
    'San José II',
    'San José Obrero',
    'San Martín',
    'San Rafael',
    'Santa Elena',
    'Santa Rosa',
    'Sector Este',
    'Sector Norte',
    'Sector Oeste',
    'Sector Sur',
    'Simón Bolívar I',
    'Simón Bolívar II',
    'Sucre',
    'Umberto Sivanovi',
    'Valmore Rodríguez',
    'Vista al Sol',
    'Zona Industrial I',
    'Zona Industrial II',
    'Otro',
  ];

  @override
  void initState() {
    super.initState();
    _loadPacientes();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPacientes() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      final response = await _apiService.getPacientes(page: 1);

      if (mounted) {
        setState(() {
          if (response.success) {
            _allPacientes = response.data;
            _aplicarFiltrosLocales();
          } else {
            _hasError = true;
            _errorMessage = 'Error al cargar pacientes';
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Error de conexión: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged(String value) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      setState(() {
        _activeSearch = value.trim().toLowerCase();
        _paginaActual = 1;
        _aplicarFiltrosLocales();
      });
    });
  }

  void _aplicarFiltrosLocales() {
    List<Paciente> result = List.from(_allPacientes);

    // 1. Filtro de búsqueda texto
    if (_activeSearch.isNotEmpty) {
      result = result.where((p) {
        final nombreCompleto = '${p.nombre} ${p.apellido}'.toLowerCase();
        final cedula = p.cedula.toLowerCase();
        final tel = (p.telefono ?? '').toLowerCase();
        final dir = (p.direccionCompleta ?? '').toLowerCase();
        final cor = (p.persona?.correo ?? '').toLowerCase();

        return nombreCompleto.contains(_activeSearch) ||
            cedula.contains(_activeSearch) ||
            tel.contains(_activeSearch) ||
            dir.contains(_activeSearch) ||
            cor.contains(_activeSearch);
      }).toList();
    }

    // 2. Filtro de sector
    if (_filtroSector != null && _filtroSector!.isNotEmpty && _filtroSector != 'todos') {
      result = result.where((p) {
        final dir = (p.direccionCompleta ?? '').toLowerCase();
        return dir.contains(_filtroSector!.toLowerCase());
      }).toList();
    }

    // 3. Filtro de sexo
    if (_filtroSexo != null && _filtroSexo!.isNotEmpty && _filtroSexo != 'todos') {
      result = result.where((p) {
        final s = (p.sexo.isNotEmpty ? p.sexo : (p.persona?.sexo ?? '')).toUpperCase();
        return s.startsWith(_filtroSexo!);
      }).toList();
    }

    // 4. Filtro de grupo etario
    if (_filtroGrupoEtario != null && _filtroGrupoEtario != 'todos') {
      result = result.where((p) {
        final edad = p.edad;
        if (edad == null) return false;

        switch (_filtroGrupoEtario) {
          case 'lactante_menor':
            return edad < 1;
          case 'lactante_mayor':
            return edad >= 1 && edad < 2;
          case 'preescolar':
            return edad >= 2 && edad < 5;
          case 'escolar':
            return edad >= 5 && edad < 12;
          case 'adolescente':
            return edad >= 12 && edad < 18;
          case 'adulto':
            return edad >= 18 && edad < 60;
          case 'adulto_mayor':
            return edad >= 60;
          case 'menores':
            return edad < 18;
          default:
            return true;
        }
      }).toList();
    }

    _filteredPacientes = result;
  }

  void _limpiarFiltros() {
    setState(() {
      _searchController.clear();
      _activeSearch = '';
      _filtroSector = null;
      _filtroGrupoEtario = null;
      _filtroSexo = null;
      _paginaActual = 1;
      _aplicarFiltrosLocales();
    });
  }

  // Exportar lista actual a CSV
  void _exportarCSV() {
    if (_filteredPacientes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay pacientes para exportar con los filtros actuales.')),
      );
      return;
    }

    final StringBuffer buffer = StringBuffer();
    // Cabecera CSV
    buffer.writeln('ID,Cedula/Codigo,Nombres,Apellidos,Sexo,Edad,Fecha_Nacimiento,Sector_Direccion,Telefono,Correo,Tipo_Sangre,Alergias');

    for (final p in _filteredPacientes) {
      final id = p.idPaciente;
      final ci = '"${p.cedula}"';
      final nom = '"${p.persona?.nombre1 ?? p.nombre}"';
      final ape = '"${p.persona?.apellido1 ?? p.apellido}"';
      final sexo = p.sexoFormateado;
      final edad = p.edad != null ? '${p.edad}' : '';
      final fn = p.persona?.fechaNacimiento != null ? p.persona!.fechaNacimiento.toString().split('T')[0] : '';
      final dir = '"${(p.direccionCompleta ?? '').replaceAll('"', '""')}"';
      final tel = '"${p.telefono ?? ''}"';
      final cor = '"${p.persona?.correo ?? ''}"';
      final ts = '"${p.persona?.estadoCivil ?? ''}"';
      final alerg = '""';

      buffer.writeln('$id,$ci,$nom,$ape,$sexo,$edad,$fn,$dir,$tel,$cor,$ts,$alerg');
    }

    final csvContent = buffer.toString();
    final bytes = utf8.encode('\uFEFF$csvContent'); // UTF-8 BOM para Excel

    if (kIsWeb) {
      webHelper.downloadCsvBytes(bytes, 'censo_nominal_guanipa_${DateTime.now().millisecondsSinceEpoch}.csv');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Archivo CSV descargado exitosamente. Compatible con Microsoft Excel y LibreOffice.'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('CSV generado con ${_filteredPacientes.length} registros.'),
          backgroundColor: const Color(0xFF1565C0),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Column(
          children: [
            // ─── 1. Header Institucional y Botones Superiores ────────────────
            _buildHeader(),

            // ─── 2. Barra de Métricas y KPIs en Vivo ─────────────────────────
            _buildBarraMetricas(),

            // ─── 3. Barra de Búsqueda y Filtros Multinivel ───────────────────
            _buildBarraFiltros(),

            // ─── 4. Data Grid Central (Tabla Compacta) ───────────────────────
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Color(0xFF1565C0)),
                          SizedBox(height: 12),
                          Text('Cargando registro nominal...', style: TextStyle(color: Color(0xFF64748B))),
                        ],
                      ),
                    )
                  : _hasError
                      ? _buildErrorView()
                      : _filteredPacientes.isEmpty
                          ? _buildEmptyView()
                          : _buildDataGrid(),
            ),

            // ─── 5. Paginador / Footer ───────────────────────────────────────
            _buildFooterPaginacion(),
          ],
        ),
      ),
    );
  }

  // ─── 1. Encabezado ─────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        if (isMobile) {
          return Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1565C0),
                        side: const BorderSide(color: Color(0xFFBFDBFE)),
                        backgroundColor: const Color(0xFFEFF6FF),
                        minimumSize: const Size(40, 38),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => context.canPop() ? context.pop() : context.go('/'),
                      child: const Icon(Icons.arrow_back_rounded, size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Registro Nominal',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.download_rounded, size: 20, color: Color(0xFF0F766E)),
                      tooltip: 'Exportar CSV',
                      onPressed: _exportarCSV,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          QuickPatientDialog.show(context, onPatientCreated: (_) => _loadPacientes());
                        },
                        icon: const Icon(Icons.flash_on_rounded, size: 16),
                        label: const Text('Alta Rápida', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00897B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => CreatePatientDialog(onPatientCreated: ([_]) => _loadPacientes()),
                          );
                        },
                        icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                        label: const Text('Completo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        // Desktop / tablet
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1565C0),
                  side: const BorderSide(color: Color(0xFFBFDBFE)),
                  backgroundColor: const Color(0xFFEFF6FF),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                label: const Text('Inicio', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () => context.canPop() ? context.pop() : context.go('/'),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.people_alt_rounded, color: Color(0xFF1565C0), size: 24),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Registro Nominal de Pacientes',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    'Censo poblacional y trazabilidad nominal del ASIC Guanipa / CDI Pedro Urbina',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _exportarCSV,
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text('Exportar CSV / Excel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F766E),
                  side: const BorderSide(color: Color(0xFF0F766E), width: 1.2),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {
                  QuickPatientDialog.show(context, onPatientCreated: (_) => _loadPacientes());
                },
                icon: const Icon(Icons.flash_on_rounded, size: 16),
                label: const Text('Alta Rápida (<20s)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00897B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => CreatePatientDialog(onPatientCreated: ([_]) => _loadPacientes()),
                  );
                },
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                label: const Text('Registro Completo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── 2. Métricas y KPIs ───────────────────────────────────────────────────
  Widget _buildBarraMetricas() {
    final total = _allPacientes.length;
    final menores = _allPacientes.where((p) => p.esMenor).length;
    final adultos = total - menores;
    final filtrados = _filteredPacientes.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      color: const Color(0xFFF8FAFC),
      child: Row(
        children: [
          _chipMetrica('Total Registrados', '$total', Icons.groups_rounded, const Color(0xFF1E3A8A)),
          const SizedBox(width: 12),
          _chipMetrica('Menores / Pediátricos', '$menores', Icons.child_care_rounded, const Color(0xFFB45309)),
          const SizedBox(width: 12),
          _chipMetrica('Adultos (18+)', '$adultos', Icons.person_rounded, const Color(0xFF0F766E)),
          const Spacer(),
          if (filtrados != total)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF93C5FD)),
              ),
              child: Text(
                'Mostrando $filtrados de $total pacientes',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chipMetrica(String label, String valor, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(width: 6),
          Text(
            valor,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: color),
          ),
        ],
      ),
    );
  }

  // ─── 3. Barra de Filtros ──────────────────────────────────────────────────
  Widget _buildBarraFiltros() {
    final tieneFiltrosActivos = _activeSearch.isNotEmpty ||
        (_filtroSector != null && _filtroSector != 'todos') ||
        (_filtroGrupoEtario != null && _filtroGrupoEtario != 'todos') ||
        (_filtroSexo != null && _filtroSexo != 'todos');

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        final buscador = SizedBox(
          height: 38,
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: isMobile
                  ? 'Buscar por nombre, cédula...'
                  : 'Buscar por nombre, cédula, teléfono o dirección...',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
            ),
          ),
        );

        final sectorFiltro = SizedBox(
          height: 38,
          child: DropdownButtonFormField<String>(
            value: _filtroSector,
            isExpanded: true,
            style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
            decoration: InputDecoration(
              labelText: 'Sector',
              labelStyle: const TextStyle(fontSize: 11),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            items: [
              const DropdownMenuItem(value: 'todos', child: Text('Todos los sectores')),
              ..._sectoresGuanipa.map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis))),
            ],
            onChanged: (v) {
              setState(() {
                _filtroSector = v;
                _paginaActual = 1;
                _aplicarFiltrosLocales();
              });
            },
          ),
        );

        final etarioFiltro = SizedBox(
          height: 38,
          child: DropdownButtonFormField<String>(
            value: _filtroGrupoEtario,
            isExpanded: true,
            style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
            decoration: InputDecoration(
              labelText: 'Edad',
              labelStyle: const TextStyle(fontSize: 11),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            items: const [
              DropdownMenuItem(value: 'todos', child: Text('Todas las edades')),
              DropdownMenuItem(value: 'menores', child: Text('👶 Menores (<18)')),
              DropdownMenuItem(value: 'lactante_menor', child: Text('🍼 Lactante <1año')),
              DropdownMenuItem(value: 'lactante_mayor', child: Text('👶 Lactante 1año')),
              DropdownMenuItem(value: 'preescolar', child: Text('🧒 Preescolar 2-4a')),
              DropdownMenuItem(value: 'escolar', child: Text('🎒 Escolar 5-11a')),
              DropdownMenuItem(value: 'adolescente', child: Text('🧑 Adolescente 12-17')),
              DropdownMenuItem(value: 'adulto', child: Text('🧑 Adulto 18-59')),
              DropdownMenuItem(value: 'adulto_mayor', child: Text('👴 Adulto Mayor 60+')),
            ],
            onChanged: (v) {
              setState(() {
                _filtroGrupoEtario = v;
                _paginaActual = 1;
                _aplicarFiltrosLocales();
              });
            },
          ),
        );

        final sexoFiltro = SizedBox(
          height: 38,
          child: DropdownButtonFormField<String>(
            value: _filtroSexo,
            isExpanded: true,
            style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
            decoration: InputDecoration(
              labelText: 'Sexo',
              labelStyle: const TextStyle(fontSize: 11),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            items: const [
              DropdownMenuItem(value: 'todos', child: Text('Todos')),
              DropdownMenuItem(value: 'F', child: Text('Femenino')),
              DropdownMenuItem(value: 'M', child: Text('Masculino')),
            ],
            onChanged: (v) {
              setState(() {
                _filtroSexo = v;
                _paginaActual = 1;
                _aplicarFiltrosLocales();
              });
            },
          ),
        );

        return Container(
          padding: isMobile
              ? const EdgeInsets.fromLTRB(12, 6, 12, 10)
              : const EdgeInsets.fromLTRB(20, 6, 20, 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    buscador,
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: sectorFiltro),
                        const SizedBox(width: 8),
                        Expanded(child: etarioFiltro),
                        const SizedBox(width: 8),
                        SizedBox(width: 100, child: sexoFiltro),
                        if (tieneFiltrosActivos) ...[
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.filter_alt_off_rounded, color: Colors.redAccent, size: 20),
                            tooltip: 'Limpiar filtros',
                            onPressed: _limpiarFiltros,
                          ),
                        ],
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(flex: 3, child: buscador),
                    const SizedBox(width: 10),
                    Expanded(flex: 2, child: sectorFiltro),
                    const SizedBox(width: 10),
                    Expanded(flex: 2, child: etarioFiltro),
                    const SizedBox(width: 10),
                    SizedBox(width: 110, child: sexoFiltro),
                    if (tieneFiltrosActivos) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.filter_alt_off_rounded, color: Colors.redAccent, size: 20),
                        tooltip: 'Limpiar filtros',
                        onPressed: _limpiarFiltros,
                      ),
                    ],
                  ],
                ),
        );
      },
    );
  }

  // ─── 4. Data Grid Central (Tabla Compacta en Escritorio / Tarjetas en Móvil) ─
  Widget _buildDataGrid() {
    final inicio = (_paginaActual - 1) * _filasPorPagina;
    final fin = (inicio + _filasPorPagina) > _filteredPacientes.length
        ? _filteredPacientes.length
        : (inicio + _filasPorPagina);
    final pacientesPagina = _filteredPacientes.sublist(inicio, fin);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 750;

        if (isMobile) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              children: pacientesPagina.map((p) => _buildMobileCard(p)).toList(),
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFCBD5E1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(1.6), // Cédula / Código
                  1: FlexColumnWidth(2.5), // Paciente
                  2: FlexColumnWidth(2.1), // Sector / Habitación
                  3: FlexColumnWidth(1.9), // Contacto
                  4: FlexColumnWidth(1.5), // Datos Clínicos
                  5: FlexColumnWidth(2.8), // Acciones (con Constancia y Récipe)
                },
                children: [
                  // ─── Cabecera de la Tabla ─────────────────────────────────────
                  TableRow(
                    decoration: const BoxDecoration(
                      color: Color(0xFF0F172A),
                    ),
                    children: [
                      _headerCell('Identidad / CI', Icons.badge_outlined),
                      _headerCell('Paciente', Icons.person_outline),
                      _headerCell('Sector & Ubicación', Icons.location_on_outlined),
                      _headerCell('Contacto', Icons.contact_phone_outlined),
                      _headerCell('Clínica Básica', Icons.medical_information_outlined),
                      _headerCell('Acciones Rápidas', Icons.settings_outlined, alignCenter: true),
                    ],
                  ),
                  // ─── Filas de Pacientes ───────────────────────────────────────
                  ...pacientesPagina.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final p = entry.value;
                    final isEven = idx % 2 == 0;
                    return _buildDataGridRow(p, isEven: isEven);
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _headerCell(String label, IconData icon, {bool alignCenter = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        mainAxisAlignment: alignCenter ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  TableRow _buildDataGridRow(Paciente p, {required bool isEven}) {
    final persona = p.persona;
    final nombreCompleto = p.nombreCompleto.isNotEmpty ? p.nombreCompleto : '${p.nombre} ${p.apellido}';
    final cedula = p.cedula.isNotEmpty ? p.cedula : 'Sin CI';
    final esMenor = p.esMenor;
    final edadStr = p.edadFormateada;
    final sexo = p.sexoFormateado;
    final telefono = p.telefono ?? persona?.telefono;
    final correo = persona?.correo;
    final direccion = p.direccionCompleta ?? 'San José de Guanipa';
    final tipoSangre = persona?.estadoCivil ?? 'S/D';

    return TableRow(
      decoration: BoxDecoration(
        color: isEven ? Colors.white : const Color(0xFFF8FAFC),
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 0.8)),
      ),
      children: [
        // 1. Cédula con Badge
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: esMenor
                      ? const Color(0xFFFEF3C7)
                      : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: esMenor ? const Color(0xFFF59E0B) : const Color(0xFF93C5FD),
                  ),
                ),
                child: Text(
                  cedula,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: esMenor ? const Color(0xFF92400E) : const Color(0xFF1E40AF),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                esMenor ? 'Menor Dependiente' : 'Titular Adulto',
                style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),

        // 2. Paciente (Avatar, Nombre, Edad, Sexo)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: (sexo == 'Masculino' ? const Color(0xFF1565C0) : Colors.pink.shade400).withValues(alpha: 0.15),
                child: Text(
                  p.nombre.isNotEmpty ? p.nombre[0].toUpperCase() : 'P',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: sexo == 'Masculino' ? const Color(0xFF1565C0) : Colors.pink.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombreCompleto,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$edadStr · $sexo',
                      style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 3. Sector & Habitación
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                direccion,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF334155)),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ],
          ),
        ),

        // 4. Contacto (Teléfono y Correo)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (telefono != null && telefono.isNotEmpty)
                Row(
                  children: [
                    const Icon(Icons.phone_rounded, size: 12, color: Color(0xFF00897B)),
                    const SizedBox(width: 4),
                    Text(telefono, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                  ],
                )
              else
                const Text('Sin teléfono', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
              if (correo != null && correo.isNotEmpty)
                Row(
                  children: [
                    const Icon(Icons.email_outlined, size: 12, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        correo,
                        style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),

        // 5. Datos Clínicos Básicos
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  tipoSangre != 'S/D' ? tipoSangre : 'S/D',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red.shade700),
                ),
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Ficha activa',
                  style: TextStyle(fontSize: 10, color: Color(0xFF059669), fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),

        // 6. Acciones Rápidas (Icon Buttons compactos con soporte responsive)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 2,
            runSpacing: 2,
            children: [
              // Ficha Historial
              Tooltip(
                message: 'Ver Ficha e Historial',
                child: IconButton(
                  icon: const Icon(Icons.folder_shared_rounded, size: 18, color: Color(0xFF1565C0)),
                  tooltip: 'Ver Ficha e Historial',
                  splashRadius: 18,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: const EdgeInsets.all(5),
                  onPressed: () {
                    final String identifier = p.cedula.isNotEmpty ? p.cedula : p.idPaciente.toString();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PatientHistoryScreen(
                          pacienteId: identifier,
                          nombrePaciente: nombreCompleto,
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Carnet Digital con QR
              Tooltip(
                message: 'Generar Carnet Digital (QR)',
                child: IconButton(
                  icon: const Icon(Icons.qr_code_2_rounded, size: 18, color: Color(0xFF0D9488)),
                  tooltip: 'Generar Carnet Digital (QR)',
                  splashRadius: 18,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: const EdgeInsets.all(5),
                  onPressed: () {
                    CarnetVacunacionDialog.show(context, paciente: p);
                  },
                ),
              ),
              // Constancia Oficial de Atención con QR
              Tooltip(
                message: 'Constancia Oficial de Atención (QR)',
                child: IconButton(
                  icon: const Icon(Icons.verified_rounded, size: 18, color: Color(0xFF0284C7)),
                  tooltip: 'Constancia Oficial de Atención (QR)',
                  splashRadius: 18,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: const EdgeInsets.all(5),
                  onPressed: () {
                    ConstanciaAtencionDialog.show(context, paciente: p);
                  },
                ),
              ),
              // Récipe Digital Oficial con QR (Destacado)
              Tooltip(
                message: 'Emitir Constancia Médica Oficial (QR)',
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFBAE6FD), width: 0.8),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.verified_rounded, size: 18, color: Color(0xFF0284C7)),
                    tooltip: 'Emitir Constancia Médica (QR)',
                    splashRadius: 18,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: const EdgeInsets.all(5),
                    onPressed: () {
                      ConstanciaAtencionDialog.show(context, paciente: p);
                    },
                  ),
                ),
              ),
              // Vacunar rápido (Directo a Inmunización)
              Tooltip(
                message: 'Registrar Vacunación',
                child: IconButton(
                  icon: const Icon(Icons.vaccines_rounded, size: 18, color: Color(0xFF2E7D32)),
                  tooltip: 'Registrar Vacunación',
                  splashRadius: 18,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: const EdgeInsets.all(5),
                  onPressed: () {
                    context.go('/jornada-diaria');
                  },
                ),
              ),
              // Consulta Médica
              Tooltip(
                message: 'Atender Consulta Médica',
                child: IconButton(
                  icon: const Icon(Icons.medical_services_rounded, size: 18, color: Color(0xFFD97706)),
                  tooltip: 'Atender Consulta Médica',
                  splashRadius: 18,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: const EdgeInsets.all(5),
                  onPressed: () {
                    context.go('/consulta-medica');
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Tarjeta Móvil Adaptativa para Android / Pantallas Pequeñas ───────────
  Widget _buildMobileCard(Paciente p) {
    final persona = p.persona;
    final nombreCompleto = p.nombreCompleto.isNotEmpty ? p.nombreCompleto : '${p.nombre} ${p.apellido}';
    final cedula = p.cedula.isNotEmpty ? p.cedula : 'Sin CI';
    final esMenor = p.esMenor;
    final edadStr = p.edadFormateada;
    final sexo = p.sexoFormateado;
    final telefono = p.telefono ?? persona?.telefono;
    final direccion = p.direccionCompleta ?? 'San José de Guanipa';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila 1: Avatar + Nombre + Badges
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: (sexo == 'Masculino' ? const Color(0xFF1565C0) : Colors.pink.shade400).withValues(alpha: 0.15),
                child: Text(
                  p.nombre.isNotEmpty ? p.nombre[0].toUpperCase() : 'P',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: sexo == 'Masculino' ? const Color(0xFF1565C0) : Colors.pink.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombreCompleto,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: esMenor ? const Color(0xFFFEF3C7) : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: esMenor ? const Color(0xFFF59E0B) : const Color(0xFF93C5FD),
                            ),
                          ),
                          child: Text(
                            cedula,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: esMenor ? const Color(0xFF92400E) : const Color(0xFF1E40AF),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$edadStr · $sexo',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Divider(height: 18, color: Color(0xFFF1F5F9)),

          // Fila 2: Ubicación & Contacto
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 13, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  direccion,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (telefono != null && telefono.isNotEmpty) ...[
                const SizedBox(width: 8),
                const Icon(Icons.phone_outlined, size: 13, color: Color(0xFF0D9488)),
                const SizedBox(width: 3),
                Text(
                  telefono,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0D9488)),
                ),
              ],
            ],
          ),

          const SizedBox(height: 12),

          // Fila 3: Botones de Acción Táctiles adaptados a pulgar
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              // Ficha
              OutlinedButton.icon(
                icon: const Icon(Icons.folder_shared_rounded, size: 14, color: Color(0xFF1565C0)),
                label: const Text('Ficha', style: TextStyle(fontSize: 11, color: Color(0xFF1565C0))),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  side: const BorderSide(color: Color(0xFF93C5FD)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  final String identifier = p.cedula.isNotEmpty ? p.cedula : p.idPaciente.toString();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PatientHistoryScreen(
                        pacienteId: identifier,
                        nombrePaciente: nombreCompleto,
                      ),
                    ),
                  );
                },
              ),
              // Carnet QR
              OutlinedButton.icon(
                icon: const Icon(Icons.qr_code_2_rounded, size: 14, color: Color(0xFF0D9488)),
                label: const Text('Carnet', style: TextStyle(fontSize: 11, color: Color(0xFF0D9488))),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  side: const BorderSide(color: Color(0xFF99F6E4)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => CarnetVacunacionDialog.show(context, paciente: p),
              ),
              // Constancia Médica QR
              ElevatedButton.icon(
                icon: const Icon(Icons.verified_rounded, size: 14, color: Colors.white),
                label: const Text('Constancia Médica (QR)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                onPressed: () => ConstanciaAtencionDialog.show(context, paciente: p),
              ),
              // Vacunar
              ElevatedButton.icon(
                icon: const Icon(Icons.vaccines_rounded, size: 14),
                label: const Text('Vacunar', style: TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF15803D),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                onPressed: () => context.go('/jornada-diaria'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── 5. Paginación y Footer ───────────────────────────────────────────────
  Widget _buildFooterPaginacion() {
    final totalFiltrados = _filteredPacientes.length;
    final totalPaginas = (totalFiltrados / _filasPorPagina).ceil().clamp(1, 9999);
    final inicio = totalFiltrados == 0 ? 0 : (_paginaActual - 1) * _filasPorPagina + 1;
    final fin = (_paginaActual * _filasPorPagina).clamp(0, totalFiltrados);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Text(
            'Mostrando registros $inicio-$fin de $totalFiltrados',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const Spacer(),
          // Selector de filas por página
          const Text('Filas por página: ', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          DropdownButton<int>(
            value: _filasPorPagina,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 10, child: Text('10', style: TextStyle(fontSize: 12))),
              DropdownMenuItem(value: 15, child: Text('15', style: TextStyle(fontSize: 12))),
              DropdownMenuItem(value: 25, child: Text('25', style: TextStyle(fontSize: 12))),
              DropdownMenuItem(value: 50, child: Text('50', style: TextStyle(fontSize: 12))),
            ],
            onChanged: (v) {
              if (v != null) {
                setState(() {
                  _filasPorPagina = v;
                  _paginaActual = 1;
                });
              }
            },
          ),
          const SizedBox(width: 16),
          // Botón Anterior
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: _paginaActual > 1 ? () => setState(() => _paginaActual--) : null,
            splashRadius: 18,
          ),
          Text('Página $_paginaActual de $totalPaginas', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          // Botón Siguiente
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: _paginaActual < totalPaginas ? () => setState(() => _paginaActual++) : null,
            splashRadius: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.person_search_rounded, size: 54, color: Color(0xFF94A3B8)),
          const SizedBox(height: 12),
          const Text(
            'No se encontraron pacientes',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Prueba ajustando los términos de búsqueda o los filtros aplicados.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _limpiarFiltros,
            icon: const Icon(Icons.restart_alt_rounded, size: 16),
            label: const Text('Restablecer Filtros'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
          const SizedBox(height: 12),
          Text(_errorMessage ?? 'Error desconocido', style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _loadPacientes,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}

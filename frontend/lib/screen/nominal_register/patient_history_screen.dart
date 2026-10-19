import 'package:flutter/material.dart';
import 'package:asis_guanipa_frontend/services/api_service.dart';
import 'package:asis_guanipa_frontend/models/paciente.dart';
import 'package:asis_guanipa_frontend/screen/nominal_register/carnet_vacunacion_dialog.dart';
import 'package:asis_guanipa_frontend/screen/nominal_register/recipe_digital_dialog.dart';

class PatientHistoryScreen extends StatefulWidget {
  final String pacienteId;
  final String nombrePaciente;

  const PatientHistoryScreen({
    super.key,
    required this.pacienteId,
    required this.nombrePaciente,
  });

  @override
  State<PatientHistoryScreen> createState() => _PatientHistoryScreenState();
}

class _PatientHistoryScreenState extends State<PatientHistoryScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;

  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _historial;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadHistorial();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHistorial() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _api.getHistorialPaciente(widget.pacienteId);
      if (mounted) {
        setState(() {
          if (data['success'] == true) {
            _historial = data;
          } else {
            _error = data['message'] ?? 'Error al cargar historial';
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error de conexión: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Historial del Paciente',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.nombrePaciente,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton.icon(
              onPressed: () {
                if (_historial != null && _historial!['paciente'] != null) {
                  final pacienteObj = Paciente.fromJson(_historial!['paciente']);
                  RecipeDigitalDialog.show(context, paciente: pacienteObj);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cargando información del paciente...')),
                  );
                }
              },
              icon: const Icon(Icons.receipt_long_rounded, size: 16),
              label: const Text('Récipe Digital (QR)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: () {
                if (_historial != null && _historial!['paciente'] != null) {
                  final pacienteObj = Paciente.fromJson(_historial!['paciente']);
                  CarnetVacunacionDialog.show(context, paciente: pacienteObj);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cargando información para el carnet...')),
                  );
                }
              },
              icon: const Icon(Icons.qr_code_2_rounded, size: 16),
              label: const Text('Carnet Digital (QR)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00897B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.medical_services_outlined), text: 'Atenciones'),
            Tab(icon: Icon(Icons.vaccines), text: 'Vacunas'),
            Tab(icon: Icon(Icons.person_outline), text: 'Datos del Paciente'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF1565C0)),
                  SizedBox(height: 16),
                  Text('Cargando historial...'),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadHistorial,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildAtencionesList(),
                    _buildVacunasList(),
                    _buildDatosPaciente(),
                  ],
                ),
    );
  }

  // ───────────── TAB: ATENCIONES ─────────────
  Widget _buildAtencionesList() {
    final atenciones = (_historial!['atenciones'] as List?) ?? [];
    if (atenciones.isEmpty) {
      return _emptyState(Icons.medical_services_outlined, 'No hay atenciones registradas');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: atenciones.length,
      itemBuilder: (context, i) => _atencionCard(atenciones[i]),
    );
  }

  Widget _atencionCard(Map<String, dynamic> a) {
    final fecha = _formatDate(a['fecha_visita'] ?? '');
    final centro = a['centro']?['nombre_centro'] ?? 'CDI Pedro Urbina';
    final diagnosticos = (a['diagnosticos'] as List?) ?? [];
    final consumos = (a['consumos'] as List?) ?? [];
    final tratamientos = (a['tratamientos'] as List?) ?? [];
    final tipoAtencion = a['tipo_atencion'] ?? 'inmunizacion';
    final isConsulta = tipoAtencion == 'consulta_medica';

    // Separar tratamientos por tipo
    final indicaciones = tratamientos
        .where((t) => t['tipo_tratamiento'] == 'Indicación Médica')
        .toList();
    final observacionesList = tratamientos
        .where((t) => t['tipo_tratamiento'] == 'Observación Médica')
        .toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: (isConsulta ? const Color(0xFF1565C0) : const Color(0xFF2E7D32)).withValues(alpha: 0.12),
          child: Icon(
            isConsulta ? Icons.medical_services_rounded : Icons.vaccines_rounded,
            color: isConsulta ? const Color(0xFF1565C0) : const Color(0xFF2E7D32),
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Text(
              fecha,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: (isConsulta ? Colors.blue.shade50 : Colors.green.shade50),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isConsulta ? Colors.blue.shade300 : Colors.green.shade300,
                ),
              ),
              child: Text(
                isConsulta ? 'Consulta Médica' : 'Inmunización',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isConsulta ? const Color(0xFF0D47A1) : const Color(0xFF1B5E20),
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(centro, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (a['motivo_consulta'] != null && (a['motivo_consulta'] as String).isNotEmpty) ...[
                  _sectionLabel('Motivo de Consulta'),
                  Text(a['motivo_consulta'], style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
                  const SizedBox(height: 8),
                ],
                if (a['diagnostico_general'] != null &&
                    (a['diagnostico_general'] as String).isNotEmpty) ...[
                  _sectionLabel('Diagnóstico General'),
                  Text(a['diagnostico_general'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                ],
                // Signos vitales clínicos directos de la atención
                if (a['presion_arterial'] != null || a['temperatura'] != null || a['frecuencia_cardiaca'] != null) ...[
                  _sectionLabel('Signos Vitales Registrados'),
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 6,
                      children: [
                        if (a['presion_arterial'] != null)
                          Text('PA: ${a['presion_arterial']} mmHg', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        if (a['frecuencia_cardiaca'] != null)
                          Text('FC: ${a['frecuencia_cardiaca']} lpm', style: const TextStyle(fontSize: 12)),
                        if (a['frecuencia_respiratoria'] != null)
                          Text('FR: ${a['frecuencia_respiratoria']} rpm', style: const TextStyle(fontSize: 12)),
                        if (a['temperatura'] != null)
                          Text('Temp: ${a['temperatura']} °C', style: const TextStyle(fontSize: 12)),
                        if (a['saturacion_oxigeno'] != null)
                          Text('SpO2: ${a['saturacion_oxigeno']} %', style: const TextStyle(fontSize: 12)),
                        if (a['peso'] != null)
                          Text('Peso: ${a['peso']} kg', style: const TextStyle(fontSize: 12)),
                        if (a['talla'] != null)
                          Text('Talla: ${a['talla']} cm', style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
                if (a['tratamiento_indicado'] != null && (a['tratamiento_indicado'] as String).isNotEmpty) ...[
                  _sectionLabel('Tratamiento Indicado / Récipe'),
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Text(
                      a['tratamiento_indicado'],
                      style: TextStyle(fontSize: 13, color: Colors.green.shade900),
                    ),
                  ),
                ],
                if (indicaciones.isNotEmpty) ...[
                  _sectionLabel('Tratamiento Indicado'),
                  ...indicaciones.map((t) => Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.medication_outlined, size: 16, color: Colors.green.shade700),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            t['detalles'] ?? '',
                            style: TextStyle(fontSize: 13, color: Colors.green.shade900),
                          ),
                        ),
                      ],
                    ),
                  )),
                  const SizedBox(height: 8),
                ],
                if (observacionesList.isNotEmpty) ...[
                  _sectionLabel('Observaciones Médicas'),
                  ...observacionesList.map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.notes, size: 16, color: Color(0xFF1565C0)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            t['detalles'] ?? '',
                            style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
                    ),
                  )),
                  const SizedBox(height: 8),
                ],
                if (diagnosticos.isNotEmpty) ...[
                  _sectionLabel('Diagnósticos Específicos'),
                  ...diagnosticos.map((d) {
                    final diag = d['diagnostico'];
                    final gravedad = diag?['gravedad'] ?? '';
                    Color gravedadColor = Colors.grey;
                    if (gravedad.toLowerCase() == 'leve') gravedadColor = Colors.green;
                    if (gravedad.toLowerCase() == 'moderada') gravedadColor = Colors.orange;
                    if (gravedad.toLowerCase() == 'grave') gravedadColor = Colors.red;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1565C0).withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFF1565C0).withValues(alpha: 0.12)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.circle,
                                    size: 8, color: Color(0xFF1565C0)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    diag?['condicion'] ?? 'Sin condición',
                                    style: const TextStyle(
                                        fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                if (gravedad.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: gravedadColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      gravedad,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: gravedadColor,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if ((diag?['descripcion'] ?? '').isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                diag!['descripcion'],
                                style:
                                    TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                            ],
                            if (d['observacion_medica'] != null &&
                                (d['observacion_medica'] as String).isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Obs: ${d['observacion_medica']}',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[500],
                                    fontStyle: FontStyle.italic),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                ],
                if (consumos.isNotEmpty) ...[
                  _sectionLabel('Insumos / Medicamentos Entregados'),
                  ...consumos.map((c) {
                    final art = c['lote']?['articulo'];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          const Icon(Icons.medication_outlined,
                              size: 16, color: Color(0xFF0D47A1)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${art?['nombre_articulo'] ?? 'Insumo'} · Cantidad: ${c['cantidad_usada'] ?? '-'} ${art?['unidad_medida'] ?? ''}',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w500),
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
        ],
      ),
    );
  }

  // ───────────── TAB: VACUNAS ─────────────
  Widget _buildVacunasList() {
    final atenciones = (_historial!['atenciones'] as List?) ?? [];
    final List<Map<String, dynamic>> vacunas = [];
    for (final a in atenciones) {
      final vacunaciones = (a['vacunaciones'] as List?) ?? [];
      for (final v in vacunaciones) {
        vacunas.add({...Map<String, dynamic>.from(v), 'fecha_visita': a['fecha_visita']});
      }
    }

    if (vacunas.isEmpty) {
      return _emptyState(Icons.vaccines, 'No hay vacunas registradas');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: vacunas.length,
      itemBuilder: (context, i) {
        final v = vacunas[i];
        final art = v['lote']?['articulo'];
        final esquema = v['esquema'];
        final fecha = _formatDate(v['fecha_visita'] ?? '');
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green.withValues(alpha: 0.1),
              child: const Icon(Icons.vaccines, color: Colors.green, size: 22),
            ),
            title: Text(
              art?['nombre_articulo'] ?? 'Vacuna',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (esquema != null)
                  Text(
                    'Dosis ${esquema['numero_dosis'] ?? '-'}',
                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                  ),
                Text(
                  'Fecha: $fecha',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                v['sitio_aplicacion'] ?? 'Aplicada',
                style: const TextStyle(
                    color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        );
      },
    );
  }

  // ───────────── TAB: DATOS DEL PACIENTE ─────────────
  Widget _buildDatosPaciente() {
    final p = _historial!['paciente'] as Map<String, dynamic>? ?? {};
    final persona = p['persona'] as Map<String, dynamic>? ?? {};
    final representante = p['representante'] as Map<String, dynamic>?;
    final parentesco = p['parentesco_representante'] as String?;

    // Datos personales
    final nombre1 = persona['nombre1'] ?? '';
    final nombre2 = persona['nombre2'] ?? '';
    final apellido1 = persona['apellido1'] ?? '';
    final apellido2 = persona['apellido2'] ?? '';
    final nombreCompleto =
        '$nombre1 $nombre2 $apellido1 $apellido2'.replaceAll(RegExp(r'\s+'), ' ').trim();
    final cedula = persona['cedula_identidad'] ?? 'Sin cédula';
    final sexo = persona['sexo'] ?? '';
    final fechaNac = _formatDate(persona['fecha_nacimiento'] ?? '');
    final estadoCivil = persona['estado_civil'] ?? '';
    final ocupacion = persona['ocupacion'] ?? '';

    // Contacto
    final telefonos = (persona['telefonos'] as List?) ?? [];
    final correos = (persona['correos'] as List?) ?? [];
    final direcciones = (persona['direcciones'] as List?) ?? [];

    // Representante
    String nombreRep = '';
    String cedulaRep = '';
    String telefonoRep = '';
    if (representante != null) {
      final n1 = representante['nombre1'] ?? '';
      final n2 = representante['nombre2'] ?? '';
      final a1 = representante['apellido1'] ?? '';
      final a2 = representante['apellido2'] ?? '';
      nombreRep = '$n1 $n2 $a1 $a2'.replaceAll(RegExp(r'\s+'), ' ').trim();
      cedulaRep = representante['cedula_identidad'] ?? 'Sin cédula';
      final tels = (representante['telefonos'] as List?) ?? [];
      if (tels.isNotEmpty) {
        telefonoRep = tels[0]['numero_telefono'] ?? '';
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Resumen identidad ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      child: Icon(
                        sexo == 'M' ? Icons.person : Icons.person_outline,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nombreCompleto.isNotEmpty ? nombreCompleto : widget.nombrePaciente,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'C.I: $cedula',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    if (fechaNac.isNotEmpty)
                      _chipInfo(Icons.cake, 'Nac: $fechaNac'),
                    if (sexo.isNotEmpty)
                      _chipInfo(
                          Icons.wc, sexo == 'M' ? 'Masculino' : sexo == 'F' ? 'Femenino' : sexo),
                    if (estadoCivil.isNotEmpty)
                      _chipInfo(Icons.favorite_border, estadoCivil),
                    if (ocupacion.isNotEmpty)
                      _chipInfo(Icons.work_outline, ocupacion),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Datos de contacto ──
          _sectionHeader('Datos de Contacto', Icons.phone, Colors.teal),
          if (telefonos.isNotEmpty)
            ...telefonos.map((t) => _infoTile(
                  Icons.phone,
                  'Teléfono',
                  t['numero_telefono'] ?? '-',
                  Colors.teal,
                ))
          else
            _infoTile(Icons.phone, 'Teléfono', 'No registrado', Colors.grey),

          if (correos.isNotEmpty)
            ...correos.map((c) => _infoTile(
                  Icons.email_outlined,
                  'Correo',
                  c['correo'] ?? '-',
                  Colors.teal,
                ))
          else
            _infoTile(Icons.email_outlined, 'Correo', 'No registrado', Colors.grey),

          if (direcciones.isNotEmpty) ...[
            ...direcciones.map((d) {
              final sector = d['sector']?['nombre_sector'];
              final parts = <String>[
                if (d['parroquia'] != null && (d['parroquia'] as String).isNotEmpty)
                  'Par. ${d['parroquia']}',
                if (sector != null && sector.isNotEmpty) 'Sector $sector',
                if (d['calle'] != null && (d['calle'] as String).isNotEmpty)
                  'Calle ${d['calle']}',
                if (d['numero_casa'] != null && (d['numero_casa'] as String).isNotEmpty)
                  'Casa ${d['numero_casa']}',
                if (d['punto_referencia'] != null &&
                    (d['punto_referencia'] as String).isNotEmpty)
                  d['punto_referencia'],
              ];
              return _infoTile(
                Icons.location_on_outlined,
                'Dirección',
                parts.isNotEmpty ? parts.join(', ') : 'Sin detalle',
                Colors.teal,
              );
            })
          ] else
            _infoTile(Icons.location_on_outlined, 'Dirección', 'No registrada', Colors.grey),

          const SizedBox(height: 16),

          // ── Datos clínicos ──
          _sectionHeader(
            'Datos Clínicos',
            Icons.local_hospital_outlined,
            Colors.blue.shade700,
            action: OutlinedButton.icon(
              onPressed: () => _mostrarDialogoEditarDatosClinicos(p),
              icon: const Icon(Icons.edit_note_rounded, size: 16),
              label: const Text(
                'Editar / Completar',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue.shade700,
                side: BorderSide(color: Colors.blue.shade700, width: 1.2),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          _infoTile(Icons.monitor_weight_outlined, 'Peso',
              p['peso'] != null ? '${p['peso']} kg' : 'No registrado', Colors.blue),
          _infoTile(Icons.bloodtype, 'Tipo de Sangre', p['tipo_sangre'] ?? 'No registrado',
              Colors.red),
          _infoTile(
              Icons.warning_amber_outlined,
              'Alergias',
              (p['alergias'] == null || (p['alergias'] as String? ?? '').isEmpty)
                  ? 'Sin alergias registradas'
                  : p['alergias'],
              Colors.orange),
          _infoTile(
              Icons.local_hospital_outlined,
              'Enfermedades Crónicas',
              (p['enfermedades_cronicas'] == null ||
                      (p['enfermedades_cronicas'] as String? ?? '').isEmpty)
                  ? 'Ninguna registrada'
                  : p['enfermedades_cronicas'],
              Colors.purple),
          _infoTile(
              Icons.vaccines_outlined,
              'Vacunas Previas',
              (p['vacunas'] == null || (p['vacunas'] as String? ?? '').isEmpty)
                  ? 'No especificadas'
                  : p['vacunas'],
              Colors.green),
          _infoTile(
              Icons.accessibility_new,
              'Discapacidad',
              (p['discapacidad'] == null || (p['discapacidad'] as String? ?? '').isEmpty)
                  ? 'No registrada'
                  : p['discapacidad'],
              Colors.teal),
          _infoTile(
              Icons.family_restroom,
              'Antecedentes Familiares',
              (p['antecedentes_familiares'] == null ||
                      (p['antecedentes_familiares'] as String? ?? '').isEmpty)
                  ? 'No registrados'
                  : p['antecedentes_familiares'],
              Colors.indigo),

          if (representante != null) ...[
            const SizedBox(height: 16),
          _sectionHeader('Representante / Tutor', Icons.family_restroom, Colors.deepOrange),
            _infoTile(Icons.person_pin_outlined, 'Nombre', nombreRep, Colors.deepOrange),
            _infoTile(
                Icons.badge_outlined,
                'Cédula',
                cedulaRep,
                Colors.deepOrange),
            if (parentesco != null && parentesco.isNotEmpty)
              _infoTile(Icons.people_outline, 'Parentesco', parentesco, Colors.deepOrange),
            if (telefonoRep.isNotEmpty)
              _infoTile(Icons.phone, 'Teléfono', telefonoRep, Colors.deepOrange),
          ],

          const SizedBox(height: 16),

          // ── Total atenciones ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1565C0).withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.history, color: Color(0xFF1565C0)),
                const SizedBox(width: 12),
                Text(
                  'Total de atenciones: ${_historial!['total_atenciones'] ?? 0}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1565C0),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ───────────── Helpers ─────────────
  Widget _emptyState(IconData icon, String text) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 72, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(text, style: TextStyle(fontSize: 16, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1565C0),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _sectionHeader(String label, IconData icon, Color color, {Widget? action}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          if (action != null) action,
        ],
      ),
    );
  }

  Future<void> _mostrarDialogoEditarDatosClinicos(Map<String, dynamic> pacienteData) async {
    final idPaciente = pacienteData['id_paciente'] is int
        ? pacienteData['id_paciente'] as int
        : int.tryParse(pacienteData['id_paciente']?.toString() ?? '') ??
            int.tryParse(widget.pacienteId) ??
            0;

    if (idPaciente == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: No se pudo identificar el ID del paciente'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final actualizado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _EditarDatosClinicosDialog(
        idPaciente: idPaciente,
        pacienteData: pacienteData,
      ),
    );

    if (actualizado == true && mounted) {
      _loadHistorial();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 8),
              Text('Datos clínicos actualizados correctamente'),
            ],
          ),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
    }
  }

  Widget _infoTile(IconData icon, String label, String value, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 1,
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color, size: 18),
        ),
        title: Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        subtitle: Text(
          value,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
      ),
    );
  }

  Widget _chipInfo(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white70),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  String _formatDate(String date) {
    if (date.isEmpty) return 'Sin fecha';
    try {
      final d = DateTime.parse(date);
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return date;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DIÁLOGO PARA EDITAR/REGISTRAR DATOS CLÍNICOS DEL PACIENTE
// ─────────────────────────────────────────────────────────────────────────────
class _EditarDatosClinicosDialog extends StatefulWidget {
  final int idPaciente;
  final Map<String, dynamic> pacienteData;

  const _EditarDatosClinicosDialog({
    required this.idPaciente,
    required this.pacienteData,
  });

  @override
  State<_EditarDatosClinicosDialog> createState() => _EditarDatosClinicosDialogState();
}

class _EditarDatosClinicosDialogState extends State<_EditarDatosClinicosDialog> {
  final _api = ApiService();
  final _pesoCtrl = TextEditingController();
  String? _tipoSangre;
  final _alergiasCtrl = TextEditingController();
  final _enfermedadesCronicasCtrl = TextEditingController();
  final _vacunasPreviasCtrl = TextEditingController();
  final _discapacidadCtrl = TextEditingController();
  final _antecedentesFamiliaresCtrl = TextEditingController();

  bool _guardando = false;
  String? _error;

  static const _gruposSanguineos = [
    'O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-'
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.pacienteData;
    if (p['peso'] != null) {
      _pesoCtrl.text = p['peso'].toString();
    }
    final sang = p['tipo_sangre']?.toString().trim();
    if (sang != null && _gruposSanguineos.contains(sang)) {
      _tipoSangre = sang;
    }
    _alergiasCtrl.text = p['alergias']?.toString() ?? '';
    _enfermedadesCronicasCtrl.text = p['enfermedades_cronicas']?.toString() ?? '';
    _vacunasPreviasCtrl.text = p['vacunas']?.toString() ?? '';
    _discapacidadCtrl.text = p['discapacidad']?.toString() ?? '';
    _antecedentesFamiliaresCtrl.text = p['antecedentes_familiares']?.toString() ?? '';
  }

  @override
  void dispose() {
    _pesoCtrl.dispose();
    _alergiasCtrl.dispose();
    _enfermedadesCronicasCtrl.dispose();
    _vacunasPreviasCtrl.dispose();
    _discapacidadCtrl.dispose();
    _antecedentesFamiliaresCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() {
      _guardando = true;
      _error = null;
    });

    double? pesoVal;
    if (_pesoCtrl.text.trim().isNotEmpty) {
      pesoVal = double.tryParse(_pesoCtrl.text.trim().replaceAll(',', '.'));
      if (pesoVal == null || pesoVal <= 0 || pesoVal > 400) {
        setState(() {
          _guardando = false;
          _error = 'Ingrese un peso válido en kg (ej: 68.5)';
        });
        return;
      }
    }

    final res = await _api.actualizarDatosClinicos(
      idPaciente: widget.idPaciente,
      peso: pesoVal,
      tipoSangre: _tipoSangre,
      alergias: _alergiasCtrl.text.trim().isNotEmpty ? _alergiasCtrl.text.trim() : null,
      enfermedadesCronicas: _enfermedadesCronicasCtrl.text.trim().isNotEmpty ? _enfermedadesCronicasCtrl.text.trim() : null,
      vacunas: _vacunasPreviasCtrl.text.trim().isNotEmpty ? _vacunasPreviasCtrl.text.trim() : null,
      discapacidad: _discapacidadCtrl.text.trim().isNotEmpty ? _discapacidadCtrl.text.trim() : null,
      antecedentesFamiliares: _antecedentesFamiliaresCtrl.text.trim().isNotEmpty ? _antecedentesFamiliaresCtrl.text.trim() : null,
    );

    if (!mounted) return;
    setState(() => _guardando = false);

    if (res['success'] == true) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _error = res['message'] ?? 'Error al guardar los datos clínicos');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Encabezado
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Datos Clínicos del Paciente',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Actualización de ficha médica nominal',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(false),
                    splashRadius: 20,
                  ),
                ],
              ),
            ),

            // Formulario scrolleable
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('Peso (kg)'),
                              _textField(
                                controller: _pesoCtrl,
                                hint: 'Ej: 68.5',
                                icon: Icons.monitor_weight_outlined,
                                isNumber: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('Grupo Sanguíneo'),
                              DropdownButtonFormField<String>(
                                initialValue: _tipoSangre,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  isDense: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                  ),
                                ),
                                hint: const Text('Seleccionar', style: TextStyle(fontSize: 13)),
                                items: _gruposSanguineos
                                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                                    .toList(),
                                onChanged: (val) => setState(() => _tipoSangre = val),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    _label('Alergias Conocidas'),
                    _textField(
                      controller: _alergiasCtrl,
                      hint: 'Ej: Penicilina, sulfas, dipirona, mariscos...',
                      icon: Icons.warning_amber_rounded,
                    ),

                    const SizedBox(height: 12),
                    _label('Enfermedades Crónicas'),
                    _textField(
                      controller: _enfermedadesCronicasCtrl,
                      hint: 'Ej: Hipertensión arterial, Diabetes tipo 2, Asma...',
                      icon: Icons.favorite_border_rounded,
                    ),

                    const SizedBox(height: 12),
                    _label('Vacunas Previas'),
                    _textField(
                      controller: _vacunasPreviasCtrl,
                      hint: 'Ej: Esquema PAI al día, Pentavalente 3ra dosis...',
                      icon: Icons.vaccines_outlined,
                    ),

                    const SizedBox(height: 12),
                    _label('Discapacidad (si aplica)'),
                    _textField(
                      controller: _discapacidadCtrl,
                      hint: 'Ej: Ninguna, visual, auditiva, motora...',
                      icon: Icons.accessibility_new_rounded,
                    ),

                    const SizedBox(height: 12),
                    _label('Antecedentes Familiares Relevantes'),
                    _textField(
                      controller: _antecedentesFamiliaresCtrl,
                      hint: 'Ej: Madre diabética, Padre hipertenso...',
                      icon: Icons.family_restroom_rounded,
                    ),
                  ],
                ),
              ),
            ),

            // Footer botones
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _guardando ? null : () => Navigator.of(context).pop(false),
                    child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _guardando ? null : _guardar,
                    icon: _guardando
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_rounded, size: 18),
                    label: Text(_guardando ? 'Guardando...' : 'Guardar Datos'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF334155),
        ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isNumber = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        prefixIcon: Icon(icon, size: 18, color: Colors.blueGrey.shade400),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF1565C0), width: 1.5),
        ),
      ),
    );
  }
}

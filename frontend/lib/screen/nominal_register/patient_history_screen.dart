import 'package:flutter/material.dart';
import 'package:asis_guanipa_frontend/services/api_service.dart';

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
    final centro = a['centro']?['nombre_centro'] ?? 'Sin centro';
    final diagnosticos = (a['diagnosticos'] as List?) ?? [];
    final consumos = (a['consumos'] as List?) ?? [];
    final tratamientos = (a['tratamientos'] as List?) ?? [];

    // Separar tratamientos por tipo
    final indicaciones = tratamientos
        .where((t) => t['tipo_tratamiento'] == 'Indicación Médica')
        .toList();
    final observacionesList = tratamientos
        .where((t) => t['tipo_tratamiento'] == 'Observación Médica')
        .toList();
    final signosVitales = tratamientos
        .where((t) => t['tipo_tratamiento'] == 'Signos Vitales')
        .toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF1565C0).withValues(alpha: 0.1),
          child: const Icon(Icons.medical_services, color: Color(0xFF1565C0), size: 20),
        ),
        title: Text(
          fecha,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(centro, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (a['diagnostico_general'] != null &&
                    (a['diagnostico_general'] as String).isNotEmpty) ...[
                  _sectionLabel('Diagnóstico General / Motivo'),
                  Text(a['diagnostico_general'], style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 8),
                ],
                if (signosVitales.isNotEmpty) ...[
                  _sectionLabel('Signos Vitales'),
                  ...signosVitales.map((s) => Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.monitor_heart_outlined, size: 16, color: Colors.red.shade700),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            s['detalles'] ?? '',
                            style: TextStyle(fontSize: 13, color: Colors.red.shade900, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  )),
                  const SizedBox(height: 8),
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
          _sectionHeader('Datos Clínicos', Icons.local_hospital_outlined, Colors.blue.shade700),
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

  Widget _sectionHeader(String label, IconData icon, Color color) {
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
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
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

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:asis_guanipa_frontend/providers/auth_providers.dart';
import 'package:asis_guanipa_frontend/providers/guardia_provider.dart';
import 'package:asis_guanipa_frontend/services/api_service.dart';

class AperturaGuardiaDialog extends StatefulWidget {
  const AperturaGuardiaDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AperturaGuardiaDialog(),
    );
  }

  @override
  State<AperturaGuardiaDialog> createState() => _AperturaGuardiaDialogState();
}

class _AperturaGuardiaDialogState extends State<AperturaGuardiaDialog> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _api = ApiService();

  bool _loadingJornadas = false;
  List<Map<String, dynamic>> _jornadasDisponibles = [];
  Map<String, dynamic>? _selectedJornada;

  String _modalidad = 'intramural'; // 'intramural' | 'extramural'
  String _centroSalud = 'CDI Pedro Urbina';
  String _turno = 'Mañana (7:00 AM - 1:00 PM)';
  final _supervisorCtrl = TextEditingController();
  final _sectorCtrl = TextEditingController();
  final _termoCtrl = TextEditingController();
  final _liderCtrl = TextEditingController();
  final _temperaturaCtrl = TextEditingController(text: '4.0');

  static const _turnos = [
    'Mañana (7:00 AM - 1:00 PM)',
    'Tarde (1:00 PM - 7:00 PM)',
    'Noche (7:00 PM - 7:00 AM)',
    'Guardia 24 Horas',
  ];

  static const _centrosDisponibles = [
    'CDI Pedro Urbina',
    'CPT 1 (Consultorio Popular Tipo 1)',
    'CPT 2 (Consultorio Popular Tipo 2)',
    'CPT 3 (Consultorio Popular Tipo 3)',
  ];

  @override
  void initState() {
    super.initState();
    // Sugerir turno según la hora
    final hora = DateTime.now().hour;
    if (hora >= 7 && hora < 13) {
      _turno = 'Mañana (7:00 AM - 1:00 PM)';
    } else if (hora >= 13 && hora < 19) {
      _turno = 'Tarde (1:00 PM - 7:00 PM)';
    } else {
      _turno = 'Noche (7:00 PM - 7:00 AM)';
    }

    _cargarJornadas();

    // Autocompletar con usuario actual
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final u = auth.getCurrentUser();
      final username = u?.username ?? 'Personal de Guardia';
      _supervisorCtrl.text = username;
      _liderCtrl.text = username;
    });
  }

  Future<void> _cargarJornadas() async {
    setState(() => _loadingJornadas = true);
    try {
      final res = await _api.getOperativos();
      if (res['success'] == true && mounted) {
        final List data = res['data'] ?? [];
        final filtradas = data
            .map((e) => Map<String, dynamic>.from(e))
            .where((j) => (j['estado'] ?? '') == 'activa' || (j['estado'] ?? '') == 'planificada')
            .toList();
        setState(() {
          _jornadasDisponibles = filtradas;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingJornadas = false);
  }

  void _onJornadaSeleccionada(Map<String, dynamic>? j) {
    setState(() {
      _selectedJornada = j;
      if (j != null) {
        final mod = (j['modalidad'] ?? 'intramural').toString().toLowerCase();
        _modalidad = mod == 'extramural' ? 'extramural' : 'intramural';

        final resp = (j['responsable'] ?? '').toString().trim();
        if (resp.isNotEmpty) {
          _supervisorCtrl.text = resp;
          _liderCtrl.text = resp;
        }

        if (_modalidad == 'extramural') {
          final sec = (j['sector_comunidad'] ?? '').toString().trim();
          if (sec.isNotEmpty) {
            _sectorCtrl.text = sec;
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _supervisorCtrl.dispose();
    _sectorCtrl.dispose();
    _termoCtrl.dispose();
    _liderCtrl.dispose();
    _temperaturaCtrl.dispose();
    super.dispose();
  }

  void _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    final guardiaProv = Provider.of<GuardiaProvider>(context, listen: false);

    final idOp = _selectedJornada != null ? (_selectedJornada!['id_operativo'] as num?)?.toInt() : null;
    final nomOp = _selectedJornada != null ? _selectedJornada!['nombre_operativo']?.toString() : null;

    await guardiaProv.abrirGuardia(
      modalidad: _modalidad,
      centroSalud: _centroSalud,
      turno: _turno,
      supervisor: _supervisorCtrl.text.trim(),
      sectorComunidad: _modalidad == 'extramural' ? _sectorCtrl.text.trim() : null,
      termoId: _modalidad == 'extramural' ? _termoCtrl.text.trim() : null,
      liderJornada: _modalidad == 'extramural' ? _liderCtrl.text.trim() : null,
      temperaturaInicialTermo: _modalidad == 'extramural' ? _temperaturaCtrl.text.trim() : null,
      idOperativo: idOp,
      nombreJornada: nomOp,
      jornadaData: _selectedJornada,
    );

    if (!mounted) return;
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1565C0),
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _selectedJornada != null
                    ? 'Guardia iniciada y vinculada a "$nomOp"'
                    : (_modalidad == 'intramural'
                        ? 'Guardia Intramural iniciada en $_centroSalud ($turnoCorto)'
                        : 'Despliegue Extramural iniciado: ${_sectorCtrl.text.trim()}'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get turnoCorto {
    if (_turno.contains('Mañana')) return 'Turno Mañana';
    if (_turno.contains('Tarde')) return 'Turno Tarde';
    if (_turno.contains('Noche')) return 'Turno Noche';
    return '24 Horas';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 16,
      child: Container(
        width: isMobile ? size.width * 0.95 : 560,
        constraints: BoxConstraints(maxHeight: size.height * 0.90),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.shield_moon_rounded, color: Color(0xFF1565C0), size: 26),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Apertura de Guardia / Turno',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Planificación logística y asignación previa a la atención',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Form fields
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // SECCIÓN: Jornada de Vacunación
                      _buildSeccionJornada(),
                      const SizedBox(height: 18),

                      // Selector de Modalidad
                      const Text(
                        'MODALIDAD DE ATENCIÓN',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildModalidadCard(
                              id: 'intramural',
                              titulo: 'Intramural',
                              subtitulo: 'Atención dentro del CDI',
                              icon: Icons.local_hospital_rounded,
                              color: const Color(0xFF1565C0),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildModalidadCard(
                              id: 'extramural',
                              titulo: 'Extramural',
                              subtitulo: 'Jornada en Comunidad',
                              icon: Icons.airport_shuttle_rounded,
                              color: const Color(0xFF0D9488),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      if (_modalidad == 'intramural') ...[
                        // INTRAMURAL FIELDS
                        _buildLabel('Centro de Salud'),
                        DropdownButtonFormField<String>(
                          value: _centroSalud,
                          decoration: _inputDecoration(Icons.business_rounded),
                          items: _centrosDisponibles.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: (v) => setState(() => _centroSalud = v ?? _centroSalud),
                        ),
                        const SizedBox(height: 14),

                        _buildLabel('Turno de Guardia'),
                        DropdownButtonFormField<String>(
                          value: _turno,
                          decoration: _inputDecoration(Icons.schedule_rounded),
                          items: _turnos.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                          onChanged: (v) => setState(() => _turno = v ?? _turno),
                        ),
                        const SizedBox(height: 14),

                        _buildLabel('Responsable / Supervisor de Guardia'),
                        TextFormField(
                          controller: _supervisorCtrl,
                          decoration: _inputDecoration(Icons.person_rounded),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Ingrese el responsable de guardia' : null,
                        ),
                      ] else ...[
                        // EXTRAMURAL FIELDS
                        _buildLabel('Sector o Comunidad de Destino'),
                        TextFormField(
                          controller: _sectorCtrl,
                          decoration: _inputDecoration(Icons.location_on_rounded, hint: 'Ej. Sector San José, Vista Al Sol'),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Ingrese el sector o comunidad destino' : null,
                        ),
                        const SizedBox(height: 14),

                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('Identificador de Termo'),
                                  TextFormField(
                                    controller: _termoCtrl,
                                    decoration: _inputDecoration(Icons.inventory_2_rounded, hint: 'Ej. Termo #1 (KST-01)'),
                                    validator: (v) => v == null || v.trim().isEmpty ? 'Indique el termo' : null,
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
                                  _buildLabel('Temp. Inicial (°C)'),
                                  TextFormField(
                                    controller: _temperaturaCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: _inputDecoration(Icons.thermostat_rounded, hint: '+4.0'),
                                    validator: (v) => v == null || v.trim().isEmpty ? 'Temp.' : null,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        _buildLabel('Líder de Despliegue / Vacunador Responsable'),
                        TextFormField(
                          controller: _liderCtrl,
                          decoration: _inputDecoration(Icons.badge_rounded),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Ingrese el nombre del líder de despliegue' : null,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Botones de acción
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _guardar,
                    icon: const Icon(Icons.play_arrow_rounded, size: 20),
                    label: const Text('Iniciar Guardia'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _modalidad == 'intramural' ? const Color(0xFF1565C0) : const Color(0xFF0D9488),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSeccionJornada() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.campaign_rounded, color: Color(0xFF1565C0), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'JORNADA DE VACUNACIÓN (OPCIONAL)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              if (_loadingJornadas)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Si seleccionas una jornada, tu guardia se vinculará directamente a ella y trabajarás con su stock reservado al entrar al registro de inmunización.',
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.3),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<Map<String, dynamic>?>(
            value: _selectedJornada,
            isExpanded: true,
            decoration: _inputDecoration(
              Icons.event_available_rounded,
              hint: 'Seleccionar jornada activa o planificada...',
            ),
            items: [
              const DropdownMenuItem<Map<String, dynamic>?>(
                value: null,
                child: Text(
                  'Ninguna (Guardia ordinaria / General CDI)',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
              ),
              ..._jornadasDisponibles.map((j) {
                final nombre = j['nombre_operativo'] ?? 'Jornada';
                final mod = (j['modalidad'] ?? 'intramural').toString().toUpperCase();
                final sector = j['sector_comunidad'] ?? 'CDI';
                final estado = (j['estado'] ?? 'activa').toString().toUpperCase();

                return DropdownMenuItem<Map<String, dynamic>?>(
                  value: j,
                  child: Text(
                    '[$estado] [$mod] $nombre ($sector)',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }),
            ],
            onChanged: (val) {
              _onJornadaSeleccionada(val);
            },
          ),
          if (_selectedJornada != null) ...[
            const SizedBox(height: 10),
            _buildJornadaSeleccionadaCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildJornadaSeleccionadaCard() {
    final j = _selectedJornada!;
    final isExt = (j['modalidad'] ?? 'intramural').toString().toLowerCase() == 'extramural';
    final nombre = j['nombre_operativo'] ?? 'Jornada';
    final resp = j['responsable'] ?? 'Sin asignar';
    final sector = j['sector_comunidad'] ?? 'CDI Pedro Urbina';
    final List stock = j['stockBloqueado'] ?? [];

    // Parse participantes
    final rawPersonal = j['personal_participante'];
    String personalStr = '';
    if (rawPersonal is List) {
      personalStr = rawPersonal.map((p) => p is Map ? (p['username'] ?? '') : p.toString()).join(', ');
    } else if (rawPersonal is String && rawPersonal.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawPersonal);
        if (decoded is List) {
          personalStr = decoded.map((p) => p is Map ? (p['username'] ?? '') : p.toString()).join(', ');
        } else {
          personalStr = rawPersonal;
        }
      } catch (_) {
        personalStr = rawPersonal;
      }
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isExt ? const Color(0xFFFAF5FF) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isExt ? const Color(0xFFD8B4FE) : const Color(0xFF86EFAC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isExt ? Icons.terrain_rounded : Icons.local_hospital_rounded,
                size: 18,
                color: isExt ? const Color(0xFF7B1FA2) : const Color(0xFF15803D),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  nombre,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isExt ? const Color(0xFF581C87) : const Color(0xFF14532D),
                  ),
                ),
              ),
              InkWell(
                onTap: () => _onJornadaSeleccionada(null),
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Lugar: $sector  •  Resp: @$resp',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (stock.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Text(
                    '${stock.length} lote(s) con stock reservado',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                  ),
                ),
              ],
            ],
          ),
          if (personalStr.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              'Personal asignado: $personalStr',
              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 6),
          const Row(
            children: [
              Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF16A34A)),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Al entrar a Inmunizaciones estarás asignado automáticamente a esta jornada.',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF15803D)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModalidadCard({
    required String id,
    required String titulo,
    required String subtitulo,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _modalidad == id;
    return InkWell(
      onTap: () => setState(() => _modalidad = id),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : const Color(0xFF94A3B8), size: 28),
            const SizedBox(height: 6),
            Text(
              titulo,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isSelected ? color : const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitulo,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? color.withValues(alpha: 0.8) : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF334155),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(IconData icon, {String? hint}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 20),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF1565C0), width: 1.8),
      ),
    );
  }
}

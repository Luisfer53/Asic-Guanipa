import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:asis_guanipa_frontend/services/api_service.dart';
import 'package:asis_guanipa_frontend/providers/auth_providers.dart';

const _sectoresGuanipa = [
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
];

class _ItemStockBloqueo {
  Map<String, dynamic>? lote;
  int cantidad;
  _ItemStockBloqueo({this.lote, this.cantidad = 1});
}

class CrearJornadaDialog extends StatefulWidget {
  const CrearJornadaDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const CrearJornadaDialog(),
    );
  }

  @override
  State<CrearJornadaDialog> createState() => _CrearJornadaDialogState();
}

class _CrearJornadaDialogState extends State<CrearJornadaDialog> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _api = ApiService();

  String _modalidad = 'intramural'; // 'intramural' o 'extramural'
  final _nombreCtrl = TextEditingController();
  final _responsableCtrl = TextEditingController();
  final _personalCtrl = TextEditingController();
  final _sectorCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();

  DateTime _fecha = DateTime.now();
  String _centroSalud = 'CDI Pedro Urbina';
  int _idCentroOrganizador = 1;

  bool _loadingInventario = true;
  bool _loadingPersonal = true;
  bool _saving = false;

  List<Map<String, dynamic>> _lotesDisponibles = [];
  final List<_ItemStockBloqueo> _itemsBloqueo = [];

  List<Map<String, dynamic>> _personalDisponible = [];
  Map<String, dynamic>? _selectedResponsable;
  final Set<String> _selectedParticipantesUsernames = {};

  static const _primary = Color(0xFF1565C0);
  static const _teal = Color(0xFF00897B);

  @override
  void initState() {
    super.initState();
    _initDefaults();
    _cargarLotes();
    _cargarPersonal();
  }

  void _initDefaults() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final user = auth.getCurrentUser();
      final username = user?.username ?? 'Coordinador de Inmunización';
      _responsableCtrl.text = username;
      _personalCtrl.text = '$username (Responsable)';
      _nombreCtrl.text = 'Jornada de Inmunización ${DateFormat('dd/MM/yyyy').format(_fecha)}';
    });
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _responsableCtrl.dispose();
    _personalCtrl.dispose();
    _sectorCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarLotes() async {
    setState(() => _loadingInventario = true);
    try {
      final res = await _api.getInventario();
      if (res['success'] == true) {
        final List data = res['data'] ?? [];
        final today = DateTime.now();

        _lotesDisponibles = data
            .where((l) {
              final exp = DateTime.tryParse(l['fecha_vencimiento'] ?? '');
              final stockAct = (l['stock_actual'] ?? 0) as int;
              final stockRes = (l['stock_reservado'] ?? 0) as int;
              final stockLibre = stockAct - stockRes;
              return exp != null && exp.isAfter(today) && stockLibre > 0;
            })
            .map((l) => Map<String, dynamic>.from(l))
            .toList();

        // Agregar una fila inicial para facilitar el bloqueo
        if (_lotesDisponibles.isNotEmpty && _itemsBloqueo.isEmpty) {
          _itemsBloqueo.add(_ItemStockBloqueo(
            lote: _lotesDisponibles.first,
            cantidad: 10,
          ));
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingInventario = false);
  }

  Future<void> _cargarPersonal() async {
    setState(() => _loadingPersonal = true);
    try {
      final res = await _api.getPersonalDisponible();
      if (res['success'] == true) {
        final List data = res['data'] ?? [];
        _personalDisponible = data.map((e) => Map<String, dynamic>.from(e)).toList();

        final auth = Provider.of<AuthProvider>(context, listen: false);
        final currentUsername = auth.getCurrentUser()?.username?.toLowerCase() ?? '';

        final currentUserObj = _personalDisponible.firstWhere(
          (u) => (u['username'] ?? '').toString().toLowerCase() == currentUsername,
          orElse: () => _personalDisponible.isNotEmpty ? _personalDisponible.first : {},
        );

        if (currentUserObj.isNotEmpty) {
          _selectedResponsable = currentUserObj;
          _responsableCtrl.text = currentUserObj['username'] ?? '';
          _selectedParticipantesUsernames.add(currentUserObj['username'] ?? '');
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingPersonal = false);
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    if (_modalidad == 'extramural' && _sectorCtrl.text.trim().isEmpty) {
      _showToast('Por favor indique el sector o comunidad de la jornada extramural', isError: true);
      return;
    }

    // Validar stock seleccionado
    final lotesPayload = <Map<String, dynamic>>[];
    for (final item in _itemsBloqueo) {
      if (item.lote != null && item.cantidad > 0) {
        final idLote = item.lote!['id_lote_insumo'] ?? item.lote!['id_lote'];
        final stockLibre = ((item.lote!['stock_actual'] ?? 0) as int) - ((item.lote!['stock_reservado'] ?? 0) as int);

        if (item.cantidad > stockLibre) {
          final nomArt = item.lote!['articulo']?['nombre_articulo'] ?? 'Insumo';
          _showToast('La cantidad ($item.cantidad) excede el stock libre disponible ($stockLibre) de $nomArt', isError: true);
          return;
        }

        lotesPayload.add({
          'id_lote_insumo': idLote,
          'cantidad': item.cantidad,
        });
      }
    }

    final participantesList = _selectedParticipantesUsernames.toList();
    if (participantesList.isEmpty && _responsableCtrl.text.isNotEmpty) {
      participantesList.add(_responsableCtrl.text.trim());
    }

    try {
      final res = await _api.crearOperativo(
        nombreOperativo: _nombreCtrl.text.trim(),
        modalidad: _modalidad,
        fechaOperativo: DateFormat('yyyy-MM-dd').format(_fecha),
        idCentroOrganizador: _idCentroOrganizador,
        sectorComunidad: _modalidad == 'extramural' ? _sectorCtrl.text.trim() : null,
        responsable: _responsableCtrl.text.trim(),
        personalParticipante: jsonEncode(participantesList),
        descripcion: _descripcionCtrl.text.trim(),
        lotesBloqueados: lotesPayload,
      );

      if (res['success'] == true) {
        if (!mounted) return;
        Navigator.of(context).pop(true);
        _showToast('¡Jornada de vacunación creada con stock bloqueado!', isError: false);
      } else {
        _showToast(res['message'] ?? 'Error al crear la jornada', isError: true);
      }
    } catch (e) {
      _showToast('Error de red al guardar la jornada: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showToast(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade700 : const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isExtramural = _modalidad == 'extramural';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 720),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isExtramural
                      ? [const Color(0xFF4A148C), const Color(0xFF7B1FA2)]
                      : [_primary, const Color(0xFF1976D2)],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isExtramural ? Icons.groups_rounded : Icons.local_hospital_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isExtramural ? 'Crear Jornada Extramural (Comunitaria)' : 'Crear Jornada Intramural (En CDI)',
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          isExtramural
                              ? 'Planificación y asignación de biológicos para despliegue en campo'
                              : 'Campaña especial o jornada masiva dentro de las instalaciones del CDI',
                          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Selector de Modalidad (Intramural vs Extramural)
                      const Text(
                        'Modalidad de la Jornada',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildModalidadCard(
                              title: 'Dentro del CDI (Intramural)',
                              subtitle: 'Puesto fijo central en sala de inmunización',
                              icon: Icons.local_hospital_rounded,
                              isSelected: _modalidad == 'intramural',
                              activeColor: _primary,
                              onTap: () => setState(() => _modalidad = 'intramural'),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildModalidadCard(
                              title: 'Jornada Extramural (Comunidad)',
                              subtitle: 'Despliegue móvil en sector o escuela',
                              icon: Icons.terrain_rounded,
                              isSelected: _modalidad == 'extramural',
                              activeColor: const Color(0xFF7B1FA2),
                              onTap: () => setState(() => _modalidad = 'extramural'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Datos Generales
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Nombre de la jornada
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _nombreCtrl,
                              decoration: InputDecoration(
                                labelText: 'Nombre de la Jornada *',
                                hintText: 'Ej. Campaña Pentavalente y Polio - Sector Casco Viejo',
                                prefixIcon: const Icon(Icons.campaign_rounded, color: _primary),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                            ),
                          ),
                          const SizedBox(width: 14),
                          // Selector de Fecha
                          Expanded(
                            flex: 2,
                            child: InkWell(
                              onTap: _pickFecha,
                              borderRadius: BorderRadius.circular(10),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Fecha de la Jornada *',
                                  prefixIcon: const Icon(Icons.calendar_today_rounded, color: _primary),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: Text(
                                  DateFormat('dd/MM/yyyy').format(_fecha),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Ubicación / Sector
                      if (isExtramural) ...[
                        Autocomplete<String>(
                          initialValue: TextEditingValue(text: _sectorCtrl.text),
                          optionsBuilder: (textEditingValue) {
                            if (textEditingValue.text.isEmpty) return _sectoresGuanipa;
                            return _sectoresGuanipa.where((s) =>
                                s.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                          },
                          onSelected: (selection) => _sectorCtrl.text = selection,
                          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                            controller.addListener(() => _sectorCtrl.text = controller.text);
                            return TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                labelText: 'Sector o Comunidad de Guanipa *',
                                hintText: 'Escriba o seleccione el sector de despliegue',
                                prefixIcon: const Icon(Icons.place_rounded, color: Color(0xFF7B1FA2)),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Indique el sector comunitario' : null,
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                      ] else ...[
                        InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Centro Organizador / Sede',
                            prefixIcon: const Icon(Icons.domain_rounded, color: _primary),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(_centroSalud, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ─── RESPONSABLE Y PARTICIPANTES CON ROLES AUTORIZADOS ───
                      const Text(
                        'Responsable de la Jornada *',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 6),
                      if (_loadingPersonal)
                        const LinearProgressIndicator()
                      else if (_personalDisponible.isEmpty)
                        TextFormField(
                          controller: _responsableCtrl,
                          decoration: InputDecoration(
                            hintText: 'Username del responsable',
                            prefixIcon: const Icon(Icons.person_pin_rounded, color: _teal),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                        )
                      else
                        DropdownButtonFormField<Map<String, dynamic>>(
                          value: _selectedResponsable,
                          isExpanded: true,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.person_pin_rounded, color: _teal),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          items: _personalDisponible.map((u) {
                            final nom = u['nombre_completo'] ?? u['username'];
                            final r = (u['roles'] as List?)?.join(', ') ?? '';
                            return DropdownMenuItem(
                              value: u,
                              child: Text(
                                '$nom ($r) - @${u['username']}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedResponsable = val;
                              if (val != null) {
                                _responsableCtrl.text = val['username'] ?? '';
                                _selectedParticipantesUsernames.add(val['username'] ?? '');
                              }
                            });
                          },
                          validator: (v) => v == null && _responsableCtrl.text.isEmpty ? 'Seleccione responsable' : null,
                        ),
                      const SizedBox(height: 16),

                      // Selector de Personal Participante Autorizado
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.badge_rounded, color: Color(0xFF0F766E), size: 20),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Personal Participante Autorizado (Roles Permitidos)',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                                      ),
                                      Text(
                                        'Solo los usuarios seleccionados aquí tendrán permiso para registrar inmunizaciones asociadas a esta jornada.',
                                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_personalDisponible.isNotEmpty)
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        if (_selectedParticipantesUsernames.length == _personalDisponible.length) {
                                          _selectedParticipantesUsernames.clear();
                                          if (_selectedResponsable != null) {
                                            _selectedParticipantesUsernames.add(_selectedResponsable!['username']);
                                          }
                                        } else {
                                          _selectedParticipantesUsernames.addAll(
                                            _personalDisponible.map((u) => u['username'] as String),
                                          );
                                        }
                                      });
                                    },
                                    child: Text(
                                      _selectedParticipantesUsernames.length == _personalDisponible.length
                                          ? 'Deseleccionar'
                                          : 'Seleccionar Todos',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            if (_loadingPersonal)
                              const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
                            else if (_personalDisponible.isEmpty)
                              Text(
                                'No se encontraron usuarios con roles autorizados activos (Médico, Enfermería, Inmunizador, Admin).',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                              )
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _personalDisponible.map((u) {
                                  final username = u['username'] as String? ?? '';
                                  final nom = u['nombre_completo'] ?? username;
                                  final rolesStr = (u['roles'] as List?)?.join(', ') ?? '';
                                  final isSelected = _selectedParticipantesUsernames.contains(username);
                                  final isResp = _selectedResponsable != null && _selectedResponsable!['username'] == username;

                                  return FilterChip(
                                    selected: isSelected,
                                    showCheckmark: true,
                                    avatar: CircleAvatar(
                                      backgroundColor: isSelected ? Colors.white : const Color(0xFF0F766E),
                                      child: Text(
                                        nom.isNotEmpty ? nom[0].toUpperCase() : 'U',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected ? const Color(0xFF0F766E) : Colors.white,
                                        ),
                                      ),
                                    ),
                                    label: Text(
                                      '$nom (@$username) • $rolesStr${isResp ? " [Líder]" : ""}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        color: isSelected ? Colors.white : const Color(0xFF1E293B),
                                      ),
                                    ),
                                    selectedColor: const Color(0xFF0F766E),
                                    backgroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      side: BorderSide(
                                        color: isSelected ? const Color(0xFF0F766E) : const Color(0xFFCBD5E1),
                                      ),
                                    ),
                                    onSelected: (selected) {
                                      setState(() {
                                        if (selected) {
                                          _selectedParticipantesUsernames.add(username);
                                        } else {
                                          _selectedParticipantesUsernames.remove(username);
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ─── SECCIÓN: STOCK BLOQUEADO / RESERVADO ────────────────
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade100,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.lock_clock_rounded, color: Colors.amber.shade900, size: 20),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Stock Bloqueado Exclusivo para esta Jornada',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                                      ),
                                      Text(
                                        'Las dosis asignadas aquí quedarán reservadas para esta jornada y no podrán consumirse en atenciones rutinarias.',
                                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    foregroundColor: _primary,
                                    backgroundColor: Colors.blue.shade50,
                                  ),
                                  icon: const Icon(Icons.add_rounded, size: 18),
                                  label: const Text('Agregar Lote', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  onPressed: _agregarItemBloqueo,
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            if (_loadingInventario)
                              const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
                            else if (_itemsBloqueo.isEmpty)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  child: Text(
                                    'No ha seleccionado stock bloqueado. Pulse "+ Agregar Lote" para reservar biológicos.',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                  ),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _itemsBloqueo.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final item = _itemsBloqueo[index];
                                  final stockLibre = item.lote != null
                                      ? (((item.lote!['stock_actual'] ?? 0) as int) - ((item.lote!['stock_reservado'] ?? 0) as int))
                                      : 0;

                                  return Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                    ),
                                    child: Row(
                                      children: [
                                        // Selector de Lote
                                        Expanded(
                                          flex: 4,
                                          child: DropdownButtonFormField<Map<String, dynamic>>(
                                            value: item.lote,
                                            isExpanded: true,
                                            decoration: const InputDecoration(
                                              labelText: 'Vacuna / Insumo',
                                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                              border: OutlineInputBorder(),
                                            ),
                                            items: _lotesDisponibles.map((lote) {
                                              final art = lote['articulo'] ?? {};
                                              final nomArt = art['nombre_articulo'] ?? lote['nombre_articulo'] ?? 'Vacuna';
                                              final numLote = lote['numero_lote'] ?? '';
                                              final libre = ((lote['stock_actual'] ?? 0) as int) - ((lote['stock_reservado'] ?? 0) as int);
                                              return DropdownMenuItem(
                                                value: lote,
                                                child: Text(
                                                  '$nomArt [Lote: $numLote] (Libre: $libre)',
                                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              );
                                            }).toList(),
                                            onChanged: (val) {
                                              setState(() {
                                                item.lote = val;
                                                final maxLibre = val != null
                                                    ? (((val['stock_actual'] ?? 0) as int) - ((val['stock_reservado'] ?? 0) as int))
                                                    : 1;
                                                if (item.cantidad > maxLibre) {
                                                  item.cantidad = maxLibre;
                                                }
                                              });
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 12),

                                        // Cantidad a bloquear
                                        SizedBox(
                                          width: 140,
                                          child: TextFormField(
                                            initialValue: item.cantidad.toString(),
                                            keyboardType: TextInputType.number,
                                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                            decoration: InputDecoration(
                                              labelText: 'Cant. Bloquear',
                                              helperText: 'Máx: $stockLibre',
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                              border: const OutlineInputBorder(),
                                            ),
                                            onChanged: (val) {
                                              final parsed = int.tryParse(val) ?? 0;
                                              item.cantidad = parsed;
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),

                                        // Botón eliminar fila
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                                          tooltip: 'Quitar insumo',
                                          onPressed: () => setState(() => _itemsBloqueo.removeAt(index)),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Observaciones / Notas
                      TextFormField(
                        controller: _descripcionCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Notas u Observaciones del Operativo (Opcional)',
                          hintText: 'Metas de vacunación, puntos de hidratación, ruta de transporte, etc.',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 14),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isExtramural ? const Color(0xFF7B1FA2) : _primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.lock_rounded, size: 18),
                    label: Text(
                      _saving ? 'Guardando y Bloqueando...' : 'Crear y Bloquear Stock',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    onPressed: _saving ? null : _guardar,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModalidadCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFFCBD5E1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? activeColor : Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isSelected ? Colors.white : Colors.grey.shade600, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isSelected ? activeColor : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _agregarItemBloqueo() {
    if (_lotesDisponibles.isEmpty) {
      _showToast('No hay lotes con stock libre disponible para reservar', isError: true);
      return;
    }
    setState(() {
      _itemsBloqueo.add(_ItemStockBloqueo(
        lote: _lotesDisponibles.first,
        cantidad: 10,
      ));
    });
  }

  Future<void> _pickFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );
    if (picked != null) {
      setState(() => _fecha = picked);
    }
  }
}

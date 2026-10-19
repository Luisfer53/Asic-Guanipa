import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:asis_guanipa_frontend/services/api_service.dart';
import 'crear_jornada_dialog.dart';

class GestionarJornadasDialog extends StatefulWidget {
  final Map<String, dynamic>? jornadaActivaActual;
  final Function(Map<String, dynamic>)? onSeleccionarJornadaActiva;

  const GestionarJornadasDialog({
    super.key,
    this.jornadaActivaActual,
    this.onSeleccionarJornadaActiva,
  });

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    Map<String, dynamic>? jornadaActivaActual,
    Function(Map<String, dynamic>)? onSeleccionarJornadaActiva,
  }) {
    return showDialog<Map<String, dynamic>?>(
      context: context,
      barrierDismissible: true,
      builder: (context) => GestionarJornadasDialog(
        jornadaActivaActual: jornadaActivaActual,
        onSeleccionarJornadaActiva: onSeleccionarJornadaActiva,
      ),
    );
  }

  @override
  State<GestionarJornadasDialog> createState() => _GestionarJornadasDialogState();
}

class _GestionarJornadasDialogState extends State<GestionarJornadasDialog> {
  final ApiService _api = ApiService();
  bool _loading = true;
  List<Map<String, dynamic>> _jornadas = [];
  String _filtroEstado = 'todas'; // 'todas', 'activa', 'planificada', 'finalizada'

  static const _primary = Color(0xFF1565C0);
  static const _green = Color(0xFF2E7D32);
  static const _purple = Color(0xFF7B1FA2);

  @override
  void initState() {
    super.initState();
    _cargarJornadas();
  }

  Future<void> _cargarJornadas() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getOperativos();
      if (res['success'] == true) {
        final List data = res['data'] ?? [];
        _jornadas = data.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _cambiarEstado(int id, String nuevoEstado) async {
    final conf = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(nuevoEstado == 'finalizada' ? '¿Finalizar Jornada?' : '¿Cambiar Estado?'),
        content: Text(
          nuevoEstado == 'finalizada'
              ? 'Al finalizar la jornada, todo el stock remanente que no se utilizó será liberado automáticamente y devuelto al inventario disponible del CDI.'
              : '¿Desea cambiar el estado a "$nuevoEstado"?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: nuevoEstado == 'finalizada' ? Colors.orange.shade800 : _primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (conf != true) return;

    try {
      final res = await _api.cambiarEstadoOperativo(id, nuevoEstado);
      if (res['success'] == true) {
        _showToast(res['message'] ?? 'Estado actualizado');
        _cargarJornadas();
      } else {
        _showToast(res['message'] ?? 'Error al actualizar', isError: true);
      }
    } catch (e) {
      _showToast('Error de red: $e', isError: true);
    }
  }

  void _showToast(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade700 : _green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtradas = _jornadas.where((j) {
      if (_filtroEstado == 'todas') return true;
      return (j['estado'] ?? 'planificada').toString().toLowerCase() == _filtroEstado;
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880, maxHeight: 720),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.vaccines_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Jornadas de Vacunación y Stock Bloqueado',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Control de operativos intramurales y extramurales con biológicos reservados',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Nueva Jornada', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    onPressed: () async {
                      final ok = await CrearJornadaDialog.show(context);
                      if (ok == true) _cargarJornadas();
                    },
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Filtros de estado
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              color: const Color(0xFFF8FAFC),
              child: Row(
                children: [
                  const Text('Filtrar:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF64748B))),
                  const SizedBox(width: 12),
                  _buildFilterChip('Todas', 'todas'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Activas', 'activa', color: Colors.blue),
                  const SizedBox(width: 8),
                  _buildFilterChip('Planificadas', 'planificada', color: Colors.amber),
                  const SizedBox(width: 8),
                  _buildFilterChip('Finalizadas', 'finalizada', color: Colors.green),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
                    tooltip: 'Recargar lista',
                    onPressed: _cargarJornadas,
                  ),
                ],
              ),
            ),

            // Contenido
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : filtradas.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.event_busy_rounded, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 14),
                              Text(
                                'No hay jornadas registradas con el filtro actual.',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Crear Primera Jornada'),
                                style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white),
                                onPressed: () async {
                                  final ok = await CrearJornadaDialog.show(context);
                                  if (ok == true) _cargarJornadas();
                                },
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(20),
                          itemCount: filtradas.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            return _buildJornadaCard(filtradas[index]);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, {Color? color}) {
    final isSelected = _filtroEstado == value;
    final activeColor = color ?? _primary;

    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : const Color(0xFF334155),
        ),
      ),
      selected: isSelected,
      selectedColor: activeColor,
      backgroundColor: Colors.white,
      side: BorderSide(color: isSelected ? activeColor : const Color(0xFFCBD5E1)),
      onSelected: (_) => setState(() => _filtroEstado = value),
    );
  }

  Widget _buildJornadaCard(Map<String, dynamic> j) {
    final idOp = j['id_operativo'];
    final nombre = j['nombre_operativo'] ?? 'Jornada Sin Nombre';
    final modalidad = (j['modalidad'] ?? 'intramural').toString().toLowerCase();
    final isExtramural = modalidad == 'extramural';
    final estado = (j['estado'] ?? 'planificada').toString().toLowerCase();
    final fecha = j['fecha_operativo'] != null ? DateFormat('dd/MM/yyyy').format(DateTime.parse(j['fecha_operativo'])) : 'Sin fecha';
    final sector = j['sector_comunidad'] ?? j['lugar'];
    final centro = j['centroOrganizador']?['nombre_centro'] ?? 'CDI Pedro Urbina';
    final responsable = j['responsable'] ?? 'No especificado';
    final personal = j['personal_participante'] ?? '';

    // Formatear participantes si están en JSON
    String personalStr = '';
    if (personal is List) {
      personalStr = personal.map((p) => p is Map ? (p['username'] ?? '') : p.toString()).join(', ');
    } else if (personal is String && personal.isNotEmpty) {
      try {
        final decoded = jsonDecode(personal);
        if (decoded is List) {
          personalStr = decoded.map((p) => p is Map ? (p['username'] ?? '') : p.toString()).join(', ');
        } else {
          personalStr = personal;
        }
      } catch (_) {
        personalStr = personal;
      }
    }

    final List stockBloqueado = j['stockBloqueado'] ?? [];

    final isActivaActualmente = widget.jornadaActivaActual != null &&
        widget.jornadaActivaActual!['id_operativo'] == idOp;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActivaActualmente
              ? _green
              : (isExtramural ? _purple.withOpacity(0.3) : const Color(0xFFE2E8F0)),
          width: isActivaActualmente ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Barra de cabecera de la tarjeta
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isExtramural ? const Color(0xFFF3E8FF) : const Color(0xFFEFF6FF),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
            ),
            child: Row(
              children: [
                Icon(
                  isExtramural ? Icons.terrain_rounded : Icons.local_hospital_rounded,
                  color: isExtramural ? _purple : _primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isExtramural ? 'EXTRAMURAL' : 'INTRAMURAL',
                  style: TextStyle(
                    color: isExtramural ? _purple : _primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 10),
                _buildBadgeEstado(estado),
                if (isActivaActualmente) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, color: Colors.white, size: 12),
                        SizedBox(width: 4),
                        Text('Jornada en Curso', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                Text(fecha, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
              ],
            ),
          ),

          // Cuerpo de la tarjeta
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 8),

                // Ubicación y Responsables
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow(
                            Icons.place_rounded,
                            'Ubicación:',
                            isExtramural ? 'Sector: $sector' : 'Sede: $centro',
                            iconColor: isExtramural ? _purple : _primary,
                          ),
                          const SizedBox(height: 4),
                          _buildInfoRow(
                            Icons.person_pin_rounded,
                            'Responsable:',
                            responsable,
                            iconColor: const Color(0xFF00897B),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow(
                            Icons.groups_outlined,
                            'Personal Asignado:',
                            personalStr.isNotEmpty ? personalStr : 'Solo el responsable',
                            iconColor: const Color(0xFF475569),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ─── STOCK BLOQUEADO ───
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.lock_clock_rounded, size: 15, color: Colors.amber),
                          const SizedBox(width: 6),
                          const Text(
                            'Stock Bloqueado / Reservado:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF334155)),
                          ),
                          const Spacer(),
                          Text(
                            '${stockBloqueado.length} biológico(s)',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (stockBloqueado.isEmpty)
                        Text(
                          'No se reservó stock específico para esta jornada.',
                          style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey.shade500),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: stockBloqueado.map<Widget>((st) {
                            final lote = st['lote'] ?? {};
                            final art = lote['articulo'] ?? {};
                            final nomArt = art['nombre_articulo'] ?? 'Biológico';
                            final numLote = lote['numero_lote'] ?? '';
                            final bloq = st['cantidad_bloqueada'] ?? 0;
                            final usada = st['cantidad_usada'] ?? 0;
                            final rem = st['cantidad_remanente'] ?? 0;

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.vaccines_outlined, size: 14, color: _primary),
                                  const SizedBox(width: 5),
                                  Text(
                                    '$nomArt (Lote: $numLote): ',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                  ),
                                  Text(
                                    '$usada aplicadas / $bloq bloq. ',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: rem > 0 ? Colors.green.shade50 : Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Remanente: $rem',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: rem > 0 ? Colors.green.shade800 : Colors.red.shade800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Botones de acción
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (estado != 'finalizada' && estado != 'cancelada') ...[
                      // Botón Activar / Seleccionar para trabajar
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isActivaActualmente ? Colors.grey.shade600 : _primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: Icon(
                          isActivaActualmente ? Icons.check_rounded : Icons.play_arrow_rounded,
                          size: 16,
                        ),
                        label: Text(
                          isActivaActualmente ? 'Jornada Seleccionada' : 'Seleccionar Jornada',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          if (widget.onSeleccionarJornadaActiva != null) {
                            widget.onSeleccionarJornadaActiva!(j);
                          }
                          Navigator.of(context).pop(j);
                        },
                      ),
                      const SizedBox(width: 8),

                      // Finalizar Jornada (libera stock remanente)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange.shade800,
                          side: BorderSide(color: Colors.orange.shade400),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.flag_rounded, size: 16),
                        label: const Text('Finalizar y Liberar Stock', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () => _cambiarEstado(idOp, 'finalizada'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeEstado(String estado) {
    Color bg;
    Color fg;
    String label = estado.toUpperCase();

    switch (estado) {
      case 'activa':
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade800;
        break;
      case 'planificada':
        bg = Colors.amber.shade50;
        fg = Colors.amber.shade900;
        break;
      case 'finalizada':
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        break;
      case 'cancelada':
        bg = Colors.red.shade50;
        fg = Colors.red.shade800;
        break;
      default:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Color? iconColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: iconColor ?? const Color(0xFF64748B)),
        const SizedBox(width: 6),
        Text(
          '$label ',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

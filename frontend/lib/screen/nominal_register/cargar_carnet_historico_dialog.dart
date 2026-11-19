import 'package:flutter/material.dart';
import 'package:asis_guanipa_frontend/services/api_service.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// CARGA HISTÓRICA DE CARNET DE VACUNACIÓN
/// Permite registrar vacunas aplicadas en otro establecimiento o antes de que
/// el paciente fuera registrado en este sistema. No descuenta stock.
/// ─────────────────────────────────────────────────────────────────────────────

class CargarCarnetHistoricoDialog extends StatefulWidget {
  final int idPaciente;
  final String nombrePaciente;

  const CargarCarnetHistoricoDialog({
    super.key,
    required this.idPaciente,
    required this.nombrePaciente,
  });

  static Future<bool?> show(
    BuildContext context, {
    required int idPaciente,
    required String nombrePaciente,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CargarCarnetHistoricoDialog(
        idPaciente: idPaciente,
        nombrePaciente: nombrePaciente,
      ),
    );
  }

  @override
  State<CargarCarnetHistoricoDialog> createState() =>
      _CargarCarnetHistoricoDialogState();
}

class _CargarCarnetHistoricoDialogState
    extends State<CargarCarnetHistoricoDialog> {
  final ApiService _api = ApiService();
  bool _guardando = false;

  // Lista de vacunas a registrar
  final List<_VacunaHistoricaEntry> _vacunas = [];

  // Paleta
  static const _primary = Color(0xFF1565C0);
  static const _green = Color(0xFF2E7D32);
  static const _amber = Color(0xFFE65100);
  static const _grey = Color(0xFF607D8B);

  // Catálogo PAI Venezuela (nombres de vacunas del esquema)
  static const _vacunasPAI = [
    'BCG',
    'Hepatitis B',
    'Pentavalente (DPT-HB-Hib)',
    'Polio (OPV)',
    'Polio Inactivada (IPV)',
    'Rotavirus',
    'Neumocócica (PCV)',
    'Sarampión-Rubeola-Paperas (SRP)',
    'Fiebre Amarilla',
    'DPT (Refuerzo)',
    'TD (Tétanos-Difteria)',
    'Influenza',
    'Varicela',
    'VPH (Papilomavirus)',
    'Otra (especificar)',
  ];

  static const _dosisOpciones = [
    '1ra Dosis',
    '2da Dosis',
    '3ra Dosis',
    'Refuerzo',
    '1er Refuerzo',
    '2do Refuerzo',
    'Dosis Única',
    'Dosis Anual',
  ];

  @override
  void initState() {
    super.initState();
    // Iniciar con una vacuna vacía
    _vacunas.add(_VacunaHistoricaEntry());
  }

  void _agregarVacuna() {
    setState(() => _vacunas.add(_VacunaHistoricaEntry()));
  }

  void _eliminarVacuna(int index) {
    if (_vacunas.length > 1) {
      setState(() => _vacunas.removeAt(index));
    }
  }

  Future<void> _guardar() async {
    // Validar que todas las entradas estén completas
    for (int i = 0; i < _vacunas.length; i++) {
      final v = _vacunas[i];
      if ((v.nombreVacuna == null || v.nombreVacuna!.isEmpty) &&
          (v.nombreLibre.text.trim().isEmpty)) {
        _showSnack('Vacuna #${i + 1}: selecciona o escribe el nombre de la vacuna', isError: true);
        return;
      }
      if (v.dosis == null) {
        _showSnack('Vacuna #${i + 1}: selecciona la dosis aplicada', isError: true);
        return;
      }
      if (v.fechaAplicacion == null) {
        _showSnack('Vacuna #${i + 1}: ingresa la fecha de aplicación', isError: true);
        return;
      }
      if (v.establecimiento.text.trim().isEmpty) {
        _showSnack('Vacuna #${i + 1}: ingresa el establecimiento donde se aplicó', isError: true);
        return;
      }
    }

    setState(() => _guardando = true);

    final listaPayload = _vacunas.map((v) {
      final nombreFinal = v.nombreVacuna == 'Otra (especificar)'
          ? v.nombreLibre.text.trim()
          : v.nombreVacuna ?? '';
      final nombreLibre = v.nombreVacuna == 'Otra (especificar)'
          ? v.nombreLibre.text.trim()
          : null;

      return <String, dynamic>{
        'nombre_vacuna': nombreFinal,
        if (nombreLibre != null) 'nombre_vacuna_libre': nombreLibre,
        'dosis_aplicada': v.dosis!,
        'fecha_aplicacion': v.fechaAplicacion!,
        'establecimiento_origen': v.establecimiento.text.trim(),
        if (v.observaciones.text.trim().isNotEmpty)
          'observaciones': v.observaciones.text.trim(),
      };
    }).toList();

    final res = await _api.cargarCarnetHistorico(
      idPaciente: widget.idPaciente,
      vacunas: listaPayload,
    );

    if (!mounted) return;
    setState(() => _guardando = false);

    final ok = res['success'] == true;
    final data = res['data'] as Map<String, dynamic>?;
    final registradas = (data?['registradas'] as List?)?.length ?? 0;
    final errores = (data?['errores'] as List?) ?? [];

    if (ok) {
      String msg = '$registradas vacuna(s) históricas cargadas exitosamente';
      if (errores.isNotEmpty) {
        msg += ' (${errores.length} con advertencias)';
      }
      _showSnack(msg);
      Navigator.of(context).pop(true);
    } else {
      _showSnack(res['message'] ?? 'Error al cargar el carnet', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red[700] : _green,
      duration: const Duration(seconds: 4),
    ));
  }

  Future<void> _seleccionarFecha(int index) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
      locale: const Locale('es', 'VE'),
      helpText: 'Fecha de aplicación de la vacuna',
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
    );
    if (picked != null) {
      setState(() {
        _vacunas[index].fechaAplicacion =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ────────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: _primary,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.history_edu, color: Colors.white, size: 26),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Carga Histórica de Carnet',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold),
                        ),
                        Text(
                          widget.nombrePaciente,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
            ),

            // ── Banner informativo ────────────────────────────────────────
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _amber.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _amber.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: _amber, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Registra vacunas aplicadas en OTRO establecimiento o con fecha anterior. '
                      'No descuenta stock del inventario. Quedarán marcadas como "Históricas" en el carnet.',
                      style: TextStyle(fontSize: 12, color: _amber),
                    ),
                  ),
                ],
              ),
            ),

            // ── Lista de vacunas ──────────────────────────────────────────
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _vacunas.length,
                itemBuilder: (context, index) =>
                    _buildVacunaCard(index),
              ),
            ),

            // ── Botón agregar vacuna ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: OutlinedButton.icon(
                onPressed: _agregarVacuna,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Agregar otra vacuna'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primary,
                  side: const BorderSide(color: _primary),
                  minimumSize: const Size(double.infinity, 40),
                ),
              ),
            ),

            // ── Acciones ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _guardando
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _guardando ? null : _guardar,
                      icon: _guardando
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_alt, color: Colors.white),
                      label: Text(
                        _guardando ? 'Guardando...' : 'Guardar Carnet Histórico',
                        style: const TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _green,
                        minimumSize: const Size(0, 44),
                      ),
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

  Widget _buildVacunaCard(int index) {
    final v = _vacunas[index];
    final esOtra = v.nombreVacuna == 'Otra (especificar)';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado de tarjeta
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                        color: _primary, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Vacuna',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: _primary)),
                const Spacer(),
                if (_vacunas.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.red, size: 20),
                    tooltip: 'Eliminar esta vacuna',
                    onPressed: () => _eliminarVacuna(index),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Nombre de la vacuna
            DropdownButtonFormField<String>(
              value: v.nombreVacuna,
              decoration: const InputDecoration(
                labelText: 'Vacuna *',
                prefixIcon: Icon(Icons.vaccines_outlined),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: _vacunasPAI
                  .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                  .toList(),
              onChanged: (val) => setState(() => v.nombreVacuna = val),
            ),

            // Nombre libre (si es "Otra")
            if (esOtra) ...[
              const SizedBox(height: 10),
              TextField(
                controller: v.nombreLibre,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la vacuna *',
                  hintText: 'Ej: Antirrábica, Meningocócica...',
                  border: OutlineInputBorder(),
                  isDense: true,
                  prefixIcon: Icon(Icons.edit_outlined),
                ),
              ),
            ],

            const SizedBox(height: 10),

            Row(
              children: [
                // Dosis aplicada
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: v.dosis,
                    decoration: const InputDecoration(
                      labelText: 'Dosis *',
                      prefixIcon: Icon(Icons.format_list_numbered),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: _dosisOpciones
                        .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                        .toList(),
                    onChanged: (val) => setState(() => v.dosis = val),
                  ),
                ),
                const SizedBox(width: 10),

                // Fecha de aplicación
                Expanded(
                  child: InkWell(
                    onTap: () => _seleccionarFecha(index),
                    borderRadius: BorderRadius.circular(4),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Fecha de Aplicación *',
                        prefixIcon: const Icon(Icons.calendar_today_outlined),
                        border: const OutlineInputBorder(),
                        isDense: true,
                        suffixIcon: v.fechaAplicacion != null
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () => setState(
                                    () => v.fechaAplicacion = null),
                              )
                            : null,
                      ),
                      child: Text(
                        v.fechaAplicacion ?? 'Seleccionar...',
                        style: TextStyle(
                          color: v.fechaAplicacion != null
                              ? Colors.black87
                              : _grey,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Establecimiento
            TextField(
              controller: v.establecimiento,
              decoration: const InputDecoration(
                labelText: 'Establecimiento donde fue aplicada *',
                hintText: 'Ej: CDI Maturín, Ambulatorio Rural Los Pinos, Hospital de Niños...',
                border: OutlineInputBorder(),
                isDense: true,
                prefixIcon: Icon(Icons.local_hospital_outlined),
              ),
            ),

            const SizedBox(height: 10),

            // Observaciones (opcional)
            TextField(
              controller: v.observaciones,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Observaciones (opcional)',
                hintText: 'Ej: Reacción leve, se aplicó junto con otra vacuna...',
                border: OutlineInputBorder(),
                isDense: true,
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final v in _vacunas) {
      v.dispose();
    }
    super.dispose();
  }
}

/// Modelo de entrada para una vacuna histórica
class _VacunaHistoricaEntry {
  String? nombreVacuna;
  String? dosis;
  String? fechaAplicacion;
  final TextEditingController nombreLibre = TextEditingController();
  final TextEditingController establecimiento = TextEditingController();
  final TextEditingController observaciones = TextEditingController();

  void dispose() {
    nombreLibre.dispose();
    establecimiento.dispose();
    observaciones.dispose();
  }
}

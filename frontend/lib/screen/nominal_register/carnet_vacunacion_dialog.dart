import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:asis_guanipa_frontend/models/paciente.dart';
import 'package:asis_guanipa_frontend/services/api_service.dart';
import 'package:asis_guanipa_frontend/providers/auth_providers.dart';

import 'package:asis_guanipa_frontend/utils/web_helper.dart' as webHelper;

/// ─────────────────────────────────────────────────────────────────────────────
/// CARNET DIGITAL DE VACUNACIÓN OFICIAL (MPPS / ASIC GUANIPA / CDI PEDRO URBINA)
/// Formato CR-80 Estándar (85.6 × 54 mm) — Tamaño Carnet de Bolsillo
/// QR de Verificación de Autenticidad con URL Oficial del Sistema
/// ─────────────────────────────────────────────────────────────────────────────
class CarnetVacunacionDialog extends StatefulWidget {
  final Paciente paciente;
  final String? vacunadorNombre;

  const CarnetVacunacionDialog({
    super.key,
    required this.paciente,
    this.vacunadorNombre,
  });

  static Future<void> show(
    BuildContext context, {
    required Paciente paciente,
    String? vacunadorNombre,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => CarnetVacunacionDialog(
        paciente: paciente,
        vacunadorNombre: vacunadorNombre,
      ),
    );
  }

  @override
  State<CarnetVacunacionDialog> createState() => _CarnetVacunacionDialogState();
}

class _CarnetVacunacionDialogState extends State<CarnetVacunacionDialog> {
  final ApiService _apiService = ApiService();
  bool _loading = true;
  String? _error;
  List<dynamic> _atenciones = [];
  Map<String, dynamic>? _pacienteDetalle;

  // 0: Anverso, 1: Reverso, 2: Doble Cara completa
  int _vistaSeleccionada = 2;

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
  }

  Future<void> _cargarHistorial() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final idOIdentificador = widget.paciente.idPaciente > 0
          ? widget.paciente.idPaciente.toString()
          : (widget.paciente.persona?.cedulaIdentidad ?? widget.paciente.cedula);

      final res = await _apiService.getHistorialPaciente(idOIdentificador);
      if (mounted) {
        if (res['success'] == true) {
          setState(() {
            _atenciones = res['atenciones'] ?? [];
            _pacienteDetalle = res['paciente'];
            _loading = false;
          });
        } else {
          setState(() {
            _error = res['message'] ?? 'No se pudo cargar el historial';
            _loading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error de conexión: $e';
          _loading = false;
        });
      }
    }
  }

  // Filtrar solo las atenciones con vacunas
  List<Map<String, dynamic>> _extraerVacunasAplicadas() {
    final List<Map<String, dynamic>> vacunas = [];

    for (final atencion in _atenciones) {
      final fechaVisita = atencion['fecha_visita'] ?? atencion['createdAt'];
      final centroNombre = atencion['centro']?['nombre_centro'] ?? 'CDI Dr. Pedro Urbina';
      // NOTA: 'dosis_esquema' no es campo del modelo AtencionDiaria;
      // se obtiene desde RegistroVacunacion.esquema.numero_dosis
      final via = atencion['via_administracion'];
      final sitio = atencion['sitio_administracion'];
      final modalidad = atencion['modalidad'] ?? 'Intramural';

      // 1. Registros en tabla registro_vacunacion (fuente principal)
      if (atencion['vacunaciones'] != null && (atencion['vacunaciones'] as List).isNotEmpty) {
        for (final vac in atencion['vacunaciones']) {
          final articulo = vac['lote']?['articulo'];
          final nombreVacuna = articulo?['nombre_articulo'] ?? 'Biológico PAI';
          final loteNum = vac['lote']?['numero_lote'] ?? 'S/L';
          // Usar numero_dosis del esquema, o dosis_aplicada del registro, o fallback
          String numDosis = 'Dosis Única';
          if (vac['esquema']?['numero_dosis'] != null) {
            numDosis = 'Dosis ${vac['esquema']['numero_dosis']}';
          } else if (vac['dosis_aplicada'] != null && vac['dosis_aplicada'].toString().isNotEmpty) {
            numDosis = vac['dosis_aplicada'].toString();
          }
          vacunas.add({
            'vacuna': nombreVacuna, 'dosis': numDosis, 'fecha': fechaVisita,
            'lote': loteNum, 'via': vac['via_administracion'] ?? via ?? 'Intramuscular',
            'sitio': vac['sitio_administracion'] ?? sitio ?? 'Deltoides',
            'centro': centroNombre, 'modalidad': vac['modalidad'] ?? modalidad,
          });
        }
      }
      // 2. Atención de tipo inmunización con consumos (registros legacy)
      else if (atencion['tipo_atencion'] == 'inmunizacion') {
        String nombreVacuna = 'Inmunización / Biológico';
        String loteNum = 'S/L';
        if (atencion['consumos'] != null && (atencion['consumos'] as List).isNotEmpty) {
          final primerConsumo = atencion['consumos'][0];
          // Solo registrar consumos de tipo Biológico/Vacuna
          final tipoArticulo = primerConsumo['lote']?['articulo']?['tipo']?.toString().toLowerCase();
          if (tipoArticulo == null || tipoArticulo.contains('biol') || tipoArticulo.contains('vacun') || tipoArticulo.contains('insumo')) {
            nombreVacuna = primerConsumo['lote']?['articulo']?['nombre_articulo'] ?? nombreVacuna;
            loteNum = primerConsumo['lote']?['numero_lote'] ?? loteNum;
            vacunas.add({
              'vacuna': nombreVacuna, 'dosis': 'Dosis Única', 'fecha': fechaVisita,
              'lote': loteNum, 'via': via ?? 'Intramuscular',
              'sitio': sitio ?? 'Deltoides', 'centro': centroNombre, 'modalidad': modalidad,
            });
          }
        }
      }
    }
    return vacunas;
  }

  static String _normalizarCedulaParaHash(String c) {
    String clean = c.toUpperCase().replaceAll(RegExp(r'[^0-9A-Z]'), '');
    if (RegExp(r'^\d+$').hasMatch(clean)) clean = 'V$clean';
    return clean;
  }

  /// Hash determinista estándar de 32 bits para verificar la autenticidad del carnet
  String _generarHashVerificacion(String cedula, int totalDosis) {
    final clean = _normalizarCedulaParaHash(cedula);
    final raw = 'CDI-PEDRO-URBINA|$clean|$totalDosis|PAI-MPPS-2026';
    int hash = 5381;
    for (final c in raw.codeUnits) {
      hash = (((hash << 5) + hash) ^ c) & 0xFFFFFFFF;
    }
    return (hash % 9999999).toString().padLeft(7, '0');
  }

  /// URL de verificación oficial codificada en el QR
  String _generarUrlVerificacion({
    required String cedula,
    required int totalDosis,
    required String hash,
  }) {
    final baseUrl = ApiService.getBaseUrlWithoutApi(ApiService.baseUrl);
    final cleanCedula = cedula.replaceAll(' ', '').replaceAll('-', '');
    return '$baseUrl/carnet/verificar?id=$cleanCedula&dosis=$totalDosis&hash=$hash';
  }

  String _obtenerNombreVacunador() {
    // 1. Si se pasó explícitamente desde la jornada
    if (widget.vacunadorNombre != null && widget.vacunadorNombre!.trim().isNotEmpty) {
      return widget.vacunadorNombre!.trim();
    }
    // 2. Si las atenciones traen usuarioRegistra
    for (final atencion in _atenciones) {
      final u = atencion['usuarioRegistra'];
      if (u != null) {
        final p = u['persona'];
        if (p != null) {
          final nom = '${p['nombre1'] ?? ''} ${p['apellido1'] ?? ''}'.trim();
          if (nom.isNotEmpty) return nom;
        }
        if (u['nombre_usuario'] != null && u['nombre_usuario'].toString().isNotEmpty) {
          return u['nombre_usuario'].toString();
        }
      }
    }
    // 3. Del usuario en sesión actual de AuthProvider
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final u = auth.getCurrentUser();
      if (u != null) {
        if (u.displayName.isNotEmpty && u.displayName != 'Usuario') {
          return u.displayName;
        }
        final uname = (u.username ?? '').trim();
        if (uname.isNotEmpty) return uname;
      }
    } catch (_) {}

    return 'Personal de Inmunización CDI';
  }

  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  Future<String?> _generarQrBase64(String data) async {
    try {
      final painter = QrPainter(
        data: data,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
        gapless: true,
        // qr_flutter 4.x: usar eyeStyle/dataModuleStyle en lugar de color/emptyColor
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Color(0xFF0F172A),
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Color(0xFF0F172A),
        ),
      );
      final picData = await painter.toImageData(220);
      if (picData != null) {
        return 'data:image/png;base64,${base64Encode(picData.buffer.asUint8List())}';
      }
    } catch (_) {}
    return null;
  }

  Future<void> _imprimirCarnet({bool abrirEnNuevaPestana = false}) async {
    if (!kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Función de impresión disponible en navegador web.'),
          backgroundColor: Color(0xFF1E3A8A),
        ),
      );
      return;
    }

    // 1. Abrir ventana en blanco síncronamente al clic para evitar bloqueo de pop-up
    dynamic ventanaPrevia;
    try {
      ventanaPrevia = webHelper.openBlankWindow();
    } catch (_) {}

    final persona = widget.paciente.persona;
    final nombreCompleto = widget.paciente.nombreCompleto;
    final cedula = widget.paciente.cedula;
    final edad = widget.paciente.edadFormateada;
    final sexo = widget.paciente.sexoFormateado;
    final esMenor = widget.paciente.esMenor;
    final direccion = widget.paciente.direccionCompleta ?? 'San José de Guanipa';
    final fechaNac = persona?.fechaNacimiento != null
        ? persona!.fechaNacimiento.toString().split('T')[0]
        : 'S/D';
    final grupoSanguineo = _pacienteDetalle?['tipo_sangre'] ?? 'S/D';

    final vacunasAplicadas = _extraerVacunasAplicadas();
    final hash = _generarHashVerificacion(cedula, vacunasAplicadas.length);
    final urlQR = _generarUrlVerificacion(cedula: cedula, totalDosis: vacunasAplicadas.length, hash: hash);
    final vacunadorNombre = _obtenerNombreVacunador();

    // Generar QR base64 (falla silenciosamente si hay error — fallback a URL externa)
    String? qrBase64;
    try {
      qrBase64 = await _generarQrBase64(urlQR).timeout(
        const Duration(milliseconds: 800),
        onTimeout: () => null,
      );
    } catch (_) {}

    final htmlContent = _construirHtmlImpresion(
      nombreCompleto: nombreCompleto,
      cedula: cedula,
      edad: edad,
      sexo: sexo,
      esMenor: esMenor,
      direccion: direccion,
      fechaNac: fechaNac,
      grupoSanguineo: grupoSanguineo,
      totalDosis: vacunasAplicadas.length,
      hash: hash,
      qrBase64: qrBase64,
      vacunasAplicadas: vacunasAplicadas,
      vacunadorNombre: vacunadorNombre,
      urlQR: urlQR,
    );

    try {
      await webHelper.openHtmlPrint(htmlContent, ventanaPrevia);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text(
                'Carnet abierto en nueva pestaña. Usa Ctrl+P para imprimir o Guardar como PDF.',
                style: TextStyle(fontSize: 12),
              )),
            ]),
            duration: Duration(seconds: 4),
            backgroundColor: Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error al imprimir carnet: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al procesar impresión: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _construirHtmlImpresion({
    required String nombreCompleto,
    required String cedula,
    required String edad,
    required String sexo,
    required bool esMenor,
    required String direccion,
    required String fechaNac,
    required String grupoSanguineo,
    required int totalDosis,
    required String hash,
    required String? qrBase64,
    required List<Map<String, dynamic>> vacunasAplicadas,
    required String vacunadorNombre,
    required String urlQR,
  }) {
    final now = DateTime.now();
    final fechaHoy = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    final filasVacunas = vacunasAplicadas.take(6).map((v) {
      final fechaRaw = v['fecha'] != null ? v['fecha'].toString().split('T')[0] : '-';
      final vacuna = _escapeHtml((v['vacuna'] ?? '-').toString());
      final dosis = _escapeHtml((v['dosis'] ?? '-').toString());
      final lote = _escapeHtml((v['lote'] ?? 'S/L').toString());
      final centro = _escapeHtml((v['centro'] ?? 'CDI Pedro Urbina').toString());
      return '''
        <tr>
          <td style="font-weight: 700;">$vacuna</td>
          <td><span class="dosis-chip">$dosis</span></td>
          <td>$fechaRaw</td>
          <td style="font-family: monospace; font-weight: 600;">$lote</td>
          <td style="font-style: italic; color: #334155;">$centro</td>
        </tr>
      ''';
    }).join('');

    final filasVacias = vacunasAplicadas.isEmpty
        ? '<tr><td colspan="5" style="text-align: center; padding: 4mm; color: #64748b; font-style: italic;">Sin dosis registradas en el sistema nominal.</td></tr>'
        : filasVacunas;

    final imgQrTag = qrBase64 != null
        ? '<img src="$qrBase64" alt="QR Verificación" />'
        : '<img src="https://api.qrserver.com/v1/create-qr-code/?size=180x180&data=${Uri.encodeComponent(urlQR)}" alt="QR Verificación" onerror="this.style.display=\'none\'" />';

    final badgePediatrico = esMenor
        ? '<span class="pediatrico-badge">PEDIÁTRICO</span>'
        : '';

    return '''<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Carnet de Vacunacion - ${_escapeHtml(cedula)}</title>
  <style>
    @page {
      size: A4 portrait;
      margin: 10mm;
    }
    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      -webkit-print-color-adjust: exact !important;
      print-color-adjust: exact !important;
    }

    /* ── Barra superior fija — NO afecta el flujo del documento ── */
    .toolbar {
      position: fixed;
      top: 0; left: 0; right: 0;
      background: #1e293b;
      display: flex;
      align-items: center;
      gap: 10px;
      padding: 10px 20px;
      z-index: 9999;
      box-shadow: 0 2px 8px rgba(0,0,0,0.3);
    }
    .toolbar-title {
      color: #94a3b8;
      font-size: 11px;
      font-weight: 600;
      flex: 1;
      letter-spacing: 0.3px;
    }
    .btn-print {
      background: #1565c0;
      color: #ffffff;
      border: none;
      padding: 7px 16px;
      border-radius: 5px;
      font-weight: 700;
      font-size: 11px;
      cursor: pointer;
    }
    .btn-print:hover { background: #0d47a1; }
    .btn-cerrar {
      background: #475569;
      color: #ffffff;
      border: none;
      padding: 7px 12px;
      border-radius: 5px;
      cursor: pointer;
      font-size: 11px;
      font-weight: 600;
    }
    .btn-cerrar:hover { background: #334155; }

    /* ── Página — con espacio para la barra fija ── */
    body {
      background: #e2e8f0;
      padding-top: 60px;
      padding-bottom: 24px;
      display: flex;
      flex-direction: column;
      align-items: center;
      min-height: 100vh;
    }

    /* ── Al imprimir: ocultar solo la barra, sin alterar el carnet ── */
    @media print {
      .toolbar { display: none !important; }
      body {
        background: #ffffff !important;
        padding-top: 0 !important;
        padding-bottom: 0 !important;
        display: block;
      }
      .carnet-wrapper {
        margin: 0 auto !important;
      }
    }

    /* ── Wrapper general del carnet ── */
    .carnet-wrapper {
      width: 85.6mm;
      display: flex;
      flex-direction: column;
      align-items: center;
    }

    /* ── Tarjeta CR-80 (85.6 x 54 mm) ── */
    .tarjeta {
      width: 85.6mm;
      height: 54mm;
      border: 1px solid #1e3a8a;
      border-radius: 3.2mm;
      overflow: hidden;
      background: #ffffff;
      display: flex;
      flex-direction: column;
    }
    .tarjeta-reverso { border-color: #0f766e; }

    /* Bandera venezolana */
    .bandera {
      display: flex;
      height: 1.8mm;
      width: 100%;
      flex-shrink: 0;
    }
    .bandera .amarillo { flex: 1; background: #facc15; }
    .bandera .azul     { flex: 1; background: #1d4ed8; }
    .bandera .rojo     { flex: 1; background: #dc2626; }

    /* ── Anverso ── */
    .header-anverso {
      background: #0f172a;
      color: #ffffff;
      padding: 1.2mm 2.5mm;
      display: flex;
      justify-content: space-between;
      align-items: center;
      flex-shrink: 0;
    }
    .titulo-inst { font-size: 5.2pt; font-weight: 800; line-height: 1.15; }
    .sub-inst    { font-size: 4.8pt; color: #93c5fd; font-weight: 600; }
    .badge-pai {
      background: #1e3a8a;
      border: 0.5px solid #60a5fa;
      color: #fff;
      font-size: 5pt;
      font-weight: 800;
      padding: 1px 3px;
      border-radius: 2px;
      white-space: nowrap;
    }
    .barra-folio {
      background: #1e3a8a;
      color: #fff;
      padding: 0.8mm 2.5mm;
      display: flex;
      justify-content: space-between;
      align-items: center;
      font-size: 5.5pt;
      font-weight: 800;
      flex-shrink: 0;
    }
    .folio { color: #fde047; font-family: monospace; }

    .cuerpo-anverso {
      padding: 1.5mm 2.5mm;
      display: flex;
      flex: 1;
      justify-content: space-between;
      align-items: center;
      overflow: hidden;
      gap: 2mm;
    }
    .datos-paciente { flex: 1; overflow: hidden; }
    .nombre-paciente {
      font-size: 7pt;
      font-weight: 900;
      color: #0f172a;
      text-transform: uppercase;
      line-height: 1.1;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .fila-cedula {
      display: flex;
      align-items: center;
      margin-top: 0.8mm;
      gap: 1.5mm;
      flex-wrap: wrap;
    }
    .cedula-badge {
      background: #eff6ff;
      border: 0.6px solid #93c5fd;
      color: #1e3a8a;
      font-size: 6pt;
      font-weight: 800;
      padding: 0.5px 3px;
      border-radius: 2px;
      font-family: monospace;
    }
    .pediatrico-badge {
      background: #fef3c7;
      color: #b45309;
      font-size: 4.8pt;
      font-weight: 800;
      padding: 0.5px 2px;
      border-radius: 2px;
    }
    .grid-datos {
      display: grid;
      grid-template-columns: repeat(4, 1fr);
      gap: 1mm;
      margin-top: 1mm;
    }
    .campo-label { color: #64748b; font-size: 4pt; font-weight: 700; display: block; }
    .campo-val   { color: #0f172a; font-weight: 700; font-size: 5pt; }
    .direccion-txt {
      font-size: 4.5pt;
      color: #475569;
      margin-top: 0.8mm;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .badge-dosis-total {
      display: inline-block;
      margin-top: 0.8mm;
      background: #dcfce7;
      border: 0.5px solid #86efac;
      color: #15803d;
      font-size: 4.8pt;
      font-weight: 800;
      padding: 0.5px 3px;
      border-radius: 2px;
    }

    /* QR */
    .qr-box {
      border: 0.7px solid #1e3a8a;
      border-radius: 2mm;
      padding: 1mm;
      text-align: center;
      display: flex;
      flex-direction: column;
      align-items: center;
      background: #ffffff;
      min-width: 20mm;
      max-width: 22mm;
      flex-shrink: 0;
    }
    .qr-tag {
      background: #1e3a8a;
      color: #fff;
      font-size: 3.8pt;
      font-weight: 800;
      padding: 0.5px 2px;
      border-radius: 1px;
      width: 100%;
      display: block;
    }
    .qr-box img {
      width: 15mm;
      height: 15mm;
      margin: 0.8mm 0;
      display: block;
    }
    .qr-sub  { font-size: 3.8pt; font-weight: 800; color: #16a34a; }
    .qr-hash { font-size: 3.5pt; color: #94a3b8; font-family: monospace; }

    .pie-anverso {
      background: #f1f5f9;
      border-top: 0.5px solid #e2e8f0;
      padding: 0.6mm 2.5mm;
      display: flex;
      justify-content: space-between;
      font-size: 4pt;
      color: #64748b;
      font-weight: 700;
      flex-shrink: 0;
    }

    /* Línea de corte */
    .linea-corte {
      width: 85.6mm;
      margin: 2mm 0;
      display: flex;
      align-items: center;
      justify-content: center;
      color: #94a3b8;
      font-size: 5pt;
      font-family: monospace;
    }
    .linea-corte::before, .linea-corte::after {
      content: "";
      flex: 1;
      border-bottom: 0.8px dashed #94a3b8;
      margin: 0 2mm;
    }

    /* ── Reverso ── */
    .header-reverso {
      background: #0f766e;
      color: #fff;
      padding: 1mm 2.5mm;
      display: flex;
      justify-content: space-between;
      align-items: center;
      font-size: 5.5pt;
      font-weight: 800;
      flex-shrink: 0;
    }
    .sub-reverso-titular {
      background: #ecfdf5;
      color: #064e3b;
      font-size: 4.8pt;
      font-weight: 800;
      padding: 0.6mm 2.5mm;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
      border-bottom: 0.5px solid #a7f3d0;
      flex-shrink: 0;
    }
    .tabla-vacunas {
      width: 100%;
      border-collapse: collapse;
      font-size: 4.8pt;
      flex: 1;
    }
    .tabla-vacunas th {
      background: #ecfdf5;
      color: #064e3b;
      font-weight: 800;
      padding: 0.6mm 1.2mm;
      text-align: left;
      border-bottom: 0.5px solid #a7f3d0;
      font-size: 4.5pt;
    }
    .tabla-vacunas td {
      padding: 0.6mm 1.2mm;
      border-bottom: 0.4px solid #e2e8f0;
      color: #0f172a;
      vertical-align: middle;
      font-size: 4.8pt;
      line-height: 1.1;
    }
    .tabla-vacunas tr:nth-child(even) { background: #fafafa; }
    .dosis-chip {
      background: #dcfce7;
      color: #15803d;
      font-weight: 800;
      padding: 0.3px 2px;
      border-radius: 2px;
      font-size: 4.2pt;
      display: inline-block;
    }
    .pie-reverso {
      background: #f0fdf4;
      border-top: 0.6px solid #a7f3d0;
      padding: 0.8mm 2.5mm;
      display: flex;
      justify-content: space-between;
      align-items: center;
      flex-shrink: 0;
    }
    .sello-area { font-size: 4.5pt; color: #334155; line-height: 1.2; }
    .sello-area strong { color: #0f172a; font-size: 5pt; display: block; }
    .responsable-area {
      border: 0.7px dashed #059669;
      background: #ffffff;
      border-radius: 2px;
      padding: 0.6mm 1.8mm;
      text-align: right;
      min-width: 30mm;
    }
    .responsable-label { font-size: 4pt; font-weight: 800; color: #059669; }
    .responsable-nombre {
      font-size: 5.5pt;
      font-weight: 900;
      color: #0f172a;
      text-transform: uppercase;
      line-height: 1.1;
    }
    .responsable-rol { font-size: 3.8pt; color: #64748b; }
  </style>
</head>
<body>
  <!-- Barra fija — se oculta al imprimir, no afecta el layout del carnet -->
  <div class="toolbar">
    <span class="toolbar-title">CARNET DE VACUNACION — ${_escapeHtml(cedula)}</span>
    <button class="btn-print" onclick="window.print();">Imprimir / Guardar PDF</button>
    <button class="btn-cerrar" onclick="window.close();">Cerrar</button>
  </div>

  <!-- Carnet — este es EXACTAMENTE lo que se imprime -->
  <div class="carnet-wrapper">

    <!-- CARA FRONTAL (ANVERSO) -->
    <div class="tarjeta">
      <div class="bandera">
        <div class="amarillo"></div>
        <div class="azul"></div>
        <div class="rojo"></div>
      </div>
      <div class="header-anverso">
        <div>
          <div class="titulo-inst">REPUBLICA BOLIVARIANA DE VENEZUELA &middot; MPPS</div>
          <div class="sub-inst">ASIC SAN JOSE DE GUANIPA &middot; CDI DR. PEDRO URBINA</div>
        </div>
        <span class="badge-pai">PAI OFICIAL</span>
      </div>
      <div class="barra-folio">
        <span>CARNET NOMINAL DE INMUNIZACION</span>
        <span class="folio">FOLIO: ${_escapeHtml(cedula.replaceAll(' ', ''))}</span>
      </div>
      <div class="cuerpo-anverso">
        <div class="datos-paciente">
          <div class="nombre-paciente">${_escapeHtml(nombreCompleto)}</div>
          <div class="fila-cedula">
            <span class="cedula-badge">${_escapeHtml(cedula)}</span>
            $badgePediatrico
          </div>
          <div class="grid-datos">
            <div><span class="campo-label">F. NAC</span><span class="campo-val">${_escapeHtml(fechaNac)}</span></div>
            <div><span class="campo-label">EDAD</span><span class="campo-val">${_escapeHtml(edad)}</span></div>
            <div><span class="campo-label">SEXO</span><span class="campo-val">${_escapeHtml(sexo)}</span></div>
            <div><span class="campo-label">SANGRE</span><span class="campo-val">${_escapeHtml(grupoSanguineo)}</span></div>
          </div>
          <div class="direccion-txt">${_escapeHtml(direccion)}</div>
          <span class="badge-dosis-total">$totalDosis dosis registradas</span>
        </div>
        <div class="qr-box">
          <span class="qr-tag">VERIFICACION OFICIAL</span>
          <a href="${_escapeHtml(urlQR)}" target="_blank" style="text-decoration:none;display:block;" title="Verificar autenticidad">
            $imgQrTag
          </a>
          <span class="qr-sub">QR AUTENTICO</span>
          <span class="qr-hash">#${_escapeHtml(hash)}</span>
        </div>
      </div>
      <div class="pie-anverso">
        <span>DOCUMENTO SANITARIO OFICIAL &middot; VALIDEZ NACIONAL</span>
        <span style="color:#1e3a8a;">Escanea el QR para verificar</span>
      </div>
    </div>

    <!-- Linea de corte -->
    <div class="linea-corte">Recorte / Doblado (85.6 x 54.0 mm)</div>

    <!-- CARA POSTERIOR (REVERSO) -->
    <div class="tarjeta tarjeta-reverso">
      <div class="bandera">
        <div class="amarillo"></div>
        <div class="azul"></div>
        <div class="rojo"></div>
      </div>
      <div class="header-reverso">
        <span>REGISTRO DE INMUNIZACIONES APLICADAS (PAI)</span>
        <span>TOTAL: $totalDosis</span>
      </div>
      <div class="sub-reverso-titular">
        ${_escapeHtml(nombreCompleto.toUpperCase())} &mdash; ${_escapeHtml(cedula)}
      </div>
      <table class="tabla-vacunas">
        <thead>
          <tr>
            <th>Biologico</th>
            <th>Dosis</th>
            <th>Fecha</th>
            <th>Lote</th>
            <th>Centro</th>
          </tr>
        </thead>
        <tbody>
          $filasVacias
        </tbody>
      </table>
      <div class="pie-reverso">
        <div class="sello-area">
          <strong>CENTRO DE SALUD CDI DR. PEDRO URBINA</strong>
          <span>Guanipa, Anzoategui &middot; MPPS PAI</span><br>
          <span style="color:#64748b;font-size:4pt;">Emision: $fechaHoy</span>
        </div>
        <div class="responsable-area">
          <div class="responsable-label">RESPONSABLE DE INMUNIZACION</div>
          <div class="responsable-nombre">${_escapeHtml(vacunadorNombre)}</div>
          <div class="responsable-rol">Personal Autorizado &middot; MPPS PAI</div>
        </div>
      </div>
    </div>

  </div>
</body>
</html>''';
  }


  @override
  Widget build(BuildContext context) {
    final persona = widget.paciente.persona;
    final nombreCompleto = widget.paciente.nombreCompleto;
    final cedula = widget.paciente.cedula;
    final edad = widget.paciente.edadFormateada;
    final sexo = widget.paciente.sexoFormateado;
    final esMenor = widget.paciente.esMenor;
    final direccion = widget.paciente.direccionCompleta ?? 'San José de Guanipa';

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Center(
        child: Container(
          width: 580,
          constraints: const BoxConstraints(maxHeight: 800),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 8)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildModalHeader(),
              _buildSegmentedControl(),
              Flexible(
                child: _loading
                    ? const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: Color(0xFF1E3A8A))))
                    : _error != null
                        ? _buildErrorView()
                        : SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                            child: _buildCarnetContent(
                              nombreCompleto: nombreCompleto, cedula: cedula, edad: edad,
                              sexo: sexo, esMenor: esMenor, direccion: direccion, persona: persona,
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Header del Modal ──────────────────────────────────────────────────────
  Widget _buildModalHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32).withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.badge_rounded, color: Color(0xFF4CAF50), size: 18),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Carnet de Vacunación — Tamaño CR-80 (85.6 × 54 mm)',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5)),
              Text('PAI Oficial · MPPS · CDI Dr. Pedro Urbina · QR de Verificación de Autenticidad',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 9.5)),
            ]),
          ),
          ElevatedButton.icon(
            onPressed: () => _imprimirCarnet(abrirEnNuevaPestana: false),
            icon: const Icon(Icons.print_rounded, size: 14),
            label: const Text('Imprimir', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: const Size(0, 32),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
          const SizedBox(width: 6),
          OutlinedButton.icon(
            onPressed: () => _imprimirCarnet(abrirEnNuevaPestana: true),
            icon: const Icon(Icons.open_in_new_rounded, size: 13),
            label: const Text('PDF / Pestaña', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFF475569)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(0, 32),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white70, size: 20),
            tooltip: 'Cerrar',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  // ─── Selector de Vistas ───────────────────────────────────────────────────
  Widget _buildSegmentedControl() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _segmentButton(0, 'Anverso (Identidad & QR)', Icons.badge_outlined),
          const SizedBox(width: 6),
          _segmentButton(1, 'Reverso (Biológicos)', Icons.vaccines_outlined),
          const SizedBox(width: 6),
          _segmentButton(2, 'Carnet Completo', Icons.credit_card_rounded),
        ],
      ),
    );
  }

  Widget _segmentButton(int index, String label, IconData icon) {
    final isSelected = _vistaSeleccionada == index;
    return InkWell(
      onTap: () => setState(() => _vistaSeleccionada = index),
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFFCBD5E1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: isSelected ? Colors.white : const Color(0xFF475569)),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Colors.white : const Color(0xFF334155),
            )),
          ],
        ),
      ),
    );
  }

  // ─── Contenido principal del carnet ──────────────────────────────────────
  Widget _buildCarnetContent({
    required String nombreCompleto,
    required String cedula,
    required String edad,
    required String sexo,
    required bool esMenor,
    required String direccion,
    required Persona? persona,
  }) {
    final vacunasAplicadas = _extraerVacunasAplicadas();
    final hash = _generarHashVerificacion(cedula, vacunasAplicadas.length);
    final urlQR = _generarUrlVerificacion(cedula: cedula, totalDosis: vacunasAplicadas.length, hash: hash);
    final vacunadorNombre = _obtenerNombreVacunador();

    if (_vistaSeleccionada == 0) {
      return _buildCaraFrontal(
        nombreCompleto: nombreCompleto, cedula: cedula, edad: edad, sexo: sexo,
        esMenor: esMenor, direccion: direccion, persona: persona,
        urlQR: urlQR, hash: hash, totalDosis: vacunasAplicadas.length,
      );
    } else if (_vistaSeleccionada == 1) {
      return _buildCaraPosterior(
        cedula: cedula,
        nombreCompleto: nombreCompleto,
        vacunasAplicadas: vacunasAplicadas,
        vacunadorNombre: vacunadorNombre,
      );
    } else {
      return Column(children: [
        _buildCaraFrontal(
          nombreCompleto: nombreCompleto, cedula: cedula, edad: edad, sexo: sexo,
          esMenor: esMenor, direccion: direccion, persona: persona,
          urlQR: urlQR, hash: hash, totalDosis: vacunasAplicadas.length,
        ),
        const SizedBox(height: 16),
        _buildSeparadorDoblado(),
        const SizedBox(height: 16),
        _buildCaraPosterior(
          cedula: cedula,
          nombreCompleto: nombreCompleto,
          vacunasAplicadas: vacunasAplicadas,
          vacunadorNombre: vacunadorNombre,
        ),
        const SizedBox(height: 12),
        _buildNotaImpresion(),
      ]);
    }
  }

  Widget _buildSeparadorDoblado() {
    return Row(
      children: [
        const Icon(Icons.content_cut_rounded, size: 14, color: Color(0xFF94A3B8)),
        const SizedBox(width: 6),
        Expanded(
          child: LayoutBuilder(builder: (context, constraints) {
            final boxWidth = constraints.constrainWidth();
            const dashWidth = 5.0;
            const dashSpace = 4.0;
            final dashCount = (boxWidth / (dashWidth + dashSpace)).floor();
            return Flex(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              direction: Axis.horizontal,
              children: List.generate(dashCount, (_) {
                return const SizedBox(width: dashWidth, height: 1,
                    child: DecoratedBox(decoration: BoxDecoration(color: Color(0xFF94A3B8))));
              }),
            );
          }),
        ),
        const SizedBox(width: 6),
        const Text('Línea de doblado / Reverso',
            style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildNotaImpresion() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.print_rounded, size: 16, color: Color(0xFF16A34A)),
              SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tamaño Oficial Estándar CR-80 (85.6 × 54.0 mm)',
                      style: TextStyle(fontSize: 10.5, color: Color(0xFF15803D), fontWeight: FontWeight.bold)),
                  Text('Listo para plastificar o portar en billetera / carnet',
                      style: TextStyle(fontSize: 9, color: Color(0xFF166534))),
                ],
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: () => _imprimirCarnet(abrirEnNuevaPestana: false),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.print_rounded, size: 14),
            label: const Text('Imprimir Ahora', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ─── Cara Frontal (Anverso) — Tamaño Carnet CR-80 ─────────────────────────
  Widget _buildCaraFrontal({
    required String nombreCompleto,
    required String cedula,
    required String edad,
    required String sexo,
    required bool esMenor,
    required String direccion,
    required Persona? persona,
    required String urlQR,
    required String hash,
    required int totalDosis,
  }) {
    final fechaNac = persona?.fechaNacimiento != null
        ? persona!.fechaNacimiento.toString().split('T')[0]
        : 'S/D';
    final grupoSanguineo = _pacienteDetalle?['tipo_sangre'] ?? 'S/D';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E3A8A), width: 1.2),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Franja tricolor bandera Venezuela
          Row(children: [
            Expanded(flex: 3, child: Container(height: 4, color: const Color(0xFFFACC15))),
            Expanded(flex: 3, child: Container(height: 4, color: const Color(0xFF1D4ED8))),
            Expanded(flex: 3, child: Container(height: 4, color: const Color(0xFFDC2626))),
          ]),

          // Encabezado institucional
          Container(
            color: const Color(0xFF0F172A),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(children: [
              const Icon(Icons.health_and_safety, color: Color(0xFF38BDF8), size: 16),
              const SizedBox(width: 6),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('REPÚBLICA BOLIVARIANA DE VENEZUELA · MPPS',
                    style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold)),
                Text('ASIC SAN JOSÉ DE GUANIPA · CDI DR. PEDRO URBINA',
                    style: TextStyle(color: Color(0xFF93C5FD), fontSize: 8, fontWeight: FontWeight.w600)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A8A),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF60A5FA), width: 0.6),
                ),
                child: const Text('PAI OFICIAL', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
              ),
            ]),
          ),

          // Barra: Título del carnet & Folio
          Container(
            color: const Color(0xFF1E3A8A),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('CARNET NOMINAL DE INMUNIZACIÓN',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.3)),
                Text('FOLIO: ${cedula.replaceAll(' ', '')}',
                    style: const TextStyle(color: Color(0xFFFDE047), fontSize: 9.5, fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          // Cuerpo: Datos del titular + QR de Verificación
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              // Datos del titular
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(nombreCompleto.toUpperCase(),
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), height: 1.1),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF93C5FD), width: 0.8),
                    ),
                    child: Text(cedula, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                  ),
                  if (esMenor) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(4)),
                      child: const Text('PEDIÁTRICO', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
                    ),
                  ],
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  _miniCampo('F. NAC', fechaNac), const SizedBox(width: 8),
                  _miniCampo('EDAD', edad), const SizedBox(width: 8),
                  _miniCampo('SEXO', sexo), const SizedBox(width: 8),
                  _miniCampo('SANGRE', grupoSanguineo),
                ]),
                const SizedBox(height: 5),
                Row(children: [
                  const Icon(Icons.location_on_outlined, size: 11, color: Color(0xFF64748B)),
                  const SizedBox(width: 3),
                  Expanded(child: Text(direccion,
                      style: const TextStyle(fontSize: 9, color: Color(0xFF475569)),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Text('✓ $totalDosis dosis registradas',
                      style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                ),
              ])),

              const SizedBox(width: 10),
              // QR de Verificación de Autenticidad
              _buildQRVerificacion(urlQR, hash),
            ]),
          ),

          // Pie del anverso
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('DOCUMENTO SANITARIO OFICIAL · VALIDEZ NACIONAL',
                    style: TextStyle(fontSize: 7.5, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                Text('Escanea el QR para verificar autenticidad',
                    style: TextStyle(fontSize: 7.5, color: Color(0xFF1E3A8A), fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  // ─── Bloque QR con URL de Verificación Oficial ────────────────────────────
  Widget _buildQRVerificacion(String urlQR, String hash) {
    return Tooltip(
      message: 'Escanear con teléfono o hacer clic para verificar autenticidad',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () {
            if (kIsWeb) {
              webHelper.openInNewTab(urlQR);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF1E3A8A), width: 1),
              boxShadow: [BoxShadow(color: const Color(0xFF1E3A8A).withValues(alpha: 0.10), blurRadius: 6)],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFF1E3A8A), borderRadius: BorderRadius.circular(3)),
                child: const Text('VERIFICACIÓN OFICIAL',
                    style: TextStyle(color: Colors.white, fontSize: 5.5, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 3),
              QrImageView(
                data: urlQR,
                version: QrVersions.auto,
                size: 84,
                gapless: true,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF0F172A)),
                dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 2),
              const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.verified, size: 9, color: Color(0xFF16A34A)),
                SizedBox(width: 2),
                Text('QR AUTÉNTICO', style: TextStyle(fontSize: 7, fontWeight: FontWeight.w800, color: Color(0xFF16A34A))),
              ]),
              const SizedBox(height: 2),
              Text('Hash: $hash',
                  style: const TextStyle(fontSize: 6, color: Color(0xFF94A3B8), fontFamily: 'monospace', fontWeight: FontWeight.bold)),
            ]),
          ),
        ),
      ),
    );
  }

  // ─── Cara Posterior (Reverso) — Dosis Aplicadas ───────────────────────────
  Widget _buildCaraPosterior({
    required String cedula,
    required String nombreCompleto,
    required List<Map<String, dynamic>> vacunasAplicadas,
    required String vacunadorNombre,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF0F766E), width: 1.2),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Franja tricolor
          Row(children: [
            Expanded(flex: 3, child: Container(height: 4, color: const Color(0xFFFACC15))),
            Expanded(flex: 3, child: Container(height: 4, color: const Color(0xFF1D4ED8))),
            Expanded(flex: 3, child: Container(height: 4, color: const Color(0xFFDC2626))),
          ]),

          // Cabecera del reverso
          Container(
            color: const Color(0xFF0F766E),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(children: [
                  Icon(Icons.vaccines, color: Colors.white, size: 14),
                  SizedBox(width: 6),
                  Text('REGISTRO DE INMUNIZACIONES APLICADAS (PAI)',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ]),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                  child: Text('TOTAL: ${vacunasAplicadas.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          // Identificación del titular en el reverso
          Container(
            color: const Color(0xFFECFDF5),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            child: Row(children: [
              const Icon(Icons.person_pin_rounded, size: 10, color: Color(0xFF0F766E)),
              const SizedBox(width: 4),
              Expanded(child: Text('${nombreCompleto.toUpperCase()} — $cedula',
                  style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF064E3B)),
                  overflow: TextOverflow.ellipsis)),
            ]),
          ),

          // Tabla compacta de dosis
          if (vacunasAplicadas.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: const Center(child: Column(children: [
                Icon(Icons.info_outline_rounded, size: 28, color: Color(0xFF94A3B8)),
                SizedBox(height: 6),
                Text('No registra dosis aplicadas en el sistema nominal.',
                    style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                Text('Al aplicar un biológico se actualizará automáticamente este carnet.',
                    style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
              ])),
            )
          else
            Table(
              columnWidths: const {
                0: FlexColumnWidth(2.6),
                1: FlexColumnWidth(1.2),
                2: FlexColumnWidth(1.4),
                3: FlexColumnWidth(1.2),
                4: FlexColumnWidth(1.6),
              },
              children: [
                TableRow(
                  decoration: const BoxDecoration(color: Color(0xFFECFDF5)),
                  children: [
                    _thCell('Biológico / Vacuna'), _thCell('Dosis'),
                    _thCell('Fecha'), _thCell('Lote'), _thCell('Establecimiento'),
                  ],
                ),
                ...vacunasAplicadas.take(6).map((v) {
                  final fechaRaw = v['fecha'] != null ? v['fecha'].toString().split('T')[0] : '-';
                  return TableRow(
                    decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFD1FAE5), width: 0.6))),
                    children: [
                      _tdCell(v['vacuna'] ?? '-', isBold: true),
                      _tdBadgeDosis(v['dosis'] ?? '-'),
                      _tdCell(fechaRaw),
                      _tdCell(v['lote'] ?? 'S/L'),
                      _tdCell(v['centro'] ?? 'CDI Pedro Urbina', isItalic: true),
                    ],
                  );
                }),
              ],
            ),

          // Pie del reverso
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: const BoxDecoration(
              color: Color(0xFFF0FDF4),
              border: Border(top: BorderSide(color: Color(0xFFD1FAE5))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('CENTRO DE SALUD CDI DR. PEDRO URBINA',
                      style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                  Text('Titular: $cedula · Guanipa, Anzoátegui',
                      style: const TextStyle(fontSize: 7, color: Color(0xFF64748B))),
                  const Text('ASIC Guanipa · Salud MPPS',
                      style: TextStyle(fontSize: 6.5, color: Color(0xFF94A3B8))),
                ]),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFF0F766E), width: 0.8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('RESPONSABLE DE INMUNIZACIÓN',
                          style: TextStyle(fontSize: 6.5, fontWeight: FontWeight.bold, color: Color(0xFF0F766E))),
                      const SizedBox(height: 1),
                      Text(vacunadorNombre.toUpperCase(),
                          style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const Text('Personal Autorizado · MPPS PAI',
                          style: TextStyle(fontSize: 6, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  // ─── Helpers de Diseño ────────────────────────────────────────────────────
  Widget _miniCampo(String etiqueta, String valor) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(etiqueta, style: const TextStyle(fontSize: 7.5, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
      Text(valor, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
    ]);
  }

  Widget _thCell(String texto) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: Text(texto, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF064E3B))),
    );
  }

  Widget _tdCell(String texto, {bool isBold = false, bool isItalic = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4.5),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 8.5,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
          color: const Color(0xFF1E293B),
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _tdBadgeDosis(String dosis) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(3)),
          child: Text(dosis, style: const TextStyle(fontSize: 7.5, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline_rounded, size: 40, color: Colors.red),
        const SizedBox(height: 8),
        Text(_error ?? 'Error desconocido', style: const TextStyle(fontSize: 12, color: Colors.red)),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _cargarHistorial,
          icon: const Icon(Icons.refresh, size: 14),
          label: const Text('Reintentar', style: TextStyle(fontSize: 11)),
        ),
      ])),
    );
  }
}

import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:asis_guanipa_frontend/models/paciente.dart';
import 'package:asis_guanipa_frontend/services/api_service.dart';
import 'package:asis_guanipa_frontend/providers/auth_providers.dart';

import 'package:asis_guanipa_frontend/utils/web_helper.dart' as webHelper;

/// ─────────────────────────────────────────────────────────────────────────────
/// CONSTANCIA OFICIAL DE ATENCIÓN CON QR VERIFICABLE (FASE 4)
/// MPPS · ASIC San José de Guanipa · CDI Dr. Pedro Urbina
/// Documento médico-legal para trámites escolares, laborales e institucionales.
/// ─────────────────────────────────────────────────────────────────────────────
class ConstanciaAtencionDialog extends StatefulWidget {
  final Paciente paciente;
  final Map<String, dynamic>? atencionReciente;
  final String? profesionalNombre;
  final String? motivoAtencion;

  ConstanciaAtencionDialog({
    super.key,
    required this.paciente,
    Map<String, dynamic>? atencionReciente,
    Map<String, dynamic>? atencion,
    this.profesionalNombre,
    this.motivoAtencion,
  }) : atencionReciente = atencionReciente ?? atencion;

  static Future<void> show(
    BuildContext context, {
    required Paciente paciente,
    Map<String, dynamic>? atencionReciente,
    Map<String, dynamic>? atencion,
    String? profesionalNombre,
    String? motivoAtencion,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => ConstanciaAtencionDialog(
        paciente: paciente,
        atencionReciente: atencionReciente ?? atencion,
        profesionalNombre: profesionalNombre,
        motivoAtencion: motivoAtencion,
      ),
    );
  }

  @override
  State<ConstanciaAtencionDialog> createState() => _ConstanciaAtencionDialogState();
}

class _ConstanciaAtencionDialogState extends State<ConstanciaAtencionDialog> {
  final ApiService _apiService = ApiService();
  bool _loading = true;
  String? _error;
  List<dynamic> _historialAtenciones = [];
  Map<String, dynamic>? _selectedAtencion;
  late TextEditingController _observacionesController;

  @override
  void initState() {
    super.initState();
    _observacionesController = TextEditingController(
      text: widget.motivoAtencion ?? 'Atención sanitaria preventiva y esquema de inmunización nacional.',
    );
    _cargarDatos();
  }

  @override
  void dispose() {
    _observacionesController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (widget.atencionReciente != null) {
        _selectedAtencion = widget.atencionReciente;
      }

      final idOIdentificador = widget.paciente.idPaciente > 0
          ? widget.paciente.idPaciente.toString()
          : (widget.paciente.cedula.isNotEmpty ? widget.paciente.cedula : '0');

      if (idOIdentificador != '0') {
        final res = await _apiService.getHistorialPaciente(idOIdentificador);
        if (res['success'] == true && res['data'] != null) {
          final data = res['data'];
          if (data is Map && data['atenciones'] is List) {
            _historialAtenciones = data['atenciones'];
            if (_selectedAtencion == null && _historialAtenciones.isNotEmpty) {
              _selectedAtencion = _historialAtenciones.first as Map<String, dynamic>;
            }
          }
        }
      }
    } catch (e) {
      // Usar datos básicos si no carga el historial completo
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String _obtenerProfesional() {
    if (widget.profesionalNombre != null && widget.profesionalNombre!.isNotEmpty) {
      return widget.profesionalNombre!;
    }
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
    return 'Lcdo(a). Personal Asistencial de Guardia';
  }

  String _generarCodigoConstancia() {
    final now = DateTime.now();
    final anio = now.year;
    final ciLimpia = widget.paciente.cedula.replaceAll(RegExp(r'[^0-9]'), '');
    final suffix = ciLimpia.length >= 4 ? ciLimpia.substring(ciLimpia.length - 4) : '0001';
    final mes = now.month.toString().padLeft(2, '0');
    final dia = now.day.toString().padLeft(2, '0');
    return 'CDIPU-$anio-$mes$dia-$suffix';
  }

  String _generarUrlVerificacion(String codigo) {
    final baseUri = kIsWeb ? webHelper.getOrigin() : 'https://asicguanipa.gob.ve';
    final ced = widget.paciente.cedula.isNotEmpty ? widget.paciente.cedula : 'S-CI';
    return '$baseUri/verificar-constancia?codigo=$codigo&ci=$ced';
  }

  Future<String?> _generarQrBase64(String data) async {
    try {
      final painter = QrPainter(
        data: data,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
        gapless: true,
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

  Future<void> _imprimirConstancia() async {
    if (!kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Función de impresión directa disponible en navegador web.'),
          backgroundColor: Color(0xFF1E3A8A),
        ),
      );
      return;
    }

    // 1. Abrir la ventana en blanco inmediatamente durante el clic para evitar bloqueo de pop-up
    dynamic ventana;
    if (kIsWeb) {
      ventana = webHelper.openBlankWindow();
    }

    final p = widget.paciente;
    final codigoDoc = _generarCodigoConstancia();
    final urlVerificacion = _generarUrlVerificacion(codigoDoc);
    final qrBase64 = await _generarQrBase64(urlVerificacion) ?? '';
    final profesional = _obtenerProfesional();
    final fechaHoy = DateFormat('dd \'de\' MMMM \'de\' yyyy', 'es_ES').format(DateTime.now());
    final horaActual = DateFormat('hh:mm a').format(DateTime.now());

    final detalleVacuna = _selectedAtencion != null
        ? (_selectedAtencion!['biologico'] ??
           _selectedAtencion!['vacuna'] ??
           _selectedAtencion!['nombre_biologico'] ??
           'Inmunización Preventiva')
        : 'Inmunización / Consulta Preventiva';

    final dosis = _selectedAtencion?['dosis_esquema'] ??
        _selectedAtencion?['dosis'] ??
        'Dosis correspondiente al esquema';

    final lote = _selectedAtencion?['lote'] ?? 'Lote Oficial MPPS';

    final htmlContent = '''
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <title>Constancia de Atención - ${p.nombreCompleto}</title>
  <style>
    @page {
      size: letter portrait;
      margin: 18mm 20mm 18mm 20mm;
    }
    * {
      box-sizing: border-box;
      -webkit-print-color-adjust: exact !important;
      print-color-adjust: exact !important;
    }
    body {
      font-family: 'Segoe UI', Arial, sans-serif;
      color: #0F172A;
      margin: 0;
      padding: 0;
      line-height: 1.5;
      font-size: 13px;
      background: #FFFFFF;
    }
    .header {
      border-bottom: 2px solid #005691;
      padding-bottom: 12px;
      margin-bottom: 22px;
      display: flex;
      align-items: center;
      justify-content: space-between;
    }
    .header-text {
      flex: 1;
      text-align: center;
    }
    .header-text h3 {
      margin: 0;
      font-size: 11px;
      letter-spacing: 0.8px;
      color: #334155;
      font-weight: 600;
      text-transform: uppercase;
    }
    .header-text h2 {
      margin: 3px 0 0 0;
      font-size: 14px;
      color: #005691;
      font-weight: 800;
      letter-spacing: 0.5px;
    }
    .header-text p {
      margin: 2px 0 0 0;
      font-size: 10px;
      color: #64748B;
    }
    .doc-badge {
      text-align: right;
      font-size: 10px;
      color: #475569;
    }
    .doc-badge strong {
      display: block;
      color: #0F172A;
      font-size: 11px;
    }
    .title-banner {
      text-align: center;
      margin: 25px 0 20px 0;
    }
    .title-banner h1 {
      margin: 0;
      font-size: 18px;
      color: #0F172A;
      text-transform: uppercase;
      letter-spacing: 1.2px;
      font-weight: 900;
    }
    .title-banner span {
      display: inline-block;
      margin-top: 4px;
      background: #EFF6FF;
      color: #1E40AF;
      border: 1px solid #BFDBFE;
      padding: 3px 12px;
      border-radius: 12px;
      font-size: 10px;
      font-weight: 700;
      letter-spacing: 0.5px;
    }
    .statement {
      font-size: 14px;
      line-height: 1.8;
      text-align: justify;
      margin-bottom: 24px;
      color: #1E293B;
    }
    .statement strong {
      color: #0F172A;
    }
    .info-card {
      background: #F8FAFC;
      border: 1px solid #E2E8F0;
      border-radius: 8px;
      padding: 14px 18px;
      margin-bottom: 22px;
    }
    .info-card h4 {
      margin: 0 0 10px 0;
      font-size: 12px;
      text-transform: uppercase;
      color: #005691;
      border-bottom: 1px solid #CBD5E1;
      padding-bottom: 4px;
      letter-spacing: 0.5px;
    }
    .info-grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 10px 20px;
      font-size: 12px;
    }
    .info-item span {
      display: block;
      color: #64748B;
      font-size: 10px;
      text-transform: uppercase;
      font-weight: 600;
    }
    .info-item strong {
      color: #0F172A;
      font-size: 12px;
    }
    .verification-box {
      margin-top: 35px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      border-top: 1px dashed #CBD5E1;
      padding-top: 20px;
    }
    .qr-side {
      display: flex;
      align-items: center;
      gap: 14px;
    }
    .qr-side img {
      width: 95px;
      height: 95px;
      border: 1px solid #E2E8F0;
      border-radius: 6px;
      padding: 3px;
      background: #FFFFFF;
    }
    .qr-desc {
      font-size: 10px;
      color: #475569;
      max-width: 250px;
      line-height: 1.4;
    }
    .qr-desc strong {
      color: #005691;
      font-size: 11px;
      display: block;
      margin-bottom: 2px;
    }
    .signature-side {
      text-align: center;
      width: 240px;
    }
    .signature-line {
      border-bottom: 1px solid #0F172A;
      margin-bottom: 6px;
      height: 40px;
    }
    .signature-name {
      font-size: 12px;
      font-weight: 700;
      color: #0F172A;
    }
    .signature-role {
      font-size: 10px;
      color: #64748B;
    }
    .footer-note {
      margin-top: 25px;
      text-align: center;
      font-size: 9px;
      color: #94A3B8;
      border-top: 1px solid #F1F5F9;
      padding-top: 8px;
    }
  </style>
</head>
<body>
  <div class="header">
    <div class="header-text">
      <h3>República Bolivariana de Venezuela</h3>
      <h3>Ministerio del Poder Popular para la Salud · ASIC San José de Guanipa</h3>
      <h2>CENTRO DE DIAGNÓSTICO INTEGRAL DR. PEDRO URBINA</h2>
      <p>Municipio San José de Guanipa, Estado Anzoátegui — Sistema de Gestión Epidemiológica y Nominal</p>
    </div>
    <div class="doc-badge">
      <span>Código de Emisión:</span>
      <strong>$codigoDoc</strong>
    </div>
  </div>

  <div class="title-banner">
    <h1>Constancia Oficial de Atención</h1>
    <span>DOCUMENTO SANITARIO CERTIFICADO CON CÓDIGO QR</span>
  </div>

  <div class="statement">
    Quien suscribe, personal de salud asistencial en funciones del <strong>Centro de Diagnóstico Integral (CDI) Dr. Pedro Urbina</strong>,
    hace constar por medio de la presente que el (la) ciudadano(a) cuyos datos filiatorios se detallan a continuación,
    acudió a este centro de salud asistencial / jornada médica comunitaria y recibió la atención sanitaria correspondiente:
  </div>

  <div class="info-card">
    <h4>1. Datos de Identificación del Paciente</h4>
    <div class="info-grid">
      <div class="info-item">
        <span>Nombres y Apellidos:</span>
        <strong>${p.nombreCompleto}</strong>
      </div>
      <div class="info-item">
        <span>Cédula de Identidad / Código:</span>
        <strong>${p.cedula.isNotEmpty ? p.cedula : 'Menor sin cédula'} ${p.esMenor ? '(Menor de Edad)' : ''}</strong>
      </div>
      <div class="info-item">
        <span>Edad / Sexo:</span>
        <strong>${p.edadFormateada} · ${p.sexoFormateado}</strong>
      </div>
      <div class="info-item">
        <span>Comunidad / Sector:</span>
        <strong>${p.direccionCompleta ?? 'San José de Guanipa'}</strong>
      </div>
    </div>
  </div>

  <div class="info-card">
    <h4>2. Detalle del Acto Sanitario Realizado</h4>
    <div class="info-grid">
      <div class="info-item">
        <span>Servicio / Procedimiento:</span>
        <strong>$detalleVacuna</strong>
      </div>
      <div class="info-item">
        <span>Esquema / Dosis:</span>
        <strong>$dosis</strong>
      </div>
      <div class="info-item">
        <span>Lote Oficial:</span>
        <strong>$lote</strong>
      </div>
      <div class="info-item">
        <span>Fecha y Hora de Atención:</span>
        <strong>$fechaHoy — $horaActual</strong>
      </div>
    </div>
  </div>

  <div class="info-card">
    <h4>3. Observaciones y Recomendaciones Clínicas</h4>
    <div style="font-size: 11px; color: #334155; line-height: 1.5;">
      ${_observacionesController.text.trim()}
    </div>
  </div>

  <div class="verification-box">
    <div class="qr-side">
      ${qrBase64.isNotEmpty ? '<img src="$qrBase64" alt="Código QR de Validación">' : ''}
      <div class="qr-desc">
        <strong>VALIDACIÓN DE AUTENTICIDAD</strong>
        Escanee este código con cualquier teléfono inteligente para verificar la legitimidad de esta constancia directamente en el servidor institucional del ASIC Guanipa.
      </div>
    </div>

    <div class="signature-side">
      <div class="signature-line"></div>
      <div class="signature-name">$profesional</div>
      <div class="signature-role">Firma y Sello Oficial Asistencial<br>CDI Dr. Pedro Urbina / ASIC Guanipa</div>
    </div>
  </div>

  <div class="footer-note">
    Documento emitido con valor institucional conforme a las regulaciones sanitarias del MPPS. Válido para trámites educativos, laborales y de control epidemiológico.
  </div>

  <script>
    window.onload = function() {
      setTimeout(function() {
        window.print();
      }, 500);
    };
  </script>
</body>
</html>
''';

    await webHelper.openHtmlPrint(htmlContent, ventana);
  }

  Future<void> _lanzarImpresionWeb(String htmlContent, [dynamic ventanaPrevia]) async {
    await webHelper.openHtmlPrint(htmlContent, ventanaPrevia);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final p = widget.paciente;
    final profesional = _obtenerProfesional();
    final codigoDoc = _generarCodigoConstancia();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 36,
        vertical: isMobile ? 16 : 28,
      ),
      child: Container(
        width: 820,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // ─── Header ──────────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
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
                      color: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF0EA5E9).withValues(alpha: 0.3)),
                    ),
                    child: const Icon(
                      Icons.verified_rounded,
                      color: Color(0xFF38BDF8),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Constancia Oficial de Atención con QR',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                        Text(
                          'CDI Dr. Pedro Urbina · ASIC San José de Guanipa',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // ─── Body (Vista previa desplazable) ──────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: EdgeInsets.all(isMobile ? 14 : 22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Tarjeta de la Constancia (simulando hoja oficial)
                          Container(
                            padding: EdgeInsets.all(isMobile ? 14 : 20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Membrete
                                Center(
                                  child: Column(
                                    children: [
                                      const Text(
                                        'REPÚBLICA BOLIVARIANA DE VENEZUELA',
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                      ),
                                      const Text(
                                        'MINISTERIO DEL PODER POPULAR PARA LA SALUD',
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                      ),
                                      const SizedBox(height: 2),
                                      const Text(
                                        'CDI DR. PEDRO URBINA — ASIC GUANIPA',
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF005691)),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEFF6FF),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: const Color(0xFFBFDBFE)),
                                        ),
                                        child: Text(
                                          'CÓDIGO: $codigoDoc',
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF1E40AF)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const Divider(height: 24, color: Color(0xFFCBD5E1)),

                                // Título principal
                                const Center(
                                  child: Text(
                                    'CONSTANCIA MÉDICA DE ATENCIÓN',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF0F172A),
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Párrafo introductorio
                                RichText(
                                  text: TextSpan(
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.5),
                                    children: [
                                      const TextSpan(text: 'Por medio de la presente se hace constar que el (la) ciudadano(a) '),
                                      TextSpan(
                                        text: p.nombreCompleto.toUpperCase(),
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                      ),
                                      const TextSpan(text: ', titular de la cédula o documento de identidad '),
                                      TextSpan(
                                        text: p.cedula.isNotEmpty ? p.cedula : 'Menor dependiente',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                      ),
                                      const TextSpan(text: ', de '),
                                      TextSpan(
                                        text: p.edadFormateada,
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                      ),
                                      const TextSpan(text: ' de edad, domiciliado(a) en el sector '),
                                      TextSpan(
                                        text: p.direccionCompleta ?? 'San José de Guanipa',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                      ),
                                      const TextSpan(text: ', recibió atención en este centro asistencial conforme al siguiente registro clínico:'),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // Tarjeta de detalles de atención
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                  ),
                                  child: Column(
                                    children: [
                                      _itemFila(
                                        'Procedimiento / Biológico',
                                        _selectedAtencion != null
                                            ? (_selectedAtencion!['biologico'] ??
                                               _selectedAtencion!['vacuna'] ??
                                               _selectedAtencion!['nombre_biologico'] ??
                                               'Inmunización Preventiva')
                                            : 'Atención e Inmunización Sanitaria',
                                      ),
                                      const Divider(height: 12),
                                      _itemFila(
                                        'Dosis / Esquema',
                                        _selectedAtencion?['dosis_esquema'] ??
                                            _selectedAtencion?['dosis'] ??
                                            'Dosis correspondiente',
                                      ),
                                      const Divider(height: 12),
                                      _itemFila(
                                        'Fecha de Atención',
                                        DateFormat('dd/MM/yyyy · hh:mm a').format(DateTime.now()),
                                      ),
                                      const Divider(height: 12),
                                      _itemFila('Personal Asistencial', profesional),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 14),

                                // Campo de Observaciones editables
                                const Text(
                                  'Observaciones / Justificación:',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                ),
                                const SizedBox(height: 4),
                                TextField(
                                  controller: _observacionesController,
                                  maxLines: 2,
                                  style: const TextStyle(fontSize: 12),
                                  decoration: InputDecoration(
                                    hintText: 'Ej. Se emite constancia para fines escolares y laborales.',
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.all(10),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 18),

                                // QR y sello en la vista previa
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    children: [
                                      QrImageView(
                                        data: _generarUrlVerificacion(codigoDoc),
                                        version: QrVersions.auto,
                                        size: 75,
                                        eyeStyle: const QrEyeStyle(
                                          eyeShape: QrEyeShape.square,
                                          color: Color(0xFF0F172A),
                                        ),
                                        dataModuleStyle: const QrDataModuleStyle(
                                          dataModuleShape: QrDataModuleShape.square,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Código QR de Verificación Pública',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                            SizedBox(height: 2),
                                            Text(
                                              'Cualquier institución pública, privada o educativa puede escanear este código para corroborar la autenticidad de este documento en el servidor oficial.',
                                              style: TextStyle(fontSize: 10, color: Color(0xFF64748B), height: 1.3),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),

            // ─── Footer de Acciones ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: isMobile
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _imprimirConstancia,
                          icon: const Icon(Icons.print_rounded, size: 18),
                          label: const Text('Imprimir Constancia Oficial'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF005691),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cerrar', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        TextButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded, size: 16),
                          label: const Text('Cerrar'),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF64748B),
                          ),
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: _imprimirConstancia,
                          icon: const Icon(Icons.print_rounded, size: 18),
                          label: const Text('Imprimir Constancia Oficial'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF005691),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 1,
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

  Widget _itemFila(String label, String valor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
        ),
        Flexible(
          child: Text(
            valor,
            style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

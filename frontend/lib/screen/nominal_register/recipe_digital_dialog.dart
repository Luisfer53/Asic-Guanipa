import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:asis_guanipa_frontend/models/paciente.dart';
import 'package:asis_guanipa_frontend/services/api_service.dart';
import 'package:asis_guanipa_frontend/providers/auth_providers.dart';

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// ─────────────────────────────────────────────────────────────────────────────
/// RÉCIPE DIGITAL OFICIAL & INDICACIONES MÉDICAS
/// Formato Estandarizado MPPS / ASIC San José de Guanipa / CDI Dr. Pedro Urbina
/// Generación de Prescripción con Código QR de Trazabilidad para Farmacia
/// ─────────────────────────────────────────────────────────────────────────────

class RecipeMedicamentoItem {
  String medicamento;
  String concentracion;
  String forma;
  String cantidad;
  String via;
  String posologia;

  RecipeMedicamentoItem({
    required this.medicamento,
    this.concentracion = '',
    this.forma = 'Tabletas',
    this.cantidad = '1 Unidad',
    this.via = 'Vía Oral',
    this.posologia = '',
  });

  Map<String, String> toMap() => {
        'medicamento': medicamento,
        'concentracion': concentracion,
        'forma': forma,
        'cantidad': cantidad,
        'via': via,
        'posologia': posologia,
      };
}

class RecipeDigitalDialog extends StatefulWidget {
  final Paciente paciente;
  final String? medicoNombre;
  final String? motivoAtencion;

  const RecipeDigitalDialog({
    super.key,
    required this.paciente,
    this.medicoNombre,
    this.motivoAtencion,
  });

  static Future<void> show(
    BuildContext context, {
    required Paciente paciente,
    String? medicoNombre,
    String? motivoAtencion,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => RecipeDigitalDialog(
        paciente: paciente,
        medicoNombre: medicoNombre,
        motivoAtencion: motivoAtencion,
      ),
    );
  }

  @override
  State<RecipeDigitalDialog> createState() => _RecipeDigitalDialogState();
}

class _RecipeDigitalDialogState extends State<RecipeDigitalDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Controladores de texto del récipe
  final TextEditingController _diagnosticoController = TextEditingController();
  final TextEditingController _indicacionesGeneralesController =
      TextEditingController();
  final TextEditingController _medicoNombreController = TextEditingController();
  final TextEditingController _medicoCedulaController = TextEditingController();
  final TextEditingController _medicoMppsController = TextEditingController();
  final TextEditingController _pesoController = TextEditingController();

  final List<RecipeMedicamentoItem> _medicamentos = [];

  // Formulario rápido para añadir medicamento
  final TextEditingController _medNombreInput = TextEditingController();
  final TextEditingController _medConcInput = TextEditingController();
  final TextEditingController _medCantInput = TextEditingController();
  final TextEditingController _medPosologiaInput = TextEditingController();
  String _medFormaSeleccionada = 'Tabletas';
  String _medViaSeleccionada = 'Vía Oral';

  static const Color _primary = Color(0xFF1E3A8A); // Azul institucional MPPS
  static const Color _accent = Color(0xFF0284C7);
  static const Color _surface = Color(0xFFF8FAFC);
  static const Color _cardBorder = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _diagnosticoController.text = widget.motivoAtencion ??
        (widget.paciente.esMenor
            ? 'Control de Salud / Inmunización Pediátrica'
            : 'Atención Médica General / Inmunización');

    _indicacionesGeneralesController.text =
        '1. Mantener adecuada hidratación oral.\n'
        '2. En caso de presentar fiebre > 38.5°C o malestar post-vacunal, administrar antipirético según posología indicada.\n'
        '3. No frotar ni aplicar compresas calientes en el área de inyección.\n'
        '4. Acudir al CDI ante cualquier signo de alarma o reacción adversa.';

    // Inicializar datos del médico desde la sesión actual o parámetro
    _inicializarDatosMedico();

    // Precargar un medicamento común post-atención por defecto
    _medicamentos.add(
      RecipeMedicamentoItem(
        medicamento: widget.paciente.esMenor
            ? 'Acetaminofén (Paracetamol) Pediátrico'
            : 'Acetaminofén (Paracetamol)',
        concentracion: widget.paciente.esMenor ? '120 mg / 5 mL' : '500 mg',
        forma: widget.paciente.esMenor ? 'Jarabe / Suspensión' : 'Tabletas',
        cantidad: widget.paciente.esMenor ? '1 Frasco x 120 mL' : '1 Blíster x 10 tabletas',
        via: 'Vía Oral',
        posologia: widget.paciente.esMenor
            ? 'Administrar según peso corporal cada 6 a 8 horas si hay fiebre o dolor.'
            : 'Tomar 1 tableta cada 8 horas en caso de fiebre o dolor moderado (máx. 3 días).',
      ),
    );
  }

  void _inicializarDatosMedico() {
    if (widget.medicoNombre != null && widget.medicoNombre!.trim().isNotEmpty) {
      _medicoNombreController.text = widget.medicoNombre!.trim();
    } else {
      try {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final u = auth.getCurrentUser();
        if (u != null) {
          if (u.displayName.isNotEmpty && u.displayName != 'Usuario') {
            _medicoNombreController.text = u.displayName;
          } else if (u.username != null && u.username!.isNotEmpty) {
            _medicoNombreController.text = u.username!;
          }
        }
      } catch (_) {}
    }

    if (_medicoNombreController.text.isEmpty) {
      _medicoNombreController.text = 'Dr(a). Médico de Guardia';
    }

    _medicoCedulaController.text = 'V-18.942.103';
    _medicoMppsController.text = 'MPPS N° 104.892 · CM 5.210';
  }

  @override
  void dispose() {
    _tabController.dispose();
    _diagnosticoController.dispose();
    _indicacionesGeneralesController.dispose();
    _medicoNombreController.dispose();
    _medicoCedulaController.dispose();
    _medicoMppsController.dispose();
    _pesoController.dispose();
    _medNombreInput.dispose();
    _medConcInput.dispose();
    _medCantInput.dispose();
    _medPosologiaInput.dispose();
    super.dispose();
  }

  void _agregarMedicamento() {
    if (_medNombreInput.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor escribe el nombre del medicamento'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() {
      _medicamentos.add(
        RecipeMedicamentoItem(
          medicamento: _medNombreInput.text.trim(),
          concentracion: _medConcInput.text.trim(),
          forma: _medFormaSeleccionada,
          cantidad: _medCantInput.text.trim().isEmpty
              ? '1 Unidad'
              : _medCantInput.text.trim(),
          via: _medViaSeleccionada,
          posologia: _medPosologiaInput.text.trim().isEmpty
              ? 'Tomar según indicación médica.'
              : _medPosologiaInput.text.trim(),
        ),
      );

      _medNombreInput.clear();
      _medConcInput.clear();
      _medCantInput.clear();
      _medPosologiaInput.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Medicamento añadido al récipe'),
        backgroundColor: Color(0xFF16A34A),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _eliminarMedicamento(int index) {
    setState(() {
      _medicamentos.removeAt(index);
    });
  }

  // Carga rápida de combinaciones frecuentes
  void _cargarPreset(String nombre, String conc, String forma, String cant, String pos) {
    _medNombreInput.text = nombre;
    _medConcInput.text = conc;
    _medCantInput.text = cant;
    _medPosologiaInput.text = pos;
    setState(() {
      _medFormaSeleccionada = forma;
    });
  }

  String _generarHashVerificacion() {
    final clean = widget.paciente.cedula.replaceAll(RegExp(r'[^0-9A-Z]'), '');
    final raw = 'RECIPE-CDI-PEDRO-URBINA|$clean|${_medicamentos.length}|${DateTime.now().toIso8601String().substring(0, 10)}';
    int hash = 5381;
    for (final c in raw.codeUnits) {
      hash = (((hash << 5) + hash) ^ c) & 0xFFFFFFFF;
    }
    return (hash % 9999999).toString().padLeft(7, '0');
  }

  String _generarUrlVerificacion(String hash) {
    final baseUrl = ApiService.getBaseUrlWithoutApi(ApiService.baseUrl);
    final cleanCedula = widget.paciente.cedula.replaceAll(' ', '').replaceAll('-', '');
    return '$baseUrl/recipe/verificar?id=$cleanCedula&folio=$hash';
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

  Future<void> _imprimirRecipe() async {
    if (!kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Función de impresión disponible en navegador web.'),
          backgroundColor: Color(0xFF1E3A8A),
        ),
      );
      return;
    }

    final hash = _generarHashVerificacion();
    final urlQR = _generarUrlVerificacion(hash);

    String? qrBase64;
    try {
      qrBase64 = await _generarQrBase64(urlQR).timeout(
        const Duration(milliseconds: 800),
        onTimeout: () => null,
      );
    } catch (_) {}

    final htmlContent = _construirHtmlImpresion(hash, urlQR, qrBase64);

    try {
      final blob = html.Blob([htmlContent], 'text/html;charset=utf-8');
      final blobUrl = html.Url.createObjectUrlFromBlob(blob);
      final ventana = html.window.open(blobUrl, '_blank');

      if (ventana == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor permite ventanas emergentes (pop-ups) para imprimir.'),
            backgroundColor: Color(0xFFD97706),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al preparar impresión: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  String _construirHtmlImpresion(String hash, String urlQR, String? qrBase64) {
    final now = DateTime.now();
    final fechaHoy = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final horaHoy = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final pacienteNom = widget.paciente.nombreCompleto;
    final cedula = widget.paciente.cedula;
    final edad = widget.paciente.edadFormateada;
    final sexo = widget.paciente.sexoFormateado;
    final peso = _pesoController.text.trim().isNotEmpty ? '${_pesoController.text.trim()} kg' : 'S/R';
    final diag = _diagnosticoController.text.trim();
    final medico = _medicoNombreController.text.trim();
    final mpps = _medicoMppsController.text.trim();
    final cedMedico = _medicoCedulaController.text.trim();

    final qrImgTag = qrBase64 != null
        ? '<img src="$qrBase64" alt="QR Verificación" style="width: 78px; height: 78px;">'
        : '<div style="width:78px;height:78px;border:1px dashed #94a3b8;font-size:10px;display:flex;align-items:center;justify-content:center;">QR</div>';

    // Generar lista de medicamentos para el lado del récipe
    final bufferMedsRecipe = StringBuffer();
    final bufferMedsIndic = StringBuffer();

    for (int i = 0; i < _medicamentos.length; i++) {
      final m = _medicamentos[i];
      final num = i + 1;
      bufferMedsRecipe.write('''
        <div class="med-item-recipe">
          <div class="med-num">#$num</div>
          <div class="med-body">
            <div class="med-title"><strong>${m.medicamento}</strong> ${m.concentracion.isNotEmpty ? '— ' + m.concentracion : ''}</div>
            <div class="med-meta">Forma: ${m.forma} &nbsp;·&nbsp; Cantidad: <strong>${m.cantidad}</strong> &nbsp;·&nbsp; Vía: ${m.via}</div>
          </div>
        </div>
      ''');

      bufferMedsIndic.write('''
        <div class="med-item-indic">
          <div class="med-num-circle">$num</div>
          <div class="med-body">
            <div class="med-title"><strong>${m.medicamento}</strong> (${m.concentracion})</div>
            <div class="med-posologia">👉 <strong>Posología:</strong> ${m.posologia}</div>
          </div>
        </div>
      ''');
    }

    final indicGenerales = _indicacionesGeneralesController.text.trim().replaceAll('\n', '<br>');

    return '''
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <title>Récipe Médico Oficial — CDI Dr. Pedro Urbina</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: 'Segoe UI', -apple-system, BlinkMacSystemFont, Roboto, Helvetica, Arial, sans-serif;
      background: #f1f5f9;
      color: #0f172a;
      padding: 20px;
    }

    /* Barra superior de herramientas */
    .toolbar {
      max-width: 960px;
      margin: 0 auto 16px auto;
      display: flex;
      justify-content: space-between;
      align-items: center;
      background: #ffffff;
      padding: 12px 20px;
      border-radius: 10px;
      box-shadow: 0 2px 8px rgba(0,0,0,0.06);
    }
    .btn-print {
      background: #1e3a8a;
      color: #ffffff;
      border: none;
      padding: 8px 18px;
      border-radius: 6px;
      font-size: 13px;
      font-weight: 700;
      cursor: pointer;
    }
    .btn-print:hover { background: #172554; }

    /* Contenedor del Récipe Duplicado Estándar (Récipe + Indicaciones lado a lado) */
    .recipe-sheet {
      max-width: 960px;
      margin: 0 auto;
      background: #ffffff;
      border: 1px solid #cbd5e1;
      border-radius: 8px;
      display: grid;
      grid-template-columns: 1fr 1fr;
      box-shadow: 0 4px 16px rgba(0,0,0,0.08);
      position: relative;
    }

    /* Línea divisoria central con efecto de corte */
    .recipe-sheet::after {
      content: '';
      position: absolute;
      top: 0;
      bottom: 0;
      left: 50%;
      width: 1px;
      border-left: 1.5px dashed #94a3b8;
    }

    .column-half {
      padding: 24px 28px;
      display: flex;
      flex-direction: column;
      justify-content: space-between;
      min-height: 640px;
    }

    /* Encabezado */
    .header-gov {
      border-bottom: 2px solid #1e3a8a;
      padding-bottom: 10px;
      margin-bottom: 14px;
    }
    .gov-republica {
      font-size: 9.5px;
      font-weight: 800;
      color: #1e3a8a;
      letter-spacing: 0.5px;
      text-transform: uppercase;
    }
    .gov-asic {
      font-size: 12px;
      font-weight: 800;
      color: #0f172a;
    }
    .gov-cdi {
      font-size: 10px;
      color: #475569;
    }
    .doc-badge-row {
      margin-top: 6px;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    .doc-badge {
      display: inline-block;
      background: #1e3a8a;
      color: #ffffff;
      font-size: 10px;
      font-weight: 800;
      padding: 3px 8px;
      border-radius: 4px;
      letter-spacing: 0.4px;
    }
    .doc-badge.indic {
      background: #0284c7;
    }
    .folio-tag {
      font-size: 9.5px;
      font-weight: 700;
      color: #64748b;
    }

    /* Datos del Paciente */
    .patient-card {
      background: #f8fafc;
      border: 1px solid #e2e8f0;
      border-radius: 6px;
      padding: 8px 12px;
      margin-bottom: 14px;
      font-size: 11px;
      line-height: 1.5;
    }
    .patient-row {
      display: flex;
      justify-content: space-between;
    }

    /* Rp y Lista */
    .rp-symbol {
      font-size: 18px;
      font-family: 'Times New Roman', serif;
      font-weight: bold;
      color: #1e3a8a;
      margin-bottom: 8px;
    }
    .med-item-recipe, .med-item-indic {
      display: flex;
      margin-bottom: 10px;
      font-size: 11.5px;
      line-height: 1.4;
    }
    .med-num {
      font-weight: 800;
      color: #1e3a8a;
      margin-right: 8px;
      font-size: 11px;
    }
    .med-num-circle {
      width: 18px;
      height: 18px;
      background: #0284c7;
      color: #fff;
      border-radius: 50%;
      font-size: 10px;
      font-weight: bold;
      display: flex;
      align-items: center;
      justify-content: center;
      margin-right: 8px;
      flex-shrink: 0;
    }
    .med-body { flex: 1; }
    .med-meta { font-size: 10.5px; color: #475569; }
    .med-posologia { font-size: 11px; color: #0f172a; margin-top: 2px; }

    /* Indicaciones generales */
    .indic-box {
      background: #fdf2f8;
      border-left: 3px solid #ec4899;
      padding: 8px 10px;
      border-radius: 4px;
      font-size: 10.5px;
      color: #831843;
      margin-top: 10px;
      line-height: 1.4;
    }

    /* Pie de página con firma y QR */
    .footer-stamp {
      border-top: 1px solid #cbd5e1;
      padding-top: 12px;
      margin-top: 16px;
      display: flex;
      justify-content: space-between;
      align-items: flex-end;
    }
    .stamp-info {
      font-size: 10px;
      line-height: 1.4;
      color: #334155;
    }
    .signature-line {
      width: 140px;
      border-top: 1px solid #0f172a;
      margin-top: 30px;
      padding-top: 2px;
      font-size: 9.5px;
      font-weight: 700;
      text-align: center;
    }
    .qr-box {
      text-align: center;
    }
    .qr-caption {
      font-size: 8px;
      color: #64748b;
      margin-top: 2px;
      font-weight: 600;
    }

    /* Estilos al imprimir */
    @media print {
      body {
        background: #ffffff !important;
        padding: 0 !important;
      }
      .toolbar { display: none !important; }
      .recipe-sheet {
        box-shadow: none !important;
        border: 1px solid #94a3b8 !important;
        max-width: 100% !important;
        page-break-inside: avoid;
      }
    }
  </style>
</head>
<body>
  <div class="toolbar">
    <div>
      <strong style="color: #1e3a8a; font-size: 14px;">ASIC Guanipa · CDI Dr. Pedro Urbina</strong>
      <div style="font-size: 11px; color: #64748b;">Récipe Oficial Digital — Verificación QR Activa</div>
    </div>
    <button class="btn-print" onclick="window.print()">🖨️ Imprimir Récipe / Guardar PDF</button>
  </div>

  <div class="recipe-sheet">
    <!-- COLUMNA IZQUIERDA: RÉCIPE (FARMACIA) -->
    <div class="column-half">
      <div>
        <div class="header-gov">
          <div class="gov-republica">República Bolivariana de Venezuela · MPPS</div>
          <div class="gov-asic">ASIC San José de Guanipa</div>
          <div class="gov-cdi">CDI Dr. Pedro Urbina · Municipio Guanipa, Anzoátegui</div>
          <div class="doc-badge-row">
            <span class="doc-badge">RÉCIPE MÉDICO</span>
            <span class="folio-tag">FOLIO: #$hash</span>
          </div>
        </div>

        <div class="patient-card">
          <div class="patient-row">
            <span><strong>Paciente:</strong> $pacienteNom</span>
            <span><strong>C.I./ID:</strong> $cedula</span>
          </div>
          <div class="patient-row" style="margin-top: 3px;">
            <span><strong>Edad:</strong> $edad &nbsp;·&nbsp; <strong>Sexo:</strong> $sexo</span>
            <span><strong>Peso:</strong> $peso</span>
          </div>
          <div style="margin-top: 3px; font-size: 10px; color: #64748b;">
            <strong>Diagnóstico / Causa:</strong> $diag
          </div>
        </div>

        <div class="rp-symbol">Rp.</div>
        <div class="meds-list">
          $bufferMedsRecipe
        </div>
      </div>

      <div class="footer-stamp">
        <div class="stamp-info">
          <div class="signature-line">
            $medico<br>
            <span style="font-size:8.5px; font-weight:normal;">C.I. $cedMedico · $mpps</span>
          </div>
          <div style="margin-top: 4px; font-size: 9px; color: #64748b;">
            Fecha: $fechaHoy &nbsp;·&nbsp; Hora: $horaHoy
          </div>
        </div>
        <div class="qr-box">
          $qrImgTag
          <div class="qr-caption">VALIDACIÓN FARMACIA</div>
        </div>
      </div>
    </div>

    <!-- COLUMNA DERECHA: INDICACIONES (PACIENTE) -->
    <div class="column-half">
      <div>
        <div class="header-gov">
          <div class="gov-republica">República Bolivariana de Venezuela · MPPS</div>
          <div class="gov-asic">ASIC San José de Guanipa</div>
          <div class="gov-cdi">CDI Dr. Pedro Urbina · Municipio Guanipa, Anzoátegui</div>
          <div class="doc-badge-row">
            <span class="doc-badge indic">INDICACIONES MÉDICAS</span>
            <span class="folio-tag">Fecha: $fechaHoy</span>
          </div>
        </div>

        <div class="patient-card">
          <div class="patient-row">
            <span><strong>Paciente:</strong> $pacienteNom</span>
            <span><strong>Edad:</strong> $edad</span>
          </div>
          <div style="margin-top: 3px; font-size: 10.5px;">
            <strong>Tratamiento prescrito y administración:</strong>
          </div>
        </div>

        <div class="meds-list">
          $bufferMedsIndic
        </div>

        <div class="indic-box">
          <strong>Cuidados y Recomendaciones Generales:</strong><br>
          $indicGenerales
        </div>
      </div>

      <div class="footer-stamp">
        <div class="stamp-info">
          <div class="signature-line">
            $medico<br>
            <span style="font-size:8.5px; font-weight:normal;">Firma y Sello Facultativo</span>
          </div>
          <div style="margin-top: 4px; font-size: 9px; color: #64748b;">
            Centro de Diagnóstico Integral Dr. Pedro Urbina
          </div>
        </div>
        <div class="qr-box">
          $qrImgTag
          <div class="qr-caption">SEGUIMIENTO CLÍNICO</div>
        </div>
      </div>
    </div>
  </div>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960, maxHeight: 780),
        child: Column(
          children: [
            // Header del diálogo
            _buildDialogHeader(),

            // Barra de pestañas
            Container(
              color: const Color(0xFFF1F5F9),
              child: TabBar(
                controller: _tabController,
                indicatorColor: _primary,
                labelColor: _primary,
                unselectedLabelColor: const Color(0xFF64748B),
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: const [
                  Tab(icon: Icon(Icons.edit_note_rounded, size: 18), text: 'Edición del Récipe'),
                  Tab(icon: Icon(Icons.visibility_rounded, size: 18), text: 'Vista Previa Oficial (Récipe + Indicaciones)'),
                ],
              ),
            ),

            // Contenido de las pestañas
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildEdicionTab(),
                  _buildVistaPreviaTab(),
                ],
              ),
            ),

            // Footer con botones de acción
            _buildDialogFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: _primary,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Récipe Médico Digital Oficial',
                  style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Paciente: ${widget.paciente.nombreCompleto} (${widget.paciente.cedula}) · ASIC San José de Guanipa',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            tooltip: 'Cerrar',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildEdicionTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tarjeta de datos del paciente y diagnóstico
          _buildPatientInfoSection(),
          const SizedBox(height: 20),

          // Presets rápidos de medicación frecuente
          _buildPresetsBar(),
          const SizedBox(height: 16),

          // Sección para agregar nuevo medicamento
          _buildAddMedicationCard(),
          const SizedBox(height: 24),

          // Lista de medicamentos prescritos
          _buildMedicamentosList(),
          const SizedBox(height: 20),

          // Indicaciones generales y datos del médico
          _buildDoctorAndIndicationsSection(),
        ],
      ),
    );
  }

  Widget _buildPatientInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_rounded, color: _primary, size: 18),
              const SizedBox(width: 8),
              const Text('Datos del Paciente y Motivo de Consulta',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Edad: ${widget.paciente.edadFormateada} · ${widget.paciente.sexoFormateado}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _diagnosticoController,
                  decoration: const InputDecoration(
                    labelText: 'Diagnóstico Clínico / Motivo de Prescripción',
                    prefixIcon: Icon(Icons.healing_rounded, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 1,
                child: TextField(
                  controller: _pesoController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Peso (Kg)',
                    hintText: 'Ej. 14.5',
                    prefixIcon: Icon(Icons.monitor_weight_outlined, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPresetsBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Plantillas Rápidas (Un Clic):',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              avatar: const Icon(Icons.medication_liquid_rounded, size: 14, color: Color(0xFF15803D)),
              label: const Text('Acetaminofén Jarabe'),
              backgroundColor: const Color(0xFFDCFCE7),
              onPressed: () => _cargarPreset(
                'Acetaminofén (Paracetamol)',
                '120 mg / 5 mL',
                'Jarabe / Suspensión',
                '1 Frasco x 120 mL',
                'Administrar cada 6 u 8 horas si hay fiebre > 38°C o dolor.',
              ),
            ),
            ActionChip(
              avatar: const Icon(Icons.medication_rounded, size: 14, color: Color(0xFF1E40AF)),
              label: const Text('Acetaminofén 500mg Tabletas'),
              backgroundColor: const Color(0xFFDBEAFE),
              onPressed: () => _cargarPreset(
                'Acetaminofén (Paracetamol)',
                '500 mg',
                'Tabletas',
                '1 Blíster x 10 tabletas',
                'Tomar 1 tableta cada 8 horas si hay fiebre o dolor.',
              ),
            ),
            ActionChip(
              avatar: const Icon(Icons.water_drop_rounded, size: 14, color: Color(0xFFB45309)),
              label: const Text('Sales de Rehidratación (SRO)'),
              backgroundColor: const Color(0xFFFEF3C7),
              onPressed: () => _cargarPreset(
                'Sales de Rehidratación Oral (SRO)',
                'Fórmula OMS',
                'Sobres en polvo',
                '3 Sobres',
                'Diluir 1 sobre en 1 litro de agua hervida o potable. Tomar a libre demanda.',
              ),
            ),
            ActionChip(
              avatar: const Icon(Icons.healing_rounded, size: 14, color: Color(0xFF6B21A8)),
              label: const Text('Ibuprofeno 400mg'),
              backgroundColor: const Color(0xFFF3E8FF),
              onPressed: () => _cargarPreset(
                'Ibuprofeno',
                '400 mg',
                'Tabletas',
                '1 Blíster x 10 tabletas',
                'Tomar 1 tableta cada 8 horas después de las comidas por 3 días.',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAddMedicationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primary.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.add_circle_outline_rounded, color: _primary, size: 18),
              const SizedBox(width: 8),
              const Text('Agregar Medicamento a la Prescripción',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _primary)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _medNombreInput,
                  decoration: const InputDecoration(
                    labelText: 'Medicamento / Principio Activo *',
                    hintText: 'Ej. Amoxicilina, Loratadina',
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _medConcInput,
                  decoration: const InputDecoration(
                    labelText: 'Concentración',
                    hintText: 'Ej. 500 mg, 10 mg',
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: _medFormaSeleccionada,
                  decoration: const InputDecoration(
                    labelText: 'Forma Farmacéutica',
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Tabletas', child: Text('Tabletas')),
                    DropdownMenuItem(value: 'Cápsulas', child: Text('Cápsulas')),
                    DropdownMenuItem(value: 'Jarabe / Suspensión', child: Text('Jarabe / Susp.')),
                    DropdownMenuItem(value: 'Gotas', child: Text('Gotas')),
                    DropdownMenuItem(value: 'Ampolla / Inyectable', child: Text('Ampolla')),
                    DropdownMenuItem(value: 'Sobres en polvo', child: Text('Sobres')),
                    DropdownMenuItem(value: 'Crema / Ungüento', child: Text('Crema')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _medFormaSeleccionada = val);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _medCantInput,
                  decoration: const InputDecoration(
                    labelText: 'Cantidad a Despachar',
                    hintText: 'Ej. 1 Blíster, 1 Frasco',
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: _medViaSeleccionada,
                  decoration: const InputDecoration(
                    labelText: 'Vía de Administración',
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Vía Oral', child: Text('Vía Oral')),
                    DropdownMenuItem(value: 'Intramuscular', child: Text('Intramuscular')),
                    DropdownMenuItem(value: 'Intravenosa', child: Text('Intravenosa')),
                    DropdownMenuItem(value: 'Tópica / Cutánea', child: Text('Tópica')),
                    DropdownMenuItem(value: 'Oftálmica', child: Text('Oftálmica')),
                    DropdownMenuItem(value: 'Inhalatoria', child: Text('Inhalatoria')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _medViaSeleccionada = val);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 4,
                child: TextField(
                  controller: _medPosologiaInput,
                  decoration: const InputDecoration(
                    labelText: 'Posología / Indicación de uso *',
                    hintText: 'Ej. 1 tableta cada 8 horas por 5 días',
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _agregarMedicamento,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Añadir'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMedicamentosList() {
    if (_medicamentos.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _cardBorder),
        ),
        child: const Text('No hay medicamentos añadidos aún al récipe.',
            style: TextStyle(color: Color(0xFF64748B), fontStyle: FontStyle.italic)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.format_list_numbered_rounded, color: _primary, size: 18),
            const SizedBox(width: 8),
            Text('Medicamentos Prescritos (${_medicamentos.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
          ],
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _medicamentos.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final m = _medicamentos[i];
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _cardBorder),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: const Color(0xFFEFF6FF),
                    child: Text('${i + 1}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _primary)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${m.medicamento} ${m.concentracion.isNotEmpty ? '— ' + m.concentracion : ''}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Forma: ${m.forma} · Cant: ${m.cantidad} · Vía: ${m.via}',
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '👉 Posología: ${m.posologia}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF15803D)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 20),
                    tooltip: 'Eliminar del récipe',
                    onPressed: () => _eliminarMedicamento(i),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDoctorAndIndicationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Indicaciones y Cuidados Generales para el Paciente:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
        const SizedBox(height: 8),
        TextField(
          controller: _indicacionesGeneralesController,
          maxLines: 4,
          decoration: const InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
            hintText: 'Recomendaciones de reposo, hidratación, signos de alarma...',
            contentPadding: EdgeInsets.all(12),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _cardBorder),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _medicoNombreController,
                  decoration: const InputDecoration(
                    labelText: 'Profesional / Médico Responsable',
                    prefixIcon: Icon(Icons.badge_outlined, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _medicoCedulaController,
                  decoration: const InputDecoration(
                    labelText: 'C.I. Médico',
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _medicoMppsController,
                  decoration: const InputDecoration(
                    labelText: 'N° MPPS / Colegiatura',
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVistaPreviaTab() {
    final now = DateTime.now();
    final fechaHoy = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final hash = _generarHashVerificacion();
    final urlQR = _generarUrlVerificacion(hash);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 860),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF94A3B8), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra simulada de las dos mitades
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // MITAD 1: RÉCIPE (FARMACIA)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPreviewHeader('RÉCIPE MÉDICO', const Color(0xFF1E3A8A), hash),
                          const SizedBox(height: 10),
                          _buildPreviewPatientCard(),
                          const SizedBox(height: 12),
                          const Text('Rp.',
                              style: TextStyle(
                                  fontFamily: 'serif',
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E3A8A))),
                          const SizedBox(height: 8),
                          ..._medicamentos.asMap().entries.map((entry) {
                            final i = entry.key;
                            final m = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('#${i + 1} ',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A), fontSize: 12)),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('${m.medicamento} ${m.concentracion}',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                        Text('Forma: ${m.forma} · Cant: ${m.cantidad} · Vía: ${m.via}',
                                            style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 24),
                          _buildPreviewFooter(urlQR, 'Firma y Sello Facultativo', 'VALIDACIÓN FARMACIA'),
                        ],
                      ),
                    ),
                  ),

                  // Separador vertical punteado
                  Container(
                    width: 1,
                    height: 520,
                    color: const Color(0xFFCBD5E1),
                  ),

                  // MITAD 2: INDICACIONES (PACIENTE)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPreviewHeader('INDICACIONES MÉDICAS', const Color(0xFF0284C7), fechaHoy),
                          const SizedBox(height: 10),
                          _buildPreviewPatientCard(),
                          const SizedBox(height: 12),
                          const Text('Tratamiento e Instrucciones:',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                          const SizedBox(height: 8),
                          ..._medicamentos.asMap().entries.map((entry) {
                            final i = entry.key;
                            final m = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 9,
                                    backgroundColor: const Color(0xFF0284C7),
                                    child: Text('${i + 1}',
                                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(m.medicamento, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                        Text('👉 ${m.posologia}',
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF0F172A))),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFDF2F8),
                              borderRadius: BorderRadius.circular(6),
                              border: const Border(left: BorderSide(color: Color(0xFFEC4899), width: 3)),
                            ),
                            child: Text(
                              _indicacionesGeneralesController.text,
                              style: const TextStyle(fontSize: 10, color: Color(0xFF831843), height: 1.3),
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildPreviewFooter(urlQR, 'Firma Facultativo', 'SEGUIMIENTO CLÍNICO'),
                        ],
                      ),
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

  Widget _buildPreviewHeader(String badgeTitle, Color badgeColor, String metaText) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('REPÚBLICA BOLIVARIANA DE VENEZUELA · MPPS',
            style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
        const Text('ASIC San José de Guanipa · CDI Dr. Pedro Urbina',
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(badgeTitle,
                  style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold)),
            ),
            Text(metaText, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
          ],
        ),
        const Divider(color: Color(0xFFCBD5E1), height: 12),
      ],
    );
  }

  Widget _buildPreviewPatientCard() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Pac: ${widget.paciente.nombreCompleto}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5)),
              Text('C.I: ${widget.paciente.cedula}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5)),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Edad: ${widget.paciente.edadFormateada} · Sexo: ${widget.paciente.sexoFormateado} · Peso: ${_pesoController.text.isNotEmpty ? _pesoController.text + " kg" : "S/R"}',
            style: const TextStyle(fontSize: 9.5, color: Color(0xFF475569)),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewFooter(String qrUrl, String labelFirma, String qrLabel) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 110,
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFF0F172A), width: 1)),
              ),
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '${_medicoNombreController.text}\n$labelFirma',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, height: 1.2),
              ),
            ),
          ],
        ),
        Column(
          children: [
            SizedBox(
              width: 55,
              height: 55,
              child: QrImageView(
                data: qrUrl,
                version: QrVersions.auto,
                size: 55,
                padding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(height: 2),
            Text(qrLabel, style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
          ],
        ),
      ],
    );
  }

  Widget _buildDialogFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${_medicamentos.length} medicamento(s) en prescripción',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
          ),
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar', style: TextStyle(color: Color(0xFF64748B))),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _imprimirRecipe,
                icon: const Icon(Icons.print_rounded, size: 18),
                label: const Text('Imprimir Récipe / Guardar PDF',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

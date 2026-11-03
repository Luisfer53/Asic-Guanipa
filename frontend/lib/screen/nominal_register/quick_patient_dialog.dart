import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:asis_guanipa_frontend/services/api_service.dart';
import 'package:asis_guanipa_frontend/models/paciente.dart';
import 'package:asis_guanipa_frontend/providers/guardia_provider.dart';
import 'package:provider/provider.dart';

// ─── Sectores predefinidos de Guanipa ────────────────────────────────────────
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

const _parroquiasGuanipa = [
  'Parroquia General Pedro Urbina',
  'Parroquia San José',
  'Otra',
];

// ─── Modos del diálogo ────────────────────────────────────────────────────────
enum _ModoRegistro { titular, menor }

class QuickPatientDialog extends StatefulWidget {
  final void Function(Paciente nuevoPaciente) onPatientCreated;

  const QuickPatientDialog({super.key, required this.onPatientCreated});

  /// Helper para abrir el diálogo
  static Future<void> show(
    BuildContext context, {
    required void Function(Paciente) onPatientCreated,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => QuickPatientDialog(onPatientCreated: onPatientCreated),
    );
  }

  @override
  State<QuickPatientDialog> createState() => _QuickPatientDialogState();
}

class _QuickPatientDialogState extends State<QuickPatientDialog>
    with SingleTickerProviderStateMixin {
  // ─── Estado general ───────────────────────────────────────────────────────
  _ModoRegistro _modo = _ModoRegistro.titular;
  bool _saving = false;
  String? _error;

  // ─── Campos compartidos ───────────────────────────────────────────────────
  final _nombre1Ctrl = TextEditingController();
  final _nombre2Ctrl = TextEditingController();
  final _apellido1Ctrl = TextEditingController();
  final _apellido2Ctrl = TextEditingController();
  String _sexo = 'M';
  DateTime? _fechaNac;
  String? _sectorSeleccionado;
  // ─── Contacto ────────────────────────────────────────────────────────────
  final _telCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();
  bool _traEsquemaPrevio = false;

  // ─── Campos titular ───────────────────────────────────────────────────────
  final _cedulaTitularCtrl = TextEditingController();
  String _prefijoCedula = 'V'; // V o E

  // ─── Campos menor dependiente ─────────────────────────────────────────────
  final _cedulaRepCtrl = TextEditingController();
  final _nombreRepCtrl = TextEditingController();
  int _ordenHijo = 1; // N1, N2, N3…

  // ─── Dirección completa ────────────────────────────────────────────────────
  String? _parroquiaSeleccionada;
  final _calleCtrl = TextEditingController();
  final _numeroCasaCtrl = TextEditingController();
  final _puntoRefCtrl = TextEditingController();

  // ─── Datos clínicos opcionales ───────────────────────────────────────────
  bool _mostrarDatosClinicos = false;
  final _pesoCtrl = TextEditingController();
  String? _tipoSangre;
  final _alergiasCtrl = TextEditingController();
  final _enfermedadesCronicasCtrl = TextEditingController();
  final _vacunasPreviasCtrl = TextEditingController();
  final _discapacidadCtrl = TextEditingController();
  final _antecedentesFamiliaresCtrl = TextEditingController();

  final _api = ApiService();
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  static const _blue = Color(0xFF1565C0);
  static const _teal = Color(0xFF00897B);

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();

    // Pre-cargar sector de guardia activa si existe
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final guardia = context.read<GuardiaProvider>().guardia;
      if (guardia?.sectorComunidad != null && mounted) {
        setState(() => _sectorSeleccionado = guardia!.sectorComunidad);
      }
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _nombre1Ctrl.dispose();
    _nombre2Ctrl.dispose();
    _apellido1Ctrl.dispose();
    _apellido2Ctrl.dispose();
    _cedulaTitularCtrl.dispose();
    _cedulaRepCtrl.dispose();
    _nombreRepCtrl.dispose();
    _telCtrl.dispose();
    _correoCtrl.dispose();
    _calleCtrl.dispose();
    _numeroCasaCtrl.dispose();
    _puntoRefCtrl.dispose();
    _pesoCtrl.dispose();
    _alergiasCtrl.dispose();
    _enfermedadesCronicasCtrl.dispose();
    _vacunasPreviasCtrl.dispose();
    _discapacidadCtrl.dispose();
    _antecedentesFamiliaresCtrl.dispose();
    super.dispose();
  }

  // ─── Calcular cédula efectiva ─────────────────────────────────────────────
  String? _cedulaEfectiva() {
    if (_modo == _ModoRegistro.titular) {
      final num = _cedulaTitularCtrl.text.trim();
      if (num.isEmpty) return null;
      return '$_prefijoCedula-$num';
    } else {
      // Menor: cédula construida a partir del representante
      final repNum = _cedulaRepCtrl.text.trim();
      if (repNum.isEmpty) return null;
      return 'V-$repNum-N$_ordenHijo';
    }
  }

  // ─── Guardar ──────────────────────────────────────────────────────────────
  Future<void> _guardar() async {
    setState(() {
      _error = null;
      _saving = true;
    });

    final nombre1 = _nombre1Ctrl.text.trim();
    final apellido1 = _apellido1Ctrl.text.trim();

    if (nombre1.isEmpty || apellido1.isEmpty) {
      setState(() {
        _error = 'Nombre y apellido son obligatorios';
        _saving = false;
      });
      return;
    }

    if (_modo == _ModoRegistro.menor && _cedulaRepCtrl.text.trim().isEmpty) {
      setState(() {
        _error = 'Ingrese la cédula del representante';
        _saving = false;
      });
      return;
    }

    final fechaStr = _fechaNac != null
        ? '${_fechaNac!.year.toString().padLeft(4, '0')}-'
            '${_fechaNac!.month.toString().padLeft(2, '0')}-'
            '${_fechaNac!.day.toString().padLeft(2, '0')}'
        : null;

    double? pesoVal;
    if (_pesoCtrl.text.trim().isNotEmpty) {
      pesoVal = double.tryParse(_pesoCtrl.text.trim().replaceAll(',', '.'));
    }

    final res = await _api.crearPacienteRapido(
      nombre1: nombre1,
      nombre2: _nombre2Ctrl.text.trim().isNotEmpty ? _nombre2Ctrl.text.trim() : null,
      apellido1: apellido1,
      apellido2: _apellido2Ctrl.text.trim().isNotEmpty ? _apellido2Ctrl.text.trim() : null,
      sexo: _sexo,
      cedulaIdentidad: _cedulaEfectiva(),
      fechaNacimiento: fechaStr,
      sector: _sectorSeleccionado,
      parroquia: _parroquiaSeleccionada,
      calle: _calleCtrl.text.trim().isNotEmpty ? _calleCtrl.text.trim() : null,
      numeroCasa: _numeroCasaCtrl.text.trim().isNotEmpty ? _numeroCasaCtrl.text.trim() : null,
      puntoReferencia: _puntoRefCtrl.text.trim().isNotEmpty ? _puntoRefCtrl.text.trim() : null,
      telefono: _telCtrl.text.trim().isNotEmpty ? _telCtrl.text.trim() : null,
      correo: _correoCtrl.text.trim().isNotEmpty ? _correoCtrl.text.trim() : null,
      cedulaRepresentante: _modo == _ModoRegistro.menor
          ? 'V-${_cedulaRepCtrl.text.trim()}'
          : null,
      nombreRepresentante: _modo == _ModoRegistro.menor && _nombreRepCtrl.text.trim().isNotEmpty
          ? _nombreRepCtrl.text.trim()
          : null,
      ordenHijo: _modo == _ModoRegistro.menor ? _ordenHijo : null,
      traEsquemaPrevio: _traEsquemaPrevio,
      peso: pesoVal,
      tipoSangre: _tipoSangre,
      alergias: _alergiasCtrl.text.trim().isNotEmpty ? _alergiasCtrl.text.trim() : null,
      enfermedadesCronicas: _enfermedadesCronicasCtrl.text.trim().isNotEmpty ? _enfermedadesCronicasCtrl.text.trim() : null,
      vacunas: _vacunasPreviasCtrl.text.trim().isNotEmpty ? _vacunasPreviasCtrl.text.trim() : null,
      discapacidad: _discapacidadCtrl.text.trim().isNotEmpty ? _discapacidadCtrl.text.trim() : null,
      antecedentesFamiliares: _antecedentesFamiliaresCtrl.text.trim().isNotEmpty ? _antecedentesFamiliaresCtrl.text.trim() : null,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (res['success'] == true) {
      final paciente = Paciente.fromJson(res['data']);
      Navigator.of(context).pop();
      widget.onPatientCreated(paciente);
    } else {
      setState(() => _error = res['message'] ?? 'Error al registrar paciente');
    }
  }

  // ─── UI ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth < 650;
        return FadeTransition(
          opacity: _fadeAnim,
          child: Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            insetPadding: EdgeInsets.symmetric(
              horizontal: isMobile ? 8 : 20,
              vertical: isMobile ? 12 : 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(isMobile: isMobile),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        isMobile ? 14 : 24, 0,
                        isMobile ? 14 : 24, 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildModoToggle(isMobile: isMobile),
                          const SizedBox(height: 16),
                          if (_modo == _ModoRegistro.titular) _buildCamposCedulaTitular(),
                          if (_modo == _ModoRegistro.menor) _buildCamposRepresentante(isMobile: isMobile),
                          const SizedBox(height: 16),
                          _buildCamposNombre(isMobile: isMobile),
                          const SizedBox(height: 12),
                          _buildCamposSexoFecha(isMobile: isMobile),
                          const SizedBox(height: 12),
                          _buildSeccionDireccion(isMobile: isMobile),
                          const SizedBox(height: 12),
                          _buildSeccionContacto(isMobile: isMobile),
                          const SizedBox(height: 12),
                          _buildCampoEsquema(),
                          const SizedBox(height: 12),
                          _buildSeccionDatosClinicosOpcionales(isMobile: isMobile),
                          if (_error != null) ...[
                            const SizedBox(height: 10),
                            _buildError(),
                          ],
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                  _buildFooter(isMobile: isMobile),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader({bool isMobile = false}) {
    return Container(
      padding: EdgeInsets.fromLTRB(isMobile ? 14 : 24, 16, 12, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF00897B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 6 : 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.person_add_rounded, color: Colors.white, size: isMobile ? 18 : 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMobile ? 'Alta Rápida' : 'Nuevo Paciente — Alta Rápida',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 14 : 16,
                  ),
                ),
                Text(
                  'Registro express · menos de 20 segundos',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white70),
            onPressed: () => Navigator.of(context).pop(),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildModoToggle({bool isMobile = false}) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          _toggleTab(
            label: isMobile ? 'Titular' : 'Titular con Cédula',
            icon: Icons.badge_rounded,
            activo: _modo == _ModoRegistro.titular,
            onTap: () => setState(() => _modo = _ModoRegistro.titular),
            isMobile: isMobile,
          ),
          _toggleTab(
            label: isMobile ? 'Menor' : 'Menor / Dependiente',
            icon: Icons.child_care_rounded,
            activo: _modo == _ModoRegistro.menor,
            onTap: () => setState(() => _modo = _ModoRegistro.menor),
            isMobile: isMobile,
          ),
        ],
      ),
    );
  }

  Widget _toggleTab({
    required String label,
    required IconData icon,
    required bool activo,
    required VoidCallback onTap,
    bool isMobile = false,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 10),
          decoration: BoxDecoration(
            color: activo ? _blue : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: isMobile ? 18 : 16, color: activo ? Colors.white : Colors.grey.shade600),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isMobile ? 13 : 12,
                    fontWeight: activo ? FontWeight.bold : FontWeight.normal,
                    color: activo ? Colors.white : Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCamposCedulaTitular() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Cédula de Identidad'),
        const SizedBox(height: 6),
        Row(
          children: [
            // Prefijo V / E
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _prefijoCedula,
                  items: ['V', 'E'].map((p) => DropdownMenuItem(
                    value: p,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(p, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  )).toList(),
                  onChanged: (v) => setState(() => _prefijoCedula = v!),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _inputField(
                ctrl: _cedulaTitularCtrl,
                hint: '12345678',
                inputType: TextInputType.number,
                formatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCamposRepresentante({bool isMobile = false}) {
    final ordenHijoWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Orden del Hijo'),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _ordenHijo,
              isExpanded: true,
              items: List.generate(5, (i) => i + 1).map((n) => DropdownMenuItem(
                value: n,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('N$n — Hijo #$n'),
                ),
              )).toList(),
              onChanged: (v) => setState(() => _ordenHijo = v!),
            ),
          ),
        ),
      ],
    );

    final idGeneradoWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('ID que se generará'),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF93C5FD)),
          ),
          child: Text(
            _cedulaRepCtrl.text.trim().isEmpty
                ? 'V-xxxxxxxx-N$_ordenHijo'
                : 'V-${_cedulaRepCtrl.text.trim()}-N$_ordenHijo',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              color: Color(0xFF1D4ED8),
              fontSize: 13,
            ),
          ),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Cédula del Representante (V-)'),
        const SizedBox(height: 6),
        _inputField(
          ctrl: _cedulaRepCtrl,
          hint: '12345678',
          inputType: TextInputType.number,
          formatters: [FilteringTextInputFormatter.digitsOnly],
          prefixText: 'V-',
        ),
        const SizedBox(height: 10),
        _label('Nombre del Representante (opcional)'),
        const SizedBox(height: 6),
        _inputField(ctrl: _nombreRepCtrl, hint: 'María González'),
        const SizedBox(height: 10),
        if (isMobile)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ordenHijoWidget,
              const SizedBox(height: 10),
              idGeneradoWidget,
            ],
          )
        else
          Row(
            children: [
              Expanded(child: ordenHijoWidget),
              const SizedBox(width: 12),
              Expanded(child: idGeneradoWidget),
            ],
          ),
      ],
    );
  }

  Widget _buildCamposNombre({bool isMobile = false}) {
    Widget filaNombres = isMobile
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('Primer Nombre *'),
              const SizedBox(height: 6),
              _inputField(ctrl: _nombre1Ctrl, hint: 'José'),
              const SizedBox(height: 10),
              _label('Segundo Nombre'),
              const SizedBox(height: 6),
              _inputField(ctrl: _nombre2Ctrl, hint: 'Andrés'),
            ],
          )
        : Row(
            children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _label('Primer Nombre *'),
                  const SizedBox(height: 6),
                  _inputField(ctrl: _nombre1Ctrl, hint: 'José'),
                ]),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _label('Segundo Nombre'),
                  const SizedBox(height: 6),
                  _inputField(ctrl: _nombre2Ctrl, hint: 'Andrés'),
                ]),
              ),
            ],
          );

    Widget filaApellidos = isMobile
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('Primer Apellido *'),
              const SizedBox(height: 6),
              _inputField(ctrl: _apellido1Ctrl, hint: 'González'),
              const SizedBox(height: 10),
              _label('Segundo Apellido'),
              const SizedBox(height: 6),
              _inputField(ctrl: _apellido2Ctrl, hint: 'Rodríguez'),
            ],
          )
        : Row(
            children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _label('Primer Apellido *'),
                  const SizedBox(height: 6),
                  _inputField(ctrl: _apellido1Ctrl, hint: 'González'),
                ]),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _label('Segundo Apellido'),
                  const SizedBox(height: 6),
                  _inputField(ctrl: _apellido2Ctrl, hint: 'Rodríguez'),
                ]),
              ),
            ],
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        filaNombres,
        const SizedBox(height: 10),
        filaApellidos,
      ],
    );
  }

  Widget _buildCamposSexoFecha({bool isMobile = false}) {
    final sexoWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Sexo *'),
        const SizedBox(height: 6),
        Row(
          children: [
            _sexoChip('M', 'Masculino', Icons.male_rounded),
            const SizedBox(width: 8),
            _sexoChip('F', 'Femenino', Icons.female_rounded),
          ],
        ),
      ],
    );

    final fechaWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Fecha de Nacimiento'),
        const SizedBox(height: 6),
        InkWell(
          onTap: _pickFecha,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _fechaNac != null
                        ? '${_fechaNac!.day.toString().padLeft(2, '0')}/'
                            '${_fechaNac!.month.toString().padLeft(2, '0')}/'
                            '${_fechaNac!.year}'
                        : 'DD/MM/AAAA',
                    style: TextStyle(
                      color: _fechaNac != null ? Colors.black87 : Colors.grey.shade500,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sexoWidget,
          const SizedBox(height: 12),
          fechaWidget,
        ],
      );
    }

    return Row(
      children: [
        Expanded(flex: 2, child: sexoWidget),
        const SizedBox(width: 12),
        Expanded(flex: 3, child: fechaWidget),
      ],
    );
  }

  Widget _sexoChip(String valor, String label, IconData icon) {
    final activo = _sexo == valor;
    final color = valor == 'M' ? _blue : Colors.pink.shade400;
    return GestureDetector(
      onTap: () => setState(() => _sexo = valor),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: activo ? color : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: activo ? color : const Color(0xFFCBD5E1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: activo ? Colors.white : Colors.grey.shade600),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: activo ? Colors.white : Colors.grey.shade700,
                fontWeight: activo ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Sección de dirección completa claramente visible
  Widget _buildSeccionDireccion({bool isMobile = false}) {
    final parroquiaDropdown = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Parroquia'),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _parroquiaSeleccionada,
              hint: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('Parroquia...', style: TextStyle(fontSize: 12)),
              ),
              isExpanded: true,
              items: _parroquiasGuanipa
                  .map((p) => DropdownMenuItem(
                        value: p,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            p,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _parroquiaSeleccionada = v),
            ),
          ),
        ),
      ],
    );

    final sectorDropdown = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Sector / Comunidad'),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _sectorSeleccionado,
              hint: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('Sector...', style: TextStyle(fontSize: 12)),
              ),
              isExpanded: true,
              items: _sectoresGuanipa
                  .map((s) => DropdownMenuItem(
                        value: s,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            s,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _sectorSeleccionado = v),
            ),
          ),
        ),
      ],
    );

    final calleWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Calle / Avenida'),
        const SizedBox(height: 6),
        _inputField(
          ctrl: _calleCtrl,
          hint: 'Ej: Av. Bicentenario',
          prefixIcon: Icons.signpost_outlined,
        ),
      ],
    );

    final numeroCasaWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Número / Casa'),
        const SizedBox(height: 6),
        _inputField(
          ctrl: _numeroCasaCtrl,
          hint: 'Ej: Casa 12',
          prefixIcon: Icons.home_outlined,
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00897B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF00897B)),
              ),
              const SizedBox(width: 8),
              const Text(
                'Dirección de Habitación',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Fila: Parroquia y Sector
          if (isMobile)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                parroquiaDropdown,
                const SizedBox(height: 10),
                sectorDropdown,
              ],
            )
          else
            Row(
              children: [
                Expanded(flex: 1, child: parroquiaDropdown),
                const SizedBox(width: 10),
                Expanded(flex: 1, child: sectorDropdown),
              ],
            ),
          const SizedBox(height: 10),
          // Fila: Calle y Casa
          if (isMobile)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                calleWidget,
                const SizedBox(height: 10),
                numeroCasaWidget,
              ],
            )
          else
            Row(
              children: [
                Expanded(flex: 3, child: calleWidget),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: numeroCasaWidget),
              ],
            ),
          const SizedBox(height: 10),
          // Punto de referencia
          _label('Punto de Referencia'),
          const SizedBox(height: 6),
          _inputField(
            ctrl: _puntoRefCtrl,
            hint: 'Ej: Cerca de la plaza / frente a la bodega',
            prefixIcon: Icons.place_outlined,
          ),
        ],
      ),
    );
  }

  /// Sección de contacto con Teléfono y Correo Electrónico
  Widget _buildSeccionContacto({bool isMobile = false}) {
    final telWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Teléfono (opcional)'),
        const SizedBox(height: 6),
        _inputField(
          ctrl: _telCtrl,
          hint: '0416-1234567',
          inputType: TextInputType.phone,
          prefixIcon: Icons.phone_rounded,
        ),
      ],
    );

    final correoWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Correo Electrónico (opcional)'),
        const SizedBox(height: 6),
        _inputField(
          ctrl: _correoCtrl,
          hint: 'ejemplo@correo.com',
          inputType: TextInputType.emailAddress,
          prefixIcon: Icons.email_outlined,
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.contact_phone_outlined, size: 16, color: Color(0xFF1565C0)),
              ),
              const SizedBox(width: 8),
              const Text(
                'Datos de Contacto',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isMobile)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                telWidget,
                const SizedBox(height: 10),
                correoWidget,
              ],
            )
          else
            Row(
              children: [
                Expanded(flex: 1, child: telWidget),
                const SizedBox(width: 10),
                Expanded(flex: 1, child: correoWidget),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCampoEsquema() {
    return InkWell(
      onTap: () => setState(() => _traEsquemaPrevio = !_traEsquemaPrevio),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _traEsquemaPrevio ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _traEsquemaPrevio ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            Checkbox(
              value: _traEsquemaPrevio,
              onChanged: (v) => setState(() => _traEsquemaPrevio = v ?? false),
              activeColor: _blue,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Trae esquema previo de otro centro',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  Text(
                    'Marcar si el paciente ya tiene vacunas previas en otra institución',
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

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildFooter({bool isMobile = false}) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 14 : 24, 12,
        isMobile ? 14 : 24, isMobile ? 16 : 20,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  onPressed: _saving ? null : _guardar,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.flash_on_rounded, size: 18),
                  label: Text(
                    _saving ? 'Registrando...' : 'Registrar Paciente',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
              ],
            )
          : Row(
              children: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  onPressed: _saving ? null : _guardar,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.flash_on_rounded, size: 18),
                  label: Text(
                    _saving ? 'Registrando...' : 'Registrar Paciente',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF334155),
        ),
      );

  Widget _inputField({
    required TextEditingController ctrl,
    required String hint,
    TextInputType inputType = TextInputType.text,
    List<TextInputFormatter>? formatters,
    String? prefixText,
    IconData? prefixIcon,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: inputType,
      inputFormatters: formatters,
      onChanged: (_) => setState(() {}), // para actualizar preview cédula menor
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        prefixText: prefixText,
        prefixStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 18, color: Colors.grey.shade500) : null,
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
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
          borderSide: const BorderSide(color: Color(0xFF1565C0), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        isDense: true,
      ),
    );
  }

  Future<void> _pickFecha() async {
    final hoy = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaNac ?? DateTime(hoy.year - 1, hoy.month, hoy.day),
      firstDate: DateTime(1920),
      lastDate: hoy,
      helpText: 'Fecha de nacimiento',
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF1565C0)),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _fechaNac = picked);
    }
  }

  Widget _buildSeccionDatosClinicosOpcionales({bool isMobile = false}) {
    return Container(
      decoration: BoxDecoration(
        color: _mostrarDatosClinicos ? Colors.blue.shade50.withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _mostrarDatosClinicos ? const Color(0xFF1565C0).withValues(alpha: 0.3) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _mostrarDatosClinicos = !_mostrarDatosClinicos),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.medical_information_outlined,
                    size: 18,
                    color: _mostrarDatosClinicos ? const Color(0xFF1565C0) : Colors.blueGrey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Datos Clínicos Básicos (Opcional)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _mostrarDatosClinicos ? const Color(0xFF1565C0) : Colors.blueGrey.shade800,
                      ),
                    ),
                  ),
                  Icon(
                    _mostrarDatosClinicos ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: Colors.blueGrey,
                  ),
                ],
              ),
            ),
          ),
          if (_mostrarDatosClinicos) ...[
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isMobile)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Peso (kg)'),
                        _inputField(
                          ctrl: _pesoCtrl,
                          hint: 'Ej: 65.5',
                          inputType: const TextInputType.numberWithOptions(decimal: true),
                          prefixIcon: Icons.monitor_weight_outlined,
                        ),
                        const SizedBox(height: 10),
                        _label('Grupo Sanguíneo'),
                        DropdownButtonFormField<String>(
                          initialValue: _tipoSangre,
                          isExpanded: true,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFF1F5F9),
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
                          hint: const Text('Seleccione', style: TextStyle(fontSize: 13)),
                          items: const [
                            DropdownMenuItem(value: 'O+', child: Text('O+')),
                            DropdownMenuItem(value: 'O-', child: Text('O-')),
                            DropdownMenuItem(value: 'A+', child: Text('A+')),
                            DropdownMenuItem(value: 'A-', child: Text('A-')),
                            DropdownMenuItem(value: 'B+', child: Text('B+')),
                            DropdownMenuItem(value: 'B-', child: Text('B-')),
                            DropdownMenuItem(value: 'AB+', child: Text('AB+')),
                            DropdownMenuItem(value: 'AB-', child: Text('AB-')),
                          ],
                          onChanged: (val) => setState(() => _tipoSangre = val),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('Peso (kg)'),
                              _inputField(
                                ctrl: _pesoCtrl,
                                hint: 'Ej: 65.5',
                                inputType: const TextInputType.numberWithOptions(decimal: true),
                                prefixIcon: Icons.monitor_weight_outlined,
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
                                  fillColor: const Color(0xFFF1F5F9),
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
                                hint: const Text('Seleccione', style: TextStyle(fontSize: 13)),
                                items: const [
                                  DropdownMenuItem(value: 'O+', child: Text('O+')),
                                  DropdownMenuItem(value: 'O-', child: Text('O-')),
                                  DropdownMenuItem(value: 'A+', child: Text('A+')),
                                  DropdownMenuItem(value: 'A-', child: Text('A-')),
                                  DropdownMenuItem(value: 'B+', child: Text('B+')),
                                  DropdownMenuItem(value: 'B-', child: Text('B-')),
                                  DropdownMenuItem(value: 'AB+', child: Text('AB+')),
                                  DropdownMenuItem(value: 'AB-', child: Text('AB-')),
                                ],
                                onChanged: (val) => setState(() => _tipoSangre = val),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 10),
                  _label('Alergias Conocidas'),
                  _inputField(
                    ctrl: _alergiasCtrl,
                    hint: 'Ej: Penicilina, sulfas, dipirona...',
                    prefixIcon: Icons.warning_amber_rounded,
                  ),
                  const SizedBox(height: 10),
                  _label('Enfermedades Crónicas'),
                  _inputField(
                    ctrl: _enfermedadesCronicasCtrl,
                    hint: 'Ej: Hipertensión, Diabetes, Asma...',
                    prefixIcon: Icons.favorite_border_rounded,
                  ),
                  const SizedBox(height: 10),
                  _label('Discapacidad (si aplica)'),
                  _inputField(
                    ctrl: _discapacidadCtrl,
                    hint: 'Ej: Visual, auditiva, motora...',
                    prefixIcon: Icons.accessibility_new_rounded,
                  ),
                  const SizedBox(height: 10),
                  _label('Antecedentes Familiares'),
                  _inputField(
                    ctrl: _antecedentesFamiliaresCtrl,
                    hint: 'Ej: Diabetes familiar, HTA...',
                    prefixIcon: Icons.family_restroom_rounded,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

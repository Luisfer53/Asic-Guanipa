import 'package:flutter/material.dart';
import 'package:asis_guanipa_frontend/services/api_service.dart';
import 'package:asis_guanipa_frontend/models/paciente.dart';
import 'package:asis_guanipa_frontend/utils/upper_case_text_formatter.dart';

class CreatePatientDialog extends StatefulWidget {
  final Function([String? searchKey]) onPatientCreated;
  final Paciente? paciente;

  const CreatePatientDialog({
    super.key,
    required this.onPatientCreated,
    this.paciente,
  });

  @override
  State<CreatePatientDialog> createState() => _CreatePatientDialogState();
}

class _CreatePatientDialogState extends State<CreatePatientDialog> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();

  List<String> _sectores = [
    'El Carmen I',
    'El Carmen II',
    'Monte Verde',
    'Rómulo Gallegos',
    'Valmore Rodríguez',
    'San José de Guanipa Centro',
    'San José I',
    'San José II',
    'Vista al Sol',
    'La Espinal I',
    'La Espinal II',
    'Cantaura',
    'Central',
    'Barrio Blanco',
    'Inam',
    'Bicentenario I',
    'Bicentenario II',
    'Bicentenario III',
    'Nueve de Diciembre',
    'Las Malvinas',
    'La Floresta',
    'Simón Bolívar I',
    'Simón Bolívar II',
    'Andrés Bello',
    '19 de Marzo',
    'José Antonio Anzoátegui',
    'Sabana de Guanipa',
    'Cristóbal Colón',
    'Girardot',
    'Los Claveles',
    'Las Torres',
    'Ezequiel Zamora',
    'El Basquero I',
    'El Basquero II',
    'Los Olivos',
    'Umberto Sivanovi',
    'Alberto Ravell',
    'California',
    'Sucre',
    'Francisco de Miranda',
    'La Victoria',
    'Sector Sur',
    'Sector Norte',
    'Sector Este',
    'Sector Oeste',
    'Zona Industrial I',
    'Zona Industrial II',
    'La Ceiba',
    'El Mirador',
    'San José Obrero',
    'Los Rosales',
    'Santa Elena',
    '12 de Octubre',
    'Colinas de Guanipa',
    'Campo Oficina',
    'La Perla',
    'La Charneca',
    'San Francisco',
    'Guayabal',
    'Los Pinos',
    'El Palmar',
    'Bella Vista',
    'Santa Rosa',
    'San Rafael',
    'Los Laureles',
    'Las Mercedes',
    '23 de Enero',
    'San Martín',
  ];

  // ── Datos personales del paciente ──
  final _nombre1Ctrl = TextEditingController();
  final _nombre2Ctrl = TextEditingController();
  final _apellido1Ctrl = TextEditingController();
  final _apellido2Ctrl = TextEditingController();
  final _cedulaCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();
  final _ocupacionCtrl = TextEditingController();
  String _sexo = 'M';
  String _estadoCivil = 'Soltero(a)';
  DateTime? _fechaNacimiento;

  // ── Dirección de habitación del paciente ──
  String _selectedSector = 'San José de Guanipa Centro';
  final _calleCtrl = TextEditingController();
  final _numeroCasaCtrl = TextEditingController();
  final _puntoRefCtrl = TextEditingController();

  // ── Representante (solo para menores) ──
  final _nom1RepCtrl = TextEditingController();
  final _nom2RepCtrl = TextEditingController();
  final _ape1RepCtrl = TextEditingController();
  final _ape2RepCtrl = TextEditingController();
  final _cedRepCtrl = TextEditingController();
  final _telRepCtrl = TextEditingController();
  final _ocupRepCtrl = TextEditingController();
  final _parentescoCtrl = TextEditingController();
  String _sexoRep = 'M';
  String _estadoCivilRep = 'Soltero(a)';

  // ── Datos clínicos ──
  final _pesoCtrl = TextEditingController();
  final _alergiasCtrl = TextEditingController();
  final _enfermedadesCtrl = TextEditingController();
  final _vacunasCtrl = TextEditingController();
  final _discapacidadCtrl = TextEditingController();
  final _antecedentesFamCtrl = TextEditingController();
  String? _tipoSangre;

  static const List<String> _tiposSangre = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];
  static const List<String> _estadosCiviles = [
    'Soltero(a)',
    'Casado(a)',
    'Divorciado(a)',
    'Viudo(a)',
    'Concubinato',
  ];

  bool _isLoading = false;

  bool get _isMinor {
    if (_fechaNacimiento == null) return false;
    final today = DateTime.now();
    int age = today.year - _fechaNacimiento!.year;
    if (today.month < _fechaNacimiento!.month ||
        (today.month == _fechaNacimiento!.month &&
            today.day < _fechaNacimiento!.day)) {
      age--;
    }
    return age < 18;
  }

  @override
  void initState() {
    super.initState();
    _fetchSectores();
    if (widget.paciente != null) {
      final p = widget.paciente!;
      _nombre1Ctrl.text = p.persona?.nombre1 ?? p.nombre;
      _nombre2Ctrl.text = p.persona?.nombre2 ?? '';
      _apellido1Ctrl.text = p.persona?.apellido1 ?? p.apellido;
      _apellido2Ctrl.text = p.persona?.apellido2 ?? '';
      _cedulaCtrl.text = p.persona?.cedulaIdentidad ?? '';
      _telefonoCtrl.text = p.telefono ?? '';
      _correoCtrl.text = p.persona?.correo ?? '';
      _ocupacionCtrl.text = p.persona?.ocupacion ?? '';
      _sexo = p.sexo.isNotEmpty ? p.sexo : 'M';
      if (p.persona?.estadoCivil != null)
        _estadoCivil = p.persona!.estadoCivil!;

      // Dirección
      final dir = p.direccion ?? '';
      if (dir.contains(' - Sector: ')) {
        final parts = dir.split(' - Sector: ');
        _calleCtrl.text = parts[0];
        if (_sectores.contains(parts[1])) _selectedSector = parts[1];
      } else {
        _calleCtrl.text = dir;
      }

      if (p.fechaNacimiento.isNotEmpty) {
        _fechaNacimiento = DateTime.tryParse(p.fechaNacimiento);
      }

      // Representante
      _nom1RepCtrl.text = p.representante?.nombre1 ?? '';
      _nom2RepCtrl.text = p.representante?.nombre2 ?? '';
      _ape1RepCtrl.text = p.representante?.apellido1 ?? '';
      _ape2RepCtrl.text = p.representante?.apellido2 ?? '';
      _cedRepCtrl.text = p.cedulaRepresentante ?? '';
      _telRepCtrl.text = p.telefonoRepresentante ?? '';
      _parentescoCtrl.text = p.parentescoRepresentante ?? '';

      // Clínicos
      _pesoCtrl.text = p.peso != null ? p.peso.toString() : '';
      _tipoSangre = p.tipoSangre;
      _alergiasCtrl.text = p.alergias ?? '';
      _enfermedadesCtrl.text = p.enfermedadesCronicas ?? '';
      _vacunasCtrl.text = p.vacunas ?? '';
      _discapacidadCtrl.text = p.discapacidad ?? '';
      _antecedentesFamCtrl.text = p.antecedentesFamiliares ?? '';
    }
  }

  Future<void> _fetchSectores() async {
    try {
      final res = await _apiService.getSectores();
      if (res['success'] == true && res['data'] != null) {
        final List data = res['data'];
        final fetchedNames = data
            .map<String>((s) => s['nombre_sector'].toString())
            .toList();
        if (fetchedNames.isNotEmpty && mounted) {
          setState(() {
            _sectores = fetchedNames;
            if (!_sectores.contains(_selectedSector)) {
              _selectedSector = _sectores.first;
            }
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nombre1Ctrl.dispose();
    _nombre2Ctrl.dispose();
    _apellido1Ctrl.dispose();
    _apellido2Ctrl.dispose();
    _cedulaCtrl.dispose();
    _telefonoCtrl.dispose();
    _correoCtrl.dispose();
    _ocupacionCtrl.dispose();
    _calleCtrl.dispose();
    _numeroCasaCtrl.dispose();
    _puntoRefCtrl.dispose();
    _nom1RepCtrl.dispose();
    _nom2RepCtrl.dispose();
    _ape1RepCtrl.dispose();
    _ape2RepCtrl.dispose();
    _cedRepCtrl.dispose();
    _telRepCtrl.dispose();
    _ocupRepCtrl.dispose();
    _parentescoCtrl.dispose();
    _pesoCtrl.dispose();
    _alergiasCtrl.dispose();
    _enfermedadesCtrl.dispose();
    _vacunasCtrl.dispose();
    _discapacidadCtrl.dispose();
    _antecedentesFamCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _fechaNacimiento) {
      setState(() {
        _fechaNacimiento = picked;
      });
    }
  }

  Future<void> _crearPaciente() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fechaNacimiento == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor seleccione la fecha de nacimiento'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final isEditMode = widget.paciente != null;
    final Map<String, dynamic> response;

    // Construir dirección como string para compatibilidad con el parser del backend
    final String calleVal = _calleCtrl.text.trim();
    final String casaVal = _numeroCasaCtrl.text.trim();
    final String refVal = _puntoRefCtrl.text.trim();
    final String dirFinal = [
      if (calleVal.isNotEmpty) calleVal,
      if (casaVal.isNotEmpty) 'Casa $casaVal',
      if (refVal.isNotEmpty) refVal,
      '- Sector: $_selectedSector',
    ].join(' ');

    if (isEditMode) {
      response = await _apiService.updatePatient(
        id: widget.paciente!.id,
        nombre: _nombre1Ctrl.text.trim(),
        apellido: _apellido1Ctrl.text.trim(),
        cedula: _isMinor ? null : _cedulaCtrl.text.trim(),
        fechaNacimiento: _fechaNacimiento!.toIso8601String().split('T')[0],
        sexo: _sexo,
        telefono: _telefonoCtrl.text.trim().isNotEmpty
            ? _telefonoCtrl.text.trim()
            : null,
        direccion: dirFinal,
        nombreRepresentante: _isMinor ? _nom1RepCtrl.text.trim() : null,
        apellidoRepresentante: _isMinor ? _ape1RepCtrl.text.trim() : null,
        cedulaRepresentante: _isMinor ? _cedRepCtrl.text.trim() : null,
        telefonoRepresentante: _isMinor ? _telRepCtrl.text.trim() : null,
        direccionRepresentante: null,
        tipoSangre: _tipoSangre,
        peso: _pesoCtrl.text.trim().isNotEmpty
            ? double.tryParse(_pesoCtrl.text.trim())
            : null,
        alergias: _alergiasCtrl.text.trim().isNotEmpty
            ? _alergiasCtrl.text.trim()
            : null,
        enfermedadesCronicas: _enfermedadesCtrl.text.trim().isNotEmpty
            ? _enfermedadesCtrl.text.trim()
            : null,
        discapacidad: _discapacidadCtrl.text.trim().isNotEmpty
            ? _discapacidadCtrl.text.trim()
            : null,
        antecedentesFamiliares: _antecedentesFamCtrl.text.trim().isNotEmpty
            ? _antecedentesFamCtrl.text.trim()
            : null,
      );
    } else {
      response = await _apiService.crearPaciente(
        nombre: _nombre1Ctrl.text.trim(),
        nombre2: _nombre2Ctrl.text.trim().isNotEmpty
            ? _nombre2Ctrl.text.trim()
            : null,
        apellido: _apellido1Ctrl.text.trim(),
        apellido2: _apellido2Ctrl.text.trim().isNotEmpty
            ? _apellido2Ctrl.text.trim()
            : null,
        cedula: _isMinor ? '' : _cedulaCtrl.text.trim(),
        fechaNacimiento: _fechaNacimiento!.toIso8601String().split('T')[0],
        sexo: _sexo,
        estadoCivil: _estadoCivil,
        ocupacion: _ocupacionCtrl.text.trim().isNotEmpty
            ? _ocupacionCtrl.text.trim()
            : null,
        telefono: _telefonoCtrl.text.trim().isNotEmpty
            ? _telefonoCtrl.text.trim()
            : null,
        correo: _correoCtrl.text.trim().isNotEmpty
            ? _correoCtrl.text.trim()
            : null,
        calle: calleVal.isNotEmpty ? calleVal : null,
        numeroCasa: casaVal.isNotEmpty ? casaVal : null,
        puntoReferencia: refVal.isNotEmpty ? refVal : null,
        sector: _selectedSector,
        // Representante
        nombreRepresentante: _isMinor ? _nom1RepCtrl.text.trim() : null,
        nombre2Representante: _isMinor && _nom2RepCtrl.text.trim().isNotEmpty
            ? _nom2RepCtrl.text.trim()
            : null,
        apellidoRepresentante: _isMinor ? _ape1RepCtrl.text.trim() : null,
        apellido2Representante: _isMinor && _ape2RepCtrl.text.trim().isNotEmpty
            ? _ape2RepCtrl.text.trim()
            : null,
        cedulaRepresentante: _isMinor ? _cedRepCtrl.text.trim() : null,
        sexoRepresentante: _isMinor ? _sexoRep : null,
        estadoCivilRepresentante: _isMinor ? _estadoCivilRep : null,
        ocupacionRepresentante: _isMinor && _ocupRepCtrl.text.trim().isNotEmpty
            ? _ocupRepCtrl.text.trim()
            : null,
        telefonoRepresentante: _isMinor ? _telRepCtrl.text.trim() : null,
        parentescoRepresentante: _isMinor ? _parentescoCtrl.text.trim() : null,
        // Clínicos
        tipoSangre: _tipoSangre,
        peso: _pesoCtrl.text.trim().isNotEmpty
            ? double.tryParse(_pesoCtrl.text.trim())
            : null,
        alergias: _alergiasCtrl.text.trim().isNotEmpty
            ? _alergiasCtrl.text.trim()
            : null,
        enfermedadesCronicas: _enfermedadesCtrl.text.trim().isNotEmpty
            ? _enfermedadesCtrl.text.trim()
            : null,
        vacunas: _vacunasCtrl.text.trim().isNotEmpty
            ? _vacunasCtrl.text.trim()
            : null,
        discapacidad: _discapacidadCtrl.text.trim().isNotEmpty
            ? _discapacidadCtrl.text.trim()
            : null,
        antecedentesFamiliares: _antecedentesFamCtrl.text.trim().isNotEmpty
            ? _antecedentesFamCtrl.text.trim()
            : null,
      );
    }

    setState(() {
      _isLoading = false;
    });

    if (mounted) {
      if (response['success'] == true) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response['message'] ??
                  (isEditMode
                      ? 'Paciente actualizado'
                      : 'Paciente registrado exitosamente'),
            ),
            backgroundColor: Colors.green,
          ),
        );
        final String searchKey = _cedulaCtrl.text.trim().isNotEmpty
            ? _cedulaCtrl.text.trim()
            : (_nombre1Ctrl.text.trim().isNotEmpty
                  ? _nombre1Ctrl.text.trim()
                  : '');
        widget.onPatientCreated(searchKey);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response['message'] ??
                  (isEditMode
                      ? 'Error al actualizar'
                      : 'Error al registrar paciente'),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header ──
                Row(
                  children: [
                    Icon(
                      widget.paciente != null
                          ? Icons.edit_outlined
                          : Icons.person_add_outlined,
                      color: const Color(0xFF0D47A1),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.paciente != null
                          ? 'Editar Paciente'
                          : 'Registrar Paciente',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D47A1),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ─────────────────────────────────────────────
                // SECCIÓN 1: DATOS PERSONALES
                // ─────────────────────────────────────────────
                _sectionHeader(Icons.person, 'Datos Personales'),
                const SizedBox(height: 12),

                // Nombres
                Row(
                  children: [
                    Expanded(
                      child: _field(
                        _nombre1Ctrl,
                        'Primer Nombre *',
                        required: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: _field(_nombre2Ctrl, 'Segundo Nombre')),
                  ],
                ),
                const SizedBox(height: 12),
                // Apellidos
                Row(
                  children: [
                    Expanded(
                      child: _field(
                        _apellido1Ctrl,
                        'Primer Apellido *',
                        required: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: _field(_apellido2Ctrl, 'Segundo Apellido')),
                  ],
                ),
                const SizedBox(height: 12),

                // Fecha nacimiento
                InkWell(
                  onTap: () => _selectDate(context),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Fecha de Nacimiento *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    child: Text(
                      _fechaNacimiento != null
                          ? '${_fechaNacimiento!.day.toString().padLeft(2, '0')}/${_fechaNacimiento!.month.toString().padLeft(2, '0')}/${_fechaNacimiento!.year}'
                          : 'Seleccionar fecha',
                      style: TextStyle(
                        color: _fechaNacimiento != null
                            ? Colors.black
                            : Colors.grey[600],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Cédula del paciente
                _field(
                  _cedulaCtrl,
                  _isMinor ? 'Cédula de Identidad' : 'Cédula de Identidad *',
                  icon: Icons.badge_outlined,
                  keyboardType: TextInputType.number,
                  required: !_isMinor,
                  requiredMsg: 'La cédula es requerida para mayores de edad',
                ),
                const SizedBox(height: 12),

                // Sexo y Estado Civil
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _sexo,
                        decoration: const InputDecoration(
                          labelText: 'Sexo *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.wc_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'M',
                            child: Text('Masculino'),
                          ),
                          DropdownMenuItem(value: 'F', child: Text('Femenino')),
                        ],
                        onChanged: (v) => setState(() => _sexo = v!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _estadoCivil,
                        decoration: const InputDecoration(
                          labelText: 'Estado Civil',
                          border: OutlineInputBorder(),
                        ),
                        items: _estadosCiviles
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _estadoCivil = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Ocupación
                _field(_ocupacionCtrl, 'Ocupación', icon: Icons.work_outline),
                const SizedBox(height: 12),

                // Teléfono y Correo
                Row(
                  children: [
                    Expanded(
                      child: _field(
                        _telefonoCtrl,
                        'Teléfono',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _field(
                        _correoCtrl,
                        'Correo Electrónico',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ─────────────────────────────────────────────
                // SECCIÓN 2: DIRECCIÓN DE HABITACIÓN
                // ─────────────────────────────────────────────
                _sectionHeader(Icons.home, 'Dirección de Habitación'),
                const SizedBox(height: 12),

                // Sector
                DropdownButtonFormField<String>(
                  initialValue: _selectedSector,
                  decoration: const InputDecoration(
                    labelText: 'Sector / Comunidad *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.map_outlined),
                  ),
                  items: _sectores
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedSector = v!),
                ),
                const SizedBox(height: 12),

                // Calle y Número de casa
                Row(
                  children: [
                    Expanded(
                      child: _field(
                        _calleCtrl,
                        'Calle / Avenida',
                        icon: Icons.alt_route_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _field(
                        _numeroCasaCtrl,
                        'N° Casa / Apt.',
                        icon: Icons.home_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Punto de referencia
                _field(
                  _puntoRefCtrl,
                  'Punto de Referencia',
                  icon: Icons.location_searching_outlined,
                  maxLines: 2,
                ),
                const SizedBox(height: 20),

                // ─────────────────────────────────────────────
                // SECCIÓN 3: REPRESENTANTE (solo menores)
                // ─────────────────────────────────────────────
                if (_isMinor) ...[
                  _sectionHeader(
                    Icons.family_restroom,
                    'Representante / Tutor Legal *',
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          _nom1RepCtrl,
                          'Primer Nombre *',
                          required: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: _field(_nom2RepCtrl, 'Segundo Nombre')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          _ape1RepCtrl,
                          'Primer Apellido *',
                          required: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: _field(_ape2RepCtrl, 'Segundo Apellido')),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          _cedRepCtrl,
                          'Cédula *',
                          icon: Icons.badge_outlined,
                          required: true,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _sexoRep,
                          decoration: const InputDecoration(
                            labelText: 'Sexo *',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'M',
                              child: Text('Masculino'),
                            ),
                            DropdownMenuItem(
                              value: 'F',
                              child: Text('Femenino'),
                            ),
                          ],
                          onChanged: (v) => setState(() => _sexoRep = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          _parentescoCtrl,
                          'Parentesco * (Ej: Madre)',
                          required: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(
                          _telRepCtrl,
                          'Teléfono *',
                          icon: Icons.phone_outlined,
                          required: true,
                          keyboardType: TextInputType.phone,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _estadoCivilRep,
                          decoration: const InputDecoration(
                            labelText: 'Estado Civil',
                            border: OutlineInputBorder(),
                          ),
                          items: _estadosCiviles
                              .map(
                                (e) =>
                                    DropdownMenuItem(value: e, child: Text(e)),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _estadoCivilRep = v!),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: _field(_ocupRepCtrl, 'Ocupación')),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],

                // ─────────────────────────────────────────────
                // SECCIÓN 4: DATOS CLÍNICOS
                // ─────────────────────────────────────────────
                _sectionHeader(Icons.local_hospital_outlined, 'Datos Clínicos'),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _field(
                        _pesoCtrl,
                        'Peso (kg)',
                        icon: Icons.monitor_weight_outlined,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _tipoSangre,
                        decoration: const InputDecoration(
                          labelText: 'Tipo de Sangre',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.bloodtype),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('No especificado'),
                          ),
                          ..._tiposSangre.map(
                            (t) => DropdownMenuItem(value: t, child: Text(t)),
                          ),
                        ],
                        onChanged: (v) => setState(() => _tipoSangre = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _field(
                  _alergiasCtrl,
                  'Alergias conocidas',
                  icon: Icons.warning_amber_outlined,
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                _field(
                  _enfermedadesCtrl,
                  'Enfermedades Crónicas',
                  icon: Icons.local_hospital_outlined,
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                _field(
                  _vacunasCtrl,
                  'Vacunas Previas',
                  icon: Icons.vaccines_outlined,
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                _field(
                  _discapacidadCtrl,
                  'Discapacidad (si aplica)',
                  icon: Icons.accessibility_new,
                ),
                const SizedBox(height: 12),
                _field(
                  _antecedentesFamCtrl,
                  'Antecedentes Familiares',
                  icon: Icons.family_restroom,
                  maxLines: 2,
                ),
                const SizedBox(height: 24),

                // ── Botones ──
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _crearPaciente,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D47A1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                widget.paciente != null
                                    ? 'Actualizar'
                                    : 'Registrar',
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D47A1).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF0D47A1).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF0D47A1), size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF0D47A1),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    IconData? icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool required = false,
    String? requiredMsg,
  }) {
    final isNumericOrEmail = keyboardType == TextInputType.number ||
        keyboardType == TextInputType.emailAddress ||
        keyboardType == TextInputType.phone;

    return TextFormField(
      textCapitalization: isNumericOrEmail
          ? TextCapitalization.none
          : TextCapitalization.characters,
      inputFormatters: isNumericOrEmail ? [] : [UpperCaseTextFormatter()],
      controller: ctrl,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: icon != null ? Icon(icon) : null,
      ),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty)
                ? (requiredMsg ?? 'Campo requerido')
                : null
          : null,
    );
  }
}

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:asis_guanipa_frontend/services/api_service.dart';
import 'package:asis_guanipa_frontend/components/modulo_app_bar.dart';

import 'package:asis_guanipa_frontend/utils/web_helper.dart' as webHelper;

class SeguridadScreen extends StatefulWidget {
  const SeguridadScreen({super.key});

  @override
  State<SeguridadScreen> createState() => _SeguridadScreenState();
}

class _SeguridadScreenState extends State<SeguridadScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();

  // Listas principales
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _auditLogs = [];
  bool _isLoading = false;

  // Filtros Tab 1: Usuarios
  final _searchUserCtrl = TextEditingController();
  String _filtroRol = 'Todos';
  String _filtroEstado = 'Todos';

  // Filtros Tab 2: Bitácora
  final _searchAuditCtrl = TextEditingController();
  String _filtroModuloAudit = 'Todos';

  // Paleta de colores oficial
  static const _primary = Color(0xFF0D47A1);
  static const _teal = Color(0xFF00897B);
  static const _green = Color(0xFF2E7D32);
  static const _amber = Color(0xFFF57F17);
  static const _red = Color(0xFFC62828);
  static const _purple = Color(0xFF6A1B9A);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchUsersAndLogs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchUserCtrl.dispose();
    _searchAuditCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchUsersAndLogs() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _apiService.getUsers(),
        _apiService.getBitacora(),
      ]);

      if (mounted) {
        setState(() {
          if (results[0]['success'] == true) {
            _users = List<Map<String, dynamic>>.from(results[0]['data'] ?? []);
          }

          if (results[1]['success'] == true) {
            final List data = results[1]['data'] ?? [];
            _auditLogs = data.map<Map<String, dynamic>>((l) => {
              'usuario': l['usuario'] ?? 'N/A',
              'tabla': l['tabla'] ?? 'N/A',
              'accion': l['accion'] ?? 'N/A',
              'fecha': l['createdAt'] ?? l['created_at'] ?? '',
            }).toList();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar seguridad: $e'), backgroundColor: _red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // CALCULOS Y KPIS
  // ───────────────────────────────────────────────────────────────────────────

  int get _totalUsuarios => _users.length;

  int get _usuariosActivos {
    return _users.where((u) => u['activo'] != false && u['activo'] != 0).length;
  }

  int get _medicosYAsistenciales {
    return _users.where((u) {
      final role = (u['role'] ?? u['rol'] ?? '').toString().toLowerCase();
      return role.contains('medico') || role.contains('inmunizador') || role.contains('enfermer');
    }).length;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // FILTRADO DE USUARIOS
  // ───────────────────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> get _usuariosFiltrados {
    final query = _searchUserCtrl.text.trim().toLowerCase();

    return _users.where((u) {
      final username = (u['username'] ?? u['nombre_usuario'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? u['correo'] ?? '').toString().toLowerCase();
      final role = (u['role'] ?? u['rol'] ?? 'Basico').toString();
      final bool activo = u['activo'] != false && u['activo'] != 0;

      if (query.isNotEmpty && !username.contains(query) && !email.contains(query)) {
        return false;
      }

      if (_filtroRol != 'Todos' && !role.toLowerCase().contains(_filtroRol.toLowerCase())) {
        return false;
      }

      if (_filtroEstado == 'activos' && !activo) return false;
      if (_filtroEstado == 'inactivos' && activo) return false;

      return true;
    }).toList();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // FILTRADO DE BITÁCORA
  // ───────────────────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> get _bitacoraFiltrada {
    final query = _searchAuditCtrl.text.trim().toLowerCase();

    return _auditLogs.where((log) {
      final usuario = (log['usuario'] ?? '').toString().toLowerCase();
      final accion = (log['accion'] ?? '').toString().toLowerCase();
      final tabla = (log['tabla'] ?? '').toString().toLowerCase();

      if (query.isNotEmpty && !usuario.contains(query) && !accion.contains(query)) {
        return false;
      }

      if (_filtroModuloAudit != 'Todos' && !tabla.contains(_filtroModuloAudit.toLowerCase())) {
        return false;
      }

      return true;
    }).toList();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // EXPORTACIÓN A CSV DE BITÁCORA
  // ───────────────────────────────────────────────────────────────────────────

  void _exportarBitacoraCsv() {
    final logs = _bitacoraFiltrada;
    if (logs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay registros de bitácora para exportar'), backgroundColor: _amber),
      );
      return;
    }

    final buffer = StringBuffer();
    // UTF-8 BOM para Excel
    buffer.write('\uFEFF');
    buffer.writeln('Fecha / Hora,Usuario Responsable,Módulo / Tabla,Acción Registrada');

    for (final l in logs) {
      final f = (l['fecha'] ?? '').toString().replaceAll('"', '""');
      final u = (l['usuario'] ?? 'N/A').toString().replaceAll('"', '""');
      final t = (l['tabla'] ?? 'N/A').toString().replaceAll('"', '""');
      final a = (l['accion'] ?? 'N/A').toString().replaceAll('"', '""');
      buffer.writeln('"$f","$u","$t","$a"');
    }

    final bytes = utf8.encode(buffer.toString());
    webHelper.downloadCsvBytes(bytes, 'bitacora_auditoria_asic_guanipa_${DateTime.now().toString().substring(0, 10)}.csv');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ Se exportaron ${logs.length} eventos de bitácora a Excel/CSV'),
        backgroundColor: _green,
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // DIÁLOGOS: CREAR Y EDITAR USUARIO
  // ───────────────────────────────────────────────────────────────────────────

  void _showUserDialog({Map<String, dynamic>? user}) {
    final isEdit = user != null;
    final int? userId = user?['id'] ?? user?['id_serial'] ?? user?['id_usuario'];

    final formKey = GlobalKey<FormState>();
    final usernameCtrl = TextEditingController(text: user?['username'] ?? user?['nombre_usuario'] ?? '');
    final emailCtrl = TextEditingController(text: user?['email'] ?? user?['correo'] ?? '');
    final passwordCtrl = TextEditingController();
    String selectedRole = _extraerRol(user);

    const rolesDisponibles = [
      'Medico',
      'Inmunizador',
      'Inventario',
      'Epidemiologo',
      'Admin',
      'Basico',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(isEdit ? Icons.manage_accounts : Icons.person_add_alt_1, color: _primary),
                const SizedBox(width: 10),
                Text(
                  isEdit ? 'Actualizar Usuario / Rol' : 'Registrar Personal de Salud',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primary),
                ),
              ],
            ),
          ),
          content: SizedBox(
            width: 480,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: usernameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de Usuario *',
                        prefixIcon: Icon(Icons.account_circle_outlined),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Correo Electrónico *',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: passwordCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: isEdit ? 'Nueva Contraseña (Opcional)' : 'Contraseña de Acceso *',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        isDense: true,
                        helperText: isEdit ? 'Dejar en blanco para mantener la actual' : 'Mínimo 6 caracteres',
                      ),
                      validator: (v) {
                        if (!isEdit && (v == null || v.length < 6)) {
                          return 'Mínimo 6 caracteres';
                        }
                        if (isEdit && v != null && v.isNotEmpty && v.length < 6) {
                          return 'Mínimo 6 caracteres';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: rolesDisponibles.contains(selectedRole) ? selectedRole : 'Medico',
                      decoration: const InputDecoration(
                        labelText: 'Rol Asistencial / Permisos *',
                        prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Medico', child: Text('Médico (Consulta & Triaje)')),
                        DropdownMenuItem(value: 'Inmunizador', child: Text('Inmunizador (Vacunación Rápida)')),
                        DropdownMenuItem(value: 'Inventario', child: Text('Inventario / Almacén (Kárdex)')),
                        DropdownMenuItem(value: 'Epidemiologo', child: Text('Epidemiólogo (Sala Situacional)')),
                        DropdownMenuItem(value: 'Admin', child: Text('Administrador (Acceso Total)')),
                        DropdownMenuItem(value: 'Basico', child: Text('Operador Básico')),
                      ],
                      onChanged: (val) => setDState(() => selectedRole = val ?? 'Medico'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton.icon(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final nav = Navigator.of(ctx);

                final username = usernameCtrl.text.trim();
                final email = emailCtrl.text.trim();
                final password = passwordCtrl.text.trim();

                Map<String, dynamic> res;
                if (isEdit && userId != null) {
                  res = await _apiService.updateUser(
                    id: userId,
                    username: username,
                    email: email,
                    password: password.isNotEmpty ? password : null,
                    role: selectedRole,
                  );
                } else {
                  res = await _apiService.registrarUsuario(
                    username: username,
                    email: email,
                    password: password,
                    role: selectedRole,
                  );
                }

                if (mounted) {
                  final String msg = res['message'] ??
                      (res['errors'] != null && (res['errors'] as List).isNotEmpty
                          ? res['errors'][0]['msg'].toString()
                          : (res['success'] == true
                              ? (isEdit ? 'Usuario actualizado exitosamente' : 'Usuario registrado exitosamente')
                              : 'Error al procesar usuario'));

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(msg),
                      backgroundColor: res['success'] == true ? _green : _red,
                    ),
                  );
                  if (res['success'] == true) {
                    nav.pop();
                    _fetchUsersAndLogs();
                  }
                }
              },
              icon: const Icon(Icons.check, color: Colors.white),
              label: Text(isEdit ? 'Actualizar' : 'Crear Usuario', style: const TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: _primary),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleUserActivo(Map<String, dynamic> user) async {
    final int? id = user['id'] ?? user['id_usuario'];
    if (id == null) return;

    final res = await _apiService.toggleActivo(id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Estado actualizado'),
          backgroundColor: res['success'] == true ? _green : _red,
          duration: const Duration(seconds: 2),
        ),
      );
      if (res['success'] == true) {
        _fetchUsersAndLogs();
      }
    }
  }

  void _eliminarUsuario(int id, String username) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Usuario'),
        content: Text('¿Está seguro de eliminar permanentemente la cuenta "$username"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _red, foregroundColor: Colors.white),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final res = await _apiService.deleteUser(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Usuario eliminado'),
            backgroundColor: res['success'] == true ? _green : _red,
          ),
        );
        if (res['success'] == true) _fetchUsersAndLogs();
      }
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // UI BUILD
  // ───────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: ModuloAppBar(
        titulo: 'Centro de Seguridad & Control de Acceso',
        subtitulo: 'ASIC San José de Guanipa · Auditoría Digital MPPS',
        backgroundColor: _primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar Datos',
            onPressed: _fetchUsersAndLogs,
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.amber,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.manage_accounts_outlined), text: 'Personal & Roles RBAC'),
            Tab(icon: Icon(Icons.security_outlined), text: 'Bitácora de Auditoría'),
            Tab(icon: Icon(Icons.rule_folder_outlined), text: 'Matriz de Permisos'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildKpiRibbon(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildUsuariosTab(),
                      _buildBitacoraTab(),
                      _buildMatrizPermisosTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // KPI RIBBON SUPERIOR
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildKpiRibbon() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 800;
          return Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            children: [
              _buildKpiCard(
                title: 'Total Cuentas',
                value: '$_totalUsuarios',
                subtitle: 'Personal registrado',
                icon: Icons.people,
                color: _primary,
                isWide: isWide,
              ),
              _buildKpiCard(
                title: 'Personal Activo',
                value: '$_usuariosActivos',
                subtitle: 'Habilitados para guardia',
                icon: Icons.check_circle_outline,
                color: _green,
                isWide: isWide,
              ),
              _buildKpiCard(
                title: 'Personal Asistencial',
                value: '$_medicosYAsistenciales',
                subtitle: 'Médicos e inmunizadores',
                icon: Icons.medical_services_outlined,
                color: _teal,
                isWide: isWide,
              ),
              _buildKpiCard(
                title: 'Eventos Auditados',
                value: '${_auditLogs.length}',
                subtitle: 'Registros en bitácora',
                icon: Icons.history_toggle_off,
                color: _purple,
                isWide: isWide,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isWide,
  }) {
    return Container(
      width: isWide ? 230 : 160,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withValues(alpha: 0.2),
            foregroundColor: color,
            child: Icon(icon, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
                Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TAB 1: GESTIÓN DE USUARIOS Y ROLES (DATA GRID)
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildUsuariosTab() {
    final usuarios = _usuariosFiltrados;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Barra de Filtros
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Wrap(
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  // Buscador
                  SizedBox(
                    width: 260,
                    child: TextField(
                      controller: _searchUserCtrl,
                      decoration: InputDecoration(
                        hintText: 'Buscar usuario o correo...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  // Filtro Rol
                  SizedBox(
                    width: 170,
                    child: DropdownButtonFormField<String>(
                      initialValue: _filtroRol,
                      decoration: const InputDecoration(
                        labelText: 'Rol',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Todos', child: Text('Todos los Roles')),
                        DropdownMenuItem(value: 'Medico', child: Text('Médicos')),
                        DropdownMenuItem(value: 'Inmunizador', child: Text('Inmunizadores')),
                        DropdownMenuItem(value: 'Inventario', child: Text('Inventario')),
                        DropdownMenuItem(value: 'Epidemiologo', child: Text('Epidemiólogos')),
                        DropdownMenuItem(value: 'Admin', child: Text('Administradores')),
                      ],
                      onChanged: (val) => setState(() => _filtroRol = val ?? 'Todos'),
                    ),
                  ),
                  // Filtro Estado
                  SizedBox(
                    width: 160,
                    child: DropdownButtonFormField<String>(
                      initialValue: _filtroEstado,
                      decoration: const InputDecoration(
                        labelText: 'Estado',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Todos', child: Text('Todos')),
                        DropdownMenuItem(value: 'activos', child: Text('Activos')),
                        DropdownMenuItem(value: 'inactivos', child: Text('Inactivos')),
                      ],
                      onChanged: (val) => setState(() => _filtroEstado = val ?? 'Todos'),
                    ),
                  ),
                  // Botón Nuevo Usuario
                  ElevatedButton.icon(
                    onPressed: () => _showUserDialog(),
                    icon: const Icon(Icons.person_add, color: Colors.white),
                    label: const Text('Nuevo Personal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Tabla de Usuarios
          Expanded(
            child: usuarios.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        const Text('No se encontraron usuarios con los filtros seleccionados', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowHeight: 44,
                          dataRowMinHeight: 48,
                          dataRowMaxHeight: 52,
                          headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                          columns: const [
                            DataColumn(label: Text('Usuario', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                            DataColumn(label: Text('Correo Institucional', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                            DataColumn(label: Text('Rol Asistencial', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                            DataColumn(label: Text('Acceso Activo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                            DataColumn(label: Text('Acciones', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                          ],
                          rows: usuarios.map((user) {
                            final int id = user['id'] ?? user['id_serial'] ?? user['id_usuario'] ?? 0;
                            final username = user['username'] ?? user['nombre_usuario'] ?? 'N/A';
                            final email = user['email'] ?? user['correo'] ?? 'Sin correo';
                            final role = _extraerRol(user);
                            final bool activo = user['activo'] != false && user['activo'] != 0;

                            return DataRow(
                              cells: [
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircleAvatar(
                                        radius: 14,
                                        backgroundColor: _getRolColor(role).withValues(alpha: 0.2),
                                        foregroundColor: _getRolColor(role),
                                        child: Text(
                                          username.isNotEmpty ? username[0].toUpperCase() : 'U',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    ],
                                  ),
                                ),
                                DataCell(Text(email, style: const TextStyle(fontSize: 12))),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: _getRolColor(role).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: _getRolColor(role).withValues(alpha: 0.3)),
                                    ),
                                    child: Text(
                                      _getRolLabel(role),
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _getRolColor(role)),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Switch(
                                    value: activo,
                                    activeThumbColor: _green,
                                    onChanged: (_) => _toggleUserActivo(user),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 18, color: _primary),
                                        tooltip: 'Editar Usuario / Rol',
                                        onPressed: () => _showUserDialog(user: user),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 18, color: _red),
                                        tooltip: 'Eliminar Cuenta',
                                        onPressed: () => _eliminarUsuario(id, username),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TAB 2: BITÁCORA DE AUDITORÍA
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildBitacoraTab() {
    final logs = _bitacoraFiltrada;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  SizedBox(
                    width: 280,
                    child: TextField(
                      controller: _searchAuditCtrl,
                      decoration: InputDecoration(
                        hintText: 'Buscar en bitácora por usuario o acción...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String>(
                      initialValue: _filtroModuloAudit,
                      decoration: const InputDecoration(
                        labelText: 'Módulo / Tabla',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Todos', child: Text('Todos los Módulos')),
                        DropdownMenuItem(value: 'atenciones', child: Text('Atenciones / Consulta')),
                        DropdownMenuItem(value: 'pacientes', child: Text('Pacientes')),
                        DropdownMenuItem(value: 'lotes', child: Text('Inventario / Lotes')),
                        DropdownMenuItem(value: 'reportes', child: Text('Reportes')),
                        DropdownMenuItem(value: 'auth', child: Text('Seguridad')),
                      ],
                      onChanged: (val) => setState(() => _filtroModuloAudit = val ?? 'Todos'),
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _exportarBitacoraCsv,
                    icon: const Icon(Icons.file_download_outlined, color: Colors.white),
                    label: const Text('Exportar Bitácora (Excel)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: _green),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: logs.isEmpty
                ? const Center(child: Text('No hay registros en la bitácora'))
                : Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ListView.separated(
                      itemCount: logs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final log = logs[index];
                        final usuario = log['usuario'] ?? 'sistema';
                        final tabla = log['tabla'] ?? 'N/A';
                        final accion = log['accion'] ?? 'N/A';
                        final fecha = log['fecha'] ?? '';

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          leading: CircleAvatar(
                            backgroundColor: _primary.withValues(alpha: 0.1),
                            foregroundColor: _primary,
                            child: const Icon(Icons.security, size: 18),
                          ),
                          title: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  tabla.toUpperCase(),
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  accion,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text('Usuario: $usuario · Timestamp: $fecha', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TAB 3: MATRIZ DE PERMISOS Y PRIVILEGIOS RBAC
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildMatrizPermisosTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Matriz de Privilegios Asistenciales (Normativa ASIC Guanipa)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 6),
          const Text(
            'Control estricto de accesos basado en el rol clínico del personal para resguardo de la confidencialidad médica y trazabilidad de biológicos.',
            style: TextStyle(fontSize: 13, color: Colors.black87),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            clipBehavior: Clip.antiAlias,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
              columns: const [
                DataColumn(label: Text('Módulo / Funcionalidad', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Médico', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Inmunizador', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Inventario', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Epidemiólogo', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Admin', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: const [
                DataRow(cells: [
                  DataCell(Text('Apertura y Cierre de Guardia')),
                  DataCell(Text('✓ Total', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                  DataCell(Text('✓ Total', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                  DataCell(Text('Lectura', style: TextStyle(color: Colors.grey))),
                  DataCell(Text('Lectura', style: TextStyle(color: Colors.grey))),
                  DataCell(Text('✓ Total', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                ]),
                DataRow(cells: [
                  DataCell(Text('Flujo Rápido de Inmunización')),
                  DataCell(Text('✓ Total', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                  DataCell(Text('✓ Total', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                  DataCell(Text('—', style: TextStyle(color: Colors.red))),
                  DataCell(Text('Lectura', style: TextStyle(color: Colors.grey))),
                  DataCell(Text('✓ Total', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                ]),
                DataRow(cells: [
                  DataCell(Text('Consulta Médica, Triaje & CIE-10')),
                  DataCell(Text('✓ Total', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                  DataCell(Text('—', style: TextStyle(color: Colors.red))),
                  DataCell(Text('—', style: TextStyle(color: Colors.red))),
                  DataCell(Text('Lectura', style: TextStyle(color: Colors.grey))),
                  DataCell(Text('✓ Total', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                ]),
                DataRow(cells: [
                  DataCell(Text('Almacén, Lotes & Kárdex')),
                  DataCell(Text('Lectura', style: TextStyle(color: Colors.grey))),
                  DataCell(Text('Lectura', style: TextStyle(color: Colors.grey))),
                  DataCell(Text('✓ Total', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                  DataCell(Text('Lectura', style: TextStyle(color: Colors.grey))),
                  DataCell(Text('✓ Total', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                ]),
                DataRow(cells: [
                  DataCell(Text('Actas Oficiales de Descarte MPPS')),
                  DataCell(Text('—', style: TextStyle(color: Colors.red))),
                  DataCell(Text('—', style: TextStyle(color: Colors.red))),
                  DataCell(Text('✓ Emisión', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                  DataCell(Text('Lectura', style: TextStyle(color: Colors.grey))),
                  DataCell(Text('✓ Total', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                ]),
                DataRow(cells: [
                  DataCell(Text('Sala Situacional & EPI-12')),
                  DataCell(Text('Lectura', style: TextStyle(color: Colors.grey))),
                  DataCell(Text('Lectura', style: TextStyle(color: Colors.grey))),
                  DataCell(Text('Lectura', style: TextStyle(color: Colors.grey))),
                  DataCell(Text('✓ Total', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                  DataCell(Text('✓ Total', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                ]),
                DataRow(cells: [
                  DataCell(Text('Control de Usuarios & Bitácora')),
                  DataCell(Text('—', style: TextStyle(color: Colors.red))),
                  DataCell(Text('—', style: TextStyle(color: Colors.red))),
                  DataCell(Text('—', style: TextStyle(color: Colors.red))),
                  DataCell(Text('—', style: TextStyle(color: Colors.red))),
                  DataCell(Text('✓ Total', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // HELPERS VISUALES
  // ───────────────────────────────────────────────────────────────────────────

  String _extraerRol(Map<String, dynamic>? user) {
    if (user == null) return 'Medico';
    if (user['role'] != null) return user['role'].toString();
    if (user['rol'] != null) return user['rol'].toString();
    if (user['roles'] is List && (user['roles'] as List).isNotEmpty) {
      return (user['roles'] as List).first.toString();
    }
    return 'Basico';
  }

  Color _getRolColor(String role) {
    final r = role.toLowerCase();
    if (r.contains('admin')) return _red;
    if (r.contains('medico')) return _primary;
    if (r.contains('inmunizador')) return _green;
    if (r.contains('inventario')) return _amber;
    if (r.contains('epidemiologo')) return _purple;
    return Colors.grey;
  }

  String _getRolLabel(String role) {
    final r = role.toLowerCase();
    if (r.contains('admin')) return 'Administrador';
    if (r.contains('medico')) return 'Médico';
    if (r.contains('inmunizador')) return 'Inmunizador';
    if (r.contains('inventario')) return 'Inventario';
    if (r.contains('epidemiologo')) return 'Epidemiólogo';
    return 'Operador';
  }
}

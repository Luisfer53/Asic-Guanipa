import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:asis_guanipa_frontend/services/api_service.dart';
import 'package:asis_guanipa_frontend/utils/upper_case_text_formatter.dart';
import 'package:responsive_framework/responsive_framework.dart';

class SeguridadScreen extends StatefulWidget {
  const SeguridadScreen({super.key});

  @override
  State<SeguridadScreen> createState() => _SeguridadScreenState();
}

class _SeguridadScreenState extends State<SeguridadScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  // Form Inputs State
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedRole = 'Basico';

  // Users & Logs Lists
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _auditLogs = [];
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchUsersAndLogs();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsersAndLogs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Get users list
      final usersRes = await _apiService.getUsers();
      if (usersRes['success'] == true) {
        _users = List<Map<String, dynamic>>.from(usersRes['data'] ?? []);
      }

      // 2. Fetch recent audit logs from bitácora table
      final logRes = await _apiService.getBitacora();
      if (logRes['success'] == true) {
        final List data = logRes['data'] ?? [];
        _auditLogs = data.map<Map<String, dynamic>>((l) => {
          'usuario': l['usuario'] ?? 'N/A',
          'tabla': l['tabla'] ?? 'N/A',
          'accion': l['accion'] ?? 'N/A',
          'fecha': l['createdAt'] ?? l['created_at'] ?? '',
        }).toList();
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar seguridad: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _guardarUsuario() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final res = await _apiService.registrarUsuario(
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (res['success'] == true) {
        // Now update the role of the newly registered user if it's different from the default (Basico)
        final newUser = res['data']?['user'];
        if (newUser != null && _selectedRole != 'Basico') {
          final int newUserId = newUser['id'];
          await _apiService.updateUser(
            id: newUserId,
            username: _usernameController.text.trim(),
            email: _emailController.text.trim(),
            role: _selectedRole,
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Usuario creado exitosamente'), backgroundColor: Colors.green),
          );
        }
        _usernameController.clear();
        _emailController.clear();
        _passwordController.clear();
        _fetchUsersAndLogs();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'Error al registrar usuario'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seguridad y Control de Acceso'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        actions: defaultTargetPlatform == TargetPlatform.android
            ? [
                IconButton(
                  tooltip: 'Configurar servidor',
                  icon: const Icon(Icons.settings_ethernet_outlined),
                  onPressed: () => _openServerConfigDialog(context),
                ),
              ]
            : [],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Builder(
              builder: (context) {
                final isSmall = ResponsiveBreakpoints.of(context).isMobile;
                final leftContent = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Nuevo Usuario',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: const Color(0xFF0D47A1),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Divider(height: 24),
                              TextFormField(
                                controller: _usernameController,
                                decoration: const InputDecoration(
                                  labelText: 'Nombre de Usuario',
                                  prefixIcon: Icon(Icons.person_outline),
                                  border: OutlineInputBorder(),
                                ),
                                validator: (val) => val == null || val.trim().isEmpty ? 'Ingrese nombre de usuario' : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _emailController,
                                decoration: const InputDecoration(
                                  labelText: 'Correo Electrónico',
                                  prefixIcon: Icon(Icons.email_outlined),
                                  border: OutlineInputBorder(),
                                ),
                                validator: (val) => val == null || val.trim().isEmpty ? 'Ingrese correo' : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: true,
                                decoration: const InputDecoration(
                                  labelText: 'Contraseña',
                                  prefixIcon: Icon(Icons.lock_outline),
                                  border: OutlineInputBorder(),
                                ),
                                validator: (val) => val == null || val.length < 6 ? 'Mínimo 6 caracteres' : null,
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                decoration: const InputDecoration(
                                  labelText: 'Rol Asignado',
                                  prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                                  border: OutlineInputBorder(),
                                ),
                                initialValue: _selectedRole,
                                items: const [
                                  DropdownMenuItem(value: 'Basico', child: Text('Básico')),
                                  DropdownMenuItem(value: 'Medico', child: Text('Médico')),
                                  DropdownMenuItem(value: 'Admin', child: Text('Administrador')),
                                ],
                                onChanged: (val) {
                                  setState(() {
                                    _selectedRole = val!;
                                  });
                                },
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: _isSaving ? null : _guardarUsuario,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0D47A1),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: _isSaving
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                      )
                                    : const Text('Crear Usuario', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Usuarios Registrados',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: const Color(0xFF0D47A1),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Divider(height: 24),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _users.length,
                              itemBuilder: (context, index) {
                                final user = _users[index];
                                final List roles = user['roles'] ?? [];
                                final username = user['nombre_usuario'] ?? user['username'] ?? 'N/A';
                                final bool activo = user['activo'] != false; // default true
                                final int userId = user['id_serial'] ?? user['id'] ?? 0;
                                return Card(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: BorderSide(
                                      color: activo ? Colors.green.shade100 : Colors.red.shade100,
                                      width: 1,
                                    ),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    leading: CircleAvatar(
                                      backgroundColor: activo ? const Color(0xFFE3F2FD) : Colors.red.shade50,
                                      child: Icon(
                                        activo ? Icons.person : Icons.person_off_outlined,
                                        color: activo ? const Color(0xFF0D47A1) : Colors.red.shade400,
                                      ),
                                    ),
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(username, overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: activo ? null : Colors.red.shade400,
                                              decoration: activo ? null : TextDecoration.lineThrough,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: activo ? Colors.green.shade50 : Colors.red.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            activo ? 'Activo' : 'Desactivado',
                                            style: TextStyle(
                                              color: activo ? Colors.green.shade700 : Colors.red.shade700,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(user['email'] ?? 'N/A', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                                        const SizedBox(height: 2),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE3F2FD),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            roles.isNotEmpty ? roles.join(', ') : 'Básico',
                                            style: const TextStyle(color: Color(0xFF0D47A1), fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                    trailing: IconButton(
                                      tooltip: activo ? 'Deshabilitar usuario' : 'Habilitar usuario',
                                      icon: Icon(
                                        activo ? Icons.block_rounded : Icons.check_circle_outline_rounded,
                                        color: activo ? Colors.red.shade400 : Colors.green.shade600,
                                        size: 22,
                                      ),
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: Text(activo ? 'Deshabilitar usuario' : 'Habilitar usuario'),
                                            content: Text(
                                              activo
                                                  ? '¿Deshabilitar a $username? No podrá iniciar sesión.'
                                                  : '¿Habilitar a $username? Podrá iniciar sesión nuevamente.',
                                            ),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                                              ElevatedButton(
                                                onPressed: () => Navigator.pop(ctx, true),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: activo ? Colors.red : Colors.green,
                                                  foregroundColor: Colors.white,
                                                ),
                                                child: Text(activo ? 'Deshabilitar' : 'Habilitar'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true && mounted) {
                                          final messenger = ScaffoldMessenger.of(context);
                                          final res = await _apiService.toggleActivo(userId);
                                          if (mounted) {
                                            messenger.showSnackBar(
                                              SnackBar(
                                                content: Text(res['message'] ?? 'Estado actualizado'),
                                                backgroundColor: res['success'] == true ? Colors.green : Colors.red,
                                              ),
                                            );
                                            if (res['success'] == true) _fetchUsersAndLogs();
                                          }
                                        }
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );

                Widget buildBitacoraList({required bool shrink}) {
                  if (_auditLogs.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.0),
                      child: Center(
                        child: Text('No hay registros de trazabilidad todavía.'),
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: shrink,
                    physics: shrink ? const NeverScrollableScrollPhysics() : null,
                    itemCount: _auditLogs.length,
                    itemBuilder: (context, index) {
                      final log = _auditLogs[index];
                      final rawDate = DateTime.tryParse(log['fecha'] ?? '');
                      final formattedDate = rawDate != null 
                          ? '${rawDate.day.toString().padLeft(2, '0')}/${rawDate.month.toString().padLeft(2, '0')}/${rawDate.year} ${rawDate.hour.toString().padLeft(2, '0')}:${rawDate.minute.toString().padLeft(2, '0')}'
                          : 'N/A';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.history_toggle_off_outlined, color: Colors.blueGrey, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Usuario: ${log['usuario']}  ·  Módulo: ${log['tabla']}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0D47A1)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    log['accion'] ?? '',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    formattedDate,
                                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }

                if (isSmall) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        leftContent,
                        const SizedBox(height: 16),
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Bitácora de Auditoría (Trazabilidad)',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: const Color(0xFF0D47A1),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Divider(height: 24),
                                buildBitacoraList(shrink: true),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 1,
                        child: SingleChildScrollView(child: leftContent),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 1,
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Bitácora de Auditoría (Trazabilidad)',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: const Color(0xFF0D47A1),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Divider(height: 24),
                                Expanded(child: buildBitacoraList(shrink: false)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  void _openServerConfigDialog(BuildContext context) async {
    final controller = TextEditingController(text: await ApiService.getCustomServerUrl() ?? ApiService.baseUrl);
    bool testing = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
        return AlertDialog(
          title: const Text('Configurar servidor'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [UpperCaseTextFormatter()],
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'URL del servidor (puede pegar el link del túnel)',
                ),
              ),
              const SizedBox(height: 12),
              testing ? const CircularProgressIndicator() : const SizedBox.shrink(),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
            TextButton(
              onPressed: testing
                  ? null
                  : () async {
                      setState(() => testing = true);
                      final testOk = await ApiService.testConnection(controller.text);
                      setState(() => testing = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(testOk ? 'Conexión OK' : 'No se pudo conectar')),
                      );
                    },
              child: const Text('Probar'),
            ),
            ElevatedButton(
              onPressed: testing
                  ? null
                  : () async {
                      final saved = await ApiService.setCustomServerUrl(controller.text);
                      if (saved) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('URL guardada')));
                        Navigator.pop(ctx);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al guardar')));
                      }
                    },
              child: const Text('Guardar'),
            ),
          ],
        );
      }),
    );
  }
}

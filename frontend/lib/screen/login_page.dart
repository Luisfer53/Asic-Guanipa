import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../response/login_response.dart';
import 'package:asis_guanipa_frontend/providers/auth_providers.dart';
import 'package:asis_guanipa_frontend/screen/forgot_password_screen.dart';
import 'package:asis_guanipa_frontend/services/api_service.dart';
import 'package:responsive_framework/responsive_framework.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;
  bool _isLoading = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  static const Color _bgLight = Color(0xFFF8FAFC);
  static const Color _primary = Color(0xFF1B6FE8);
  static const Color _accent = Color(0xFF0284C7);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF475569);

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _login(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    LoginResponse response = await authProvider.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!response.success) {
      final isConnError = response.message.toLowerCase().contains('conexión') ||
          response.message.toLowerCase().contains('connection') ||
          response.message.toLowerCase().contains('intente nuevamente');

      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(response.message)),
            ],
          ),
          action: SnackBarAction(
            label: 'Configurar URL',
            textColor: Colors.amberAccent,
            onPressed: () => _showServerConfigDialog(context),
          ),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

      if (isConnError) {
        _showServerConfigDialog(context, autoTriggered: true);
      }
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Text('Inicio de sesión exitoso'),
          ],
        ),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    router.push("/");
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = ResponsiveBreakpoints.of(context).isMobile ||ResponsiveBreakpoints.of(context).isTablet;

    return Scaffold(
      backgroundColor: _bgLight,
      body: Stack(
        children: [
          // Background soft gradient circles
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _primary.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            right: -80,
            child: Container(
              width: 450,
              height: 450,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _accent.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: isMobile
                ? _buildMobileLayout(context)
                : _buildDesktopLayout(context),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      children: [
        // Left panel – branding
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(56),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFEFF6FF),
                  const Color(0xFFF0F9FF),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: const Border(
                right: BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset('assets/logo.svg', height: 140),
                const SizedBox(height: 32),
                const Text(
                  'ASIC Guanipa',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [_primary, _accent],
                  ).createShader(bounds),
                  child: const Text(
                    'Sistema de Gestión de Salud',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Plataforma oficial del Centro de Diagnóstico\nIntegral Pedro Urbina · Municipio San José de Guanipa.',
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 15,
                    height: 1.7,
                  ),
                ),
                const SizedBox(height: 48),
                _buildLeftFeature(
                    Icons.lock_rounded, 'Acceso seguro con JWT y cifrado AES-256'),
                const SizedBox(height: 16),
                _buildLeftFeature(
                    Icons.manage_accounts_rounded, 'Control de roles: Admin y Médico'),
                const SizedBox(height: 16),
                _buildLeftFeature(
                    Icons.monitor_heart_rounded, 'Seguimiento epidemiológico en tiempo real'),
              ],
            ),
          ),
        ),

        // Right panel – form card
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(56),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: _buildForm(context),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Column(
          children: [
            const SizedBox(height: 24),
            SvgPicture.asset('assets/logo_icon.svg', height: 75),
            const SizedBox(height: 20),
            const Text(
              'ASIC Guanipa',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Sistema de Gestión de Salud',
              style: TextStyle(color: _textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: _buildForm(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftFeature(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _primary, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: _textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bienvenido de vuelta',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Ingresa tus credenciales para continuar',
            style: TextStyle(color: _textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 32),

          // Email field
          _buildLabel('Correo electrónico'),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _emailController,
            hint: 'nombre@ejemplo.com',
            icon: Icons.alternate_email_rounded,
            keyboard: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Ingresa tu email';
              if (!v.contains('@')) return 'Email inválido';
              return null;
            },
          ),
          const SizedBox(height: 20),

          // Password field
          _buildLabel('Contraseña'),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _passwordController,
            hint: '••••••••',
            icon: Icons.lock_outline_rounded,
            isPassword: true,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Ingresa tu contraseña';
              if (v.length < 6) return 'Mínimo 6 caracteres';
              return null;
            },
          ),

          // Forgot password
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => ForgotPasswordScreen()),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: _primary,
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: const Text(
                '¿Olvidaste tu contraseña?',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Login button
          _LoginButton(
            isLoading: _isLoading,
            onTap: () => _login(context),
          ),

          const SizedBox(height: 16),

          // Botón para configurar servidor / túnel manualmente
          Center(
            child: TextButton.icon(
              onPressed: () => _showServerConfigDialog(context),
              icon: const Icon(Icons.dns_rounded, size: 16, color: _primary),
              label: const Text(
                '⚙️ Configurar Servidor / Túnel',
                style: TextStyle(color: _primary, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Back to landing – solo visible en web
          if (kIsWeb)
            Center(
              child: TextButton.icon(
                onPressed: () => context.go('/landing'),
                icon: const Icon(Icons.arrow_back_rounded,
                    size: 14, color: _textSecondary),
                label: const Text(
                  'Volver al inicio',
                  style: TextStyle(color: _textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                style: TextButton.styleFrom(foregroundColor: _textSecondary),
              ),
            ),
        ],
      ),
    );
  }

  void _showServerConfigDialog(BuildContext parentContext, {bool autoTriggered = false}) {
    final controller = TextEditingController(text: ApiService.baseUrl);
    bool testing = false;
    bool? connectionSuccess;
    String? statusMessage = autoTriggered
        ? '⚠️ Error de conexión detectado. Pega la nueva URL del túnel para continuar.'
        : null;

    showDialog(
      context: parentContext,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Icon(Icons.dns_rounded, color: _primary),
                  SizedBox(width: 10),
                  Text('Servidor API / Túnel',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pega o ingresa el enlace generado por el script para conectar la app a la API:',
                      style: TextStyle(fontSize: 13, color: _textSecondary),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          final data = await Clipboard.getData(Clipboard.kTextPlain);
                          if (data != null && data.text != null && data.text!.isNotEmpty) {
                            final clean = ApiService.formatCleanServerUrl(data.text!);
                            controller.text = clean;
                            setDialogState(() {
                              testing = true;
                              statusMessage = 'Verificando enlace del portapapeles...';
                            });
                            final ok = await ApiService.testConnection(clean);
                            setDialogState(() {
                              testing = false;
                              connectionSuccess = ok;
                              statusMessage = ok
                                  ? '✅ Servidor accesible y responde correctamente'
                                  : '❌ No se pudo conectar a la URL pegada';
                            });
                          } else {
                            setDialogState(() {
                              statusMessage = '⚠️ El portapapeles está vacío';
                            });
                          }
                        } catch (e) {
                          setDialogState(() {
                            statusMessage = '⚠️ No se pudo leer el portapapeles';
                          });
                        }
                      },
                      icon: const Icon(Icons.assignment_turned_in_rounded, size: 16),
                      label: const Text('📋 Pegar desde Portapapeles'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _primary,
                        side: const BorderSide(color: _primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        labelText: 'URL del Servidor API',
                        hintText: 'https://xxxx.trycloudflare.com/api',
                        prefixIcon: const Icon(Icons.link_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (statusMessage != null)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (connectionSuccess == true)
                              ? const Color(0xFFDCFCE7)
                              : (connectionSuccess == false)
                                  ? const Color(0xFFFEE2E2)
                                  : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              (connectionSuccess == true)
                                  ? Icons.check_circle_rounded
                                  : (connectionSuccess == false)
                                      ? Icons.error_rounded
                                      : Icons.info_outline_rounded,
                              color: (connectionSuccess == true)
                                  ? const Color(0xFF16A34A)
                                  : (connectionSuccess == false)
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFFD97706),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                statusMessage!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: (connectionSuccess == true)
                                      ? const Color(0xFF15803D)
                                      : (connectionSuccess == false)
                                          ? const Color(0xFFB91C1C)
                                          : const Color(0xFFB45309),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    await ApiService.resetCustomServerUrl();
                    setDialogState(() {
                      controller.text = ApiService.baseUrl;
                      connectionSuccess = true;
                      statusMessage = 'Restablecido a la URL original';
                    });
                  },
                  child: const Text('Restablecer'),
                ),
                ElevatedButton.icon(
                  onPressed: testing
                      ? null
                      : () async {
                          setDialogState(() {
                            testing = true;
                            statusMessage = 'Verificando conexión...';
                          });
                          final ok = await ApiService.testConnection(controller.text);
                          setDialogState(() {
                            testing = false;
                            connectionSuccess = ok;
                            statusMessage = ok
                                ? '✅ Servidor accesible y respondiendo'
                                : '❌ No se pudo conectar a esta URL';
                          });
                        },
                  icon: testing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.network_check_rounded, size: 16),
                  label: const Text('Probar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final newUrl = controller.text.trim();
                    if (newUrl.isNotEmpty) {
                      await ApiService.setCustomServerUrl(newUrl);
                      if (parentContext.mounted) {
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(parentContext).showSnackBar(
                          SnackBar(
                            content: Text('Servidor actualizado: ${ApiService.baseUrl}'),
                            backgroundColor: const Color(0xFF16A34A),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: _textPrimary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboard = TextInputType.text,
    bool isPassword = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      obscureText: isPassword ? _obscurePassword : false,
      style: const TextStyle(color: _textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
        prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 18),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: const Color(0xFF64748B),
                  size: 18,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              )
            : null,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDC2626)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
        ),
        errorStyle: const TextStyle(color: Color(0xFFDC2626), fontSize: 12),
      ),
      validator: validator,
    );
  }
}

// ─── LOGIN BUTTON ─────────────────────────────────────────────────────────────
class _LoginButton extends StatefulWidget {
  final bool isLoading;
  final VoidCallback onTap;
  const _LoginButton({required this.isLoading, required this.onTap});

  @override
  State<_LoginButton> createState() => _LoginButtonState();
}

class _LoginButtonState extends State<_LoginButton> {
  bool _hovered = false;

  static const _primary = Color(0xFF1B6FE8);
  static const _accent = Color(0xFF0284C7);

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.isLoading ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _hovered
                  ? [const Color(0xFF2563EB), const Color(0xFF0369A1)]
                  : [_primary, _accent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: _primary.withValues(alpha: _hovered ? 0.4 : 0.25),
                blurRadius: _hovered ? 18 : 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Iniciar Sesión',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 10),
                      Icon(Icons.arrow_forward_rounded,
                          color: Colors.white, size: 18),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage>
    with TickerProviderStateMixin {
  late AnimationController _bgController;
  late AnimationController _heroController;
  late Animation<double> _heroFade;
  late Animation<Offset> _heroSlide;

  static const Color _bgLight = Color(0xFFF8FAFC);
  static const Color _primary = Color(0xFF1B6FE8);
  static const Color _accent = Color(0xFF0284C7);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF475569);

  Future<void> _downloadApp(String filename) async {
    final String backendBase = ApiService.baseUrl.replaceAll('/api', '');
    final String url = '$backendBase/downloads/$filename';
    final Uri uri = Uri.parse(url);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $uri');
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _heroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _heroFade = CurvedAnimation(
      parent: _heroController,
      curve: Curves.easeOut,
    );

    _heroSlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _heroController,
      curve: Curves.easeOut,
    ));

    _heroController.forward();
  }

  @override
  void dispose() {
    _bgController.dispose();
    _heroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isMobile = size.width < 800;

    return Scaffold(
      backgroundColor: _bgLight,
      body: Stack(
        children: [
          // Animated background soft circles
          _AnimatedBackground(controller: _bgController),

          // Main content
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildNavbar(context, isMobile),
                  _buildHero(context, isMobile),
                  const SizedBox(height: 16),
                  _buildStatsBar(isMobile),
                  const SizedBox(height: 48),
                  _buildDownloadsSection(context, isMobile),
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── NAVBAR ──────────────────────────────────────────────────────────────
  Widget _buildNavbar(BuildContext context, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 48,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        border: const Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Brand
          Row(
            children: [
              SvgPicture.asset('assets/logo_icon.svg', height: 38),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'ASIC GUANIPA',
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    'Sistema de Gestión de Salud',
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 11,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Login button
          _PrimaryButton(
            label: 'Iniciar Sesión',
            icon: Icons.login_rounded,
            onTap: () => context.push('/signin'),
          ),
        ],
      ),
    );
  }

  // ─── HERO ─────────────────────────────────────────────────────────────────
  Widget _buildHero(BuildContext context, bool isMobile) {
    return FadeTransition(
      opacity: _heroFade,
      child: SlideTransition(
        position: _heroSlide,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 24 : 80,
            vertical: isMobile ? 48 : 72,
          ),
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildHeroText(context, isMobile),
                    const SizedBox(height: 40),
                    _buildHeroCard(),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 6, child: _buildHeroText(context, isMobile)),
                    const SizedBox(width: 64),
                    Expanded(flex: 5, child: _buildHeroCard()),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHeroText(BuildContext context, bool isMobile) {
    return Column(
      crossAxisAlignment:
          isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        // Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset('assets/logo_icon.svg', height: 20),
              const SizedBox(width: 8),
              const Text(
                'Asic Guanipa',
                style: TextStyle(
                  color: _primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Sistema de Gestión Integral',
          textAlign: isMobile ? TextAlign.center : TextAlign.left,
          style: TextStyle(
            color: _textPrimary,
            fontSize: isMobile ? 36 : 48,
            fontWeight: FontWeight.w900,
            height: 1.1,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Plataforma oficial para la gestión integral de insumos, jornadas sanitarias y registro nominal de pacientes.',
          textAlign: isMobile ? TextAlign.center : TextAlign.left,
          style: const TextStyle(
            color: _textSecondary,
            fontSize: 17,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 36),
        Column(
          crossAxisAlignment:
              isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            _PrimaryButton(
              label: 'Ingresar al Sistema',
              icon: Icons.lock_open_rounded,
              onTap: () => context.push('/signin'),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.shield_outlined, color: Color(0xFF64748B), size: 16),
                SizedBox(width: 6),
                Text(
                  'Acceso seguro y autorizado',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeroCard() {
    return _LightCard(
      child: Column(
        children: [
          // Top row: icon + title
          Row(
            children: [
              SvgPicture.asset('assets/logo.svg', height: 60),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Panel de Control Centralizado',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Mini metrics
          _buildMiniMetric(
            icon: Icons.people_alt_rounded,
            label: 'Pacientes registrados',
            value: 'Registro nominal',
            color: _accent,
          ),
          const Divider(color: Color(0xFFE2E8F0), height: 24),
          _buildMiniMetric(
            icon: Icons.inventory_2_rounded,
            label: 'Control de almacén',
            value: 'Insumos y lotes',
            color: const Color(0xFFD97706),
          ),
          const Divider(color: Color(0xFFE2E8F0), height: 24),
          _buildMiniMetric(
            icon: Icons.bar_chart_rounded,
            label: 'Reportes',
            value: 'Estadísticas en tiempo real',
            color: const Color(0xFF16A34A),
          ),
          const SizedBox(height: 20),
          // Status bar
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF16A34A),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Sistema operativo · Todos los módulos activos',
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 12,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Icon(Icons.check_circle_rounded, color: color, size: 18),
      ],
    );
  }

  // ─── STATS BAR LIMPIA (3 MÉTRICAS CLAVE) ──────────────────────────────────
  Widget _buildStatsBar(bool isMobile) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 80),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 32,
        vertical: 20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              children: [
                _buildCleanMetricItem(
                  icon: Icons.check_circle_rounded,
                  iconColor: const Color(0xFF16A34A),
                  title: 'Sistema Operativo',
                  subtitle: 'En línea 24/7',
                ),
                const Divider(color: Color(0xFFF1F5F9), height: 24),
                _buildCleanMetricItem(
                  icon: Icons.security_rounded,
                  iconColor: _primary,
                  title: 'Acceso Seguro',
                  subtitle: 'Protocolo AES-256 / JWT',
                ),
                const Divider(color: Color(0xFFF1F5F9), height: 24),
                _buildCleanMetricItem(
                  icon: Icons.info_outline_rounded,
                  iconColor: const Color(0xFF0284C7),
                  title: 'Versión del Sistema',
                  subtitle: 'v1.0.0',
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: _buildCleanMetricItem(
                    icon: Icons.check_circle_rounded,
                    iconColor: const Color(0xFF16A34A),
                    title: 'Sistema Operativo',
                    subtitle: 'En línea 24/7',
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: const Color(0xFFE2E8F0),
                ),
                Expanded(
                  child: _buildCleanMetricItem(
                    icon: Icons.security_rounded,
                    iconColor: _primary,
                    title: 'Acceso Seguro',
                    subtitle: 'Protocolo AES-256 / JWT',
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: const Color(0xFFE2E8F0),
                ),
                Expanded(
                  child: _buildCleanMetricItem(
                    icon: Icons.info_outline_rounded,
                    iconColor: const Color(0xFF0284C7),
                    title: 'Versión del Sistema',
                    subtitle: 'v1.0.0',
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCleanMetricItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: _textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                color: _textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── DOWNLOADS ────────────────────────────────────────────────────────────
  Widget _buildDownloadsSection(BuildContext context, bool isMobile) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 80),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 40,
        vertical: 36,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.download_for_offline_outlined, color: _primary, size: 24),
              SizedBox(width: 8),
              Text(
                'Aplicaciones Nativas',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Descarga e instala nuestras aplicaciones para operar desde tus dispositivos.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 24,
            runSpacing: 20,
            alignment: WrapAlignment.center,
            children: [
              _buildNativeAppCard(
                isMobile: isMobile,
                title: 'Aplicación Android',
                subtitle: 'Para dispositivos móviles y tablets',
                buttonLabel: 'Descargar APK',
                icon: Icons.android_rounded,
                iconColor: const Color(0xFF16A34A),
                buttonColor: const Color(0xFF16A34A),
                onDownload: () => _downloadApp('asic-guanipa.apk'),
              ),
              _buildNativeAppCard(
                isMobile: isMobile,
                title: 'Aplicación Windows',
                subtitle: 'Para equipos de escritorio',
                buttonLabel: 'Descargar EXE',
                icon: Icons.window_rounded,
                iconColor: const Color(0xFF0284C7),
                buttonColor: const Color(0xFF0284C7),
                onDownload: () => _downloadApp('asic-guanipa.exe'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNativeAppCard({
    required bool isMobile,
    required String title,
    required String subtitle,
    required String buttonLabel,
    required IconData icon,
    required Color iconColor,
    required Color buttonColor,
    required VoidCallback onDownload,
  }) {
    return Container(
      width: isMobile ? double.infinity : 320,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onDownload,
              icon: const Icon(Icons.download_rounded, size: 16),
              label: Text(buttonLabel),
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── FOOTER ───────────────────────────────────────────────────────────────
  Widget _buildFooter() {
    return Container(
      margin: const EdgeInsets.only(top: 48),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: Center(
        child: Text(
          '© 2024 ASIC San José de Guanipa - Centro de Salud Pedro Urbina. Todos los derechos reservados.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ─── ANIMATED BACKGROUND ────────────────────────────────────────────────────
class _AnimatedBackground extends StatelessWidget {
  final AnimationController controller;
  const _AnimatedBackground({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, _) {
        final t = controller.value;
        return CustomPaint(
          painter: _BgPainter(t),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _BgPainter extends CustomPainter {
  final double t;
  _BgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    void drawOrb(
        double cx, double cy, double r, Color color, double opacity) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: opacity), Colors.transparent],
        ).createShader(Rect.fromCircle(
          center: Offset(cx * size.width, cy * size.height),
          radius: r,
        ));
      canvas.drawCircle(Offset(cx * size.width, cy * size.height), r, paint);
    }

    drawOrb(0.15 + t * 0.05, 0.2, 360, const Color(0xFF1B6FE8), 0.06);
    drawOrb(0.85 - t * 0.04, 0.15, 300, const Color(0xFF0284C7), 0.05);
    drawOrb(0.5, 0.8 - t * 0.06, 380, const Color(0xFF1B6FE8), 0.04);
  }

  @override
  bool shouldRepaint(_BgPainter old) => old.t != t;
}

// ─── LIGHT CARD ──────────────────────────────────────────────────────────────
class _LightCard extends StatelessWidget {
  final Widget child;
  const _LightCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B6FE8).withValues(alpha: 0.08),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─── PRIMARY BUTTON ──────────────────────────────────────────────────────────
class _PrimaryButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _PrimaryButton(
      {required this.label, required this.icon, required this.onTap});

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _hovered
                  ? [const Color(0xFF2563EB), const Color(0xFF0369A1)]
                  : [const Color(0xFF1B6FE8), const Color(0xFF0284C7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1B6FE8)
                    .withValues(alpha: _hovered ? 0.4 : 0.25),
                blurRadius: _hovered ? 18 : 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Icon(widget.icon, color: Colors.white, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── STAT ITEM ────────────────────────────────────────────────────────────────
class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  const _StatItem(
      {required this.value, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF1B6FE8), size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF475569), fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

// ─── SECTION LABEL ───────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF1B6FE8),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ─── FEATURE CARD ─────────────────────────────────────────────────────────────
class _FeatureCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 280,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _hovered
                ? widget.color.withValues(alpha: 0.5)
                : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: _hovered
                  ? widget.color.withValues(alpha: 0.12)
                  : const Color(0xFF0F172A).withValues(alpha: 0.03),
              blurRadius: _hovered ? 20 : 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(widget.icon, color: widget.color, size: 24),
            ),
            const SizedBox(height: 16),
            Text(
              widget.title,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.description,
              style: const TextStyle(
                color: Color(0xFF475569),
                fontSize: 13,
                height: 1.55,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── DOWNLOAD CARD ────────────────────────────────────────────────────────────
class _DownloadCard extends StatefulWidget {
  final String platform;
  final String description;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onDownload;
  const _DownloadCard({
    required this.platform,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.onDownload,
  });

  @override
  State<_DownloadCard> createState() => _DownloadCardState();
}

class _DownloadCardState extends State<_DownloadCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 280,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _hovered
                ? widget.accentColor.withValues(alpha: 0.4)
                : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: _hovered
                  ? widget.accentColor.withValues(alpha: 0.12)
                  : const Color(0xFF0F172A).withValues(alpha: 0.02),
              blurRadius: _hovered ? 24 : 8,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: widget.accentColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(widget.icon, color: widget.accentColor, size: 34),
            ),
            const SizedBox(height: 16),
            Text(
              widget.platform,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.description,
              style: const TextStyle(
                color: Color(0xFF475569),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: widget.onDownload,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: widget.accentColor,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: widget.accentColor.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.download_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Descargar',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

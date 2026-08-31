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
                  _buildStatsBar(isMobile),
                  _buildFeaturesSection(isMobile),
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
            children: const [
              Icon(Icons.verified_rounded, color: _primary, size: 14),
              SizedBox(width: 6),
              Text(
                'Plataforma Oficial · Municipio San José de Guanipa',
                style: TextStyle(
                  color: _primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Centro de Salud\nPedro Urbina',
          textAlign: isMobile ? TextAlign.center : TextAlign.left,
          style: TextStyle(
            color: _textPrimary,
            fontSize: isMobile ? 36 : 52,
            fontWeight: FontWeight.w900,
            height: 1.08,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 10),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [_primary, _accent],
          ).createShader(bounds),
          child: Text(
            'Sistema Integral de Salud',
            textAlign: isMobile ? TextAlign.center : TextAlign.left,
            style: TextStyle(
              color: Colors.white,
              fontSize: isMobile ? 20 : 26,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Control de inventario de insumos médicos, organización de jornadas de salud y registro nominal de pacientes. Todo en una sola plataforma.',
          textAlign: isMobile ? TextAlign.center : TextAlign.left,
          style: const TextStyle(
            color: _textSecondary,
            fontSize: 16,
            height: 1.65,
          ),
        ),
        const SizedBox(height: 36),
        Row(
          mainAxisAlignment:
              isMobile ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            _PrimaryButton(
              label: 'Ingresar al Portal',
              icon: Icons.arrow_forward_rounded,
              onTap: () => context.push('/signin'),
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

  // ─── STATS BAR ────────────────────────────────────────────────────────────
  Widget _buildStatsBar(bool isMobile) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 80),
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0)),
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceAround,
        runSpacing: 24,
        spacing: 40,
        children: const [
          _StatItem(value: '5', label: 'Módulos integrados', icon: Icons.dashboard_rounded),
          _StatItem(value: '2', label: 'Plataformas nativas', icon: Icons.devices_rounded),
          _StatItem(value: '100%', label: 'Seguridad AES-256', icon: Icons.security_rounded),
          _StatItem(value: '24/7', label: 'Disponibilidad', icon: Icons.cloud_done_rounded),
        ],
      ),
    );
  }

  // ─── FEATURES ─────────────────────────────────────────────────────────────
  Widget _buildFeaturesSection(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 80,
        vertical: 64,
      ),
      child: Column(
        children: [
          const _SectionLabel(label: 'Funcionalidades'),
          const SizedBox(height: 12),
          const Text(
            'Todo lo que necesitas en un solo lugar',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textPrimary,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 48),
          Wrap(
            spacing: 20,
            runSpacing: 20,
            alignment: WrapAlignment.center,
            children: const [
              _FeatureCard(
                icon: Icons.calendar_today_rounded,
                title: 'Jornada Diaria',
                description:
                    'Registro masivo de atenciones médicas por centro de salud y lote de vacuna.',
                color: _primary,
              ),
              _FeatureCard(
                icon: Icons.person_add_alt_1_rounded,
                title: 'Registro Nominal',
                description:
                    'Alta y edición de ciudadanos con historial de vacunación completo.',
                color: Color(0xFF16A34A),
              ),
              _FeatureCard(
                icon: Icons.inventory_2_rounded,
                title: 'Almacén e Insumos',
                description:
                    'Gestión de inventario físico con control de lotes y fechas de vencimiento.',
                color: Color(0xFFD97706),
              ),
              _FeatureCard(
                icon: Icons.bar_chart_rounded,
                title: 'Reportes',
                description:
                    'Generación de estadísticas epidemiológicas filtradas por fecha y sector.',
                color: Color(0xFF9333EA),
              ),
              _FeatureCard(
                icon: Icons.admin_panel_settings_rounded,
                title: 'Seguridad y Roles',
                description:
                    'Control de acceso por roles (Admin / Médico) con autenticación JWT segura.',
                color: Color(0xFFDC2626),
              ),
              _FeatureCard(
                icon: Icons.delete_sweep_rounded,
                title: 'Gestión de Descartes Biológicos',
                description:
                    'Módulo específico para el registro y control de descarte de lotes vencidos de biológicos.',
                color: _accent,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── DOWNLOADS ────────────────────────────────────────────────────────────
  Widget _buildDownloadsSection(BuildContext context, bool isMobile) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 80),
      padding: EdgeInsets.all(isMobile ? 28 : 48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const _SectionLabel(label: 'Descargas'),
          const SizedBox(height: 12),
          const Text(
            'Aplicaciones Nativas',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Instala la versión optimizada para tu dispositivo.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _textSecondary, fontSize: 15),
          ),
          const SizedBox(height: 40),
          Wrap(
            spacing: 20,
            runSpacing: 20,
            alignment: WrapAlignment.center,
            children: [
              _DownloadCard(
                platform: 'Android',
                description: 'Versión móvil · APK',
                icon: Icons.android_rounded,
                accentColor: const Color(0xFF16A34A),
                onDownload: () => _downloadApp('asic-guanipa.apk'),
              ),
              _DownloadCard(
                platform: 'Windows',
                description: 'Aplicación de Escritorio · EXE',
                icon: Icons.laptop_windows_rounded,
                accentColor: const Color(0xFF0284C7),
                onDownload: () => _downloadApp('asic-guanipa.exe'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── FOOTER ───────────────────────────────────────────────────────────────
  Widget _buildFooter() {
    return Container(
      margin: const EdgeInsets.only(top: 64),
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 48),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset('assets/logo_icon.svg', height: 36),
              const SizedBox(width: 10),
              const Text(
                'ASIC San José de Guanipa',
                style: TextStyle(
                  color: _textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Gobierno Bolivariano de Venezuela  ·  Ministerio del Poder Popular para la Salud',
            textAlign: TextAlign.center,
            style: TextStyle(color: _textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 6),
          const Text(
            '© 2026 Centro de Diagnóstico Integral Pedro Urbina',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
        ],
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

import 'package:flutter/material.dart';
import 'package:asis_guanipa_frontend/services/api_service.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';

class BodyHome extends StatefulWidget {
  const BodyHome({super.key});
  @override
  State<BodyHome> createState() => _BodyHomeState();
}

class _BodyHomeState extends State<BodyHome> {
  final ApiService _apiService = ApiService();

  int    _atencionesDiarias    = 0;
  int    _alertasStockBajo     = 0;
  String _semanaEpidemiologica = '—';
  bool   _loading              = true;

  static const _primary      = Color(0xFF1565C0);
  static const _primaryLight = Color(0xFF4A9EE8);

  static const _modules = [
    _Mod('Jornada Diaria',    Icons.calendar_today_rounded,       Color(0xFF2E7D32), '/jornada-diaria',
        'Registro masivo de atenciones médicas por centro de salud y lote de vacuna.'),
    _Mod('Registro Nominal',  Icons.person_add_alt_1_rounded,     Color(0xFF1565C0), '/list-patients',
        'Alta y edición de ciudadanos con historial de vacunación completo.'),
    _Mod('Almacén e Insumos', Icons.inventory_2_rounded,          Color(0xFFE65100), '/almacen',
        'Control de inventario físico, lotes y fechas de vencimiento.'),
    _Mod('Reportes',   Icons.bar_chart_rounded,            Color(0xFF6A1B9A), '/reportes',
        'Estadísticas epidemiológicas filtradas por fecha y sector.'),
    _Mod('Gestión de Descartes Biológicos', Icons.delete_sweep_rounded, Color(0xFF00838F), '/descartes-biologicos',
        'Registro y control de descarte de lotes vencidos de biológicos.'),
    _Mod('Seguridad',         Icons.admin_panel_settings_rounded, Color(0xFFC62828), '/seguridad',
        'Gestión de usuarios, roles y permisos de acceso.'),
  ];

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    setState(() => _loading = true);
    try {
      final repRes = await _apiService.getReportesDaily();
      if (repRes['success'] == true) {
        _atencionesDiarias = repRes['stats']?['total'] ?? 0;
      }
      final invRes = await _apiService.getInventario();
      if (invRes['success'] == true) {
        final List lotes = invRes['data'] ?? [];
        _alertasStockBajo = lotes.where((l) => l['alertas']?['stock_bajo'] == true).length;
      }
      final now     = DateTime.now();
      final first   = DateTime(now.year, 1, 1);
      final weekNum = (now.difference(first).inDays / 7).ceil();
      _semanaEpidemiologica = 'Semana $weekNum';
    } catch (_) {}
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _primaryLight, strokeWidth: 2),
      );
    }

    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final padding = isMobile ? 14.0 : 24.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeBanner(isMobile),
          const SizedBox(height: 20),
          _buildMetrics(),
          const SizedBox(height: 28),
          _buildSectionTitle('Módulos del Sistema'),
          const SizedBox(height: 12),
          _buildModulesList(context),
        ],
      ),
    );
  }

  // ─── Welcome Banner ────────────────────────────────────────────────────────
  Widget _buildWelcomeBanner(bool isMobile) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Buenos días' : hour < 18 ? 'Buenas tardes' : 'Buenas noches';
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF4A9EE8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: const TextStyle(
                    color: Color(0xBBFFFFFF),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Centro de Salud Pedro Urbina',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5A623).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFF5A623).withValues(alpha: 0.5)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, color: Color(0xFFF5A623), size: 7),
                      SizedBox(width: 6),
                      Text(
                        'Sistema Activo',
                        style: TextStyle(
                          color: Color(0xFFF5A623),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Refresh button
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF5A623),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF5A623).withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              onPressed: _fetchDashboardData,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
              tooltip: 'Actualizar',
              padding: const EdgeInsets.all(10),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Metrics ──────────────────────────────────────────────────────────────
  Widget _buildMetrics() {
    return Builder(builder: (context) {
      final narrow = ResponsiveBreakpoints.of(context).isMobile;
      final cards = [
        _MetricCard(
          label: 'Atenciones Hoy',
          value: _atencionesDiarias.toString(),
          icon: Icons.people_alt_rounded,
          iconColor: _primary,
          bgColor: const Color(0xFFE3F2FD),
          sub: 'Jornada activa',
        ),
        _MetricCard(
          label: 'Alertas de Stock',
          value: _alertasStockBajo.toString(),
          icon: Icons.warning_amber_rounded,
          iconColor: _alertasStockBajo > 0 ? const Color(0xFFD32F2F) : const Color(0xFF2E7D32),
          bgColor: _alertasStockBajo > 0 ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9),
          sub: _alertasStockBajo > 0 ? 'Requiere atención' : 'Stock normal',
        ),
        _MetricCard(
          label: 'Semana Epidem.',
          value: _semanaEpidemiologica,
          icon: Icons.calendar_view_week_rounded,
          iconColor: const Color(0xFF6A1B9A),
          bgColor: const Color(0xFFF3E5F5),
          sub: 'En curso',
        ),
      ];
      if (narrow) {
        return Column(
          children: cards.map((c) => Padding(padding: const EdgeInsets.only(bottom: 10), child: c)).toList(),
        );
      }
      return Row(
        children: [
          for (int i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: cards[i]),
          ],
        ],
      );
    });
  }

  // ─── Section title ────────────────────────────────────────────────────────
  Widget _buildSectionTitle(String text) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1565C0), Color(0xFFF5A623)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF1A237E),
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // ─── Modules List ─────────────────────────────────────────────────────────
  Widget _buildModulesList(BuildContext context) {
    return Builder(builder: (context) {
      final isMobile = ResponsiveBreakpoints.of(context).isMobile;
      final cols = isMobile ? 1 : 2;
      final items = List.generate(_modules.length, (i) => _ModuleRow(module: _modules[i]));

      if (cols == 1) {
        return Column(
          children: items
              .map((w) => Padding(padding: const EdgeInsets.only(bottom: 10), child: w))
              .toList(),
        );
      }

      // 2-column layout
      final leftItems  = <Widget>[];
      final rightItems = <Widget>[];
      for (int i = 0; i < items.length; i++) {
        if (i % 2 == 0) {
          leftItems.add(Padding(padding: const EdgeInsets.only(bottom: 10), child: items[i]));
        } else {
          rightItems.add(Padding(padding: const EdgeInsets.only(bottom: 10), child: items[i]));
        }
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Column(children: leftItems)),
          const SizedBox(width: 12),
          Expanded(child: Column(children: rightItems)),
        ],
      );
    });
  }
}

// ─── Metric Card ─────────────────────────────────────────────────────────────
class _MetricCard extends StatelessWidget {
  final String   label;
  final String   value;
  final IconData icon;
  final Color    iconColor;
  final Color    bgColor;
  final String   sub;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: iconColor.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Colored top accent bar
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(height: 3, color: iconColor),
          ),
          // Card content
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 11)),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        style: const TextStyle(
                          color: Color(0xFF1A237E),
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(sub,
                          style: TextStyle(color: iconColor, fontSize: 10, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Module model ─────────────────────────────────────────────────────────────
class _Mod {
  final String   title;
  final IconData icon;
  final Color    color;
  final String   route;
  final String   description;
  const _Mod(this.title, this.icon, this.color, this.route, this.description);
}

// ─── Module Row ───────────────────────────────────────────────────────────────
class _ModuleRow extends StatefulWidget {
  final _Mod module;
  const _ModuleRow({required this.module});
  @override
  State<_ModuleRow> createState() => _ModuleRowState();
}

class _ModuleRowState extends State<_ModuleRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.module;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => GoRouter.of(context).push(m.route),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _hovered ? m.color.withValues(alpha: 0.04) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovered ? m.color.withValues(alpha: 0.3) : Colors.grey.shade100,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _hovered ? 0.06 : 0.03),
                blurRadius: _hovered ? 12 : 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Colored icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: m.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(m.icon, color: m.color, size: 22),
              ),
              const SizedBox(width: 14),
              // Title + description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.title,
                      style: const TextStyle(
                        color: Color(0xFF1A237E),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      m.description,
                      style: const TextStyle(
                        color: Color(0xFF90A4AE),
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Arrow
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _hovered ? m.color.withValues(alpha: 0.1) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: _hovered ? m.color : Colors.grey.shade400,
                  size: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:asis_guanipa_frontend/services/api_service.dart';
import 'package:asis_guanipa_frontend/providers/auth_providers.dart';
import 'package:asis_guanipa_frontend/providers/guardia_provider.dart';
import 'package:asis_guanipa_frontend/components/apertura_guardia_dialog.dart';
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
    _Mod('Consulta Médica', Icons.medical_services_rounded, Color(0xFF1565C0), '/consulta-medica',
        'Atención médica general, triaje de signos vitales, diagnóstico y récipe/tratamiento.'),
    _Mod('Registro de Inmunización', Icons.vaccines_rounded, Color(0xFF2E7D32), '/jornada-diaria',
        'Aplicación rápida de vacunas intramurales y extramurales con control de biológicos.'),
    _Mod('Registro Nominal', Icons.person_add_alt_1_rounded, Color(0xFF0D47A1), '/list-patients',
        'Directorio de pacientes con historial clínico y esquema de vacunación.'),
    _Mod('Almacén e Insumos', Icons.inventory_2_rounded, Color(0xFFE65100), '/almacen',
        'Control de inventario físico, lotes, biológicos y fechas de vencimiento.'),
    _Mod('Reportes', Icons.bar_chart_rounded, Color(0xFF6A1B9A), '/reportes',
        'Estadísticas epidemiológicas filtradas por fecha, vacuna y sector.'),
    _Mod('Gestión de Descartes Biológicos', Icons.delete_sweep_rounded, Color(0xFF00838F), '/descartes-biologicos',
        'Registro y control de descarte de lotes vencidos de biológicos.'),
    _Mod('Seguridad', Icons.admin_panel_settings_rounded, Color(0xFFC62828), '/seguridad',
        'Gestión de usuarios, roles y permisos de acceso.'),
  ];

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<GuardiaProvider>().loadFromStorage();
        final auth = context.read<AuthProvider>();
        if (auth.getCurrentUser() == null) {
          auth.loadData();
        }
      }
    });
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
          _buildDashboardHeader(context, isMobile),
          const SizedBox(height: 16),
          _buildGuardiaStatusBar(context),
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

  // ─── Dashboard Header compacto ────────────────────────────────────────────
  Widget _buildDashboardHeader(BuildContext context, bool isMobile) {
    final auth = context.watch<AuthProvider>();
    final user = auth.getCurrentUser();
    String displayName = (user?.displayName ?? '').trim();
    if (displayName.isEmpty || displayName.toLowerCase() == 'usuario') {
      final alt = (user?.nombre1 ?? user?.nombreUsuario ?? user?.username ?? '').trim();
      if (alt.isNotEmpty) {
        displayName = alt;
      } else if (user?.email != null && user!.email!.contains('@')) {
        displayName = user.email!.split('@').first;
      } else {
        displayName = 'Usuario';
      }
    }

    final hour = DateTime.now().hour;
    final String greeting;
    if (hour >= 5 && hour < 12) {
      greeting = 'Buenos días';
    } else if (hour >= 12 && hour < 19) {
      greeting = 'Buenas tardes';
    } else {
      greeting = 'Buenas noches';
    }

    final now = DateTime.now();
    final dateStr = _formatDate(now);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1565C0), Color(0xFF4A9EE8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting, $displayName',
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                dateStr,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: _fetchDashboardData,
          icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B), size: 20),
          tooltip: 'Actualizar datos',
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFFF1F5F9),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime d) {
    const meses = [
      '', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];
    const dias = ['domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado'];
    final dia = dias[d.weekday % 7];
    return '${dia[0].toUpperCase()}${dia.substring(1)}, ${d.day} de ${meses[d.month]} de ${d.year}';
  }

  // ─── Guardia / Turno Status Bar ───────────────────────────────────────────
  Widget _buildGuardiaStatusBar(BuildContext context) {
    return Consumer<GuardiaProvider>(
      builder: (context, prov, _) {
        if (prov.isLoading) {
          return const SizedBox(
            height: 60,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        if (!prov.hasGuardiaActiva) {
          return _GuardiaCallToAction(
            onAbrir: () => AperturaGuardiaDialog.show(context),
          );
        }

        final guardia = prov.guardia!;
        final isExt   = guardia.isExtramural;
        final color   = isExt ? const Color(0xFF0D9488) : const Color(0xFF1565C0);
        final bgColor = isExt ? const Color(0xFFE6FAF8) : const Color(0xFFEFF6FF);
        final icon    = isExt ? Icons.airport_shuttle_rounded : Icons.local_hospital_rounded;
        final label   = isExt
            ? 'Despliegue Extramural – ${guardia.sectorComunidad ?? ''}'
            : 'Guardia Intramural – ${guardia.centroSalud}';
        final turnoCorto = guardia.turno.split('(').first.trim();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 4)],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'GUARDIA ACTIVA',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          turnoCorto,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: color.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => _confirmCerrarGuardia(context, prov),
                icon: Icon(Icons.stop_circle_rounded, size: 16, color: color),
                label: Text('Cerrar', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
                style: TextButton.styleFrom(
                  backgroundColor: color.withValues(alpha: 0.10),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmCerrarGuardia(BuildContext context, GuardiaProvider prov) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cerrar Guardia', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
          '¿Estás seguro de que deseas cerrar la guardia activa?\n\nEsta acción registrará el cierre del turno.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Cerrar Guardia'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await prov.cerrarGuardia();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Guardia cerrada correctamente'),
            backgroundColor: Color(0xFF334155),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ─── Metrics ──────────────────────────────────────────────────────────────
  Widget _buildMetrics() {
    return Builder(builder: (context) {
      final narrow = ResponsiveBreakpoints.of(context).isMobile;
      final guardiaProv = context.watch<GuardiaProvider>();
      final pacientesGuardia = guardiaProv.hasGuardiaActiva
          ? guardiaProv.guardia!.pacientesAtendidos
          : _atencionesDiarias;

      final cards = [
        _MetricCard(
          label: 'Atenciones Hoy',
          value: pacientesGuardia.toString(),
          icon: Icons.people_alt_rounded,
          iconColor: _primary,
          bgColor: const Color(0xFFE3F2FD),
          sub: guardiaProv.hasGuardiaActiva ? 'Guardia activa' : 'Jornada activa',
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

// ─── CTA cuando no hay guardia activa ─────────────────────────────────────────
class _GuardiaCallToAction extends StatelessWidget {
  final VoidCallback onAbrir;
  const _GuardiaCallToAction({required this.onAbrir});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.shield_moon_rounded, color: Color(0xFFD97706), size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sin guardia activa',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF92400E),
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  'Registre la apertura del turno antes de iniciar atenciones.',
                  style: TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: onAbrir,
            icon: const Icon(Icons.play_arrow_rounded, size: 16),
            label: const Text('Abrir Guardia', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 2,
            ),
          ),
        ],
      ),
    );
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

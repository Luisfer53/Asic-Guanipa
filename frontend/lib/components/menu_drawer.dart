import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:asis_guanipa_frontend/storage/jwt_token.dart';
import 'package:asis_guanipa_frontend/screen/login_page.dart';
import 'package:asis_guanipa_frontend/providers/auth_providers.dart';
import 'package:asis_guanipa_frontend/services/api_service.dart';

class MenuDrawer extends StatelessWidget {
  const MenuDrawer({super.key});


  static const _navItems = [
    _NavItem('Jornada Diaria',       Icons.calendar_today_rounded,       Color(0xFF2E7D32), '/jornada-diaria'),
    _NavItem('Registro Nominal',     Icons.person_add_alt_1_rounded,     Color(0xFF1565C0), '/list-patients'),
    _NavItem('Almacén e Insumos',    Icons.inventory_2_rounded,          Color(0xFFE65100), '/almacen'),
    _NavItem('Reportes',             Icons.bar_chart_rounded,            Color(0xFF6A1B9A), '/reportes'),
    _NavItem('Gestión de Descartes Biológicos', Icons.delete_sweep_rounded, Color(0xFF00838F), '/descartes-biologicos'),
    _NavItem('Seguridad',            Icons.admin_panel_settings_rounded, Color(0xFFC62828), '/seguridad'),
  ];

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser  = authProvider.getCurrentUser();

    return Drawer(
      backgroundColor: Colors.white,
      elevation: 0,
      child: Column(
        children: [
          // Gradient header
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0D47A1), Color(0xFF4A9EE8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Gold top accent line
                Container(
                  height: 4,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFF5A623), Color(0xFFFFD700), Color(0xFFF5A623)],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 36, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFF5A623).withValues(alpha: 0.6),
                                width: 2,
                              ),
                            ),
                            child: const Icon(Icons.person_rounded, color: Colors.white, size: 22),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 13,
                              height: 13,
                              decoration: const BoxDecoration(
                                color: Color(0xFFF5A623),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        currentUser?.username ?? '—',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        currentUser?.email ?? '',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Nav items ────────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 4, 12, 8),
                  child: Text(
                    'MÓDULOS',
                    style: TextStyle(
                      color: Color(0xFF90A4AE),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                ..._navItems.map((item) => _DrawerTile(item: item)),
              ],
            ),
          ),

          // ── Logout ───────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: ListTile(
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.logout_rounded, color: Colors.red.shade700, size: 18),
              ),
              title: Text(
                'Cerrar Sesión',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () async {
                // Registrar cierre de sesión en bitácora
                try {
                  await ApiService().logout();
                } catch (_) {}
                await deleteToken();
                if (context.mounted) {
                  Navigator.pop(context);
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                    (route) => false,
                  );
                }
              },
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final String   label;
  final IconData icon;
  final Color    color;
  final String   route;
  const _NavItem(this.label, this.icon, this.color, this.route);
}

class _DrawerTile extends StatefulWidget {
  final _NavItem item;
  const _DrawerTile({required this.item});

  @override
  State<_DrawerTile> createState() => _DrawerTileState();
}

class _DrawerTileState extends State<_DrawerTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _hovered
                ? widget.item.color.withValues(alpha: 0.15)
                : widget.item.color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(widget.item.icon, color: widget.item.color, size: 18),
        ),
        title: Text(
          widget.item.label,
          style: TextStyle(
            color: _hovered ? widget.item.color : const Color(0xFF37474F),
            fontSize: 13,
            fontWeight: _hovered ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        trailing: _hovered
            ? Icon(Icons.chevron_right_rounded, color: widget.item.color, size: 16)
            : null,
        onTap: () {
          Navigator.pop(context);
          GoRouter.of(context).push(widget.item.route);
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        hoverColor: widget.item.color.withValues(alpha: 0.05),
      ),
    );
  }
}

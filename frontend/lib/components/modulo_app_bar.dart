import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// AppBar estándar para todos los módulos del sistema.
/// Incluye botón de regreso al Dashboard principal, título del módulo
/// y soporte para acciones adicionales y TabBar.
class ModuloAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String titulo;
  final String? subtitulo;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final Widget? leading;

  const ModuloAppBar({
    super.key,
    required this.titulo,
    this.subtitulo,
    this.backgroundColor,
    this.foregroundColor,
    this.actions,
    this.bottom,
    this.leading,
  });

  @override
  Size get preferredSize {
    final baseHeight = kToolbarHeight;
    final bottomHeight = bottom?.preferredSize.height ?? 0;
    return Size.fromHeight(baseHeight + bottomHeight);
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? const Color(0xFF1565C0);
    final fgColor = foregroundColor ?? Colors.white;

    return AppBar(
      backgroundColor: bgColor,
      foregroundColor: fgColor,
      elevation: 2,
      leading: leading ??
          Tooltip(
            message: 'Volver al inicio',
            child: InkWell(
              onTap: () {
                // Si hay rutas en el stack, hacer pop; si no, ir al dashboard
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/');
                }
              },
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: fgColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.arrow_back_rounded, color: fgColor, size: 18),
                  ],
                ),
              ),
            ),
          ),
      leadingWidth: 48,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            titulo,
            style: TextStyle(
              color: fgColor,
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitulo != null)
            Text(
              subtitulo!,
              style: TextStyle(
                color: fgColor.withValues(alpha: 0.75),
                fontSize: 11,
              ),
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      actions: actions,
      bottom: bottom,
    );
  }
}

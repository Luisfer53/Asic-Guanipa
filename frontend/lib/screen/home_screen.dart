import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';
import '../components/menu_drawer.dart';
import '../components/body_home.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEBF5FF),
      drawer: const MenuDrawer(),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1565C0), Color(0xFF4A9EE8)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x331565C0),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Expanded(
                child: AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  surfaceTintColor: Colors.transparent,
                  leading: Builder(
                    builder: (context) => IconButton(
                      icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 22),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                      tooltip: 'Menú',
                    ),
                  ),
                  title: Row(
                    children: [
                      SvgPicture.asset('assets/logo_icon.svg', height: 38),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'ASIC Guanipa',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Sistema de Gestión de Salud',
                              style: TextStyle(
                                color: Color(0xBBFFFFFF),
                                fontSize: 10,
                                fontWeight: FontWeight.w400,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Gold accent bottom border
              Container(
                height: 3,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFF5A623), Color(0xFFFFD700), Color(0xFFF5A623)],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: const BodyHome(),
    );
  }
}

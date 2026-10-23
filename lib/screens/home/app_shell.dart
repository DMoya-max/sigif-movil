import 'package:flutter/material.dart';

import '../../models/usuario.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../dashboard/dashboard_screen.dart';
import '../login_screen.dart';
import '../productos/productos_screen.dart';
import '../usuarios/usuario_perfil_screen.dart';
import '../usuarios/usuarios_screen.dart';

class _SeccionDef {
  final String titulo;
  final IconData icono;
  final IconData iconoActivo;
  final Widget pantalla;

  const _SeccionDef({
    required this.titulo,
    required this.icono,
    required this.iconoActivo,
    required this.pantalla,
  });
}

/// Cáscara principal adaptable (Responsive para iPhone, Samsung Galaxy, Tablet y Web/Desktop).
class AppShell extends StatefulWidget {
  final Usuario usuario;

  const AppShell({super.key, required this.usuario});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _indiceActual = 0;

  List<_SeccionDef> _construirSecciones() {
    final u = SessionService.instance.usuario ?? widget.usuario;
    final moduloUsuarios = u.puedeGestionarUsuarios;

    final base = <_SeccionDef>[
      const _SeccionDef(
        titulo: 'Dashboard',
        icono: Icons.speed_outlined,
        iconoActivo: Icons.speed,
        pantalla: DashboardScreen(),
      ),
      if (moduloUsuarios)
        const _SeccionDef(
          titulo: 'Usuarios',
          icono: Icons.people_outline,
          iconoActivo: Icons.people,
          pantalla: UsuariosScreen(),
        ),
      const _SeccionDef(
        titulo: 'Productos',
        icono: Icons.inventory_2_outlined,
        iconoActivo: Icons.inventory_2,
        pantalla: ProductosScreen(),
      ),
    ];
    if (_indiceActual >= base.length) _indiceActual = 0;
    return base;
  }

  Future<void> _cerrarSesion() async {
    final ok = await confirmar(
      context,
      titulo: 'Cerrar sesión',
      mensaje: '¿Estás seguro de que quieres cerrar sesión?',
      textoConfirmar: 'Salir',
      peligro: true,
    );
    if (!ok || !mounted) return;
    await SessionService.instance.cerrarSesion();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _editarPerfil() async {
    final u = SessionService.instance.usuario ?? widget.usuario;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UsuarioPerfilScreen(usuario: u),
      ),
    );
    await SessionService.instance.refrescarSesion();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final secciones = _construirSecciones();
    final seccion = secciones[_indiceActual];
    final usuarioActual = SessionService.instance.usuario ?? widget.usuario;

    return LayoutBuilder(
      builder: (context, constraints) {
        final ancho = constraints.maxWidth;
        // Breakpoint móvil/tablet: < 820px usa Drawer + BottomNavigationBar optimizado para iPhone y Samsung
        final esMovil = ancho < 820;

        if (esMovil) {
          return Scaffold(
            backgroundColor: const Color(0xFFF5F6FA),
            drawer: Drawer(
              backgroundColor: ColoresSigif.sidebarBg,
              width: 260,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
              ),
              child: SafeArea(
                child: _Sidebar(
                  secciones: secciones,
                  indiceActual: _indiceActual,
                  onSeleccionar: (i) {
                    setState(() => _indiceActual = i);
                    Navigator.of(context).pop();
                  },
                  onCerrarSesion: _cerrarSesion,
                  compacto: true,
                ),
              ),
            ),
            body: SafeArea(
              bottom: false,
              child: Builder(
                builder: (ctx) => Column(
                  children: [
                    _UserHeaderBar(
                      usuario: usuarioActual,
                      mostrarBotonMenu: true,
                      esMovil: true,
                      onAbrirMenu: () => Scaffold.of(ctx).openDrawer(),
                      onEditarPerfil: _editarPerfil,
                      onCerrarSesion: _cerrarSesion,
                    ),
                    Expanded(child: seccion.pantalla),
                  ],
                ),
              ),
            ),
            bottomNavigationBar: NavigationBarTheme(
              data: NavigationBarThemeData(
                backgroundColor: const Color(0xFF222938),
                indicatorColor: const Color(0xFF3A56E4),
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  final selected = states.contains(WidgetState.selected);
                  return TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? Colors.white : const Color(0xFFA3B1CC),
                  );
                }),
                iconTheme: WidgetStateProperty.resolveWith((states) {
                  final selected = states.contains(WidgetState.selected);
                  return IconThemeData(
                    size: 22,
                    color: selected ? Colors.white : const Color(0xFFA3B1CC),
                  );
                }),
              ),
              child: NavigationBar(
                height: 64,
                selectedIndex: _indiceActual,
                onDestinationSelected: (i) => setState(() => _indiceActual = i),
                destinations: [
                  for (final s in secciones)
                    NavigationDestination(
                      icon: Icon(s.icono),
                      selectedIcon: Icon(s.iconoActivo),
                      label: s.titulo,
                    ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF5F6FA),
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Sidebar(
                secciones: secciones,
                indiceActual: _indiceActual,
                onSeleccionar: (i) => setState(() => _indiceActual = i),
                onCerrarSesion: _cerrarSesion,
              ),
              Expanded(
                child: Column(
                  children: [
                    _UserHeaderBar(
                      usuario: usuarioActual,
                      mostrarBotonMenu: false,
                      esMovil: false,
                      onAbrirMenu: null,
                      onEditarPerfil: _editarPerfil,
                      onCerrarSesion: _cerrarSesion,
                    ),
                    Expanded(child: seccion.pantalla),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Cabecera superior adaptable con píldora de usuario.
class _UserHeaderBar extends StatelessWidget {
  final Usuario usuario;
  final bool mostrarBotonMenu;
  final bool esMovil;
  final VoidCallback? onAbrirMenu;
  final VoidCallback onEditarPerfil;
  final VoidCallback onCerrarSesion;

  const _UserHeaderBar({
    required this.usuario,
    required this.mostrarBotonMenu,
    required this.esMovil,
    required this.onAbrirMenu,
    required this.onEditarPerfil,
    required this.onCerrarSesion,
  });

  String _capitalizar(String texto) {
    if (texto.isEmpty) return 'Usuario Activo';
    return texto[0].toUpperCase() + texto.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final inicial =
        usuario.nombre.isNotEmpty ? usuario.nombre[0].toUpperCase() : 'U';
    final nombreMostrar = _capitalizar(usuario.nombre);
    final rolMostrar = usuario.cargo.toUpperCase();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        esMovil ? 14 : 40,
        esMovil ? 10 : 24,
        esMovil ? 14 : 40,
        esMovil ? 6 : 6,
      ),
      child: Row(
        children: [
          if (mostrarBotonMenu) ...[
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onAbrirMenu,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE8EEF8)),
                  ),
                  child: const Icon(
                    Icons.menu,
                    color: Color(0xFF2D3748),
                    size: 22,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'SIGIF',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: Color(0xFF1A202C),
              ),
            ),
          ],
          const Spacer(),
          PopupMenuButton<String>(
            offset: const Offset(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            elevation: 8,
            color: Colors.white,
            onSelected: (valor) {
              if (valor == 'perfil') onEditarPerfil();
              if (valor == 'logout') onCerrarSesion();
            },
            itemBuilder: (_) => [
              PopupMenuItem<String>(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombreMostrar,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        rolMostrar,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF3B82F6),
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'perfil',
                child: Row(
                  children: [
                    Icon(
                      Icons.manage_accounts_outlined,
                      size: 18,
                      color: Color(0xFF64748B),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Editar perfil',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(
                      Icons.logout,
                      size: 18,
                      color: Color(0xFFDC2626),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Cerrar sesión',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            child: Container(
              padding: EdgeInsets.fromLTRB(
                esMovil ? 6 : 8,
                esMovil ? 4 : 6,
                esMovil ? 10 : 16,
                esMovil ? 4 : 6,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: const Color(0xFFE8EEF8)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: esMovil ? 32 : 36,
                    height: esMovil ? 32 : 36,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF3A56E4), Color(0xFF5C7CFA)],
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      inicial,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: esMovil ? 13.5 : 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: esMovil ? 110 : 160),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          nombreMostrar,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: esMovil ? 13 : 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E293B),
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          rolMostrar,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: esMovil ? 10 : 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF64748B),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    size: 16,
                    color: Color(0xFF94A3B8),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sidebar idéntico al web (`style1.css`: width 250px, fondo #222938, logo centrado).
class _Sidebar extends StatelessWidget {
  final List<_SeccionDef> secciones;
  final int indiceActual;
  final ValueChanged<int> onSeleccionar;
  final VoidCallback onCerrarSesion;
  final bool compacto;

  const _Sidebar({
    required this.secciones,
    required this.indiceActual,
    required this.onSeleccionar,
    required this.onCerrarSesion,
    this.compacto = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      decoration: const BoxDecoration(
        color: Color(0xFF222938),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 10,
            offset: Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              25,
              compacto ? 24 : 36,
              25,
              compacto ? 24 : 34,
            ),
            child: Center(
              child: Image.asset(
                'assets/img/logologin.png',
                height: compacto ? 90 : 115,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Text(
                  'SIGIF',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              children: [
                for (var i = 0; i < secciones.length; i++)
                  _itemMenu(
                    secciones[i],
                    i == indiceActual,
                    () => onSeleccionar(i),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(15),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onCerrarSesion,
                borderRadius: BorderRadius.circular(8),
                child: Ink(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFF56565), Color(0xFFC53030)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Cerrar sesión',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 14.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemMenu(
    _SeccionDef s,
    bool seleccionado,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            decoration: BoxDecoration(
              color: seleccionado
                  ? const Color(0xFF3A56E4)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              boxShadow: seleccionado
                  ? const [
                      BoxShadow(
                        color: Color(0x4D3A56E4),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  s.icono,
                  size: 19,
                  color: seleccionado
                      ? Colors.white
                      : const Color(0xFFA3B1CC),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    s.titulo,
                    style: TextStyle(
                      color: seleccionado
                          ? Colors.white
                          : const Color(0xFFA3B1CC),
                      fontSize: 15,
                      fontWeight:
                          seleccionado ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

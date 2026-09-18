import 'package:flutter/material.dart';

import '../../models/usuario.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../auditoria/auditoria_screen.dart';
import '../configuracion/configuracion_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../facturacion/facturacion_screen.dart';
import '../finanzas/finanzas_screen.dart';
import '../inventario/inventario_screen.dart';
import '../productos/productos_screen.dart';
import '../usuarios/usuarios_screen.dart';
import '../login_screen.dart';

class _SeccionDef {
  final String titulo;
  final IconData icono;
  final Widget pantalla;

  const _SeccionDef({
    required this.titulo,
    required this.icono,
    required this.pantalla,
  });
}

/// Cáscara principal de la app: sidebar (drawer) + topbar con perfil.
class AppShell extends StatefulWidget {
  final Usuario usuario;

  const AppShell({super.key, required this.usuario});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _indiceActual = 0;
  late final List<_SeccionDef> _secciones = _construirSecciones();

  List<_SeccionDef> _construirSecciones() {
    final u = widget.usuario;
    final esAdmin = u.cargo == 'SuperAdmin' || u.cargo == 'Admin';
    final base = <_SeccionDef>[
      const _SeccionDef(
          titulo: 'Dashboard',
          icono: Icons.dashboard_outlined,
          pantalla: DashboardScreen()),
      if (esAdmin)
        const _SeccionDef(
            titulo: 'Usuarios',
            icono: Icons.people_outline,
            pantalla: UsuariosScreen()),
      const _SeccionDef(
          titulo: 'Productos',
          icono: Icons.inventory_2_outlined,
          pantalla: ProductosScreen()),
      const _SeccionDef(
          titulo: 'Inventario',
          icono: Icons.warehouse_outlined,
          pantalla: InventarioScreen()),
      const _SeccionDef(
          titulo: 'Facturación',
          icono: Icons.point_of_sale_outlined,
          pantalla: FacturacionScreen()),
      const _SeccionDef(
          titulo: 'Finanzas',
          icono: Icons.account_balance_wallet_outlined,
          pantalla: FinanzasScreen()),
      if (esAdmin)
        const _SeccionDef(
            titulo: 'Auditoría',
            icono: Icons.history_outlined,
            pantalla: AuditoriaScreen()),
      if (esAdmin)
        const _SeccionDef(
            titulo: 'Configuración',
            icono: Icons.settings_outlined,
            pantalla: ConfiguracionScreen()),
    ];
    // IndexedStack necesita un índice estable: se ajusta si el actual se sale.
    if (_indiceActual >= base.length) _indiceActual = 0;
    return base;
  }

  Future<void> _cerrarSesion() async {
    final ok = await confirmar(
      context,
      titulo: 'Cerrar sesión',
      mensaje: '¿Deseas cerrar tu sesión de SIGIF?',
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ancho = constraints.maxWidth;
        final esAncho = ancho >= 900;
        final seccion = _secciones[_indiceActual];

        if (esAncho) {
          // Layout desktop: sidebar fija + contenido
          return Scaffold(
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Sidebar(
                  secciones: _secciones,
                  indiceActual: _indiceActual,
                  usuario: widget.usuario,
                  onSeleccionar: (i) => setState(() => _indiceActual = i),
                  onCerrarSesion: _cerrarSesion,
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(
                  child: Column(
                    children: [
                      _Topbar(
                        seccion: seccion,
                        esAncho: true,
                        onAbrirMenu: null,
                      ),
                      // Se reconstruye la pantalla al entrar para recargar datos.
                      Expanded(child: seccion.pantalla),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          drawer: _Sidebar(
            secciones: _secciones,
            indiceActual: _indiceActual,
            usuario: widget.usuario,
            onSeleccionar: (i) {
              setState(() => _indiceActual = i);
              Navigator.of(context).pop();
            },
            onCerrarSesion: _cerrarSesion,
          ),
          body: Column(
            children: [
              _Topbar(
                seccion: seccion,
                esAncho: false,
                onAbrirMenu: () => Scaffold.of(context).openDrawer(),
              ),
              Expanded(child: seccion.pantalla),
            ],
          ),
        );
      },
    );
  }
}

/// Barra superior con título de sección y perfil del usuario.
class _Topbar extends StatelessWidget {
  final _SeccionDef seccion;
  final bool esAncho;
  final VoidCallback? onAbrirMenu;

  const _Topbar({
    required this.seccion,
    required this.esAncho,
    required this.onAbrirMenu,
  });

  @override
  Widget build(BuildContext context) {
    final usuario = SessionService.instance.usuario;
    final rol = usuario?.cargo ?? '';

    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: ColoresSigif.tarjeta,
        border: Border(bottom: BorderSide(color: ColoresSigif.borde)),
      ),
      child: Row(
        children: [
          if (!esAncho) ...[
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: onAbrirMenu,
              tooltip: 'Menú',
            ),
            const SizedBox(width: 4),
          ],
          Icon(seccion.icono, color: ColoresSigif.azulPrimario, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              seccion.titulo,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (usuario != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: ColoresSigif.azulPrimario,
                  child: Text(
                    usuario.nombre.isNotEmpty ? usuario.nombre[0].toUpperCase() : '?',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(usuario.nombre,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                    Text(rol,
                        style: const TextStyle(
                            fontSize: 11, color: ColoresSigif.textoMitigado)),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Sidebar (drawer) replicando el estilo del web: fondo #222938.
class _Sidebar extends StatelessWidget {
  final List<_SeccionDef> secciones;
  final int indiceActual;
  final Usuario usuario;
  final ValueChanged<int> onSeleccionar;
  final VoidCallback onCerrarSesion;

  const _Sidebar({
    required this.secciones,
    required this.indiceActual,
    required this.usuario,
    required this.onSeleccionar,
    required this.onCerrarSesion,
  });

  @override
  Widget build(BuildContext context) {
    const ancho = 260.0;
    return Container(
      width: ancho,
      color: ColoresSigif.sidebarBg,
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              width: ancho,
              child: Column(
                children: [
                  // Marca
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            'assets/img/logo123.png',
                            width: 40,
                            height: 40,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const Icon(
                                Icons.storefront, color: Colors.white, size: 32),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'SIGIF',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Color(0xFF38404F), height: 1),
                  const SizedBox(height: 10),
                  // Menú
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      children: [
                        for (var i = 0; i < secciones.length; i++)
                          _itemMenu(secciones[i], i == indiceActual, () {
                            onSeleccionar(i);
                          }),
                      ],
                    ),
                  ),
                  const Divider(color: Color(0xFF38404F), height: 1),
                  // Usuario + cerrar sesión
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(
                              radius: 16,
                              backgroundColor: ColoresSigif.azulPrimario,
                              child: Icon(Icons.person, color: Colors.white, size: 18),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(usuario.nombre,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis),
                                  Text(usuario.cargo,
                                      style: const TextStyle(
                                          color: ColoresSigif.sidebarTexto,
                                          fontSize: 11)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: onCerrarSesion,
                            icon: const Icon(Icons.logout, size: 18),
                            label: const Text('Cerrar sesión'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: ColoresSigif.sidebarTexto,
                              side: const BorderSide(color: Color(0xFF38404F)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemMenu(_SeccionDef s, bool seleccionado, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: seleccionado ? ColoresSigif.azulPrimario : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(s.icono,
                    size: 20,
                    color: seleccionado ? Colors.white : ColoresSigif.sidebarTexto),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    s.titulo,
                    style: TextStyle(
                      color: seleccionado ? Colors.white : ColoresSigif.sidebarTexto,
                      fontSize: 14,
                      fontWeight: seleccionado ? FontWeight.w700 : FontWeight.w500,
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
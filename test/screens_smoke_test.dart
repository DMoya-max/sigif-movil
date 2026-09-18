import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sigif_flutter/core/constantes.dart';
import 'package:sigif_flutter/db/database.dart';
import 'package:sigif_flutter/db/repos/productos_repository.dart';
import 'package:sigif_flutter/screens/auditoria/auditoria_screen.dart';
import 'package:sigif_flutter/screens/configuracion/configuracion_screen.dart';
import 'package:sigif_flutter/screens/dashboard/dashboard_screen.dart';
import 'package:sigif_flutter/screens/facturacion/facturacion_screen.dart';
import 'package:sigif_flutter/screens/inventario/pos_screen.dart';
import 'package:sigif_flutter/screens/finanzas/finanzas_screen.dart';
import 'package:sigif_flutter/screens/finanzas/gasto_form_screen.dart';
import 'package:sigif_flutter/screens/home/app_shell.dart';
import 'package:sigif_flutter/screens/inventario/inventario_screen.dart';
import 'package:sigif_flutter/screens/inventario/registro_entrada_screen.dart';
import 'package:sigif_flutter/screens/login_screen.dart';
import 'package:sigif_flutter/screens/productos/producto_detalle_screen.dart';
import 'package:sigif_flutter/screens/productos/producto_form_screen.dart';
import 'package:sigif_flutter/screens/productos/productos_screen.dart';
import 'package:sigif_flutter/screens/usuarios/usuario_form_screen.dart';
import 'package:sigif_flutter/screens/usuarios/usuario_perfil_screen.dart';
import 'package:sigif_flutter/screens/usuarios/usuarios_screen.dart';
import 'package:sigif_flutter/services/auth_service.dart';
import 'package:sigif_flutter/theme/app_theme.dart';

/// Monta una pantalla emulando el contexto real: AppShell aporta el Scaffold,
/// así que las pantallas "de cuerpo" se prueban dentro de un Scaffold.
Future<void> _pumpPantalla(WidgetTester t, Widget w) async {
  await t.pumpWidget(w);
  for (var i = 0; i < 6; i++) {
    await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)));
    await t.pump(const Duration(milliseconds: 100));
  }
  final ex = t.takeException();
  expect(ex, isNull, reason: 'Excepción al construir la pantalla');
}

Widget _con(Widget pantalla) => MaterialApp(
      theme: AppTheme.tema(),
      home: Scaffold(body: pantalla),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fallidos = <String>[];

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    inicializarSqflite();
    await AppDatabase.instance.db;
    await SessionService.instance.iniciarSesion(
      Constantes.adminCorreo,
      Constantes.adminClave,
    );
  });

  tearDownAll(() {
    SessionService.instance.cerrarSesion();
  });

  testWidgets('pantallas de cuerpo se construyen sin excepciones',
      (tester) async {
    final pantallas = <String, Widget>{
      'Dashboard': const DashboardScreen(),
      'Productos': const ProductosScreen(),
      'Inventario': const InventarioScreen(),
      'RegistroEntrada': const RegistroEntradaScreen(),
      'Facturacion': const FacturacionScreen(),
      'Pos': const PosScreen(),
      'Finanzas': const FinanzasScreen(),
      'GastoForm': const GastoFormScreen(),
      'Usuarios': const UsuariosScreen(),
      'UsuarioForm': const UsuarioFormScreen(),
      'Auditoria': const AuditoriaScreen(),
      'Configuracion': const ConfiguracionScreen(),
      'Perfil': UsuarioPerfilScreen(usuario: SessionService.instance.usuario!),
    };

    final productos = await tester.runAsync(() async {
      final repo = await ProductosRepository.abrir();
      return repo.listar(soloActivos: true);
    });
    if (productos != null && productos.isNotEmpty) {
      pantallas['ProductoForm'] = ProductoFormScreen(producto: productos.first);
      pantallas['ProductoDetalle'] =
          ProductoDetalleScreen(producto: productos.first);
    }

    for (final nombre in pantallas.keys) {
      // ignore: avoid_print
      print('>>> Pantalla: $nombre');
      try {
        await _pumpPantalla(tester, _con(pantallas[nombre]!));
      } catch (e) {
        fallidos.add(nombre);
        // ignore: avoid_print
        print('FALLO $nombre: $e');
      }
    }

    expect(fallidos, isEmpty, reason: 'Pantallas que fallaron: $fallidos');
  });

  testWidgets('AuthScreen se construye sin excepciones', (tester) async {
    await _pumpPantalla(tester, const MaterialApp(home: LoginScreen()));
  });

  testWidgets('AppShell layout ANCHO (escritorio) sin excepciones',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpPantalla(
      tester,
      MaterialApp(
        theme: AppTheme.tema(),
        home: AppShell(usuario: SessionService.instance.usuario!),
      ),
    );
  });

  testWidgets('AppShell layout ANGOSTO (movil) sin excepciones',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpPantalla(
      tester,
      MaterialApp(
        theme: AppTheme.tema(),
        home: AppShell(usuario: SessionService.instance.usuario!),
      ),
    );
  });
}
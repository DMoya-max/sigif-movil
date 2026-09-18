import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sigif_flutter/core/constantes.dart';
import 'package:sigif_flutter/db/database.dart';
import 'package:sigif_flutter/db/repos/productos_repository.dart';
import 'package:sigif_flutter/screens/inventario/pos_screen.dart';
import 'package:sigif_flutter/services/auth_service.dart';
import 'package:sigif_flutter/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sufijo = DateTime.now().microsecondsSinceEpoch;
  final nombreActivo = '000POSACTIVO$sufijo';
  final nombreInactivo = '000POSINACTIVO$sufijo';

  Future<void> bombear(WidgetTester t) async {
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.tema(),
      home: const Scaffold(body: PosScreen()),
    ));
    for (var i = 0; i < 6; i++) {
      await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)));
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Finder botonAgregarDe(String nombre) => find.descendant(
        of: find.ancestor(of: find.text(nombre), matching: find.byType(Card)),
        matching: find.byType(FilledButton),
      );

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    inicializarSqflite();
    final repo = await ProductosRepository.abrir();
    await repo.crear(nombreActivo, 'General', precio: 1000, stock: 2);
    await repo.crear(nombreInactivo, 'General',
        precio: 500, stock: 5, activo: false);
    await SessionService.instance
        .iniciarSesion(Constantes.adminCorreo, Constantes.adminClave);
  });

  tearDownAll(() async {
    final db = await AppDatabase.instance.db;
    await db.delete('productos',
        where: 'nombre IN (?, ?)', whereArgs: [nombreActivo, nombreInactivo]);
    SessionService.instance.cerrarSesion();
  });

  testWidgets('un producto desactivado aparece y no se puede agregar',
      (tester) async {
    await bombear(tester);
    expect(find.text(nombreInactivo), findsOneWidget);
    final boton = tester.widget<FilledButton>(botonAgregarDe(nombreInactivo));
    expect(boton.onPressed, isNull);
  });

  testWidgets('el carrito no permite superar el stock disponible',
      (tester) async {
    await bombear(tester);
    for (var i = 0; i < 3; i++) {
      await tester.tap(botonAgregarDe(nombreActivo));
      await tester.pump();
    }
    expect(
      find.text('Solo hay 2 u. disponibles de "$nombreActivo".'),
      findsOneWidget,
    );
  });
}

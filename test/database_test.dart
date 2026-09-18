import 'package:flutter_test/flutter_test.dart';
import 'package:sigif_flutter/core/constantes.dart';
import 'package:sigif_flutter/db/database.dart';
import 'package:sigif_flutter/services/password_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('esquema y siembra inicial crean SuperAdmin, empresa y consumidor final',
      () async {
    final db = await AppDatabase.instance.db;

    final usuarios = await db.query('usuarios');
    expect(usuarios, isNotEmpty);
    final admin = usuarios.firstWhere(
      (u) => u['correo'] == Constantes.adminCorreo,
    );
    expect(admin['cargo'], Constantes.rolSuperAdmin);
    expect(admin['activo'], 1);
    expect(admin['es_superadmin_principal'], 1);
    expect(
      await PasswordService.verificar(Constantes.adminClave, admin['contra'] as String),
      isTrue,
    );

    final empresas = await db.query('empresa_config');
    expect(empresas.length, 1);

    final clientes = await db.query(
      'clientes',
      where: 'correo = ?',
      whereArgs: [Constantes.consumidorFinalCorreo],
    );
    expect(clientes, isNotEmpty);

    final tablas = await db
        .rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
    final nombres = tablas.map((t) => t['name']).toList();
    expect(nombres, containsAll([
      'usuarios',
      'productos',
      'clientes',
      'facturas',
      'detalle_factura',
      'entrada_inventario',
      'detalle_entrada_inventario',
      'gastos',
      'cuentas_por_pagar',
      'auditoria',
      'empresa_config',
    ]));
  });
}
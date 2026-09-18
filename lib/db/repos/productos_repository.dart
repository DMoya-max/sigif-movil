import 'package:sqflite/sqflite.dart';

import '../../core/sanitizacion.dart';
import '../../models/producto.dart';
import '../database.dart';

class ProductosRepository {
  final Database _db;
  ProductosRepository(this._db);

  static Future<ProductosRepository> abrir() async =>
      ProductosRepository(await AppDatabase.instance.db);

  Future<List<Producto>> listar({String? q, bool soloActivos = false}) async {
    final where = <String>[];
    final args = <Object?>[];
    final termino = q?.trim() ?? '';
    if (termino.isNotEmpty) {
      where.add('(nombre LIKE ? OR descripcion LIKE ? OR categoria LIKE ?)');
      args.addAll(['%$termino%', '%$termino%', '%$termino%']);
    }
    if (soloActivos) {
      where.add('activo = 1');
    }
    final filas = await _db.query(
      'productos',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: where.isEmpty ? null : args,
      orderBy: 'nombre',
    );
    return filas.map(Producto.desdeMapa).toList();
  }

  Future<List<Producto>> listarPaginado({
    String? q,
    int porPagina = 20,
    int pagina = 1,
  }) async {
    final where = <String>[];
    final args = <Object?>[];
    final termino = q?.trim() ?? '';
    if (termino.isNotEmpty) {
      where.add('(nombre LIKE ? OR descripcion LIKE ? OR categoria LIKE ?)');
      args.addAll(['%$termino%', '%$termino%', '%$termino%']);
    }
    final whereSql = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final limite = porPagina;
    final offset = (pagina - 1) * porPagina;
    final filas = await _db.rawQuery(
      'SELECT * FROM productos $whereSql ORDER BY nombre LIMIT ? OFFSET ?',
      [...args, limite, offset],
    );
    return filas.map(Producto.desdeMapa).toList();
  }

  Future<int> contar({String? q}) async {
    final termino = q?.trim() ?? '';
    if (termino.isEmpty) {
      return Sqflite.firstIntValue(await _db.rawQuery('SELECT COUNT(*) FROM productos')) ?? 0;
    }
    final filas = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM productos WHERE nombre LIKE ? OR descripcion LIKE ? OR categoria LIKE ?',
      ['%$termino%', '%$termino%', '%$termino%'],
    );
    return (filas.first['c'] as int?) ?? 0;
  }

  Future<Producto?> obtenerPorId(int id) async {
    final filas = await _db.query('productos', where: 'id = ?', whereArgs: [id], limit: 1);
    if (filas.isEmpty) return null;
    return Producto.desdeMapa(filas.first);
  }

  Future<Producto?> buscarPorNombre(String nombre) async {
    final filas = await _db.query(
      'productos',
      where: 'LOWER(nombre) = ? AND activo = 1',
      whereArgs: [nombre.trim().toLowerCase()],
      limit: 1,
    );
    if (filas.isEmpty) return null;
    return Producto.desdeMapa(filas.first);
  }

  Future<int> crear(
    String nombre,
    String categoria, {
    String? descripcion,
    required int precio,
    required int stock,
    bool activo = true,
  }) async {
    final ahora = DateTime.now();
    final p = Producto(
      nombre: Sanitizacion.limpiarNonNull(nombre),
      descripcion: Sanitizacion.limpiar(descripcion),
      precio: precio,
      stock: stock,
      categoria: Sanitizacion.limpiarNonNull(categoria),
      activo: activo,
      fechaCreacion: ahora,
      fechaActualizacion: ahora,
    );
    return _db.insert('productos', p.aMap()..remove('id'));
  }

  Future<int> actualizar(
    int id, {
    required String nombre,
    required String categoria,
    String? descripcion,
    required int precio,
    int? stock,
    bool? activo,
  }) async {
    final actual = await obtenerPorId(id);
    if (actual == null) return 0;
    final nuevo = Producto(
      id: id,
      nombre: Sanitizacion.limpiarNonNull(nombre),
      descripcion: Sanitizacion.limpiar(descripcion),
      precio: precio,
      stock: stock ?? actual.stock,
      categoria: Sanitizacion.limpiarNonNull(categoria),
      activo: activo ?? actual.activo,
      fechaCreacion: actual.fechaCreacion,
      fechaActualizacion: DateTime.now(),
    );
    return _db.update('productos', nuevo.aMap(), where: 'id = ?', whereArgs: [id]);
  }

  Future<void> activarDesactivar(int id, bool activo) async =>
      _db.update('productos', {'activo': activo ? 1 : 0, 'fecha_actualizacion': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [id]);

  Future<void> decrementarStock(int id, int cantidad) async {
    await _db.rawUpdate(
      'UPDATE productos SET stock = stock - ?, fecha_actualizacion = ? WHERE id = ?',
      [cantidad, DateTime.now().toIso8601String(), id],
    );
  }

  Future<void> incrementarStock(int id, int cantidad) async =>
      _db.rawUpdate('UPDATE productos SET stock = stock + ?, fecha_actualizacion = ? WHERE id = ?', [cantidad, DateTime.now().toIso8601String(), id]);

  Future<int> contarActivos() async => Sqflite.firstIntValue(
        await _db.rawQuery('SELECT COUNT(*) FROM productos WHERE activo = 1'),
      ) ??
      0;

  Future<int> contarStockBajo() async => Sqflite.firstIntValue(
        await _db.rawQuery('SELECT COUNT(*) FROM productos WHERE activo = 1 AND stock > 0 AND stock < 5'),
      ) ??
      0;

  Future<int> contarAgotados() async => Sqflite.firstIntValue(
        await _db.rawQuery('SELECT COUNT(*) FROM productos WHERE activo = 1 AND stock = 0'),
      ) ??
      0;
}
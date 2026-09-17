import 'package:sqflite/sqflite.dart';

import '../../core/sanitizacion.dart';
import '../../models/gasto.dart';
import '../database.dart';
import 'auditoria_repository.dart';

class GastosRepository {
  final Database _db;
  GastosRepository(this._db);

  static Future<GastosRepository> abrir() async =>
      GastosRepository(await AppDatabase.instance.db);

  Future<List<Gasto>> listar({
    DateTime? inicio,
    DateTime? fin,
    String? categoria,
    String? metodoPago,
  }) async {
    final cond = <String>[];
    final args = <Object?>[];
    if (inicio != null && fin != null) {
      cond.add('fecha >= ? AND fecha <= ?');
      args.add(_iso(inicio));
      args.add(_iso(fin));
    }
    if (categoria != null && categoria.isNotEmpty) {
      cond.add('categoria = ?');
      args.add(categoria);
    }
    if (metodoPago != null && metodoPago.isNotEmpty) {
      cond.add('metodo_pago = ?');
      args.add(metodoPago);
    }
    final where = cond.isEmpty ? null : cond.join(' AND ');
    final filas = await _db.query('gastos',
        where: where, whereArgs: cond.isEmpty ? null : args, orderBy: 'fecha DESC, id DESC');
    return filas.map(Gasto.desdeMapa).toList();
  }

  Future<Gasto?> obtenerPorId(int id) async {
    final filas = await _db.query('gastos', where: 'id = ?', whereArgs: [id], limit: 1);
    if (filas.isEmpty) return null;
    return Gasto.desdeMapa(filas.first);
  }

  Future<int> crear({
    required String concepto,
    required String categoria,
    required double valor,
    required DateTime fecha,
    String metodoPago = 'EFECTIVO',
    String proveedor = '',
    String descripcion = '',
    required String usuario,
  }) async {
    return _db.insert('gastos', {
      'concepto': Sanitizacion.limpiarNonNull(concepto),
      'categoria': categoria,
      'valor': valor,
      'fecha': _iso(fecha),
      'metodo_pago': metodoPago,
      'proveedor': Sanitizacion.limpiarNonNull(proveedor),
      'descripcion': Sanitizacion.limpiarNonNull(descripcion),
      'usuario': usuario,
      'creado_en': DateTime.now().toIso8601String(),
    });
  }

  Future<int> actualizar(Gasto gasto) async {
    return _db.update('gastos', {
      'concepto': Sanitizacion.limpiarNonNull(gasto.concepto),
      'categoria': gasto.categoria,
      'valor': gasto.valor,
      'fecha': _iso(gasto.fecha),
      'metodo_pago': gasto.metodoPago,
      'proveedor': Sanitizacion.limpiarNonNull(gasto.proveedor),
      'descripcion': Sanitizacion.limpiarNonNull(gasto.descripcion),
    }, where: 'id = ?', whereArgs: [gasto.id]);
  }

  Future<void> eliminar(int id) => _db.delete('gastos', where: 'id = ?', whereArgs: [id]);

  /// Registra auditoría de gastos.
  Future<void> auditar(String usuario, String accion) async {
    final aud = AuditoriaRepository(_db);
    await aud.registrar(usuario: usuario, accion: accion, modulo: 'FINANZAS');
  }

  /// Total de gastos en el periodo, agrupado por categoría.
  Future<List<Map<String, Object?>>> resumenPorCategoria(DateTime inicio, DateTime fin) async {
    return _db.rawQuery(
      'SELECT categoria, SUM(valor) AS total, COUNT(*) AS cantidad '
      'FROM gastos WHERE fecha >= ? AND fecha <= ? GROUP BY categoria ORDER BY total DESC',
      [_iso(inicio), _iso(fin)],
    );
  }

  Future<double> totalEnRango(DateTime inicio, DateTime fin) async {
    final filas = await _db.rawQuery(
      'SELECT COALESCE(SUM(valor), 0) AS t FROM gastos WHERE fecha >= ? AND fecha <= ?',
      [_iso(inicio), _iso(fin)],
    );
    return (filas.first['t'] as num?)?.toDouble() ?? 0;
  }

  Future<double> totalEfectivo(DateTime inicio, DateTime fin) async {
    final filas = await _db.rawQuery(
      "SELECT COALESCE(SUM(valor), 0) AS t FROM gastos WHERE fecha >= ? AND fecha <= ? AND metodo_pago = 'EFECTIVO'",
      [_iso(inicio), _iso(fin)],
    );
    return (filas.first['t'] as num?)?.toDouble() ?? 0;
  }

  Future<int> contar() async =>
      Sqflite.firstIntValue(await _db.rawQuery('SELECT COUNT(*) FROM gastos')) ?? 0;

  static String _iso(DateTime fecha) {
    final l = fecha.toLocal();
    return '${l.year.toString().padLeft(4, '0')}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
  }
}
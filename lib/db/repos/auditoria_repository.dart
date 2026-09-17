import 'package:sqflite/sqflite.dart';

import '../../models/auditoria.dart';
import '../database.dart';

class AuditoriaRepository {
  final Database _db;
  AuditoriaRepository(this._db);

  static Future<AuditoriaRepository> abrir() async =>
      AuditoriaRepository(await AppDatabase.instance.db);

  Future<int> registrar({
    required String usuario,
    required String accion,
    required String modulo,
  }) async {
    return _db.insert('auditoria', {
      'usuario': usuario,
      'accion': accion,
      'modulo': modulo,
      'fecha': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Auditoria>> listar({
    String? modulo,
    String? usuario,
    String? accion,
    DateTime? fechaDesde,
    DateTime? fechaHasta,
    int limite = 200,
  }) async {
    final cond = <String>[];
    final args = <Object?>[];
    if (modulo != null && modulo.isNotEmpty) {
      cond.add('modulo = ?');
      args.add(modulo);
    }
    if (usuario != null && usuario.trim().isNotEmpty) {
      cond.add('usuario LIKE ?');
      args.add('%${usuario.trim()}%');
    }
    if (accion != null && accion.trim().isNotEmpty) {
      cond.add('accion LIKE ?');
      args.add('%${accion.trim()}%');
    }
    if (fechaDesde != null) {
      cond.add('fecha >= ?');
      args.add(fechaDesde.toIso8601String());
    }
    if (fechaHasta != null) {
      final hasta = DateTime(fechaHasta.year, fechaHasta.month, fechaHasta.day, 23, 59, 59);
      cond.add('fecha <= ?');
      args.add(hasta.toIso8601String());
    }
    final where = cond.isEmpty ? null : cond.join(' AND ');
    final filas = await _db.query(
      'auditoria',
      where: where,
      whereArgs: cond.isEmpty ? null : args,
      orderBy: 'fecha DESC',
      limit: limite,
    );
    return filas.map(Auditoria.desdeMapa).toList();
  }

  /// Últimos `n` registros (Dashboard: actividad reciente).
  Future<List<Auditoria>> recientes(int n) async {
    final filas = await _db.query('auditoria', orderBy: 'fecha DESC', limit: n);
    return filas.map(Auditoria.desdeMapa).toList();
  }

  Future<int> contar() async =>
      Sqflite.firstIntValue(await _db.rawQuery('SELECT COUNT(*) FROM auditoria')) ?? 0;
}
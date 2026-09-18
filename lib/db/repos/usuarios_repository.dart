import 'package:sqflite/sqflite.dart';

import '../../models/usuario.dart';
import '../database.dart';

class UsuariosRepository {
  final Database _db;
  UsuariosRepository(this._db);

  static Future<UsuariosRepository> abrir() async =>
      UsuariosRepository(await AppDatabase.instance.db);

  Future<List<Usuario>> listar({String? q}) async {
    var where = '';
    final args = <Object?>[];
    final termino = q?.trim() ?? '';
    if (termino.isNotEmpty) {
      where = 'WHERE nombre LIKE ? OR cargo LIKE ? OR telefono LIKE ? OR correo LIKE ?';
      args.addAll(['%$termino%', '%$termino%', '%$termino%', '%$termino%']);
    }
    final filas = await _db.query(
      'usuarios',
      where: where.isEmpty ? null : where,
      whereArgs: where.isEmpty ? null : args,
      orderBy: 'nombre',
    );
    return filas.map(Usuario.desdeMapa).toList();
  }

  Future<Usuario?> obtenerPorId(int id) async {
    final filas = await _db.query('usuarios', where: 'id = ?', whereArgs: [id], limit: 1);
    if (filas.isEmpty) return null;
    return Usuario.desdeMapa(filas.first);
  }

  Future<Usuario?> buscarPorCorreo(String correo) async {
    final filas = await _db.query(
      'usuarios',
      where: 'LOWER(correo) = ?',
      whereArgs: [correo.trim().toLowerCase()],
      limit: 1,
    );
    if (filas.isEmpty) return null;
    return Usuario.desdeMapa(filas.first);
  }

  Future<bool> existeDocumento(String documento, {int? excluirId}) async {
    final filas = excluirId == null
        ? await _db.query('usuarios', where: 'documento = ?', whereArgs: [documento], limit: 1)
        : await _db.query('usuarios',
            where: 'documento = ? AND id != ?', whereArgs: [documento, excluirId], limit: 1);
    return filas.isNotEmpty;
  }

  Future<bool> existeTelefono(String telefono, {int? excluirId}) async {
    final filas = excluirId == null
        ? await _db.query('usuarios', where: 'telefono = ?', whereArgs: [telefono], limit: 1)
        : await _db.query('usuarios',
            where: 'telefono = ? AND id != ?', whereArgs: [telefono, excluirId], limit: 1);
    return filas.isNotEmpty;
  }

  Future<bool> existeCorreo(String correo, {int? excluirId}) async {
    final c = correo.trim().toLowerCase();
    final filas = excluirId == null
        ? await _db.query('usuarios', where: 'LOWER(correo) = ?', whereArgs: [c], limit: 1)
        : await _db.query('usuarios',
            where: 'LOWER(correo) = ? AND id != ?', whereArgs: [c, excluirId], limit: 1);
    return filas.isNotEmpty;
  }

  Future<int> crear(Usuario usuario) async =>
      _db.insert('usuarios', usuario.aMap()..remove('id'));

  Future<int> actualizar(Usuario usuario) async =>
      _db.update('usuarios', usuario.aMap(), where: 'id = ?', whereArgs: [usuario.id]);

  Future<void> cambiarEstado(int id, bool activo) async =>
      _db.update('usuarios', {'activo': activo ? 1 : 0}, where: 'id = ?', whereArgs: [id]);

  Future<int> contar() async => Sqflite.firstIntValue(
        await _db.rawQuery('SELECT COUNT(*) FROM usuarios'),
      ) ??
      0;
}
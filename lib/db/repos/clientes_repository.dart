import 'package:sqflite/sqflite.dart';

import '../../core/sanitizacion.dart';
import '../../models/cliente.dart' show Cliente;
import '../../models/factura.dart';
import '../database.dart';

class ClientesRepository {
  final Database _db;
  ClientesRepository(this._db);

  static Future<ClientesRepository> abrir() async =>
      ClientesRepository(await AppDatabase.instance.db);

  Future<List<Cliente>> listar({String? q}) async {
    final termino = q?.trim() ?? '';
    if (termino.isEmpty) {
      final filas = await _db.query('clientes', orderBy: 'nombre');
      return filas.map(Cliente.desdeMapa).toList();
    }
    final filas = await _db.query(
      'clientes',
      where: 'nombre LIKE ? OR correo LIKE ?',
      whereArgs: ['%$termino%', '%$termino%'],
      orderBy: 'nombre',
    );
    return filas.map(Cliente.desdeMapa).toList();
  }

  Future<Cliente?> obtenerPorId(int id) async {
    final filas = await _db.query('clientes', where: 'id = ?', whereArgs: [id], limit: 1);
    if (filas.isEmpty) return null;
    return Cliente.desdeMapa(filas.first);
  }

  Future<Cliente?> buscarPorCorreo(String correo) async {
    final filas = await _db.query(
      'clientes',
      where: 'LOWER(correo) = ?',
      whereArgs: [correo.trim().toLowerCase()],
      limit: 1,
    );
    if (filas.isEmpty) return null;
    return Cliente.desdeMapa(filas.first);
  }

  /// get_or_create(cliente) — retorna (cliente, creado).
  Future<(Cliente, bool)> obtenerOCrear({
    int? clienteId,
    String? nombre,
    String? correo,
  }) async {
    if (clienteId != null) {
      final c = await obtenerPorId(clienteId);
      if (c != null) return (c, false);
      throw Exception('El cliente seleccionado no existe');
    }

    if (correo != null && correo.trim().isNotEmpty) {
      final existente = await buscarPorCorreo(correo);
      if (existente != null) return (existente, false);
      final id = await crear(nombre ?? 'Cliente general', correo.trim().toLowerCase());
      final nuevo = await obtenerPorId(id);
      return (nuevo!, true);
    }

    final consumidor = await buscarPorCorreo('consumidorfinal@pos.com');
    if (consumidor != null) return (consumidor, false);
    final id = await crear('Consumidor Final', 'consumidorfinal@pos.com');
    return ((await obtenerPorId(id))!, true);
  }

  Future<int> crear(String nombre, String correo) => _db.insert('clientes', {
        'nombre': Sanitizacion.limpiarNonNull(nombre),
        'correo': correo.trim().toLowerCase(),
      });

  Future<int> actualizar(Cliente cliente) =>
      _db.update('clientes', {
        'nombre': Sanitizacion.limpiarNonNull(cliente.nombre),
        'correo': cliente.correo.trim().toLowerCase(),
      }, where: 'id = ?', whereArgs: [cliente.id]);

  /// Total gastado por un cliente (Sum de factura.total).
  Future<double> totalGastado(int clienteId) async {
    final filas = await _db.rawQuery(
      'SELECT COALESCE(SUM(total), 0) AS t FROM facturas WHERE cliente_id = ?',
      [clienteId],
    );
    return (filas.first['t'] as num?)?.toDouble() ?? 0;
  }

  /// Última fecha de compra del cliente o null.
  Future<DateTime?> ultimaFecha(int clienteId) async {
    final filas = await _db.rawQuery(
      'SELECT fecha FROM facturas WHERE cliente_id = ? ORDER BY fecha DESC LIMIT 1',
      [clienteId],
    );
    if (filas.isEmpty) return null;
    return DateTime.tryParse(filas.first['fecha'] as String);
  }

  /// Facturas de un cliente con sus detalles.
  Future<List<Factura>> facturasDe(int clienteId) async {
    final filas = await _db.query('facturas', where: 'cliente_id = ?', whereArgs: [clienteId], orderBy: 'fecha DESC');
    return filas.map(Factura.desdeMapa).toList();
  }
}
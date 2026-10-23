import 'package:sqflite/sqflite.dart';

import '../db/database.dart';
import '../models/producto.dart';
import 'api_client.dart';
import 'api_config.dart';

/// Servicio REST para el módulo de Productos (`https://sigif-final.vercel.app/api/productos/`).
/// Implementa operaciones CRUD: GET (listar/obtener), POST (crear), PUT (actualizar) y DELETE (eliminar).
class ProductosApiService {
  ProductosApiService._();
  static final ProductosApiService instance = ProductosApiService._();

  final ApiClient _api = ApiClient.instance;

  /// GET: Obtiene todos los productos desde `/api/productos/`.
  Future<List<Producto>> listar({String? q}) async {
    List<Producto> lista = [];
    try {
      final rawList = await _api.getList(ApiConfig.productosEndpoint);
      lista = rawList.map(Producto.fromJson).toList();

      final db = await AppDatabase.instance.db;
      await db.delete('productos');
      for (final p in lista) {
        await _guardarEnCacheLocal(db, p);
      }
    } catch (e) {
      final db = await AppDatabase.instance.db;
      final filas = await db.query('productos', orderBy: 'id DESC');
      lista = filas.map(Producto.desdeMapa).toList();
    }

    final termino = q?.trim().toLowerCase() ?? '';
    if (termino.isNotEmpty) {
      lista = lista.where((p) {
        final desc = p.descripcion?.toLowerCase() ?? '';
        return p.nombre.toLowerCase().contains(termino) ||
            desc.contains(termino) ||
            p.categoria.toLowerCase().contains(termino);
      }).toList();
    }

    return lista;
  }

  /// GET: Obtiene un producto por su ID desde `/api/productos/{id}/`.
  Future<Producto?> obtenerPorId(int id) async {
    try {
      final json = await _api.getMap('${ApiConfig.productosEndpoint}$id/');
      return Producto.fromJson(json);
    } catch (_) {
      final db = await AppDatabase.instance.db;
      final filas = await db.query(
        'productos',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (filas.isEmpty) return null;
      return Producto.desdeMapa(filas.first);
    }
  }

  /// POST: Crea un producto mediante `POST /api/productos/`.
  Future<Producto> crear(Producto producto) async {
    try {
      final payload = producto.toJson();
      final creadoJson =
          await _api.postMap(ApiConfig.productosEndpoint, payload);
      final creado = Producto.fromJson(creadoJson);
      final db = await AppDatabase.instance.db;
      await _guardarEnCacheLocal(db, creado);
      return creado;
    } catch (e) {
      rethrow;
    }
  }

  /// PUT: Actualiza un producto existente mediante `PUT /api/productos/{id}/`.
  Future<Producto> actualizar(Producto producto) async {
    final id = producto.id;
    if (id == null) {
      throw const ApiException('El producto a editar no tiene un ID válido.');
    }
    try {
      final payload = producto.toJson();
      final actualizadoJson = await _api.putMap(
        '${ApiConfig.productosEndpoint}$id/',
        payload,
      );
      final actualizado = Producto.fromJson(actualizadoJson);
      final db = await AppDatabase.instance.db;
      await _guardarEnCacheLocal(db, actualizado);
      return actualizado;
    } catch (e) {
      rethrow;
    }
  }

  /// Cambia el estado activo/inactivo de un producto mediante `PUT /api/productos/{id}/`.
  Future<Producto> cambiarEstado(Producto producto, bool activo) async {
    return actualizar(producto.copyWith(activo: activo));
  }

  /// DELETE: Elimina un producto mediante `DELETE /api/productos/{id}/`.
  Future<void> eliminar(int id) async {
    try {
      await _api.delete('${ApiConfig.productosEndpoint}$id/');
      final db = await AppDatabase.instance.db;
      await db.delete('productos', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _guardarEnCacheLocal(Database db, Producto p) async {
    if (p.id == null) return;
    await db.insert(
      'productos',
      p.aMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

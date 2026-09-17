import 'package:sqflite/sqflite.dart';

import '../../core/sanitizacion.dart';
import '../../models/inventario.dart';
import '../../models/producto.dart';
import '../database.dart';
import 'auditoria_repository.dart';
import 'productos_repository.dart';

/// Resultado de un registro de entrada (equivale a la respuesta de
/// `registrar_entrada` en el backend Django).
class ResultadoEntrada {
  final bool success;
  final String message;
  final int? entradaId;

  const ResultadoEntrada.success(this.message, this.entradaId) : success = true;
  const ResultadoEntrada.error(this.message)
      : success = false,
        entradaId = null;
}

class InventarioRepository {
  final Database _db;
  InventarioRepository(this._db);

  static Future<InventarioRepository> abrir() async =>
      InventarioRepository(await AppDatabase.instance.db);

  Future<List<EntradaInventario>> listarEntradas() async {
    final filas = await _db.query('entrada_inventario', orderBy: 'fecha DESC');
    return filas.map(EntradaInventario.desdeMapa).toList();
  }

  Future<List<DetalleEntradaInventario>> detallesDe(int entradaId) async {
    final filas = await _db.query('detalle_entrada_inventario',
        where: 'entrada_id = ?', whereArgs: [entradaId], orderBy: 'id');
    return filas.map(DetalleEntradaInventario.desdeMapa).toList();
  }

  Future<List<Map<String, Object?>>> detallesConProducto(int entradaId) async {
    return _db.rawQuery(
      'SELECT d.*, p.nombre AS producto_nombre FROM detalle_entrada_inventario d '
      'JOIN productos p ON p.id = d.producto_id WHERE d.entrada_id = ? ORDER BY d.id',
      [entradaId],
    );
  }

  Future<EntradaInventario?> obtenerEntrada(int id) async {
    final filas = await _db.query('entrada_inventario', where: 'id = ?', whereArgs: [id], limit: 1);
    if (filas.isEmpty) return null;
    return EntradaInventario.desdeMapa(filas.first);
  }

  /// Registro de una entrada al inventario (crea entrada, actualiza stock,
  /// registra detalle, crea Gasto REPUESTOS y audita).
  Future<ResultadoEntrada> registrarEntrada({
    required String proveedor,
    String? documento,
    String? observaciones,
    required String nombreUsuario,
    required List<Map<String, Object?>> items,
  }) async {
    final errores = <String>[];
    final proveedorLimpio = proveedor.trim();

    if (proveedorLimpio.isEmpty) {
      errores.add('El proveedor es obligatorio.');
    } else if (proveedorLimpio.length > 150) {
      errores.add('El nombre del proveedor es demasiado largo.');
    }

    if (items.isEmpty) {
      errores.add('Debes agregar al menos un producto a la entrada.');
    }

    final itemsValidos = <Map<String, Object?>>[];
    final prodRepo = ProductosRepository(_db);

    for (var idx = 0; idx < items.length; idx++) {
      final item = items[idx];
      final n = idx + 1;
      final productoId = item['producto_id'] as int?;
      final nombre = ((item['nombre'] as String?) ?? '').trim();
      final categoria = ((item['categoria'] as String?) ?? '').trim();
      final descripcion = ((item['descripcion'] as String?) ?? '').trim();
      final activo = (item['activo'] as bool?) ?? true;

      final precioVenta = item['precio_venta'] is num
          ? (item['precio_venta'] as num).toInt()
          : (int.tryParse('${item['precio_venta'] ?? ''}') ?? -1);
      final cantidad = item['cantidad'] is int
          ? item['cantidad'] as int
          : (int.tryParse('${item['cantidad'] ?? ''}') ?? -1);
      final precio = item['precio'] is num
          ? (item['precio'] as num).toInt()
          : (int.tryParse('${item['precio'] ?? ''}') ?? -1);

      if (cantidad <= 0) {
        errores.add('Producto $n: la cantidad debe ser mayor a cero.');
        continue;
      }
      if (cantidad > 100000) {
        errores.add('Producto $n: la cantidad es demasiado grande.');
        continue;
      }
      if (precio <= 0) {
        errores.add('Producto $n: el precio debe ser mayor a cero.');
        continue;
      }
      if (precioVenta <= 0) {
        errores.add('Producto $n: el precio de venta debe ser mayor a cero.');
        continue;
      }
      if (precioVenta < precio) {
        errores.add('Producto $n: el precio de venta no puede ser menor al precio de compra.');
        continue;
      }

      Producto productos;
      if (productoId != null) {
        final existente = await prodRepo.obtenerPorId(productoId);
        if (existente == null || !existente.activo) {
          errores.add('Producto $n: el producto seleccionado no existe.');
          continue;
        }
        productos = existente;
      } else {
        if (nombre.isEmpty) {
          errores.add('Producto $n: el nombre es obligatorio para un producto nuevo.');
          continue;
        }
        if (nombre.length > 100) {
          errores.add('Producto $n: el nombre es demasiado largo.');
          continue;
        }
        if (categoria.isEmpty) {
          errores.add('Producto $n: la categoría es obligatoria para un producto nuevo.');
          continue;
        }
        final duplicado = await prodRepo.buscarPorNombre(nombre);
        if (duplicado != null) {
          errores.add(
              "Producto $n: ya existe un producto llamado '$nombre'. Selecciónalo de la lista en lugar de crearlo de nuevo.");
          continue;
        }
        productos = Producto(
          nombre: Sanitizacion.limpiarNonNull(nombre),
          categoria: Sanitizacion.limpiarNonNull(categoria),
          descripcion: Sanitizacion.limpiar(descripcion),
          precio: precioVenta,
          stock: 0,
          activo: activo,
          fechaCreacion: DateTime.now(),
          fechaActualizacion: DateTime.now(),
        );
      }

      itemsValidos.add({
        'producto': productos,
        'cantidad': cantidad,
        'precio': precio,
        'precio_venta': precioVenta,
        'subtotal': precio * cantidad,
      });
    }

    if (errores.isNotEmpty) {
      return ResultadoEntrada.error(errores.join(' '));
    }

    try {
      final entradaId = await _db.transaction((txn) async {
        final total = itemsValidos.fold<int>(0, (acc, i) => acc + (i['subtotal'] as int));
        final id = await txn.insert('entrada_inventario', {
          'proveedor': Sanitizacion.limpiarNonNull(proveedorLimpio),
          'documento': Sanitizacion.limpiar((documento ?? '').trim()),
          'usuario': nombreUsuario.isNotEmpty ? nombreUsuario : 'Usuario',
          'observaciones': Sanitizacion.limpiar((observaciones ?? '').trim()),
          'fecha': DateTime.now().toIso8601String(),
          'total': total.toDouble(),
        });

        for (final item in itemsValidos) {
          final prod = item['producto'] as Producto;
          final cantidad = item['cantidad'] as int;
          final precioV = item['precio_venta'] as int;

          if (prod.id == null) {
            final nuevoId = await txn.insert('productos', {
              'nombre': prod.nombre,
              'descripcion': prod.descripcion,
              'precio': precioV,
              'stock': cantidad,
              'categoria': prod.categoria,
              'activo': prod.activo ? 1 : 0,
              'fecha_creacion': DateTime.now().toIso8601String(),
              'fecha_actualizacion': DateTime.now().toIso8601String(),
            });
            await txn.insert('detalle_entrada_inventario', {
              'entrada_id': id,
              'producto_id': nuevoId,
              'cantidad': cantidad,
              'precio': item['precio'],
              'subtotal': item['subtotal'],
            });
          } else {
            await txn.rawUpdate(
              'UPDATE productos SET precio = ?, stock = stock + ?, fecha_actualizacion = ? WHERE id = ?',
              [precioV, cantidad, DateTime.now().toIso8601String(), prod.id],
            );
            await txn.insert('detalle_entrada_inventario', {
              'entrada_id': id,
              'producto_id': prod.id,
              'cantidad': cantidad,
              'precio': item['precio'],
              'subtotal': item['subtotal'],
            });
          }
        }

        // Crear el Gasto de compra de inventario (categoría REPUESTOS)
        final numero = 'ENT-${id.toString().padLeft(5, '0')}';
        await txn.insert('gastos', {
          'concepto': 'Compra de inventario $numero',
          'categoria': 'REPUESTOS',
          'valor': total.toDouble(),
          'fecha': DateTime.now().toIso8601String().split('T').first,
          'metodo_pago': 'EFECTIVO',
          'proveedor': Sanitizacion.limpiarNonNull(proveedorLimpio),
          'descripcion':
              'Entrada de productos registrada con ${(documento ?? '').trim().isEmpty ? 'sin documento' : documento}.',
          'usuario': nombreUsuario.isNotEmpty ? nombreUsuario : 'Usuario',
          'creado_en': DateTime.now().toIso8601String(),
        });

        return id;
      });

      final numero = 'ENT-${entradaId.toString().padLeft(5, '0')}';
      final aud = AuditoriaRepository(_db);
      await aud.registrar(
        usuario: nombreUsuario.isNotEmpty ? nombreUsuario : 'Usuario',
        accion: 'REGISTRO UNA ENTRADA AL INVENTARIO $numero (proveedor: ${proveedorLimpio})',
        modulo: 'INVENTARIO',
      );

      return ResultadoEntrada.success(
        'Entrada $numero registrada correctamente. Stock actualizado.',
        entradaId,
      );
    } catch (e) {
      return const ResultadoEntrada.error('Ocurrió un error al registrar la entrada.');
    }
  }

  /// Costo unitario sugerido: último precio de compra del producto.
  Future<int?> precioCompraReciente(int productoId) async {
    final filas = await _db.rawQuery(
      'SELECT precio FROM detalle_entrada_inventario WHERE producto_id = ? ORDER BY entrada_id DESC LIMIT 1',
      [productoId],
    );
    if (filas.isEmpty) return null;
    return filas.first['precio'] as int?;
  }

  /// Consulta compras por producto (para costos en finanzas).
  Future<List<Map<String, Object?>>> comprasPorProducto(List<int> ids) async {
    if (ids.isEmpty) return [];
    final lugar = List.filled(ids.length, '?').join(',');
    return _db.rawQuery(
      'SELECT d.producto_id, d.precio, d.cantidad, e.fecha '
      'FROM detalle_entrada_inventario d JOIN entrada_inventario e ON e.id = d.entrada_id '
      'WHERE d.producto_id IN ($lugar) ORDER BY d.producto_id, e.fecha DESC, d.id DESC',
      ids,
    );
  }
}
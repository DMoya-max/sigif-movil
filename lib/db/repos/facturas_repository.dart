import 'package:sqflite/sqflite.dart';

import '../../core/descuentos.dart';
import '../../core/formato.dart';
import '../../core/sanitizacion.dart';
import '../../models/factura.dart';
import '../../models/producto.dart';
import '../database.dart';
import 'auditoria_repository.dart';
import 'clientes_repository.dart';
import 'productos_repository.dart';

/// Resultado de una venta confirmada (equivale a la respuesta JSON del
/// endpoint Django `confirmar_venta`).
class ResultadoVenta {
  final bool success;
  final String message;
  final int? facturaId;

  const ResultadoVenta.success(this.message, this.facturaId)
      : success = true;
  const ResultadoVenta.error(this.message)
      : success = false,
        facturaId = null;
}

class FacturasRepository {
  final Database _db;
  FacturasRepository(this._db);

  static Future<FacturasRepository> abrir() async =>
      FacturasRepository(await AppDatabase.instance.db);

  Future<List<Factura>> listar({String? nombreEmpleado, String? q}) async {
    final cond = <String>[];
    final args = <Object?>[];
    if (nombreEmpleado != null) {
      cond.add('usuario = ?');
      args.add(nombreEmpleado);
    }
    final termino = q?.trim() ?? '';
    if (termino.isNotEmpty) {
      cond.add('(usuario LIKE ? OR CAST(id AS TEXT) LIKE ?)');
      args.addAll(['%$termino%', '%$termino%']);
    }
    final where = cond.isEmpty ? null : cond.join(' AND ');
    final filas = await _db.query(
      'facturas',
      where: where,
      whereArgs: cond.isEmpty ? null : args,
      orderBy: 'fecha DESC',
    );
    return filas.map(Factura.desdeMapa).toList();
  }

  Future<Factura?> obtenerPorId(int id) async {
    final filas = await _db.query('facturas', where: 'id = ?', whereArgs: [id], limit: 1);
    if (filas.isEmpty) return null;
    return Factura.desdeMapa(filas.first);
  }

  Future<List<DetalleFactura>> detallesDe(int facturaId) async {
    final filas = await _db.query('detalle_factura', where: 'factura_id = ?', whereArgs: [facturaId], orderBy: 'id');
    return filas.map(DetalleFactura.desdeMapa).toList();
  }

  /// Detalle con nombre del producto (para PDFs y listados).
  Future<List<Map<String, Object?>>> detallesConProducto(int facturaId) async {
    return _db.rawQuery(
      'SELECT df.*, p.nombre AS producto_nombre FROM detalle_factura df '
      'JOIN productos p ON p.id = df.producto_id '
      'WHERE df.factura_id = ? ORDER BY df.id',
      [facturaId],
    );
  }

  /// Confirmación de venta (POS). Replica exacta de la lógica del backend:
  /// valida stock/precio/activo, aplica descuento por código, resuelve el
  /// cliente, crea factura + detalles, decrementa stock y audita.
  Future<ResultadoVenta> confirmarVenta({
    required List<Map<String, Object?>> productos,
    required String nombreUsuario,
    int? clienteId,
    String? nombreCliente,
    String? correoCliente,
    String codigoDescuento = '',
    String metodoPago = 'EFECTIVO',
    DateTime? fechaVencimiento,
  }) async {
    if (productos.isEmpty) {
      return const ResultadoVenta.error('El carrito está vacío');
    }

    final nombreLimpio = Sanitizacion.limpiarNonNull(nombreCliente ?? '').trim();
    if (nombreLimpio.length > 100) {
      return const ResultadoVenta.error('El nombre del cliente es demasiado largo');
    }
    final correo = (correoCliente ?? '').trim().toLowerCase();
    if (correo.length > 100) {
      return const ResultadoVenta.error('El correo del cliente es demasiado largo');
    }

    String metodo = metodoPago.toUpperCase();
    if (!['EFECTIVO', 'TARJETA', 'TRANSFERENCIA', 'CREDITO'].contains(metodo)) {
      metodo = 'EFECTIVO';
    }

    final descuentoPct = Descuentos.porcentajeCodigo(codigoDescuento);
    final descuentoDecimal = descuentoPct / 100;

    final prodRepo = ProductosRepository(_db);
    final clienteRepo = ClientesRepository(_db);
    final audRepo = AuditoriaRepository(_db);

    try {
      final ids = productos.map((p) => p['id']).whereType<int>().toList();
      final productosDb = <int, Producto>{};
      for (final pid in ids) {
        final p = await prodRepo.obtenerPorId(pid);
        if (p == null) {
          return const ResultadoVenta.error('Uno de los productos ya no existe');
        }
        productosDb[pid] = p;
      }

      // Validación línea a línea
      var subtotalGlobal = 0.0;
      final detalle = <Map<String, Object?>>[];
      for (final item in productos) {
        final pid = item['id'] as int;
        final cantidad = item['cantidad'] as int;
        final p = productosDb[pid]!;

        if (!p.activo) {
          return ResultadoVenta.error('El producto ${p.nombre} no está disponible');
        }
        if (cantidad <= 0) {
          return ResultadoVenta.error('Cantidad inválida para ${p.nombre}');
        }
        if (cantidad > p.stock) {
          return ResultadoVenta.error(
              'No hay suficiente stock de ${p.nombre}. Stock disponible: ${p.stock}');
        }
        final precio = p.precio;
        if (precio <= 0) {
          return ResultadoVenta.error('Precio no válido para ${p.nombre}');
        }
        final subtotal = precio * cantidad;
        subtotalGlobal += subtotal;
        detalle.add({
          'producto': p,
          'cantidad': cantidad,
          'precio': precio,
          'subtotal': subtotal,
        });
      }

      // Cliente
      Cliente cliente;
      try {
        final (obtenido, _) = await clienteRepo.obtenerOCrear(
          clienteId: clienteId,
          nombre: nombreLimpio.isEmpty ? null : nombreLimpio,
          correo: correo.isEmpty ? null : correo,
        );
        cliente = obtenido;
      } catch (e) {
        return ResultadoVenta.error(e.toString());
      }

      final valorDescuento = subtotalGlobal * descuentoDecimal;
      final totalFinal = subtotalGlobal - valorDescuento;

      final facturaId = await _db.transaction((txn) async {
        final id = await txn.insert('facturas', {
          'cliente_id': cliente.id,
          'usuario': nombreUsuario.isNotEmpty ? nombreUsuario : 'Usuario',
          'fecha': DateTime.now().toIso8601String(),
          'total': totalFinal,
          'descuento': valorDescuento,
          'metodo_pago': metodo,
          'valor_pagado': metodo == 'CREDITO' ? 0 : totalFinal,
          'fecha_vencimiento': fechaVencimiento?.toIso8601String().split('T').first,
        });

        for (final d in detalle) {
          final prod = d['producto'] as Producto;
          final cantidad = d['cantidad'] as int;
          await txn.insert('detalle_factura', {
            'factura_id': id,
            'producto_id': prod.id,
            'cantidad': cantidad,
            'precio': d['precio'],
            'subtotal': d['subtotal'],
          });
          await txn.rawUpdate(
            'UPDATE productos SET stock = stock - ? WHERE id = ?',
            [cantidad, prod.id],
          );
        }
        return id;
      });

      final accion =
          'CREÓ FACTURA #$facturaId - CLIENTE: ${cliente.nombre} - TOTAL: ${Formato.cop(totalFinal)}';
      await audRepo.registrar(
        usuario: nombreUsuario.isNotEmpty ? nombreUsuario : 'Usuario',
        accion: accion,
        modulo: 'FACTURACION',
      );

      return ResultadoVenta.success(
        'Venta realizada correctamente. La factura fue registrada.',
        facturaId,
      );
    } catch (e) {
      return const ResultadoVenta.error('Ocurrió un error al confirmar la venta. Intenta nuevamente.');
    }
  }

  /// Productos vendidos agregados (Ventas por producto / facturación).
  Future<List<Map<String, Object?>>> productosFacturados() async {
    return _db.rawQuery('''
      SELECT p.id, p.nombre, p.categoria,
             SUM(df.cantidad) AS unidades,
             SUM(df.subtotal) AS ingresos,
             COUNT(DISTINCT df.factura_id) AS transacciones
      FROM detalle_factura df
      JOIN productos p ON p.id = df.producto_id
      GROUP BY p.id, p.nombre, p.categoria
      ORDER BY ingresos DESC
    ''');
  }

  /// Ventas totales del mes actual (suma de total).
  Future<double> ventasDelMes() async {
    final ahora = DateTime.now();
    final inicio = DateTime(ahora.year, ahora.month, 1);
    final filas = await _db.rawQuery(
      'SELECT COALESCE(SUM(total), 0) AS t FROM facturas WHERE fecha >= ?',
      [inicio.toIso8601String()],
    );
    return (filas.first['t'] as num?)?.toDouble() ?? 0;
  }

  Future<int> contar() async =>
      Sqflite.firstIntValue(await _db.rawQuery('SELECT COUNT(*) FROM facturas')) ?? 0;
}
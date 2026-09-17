import '../core/numeracion.dart';

class EntradaInventario {
  final int? id;
  final String proveedor;
  final String? documento;
  final String? usuario;
  final String? observaciones;
  final DateTime fecha;
  final double total;

  const EntradaInventario({
    this.id,
    required this.proveedor,
    this.documento,
    this.usuario,
    this.observaciones,
    required this.fecha,
    required this.total,
  });

  String numeroFactura() => Numeracion.facturaEntrada(id ?? 0);

  Map<String, Object?> aMap() => {
        'id': id,
        'proveedor': proveedor,
        'documento': documento,
        'usuario': usuario,
        'observaciones': observaciones,
        'fecha': fecha.toIso8601String(),
        'total': total,
      };

  factory EntradaInventario.desdeMapa(Map<String, Object?> m) => EntradaInventario(
        id: m['id'] as int?,
        proveedor: (m['proveedor'] as String?) ?? '',
        documento: m['documento'] as String?,
        usuario: m['usuario'] as String?,
        observaciones: m['observaciones'] as String?,
        fecha: DateTime.parse(m['fecha'] as String),
        total: (m['total'] as num?)?.toDouble() ?? 0,
      );
}

class DetalleEntradaInventario {
  final int? id;
  final int? entradaId;
  final int productoId;
  final int cantidad;
  final int precio;
  final int subtotal;

  const DetalleEntradaInventario({
    this.id,
    this.entradaId,
    required this.productoId,
    required this.cantidad,
    required this.precio,
    required this.subtotal,
  });

  Map<String, Object?> aMap() => {
        'id': id,
        'entrada_id': entradaId,
        'producto_id': productoId,
        'cantidad': cantidad,
        'precio': precio,
        'subtotal': subtotal,
      };

  factory DetalleEntradaInventario.desdeMapa(Map<String, Object?> m) => DetalleEntradaInventario(
        id: m['id'] as int?,
        entradaId: m['entrada_id'] as int?,
        productoId: (m['producto_id'] as int?) ?? 0,
        cantidad: (m['cantidad'] as int?) ?? 0,
        precio: (m['precio'] as int?) ?? 0,
        subtotal: (m['subtotal'] as int?) ?? 0,
      );
}
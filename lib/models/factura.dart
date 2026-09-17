class Cliente {
  final int? id;
  final String nombre;
  final String correo;

  const Cliente({this.id, required this.nombre, required this.correo});

  Cliente copyWith({int? id, String? nombre, String? correo}) =>
      Cliente(id: id ?? this.id, nombre: nombre ?? this.nombre, correo: correo ?? this.correo);

  Map<String, Object?> aMap() => {'id': id, 'nombre': nombre, 'correo': correo};

  factory Cliente.desdeMapa(Map<String, Object?> m) => Cliente(
        id: m['id'] as int?,
        nombre: (m['nombre'] as String?) ?? '',
        correo: (m['correo'] as String?) ?? '',
      );
}

class DetalleFactura {
  final int? id;
  final int? facturaId;
  final int productoId;
  final int cantidad;
  final int precio;
  final int subtotal;

  const DetalleFactura({
    this.id,
    this.facturaId,
    required this.productoId,
    required this.cantidad,
    required this.precio,
    required this.subtotal,
  });

  Map<String, Object?> aMap() => {
        'id': id,
        'factura_id': facturaId,
        'producto_id': productoId,
        'cantidad': cantidad,
        'precio': precio,
        'subtotal': subtotal,
      };

  factory DetalleFactura.desdeMapa(Map<String, Object?> m) => DetalleFactura(
        id: m['id'] as int?,
        facturaId: m['factura_id'] as int?,
        productoId: (m['producto_id'] as int?) ?? 0,
        cantidad: (m['cantidad'] as int?) ?? 0,
        precio: (m['precio'] as int?) ?? 0,
        subtotal: (m['subtotal'] as int?) ?? 0,
      );
}

class Factura {
  final int? id;
  final int clienteId;
  final String usuario;
  final DateTime fecha;
  final double total;
  final double descuento;
  final String metodoPago;
  final double valorPagado;
  final DateTime? fechaVencimiento;

  const Factura({
    this.id,
    required this.clienteId,
    required this.usuario,
    required this.fecha,
    required this.total,
    required this.descuento,
    required this.metodoPago,
    required this.valorPagado,
    this.fechaVencimiento,
  });

  // Propiedades computadas (idénticas a Factura @property en Django)
  double get saldoPendiente => (total - valorPagado).clamp(0, double.infinity);
  String get estadoPago {
    if (saldoPendiente <= 0) return 'PAGADA';
    if (fechaVencimiento != null && fechaVencimiento!.isBefore(DateTime.now())) return 'VENCIDA';
    if (valorPagado > 0) return 'PARCIAL';
    return 'PENDIENTE';
  }

  double get baseGravable => total / 1.19;
  double get iva => total - baseGravable;

  Map<String, Object?> aMap() => {
        'id': id,
        'cliente_id': clienteId,
        'usuario': usuario,
        'fecha': fecha.toIso8601String(),
        'total': total,
        'descuento': descuento,
        'metodo_pago': metodoPago,
        'valor_pagado': valorPagado,
        'fecha_vencimiento': fechaVencimiento?.toIso8601String().split('T').first,
      };

  factory Factura.desdeMapa(Map<String, Object?> m) => Factura(
        id: m['id'] as int?,
        clienteId: (m['cliente_id'] as int?) ?? 0,
        usuario: (m['usuario'] as String?) ?? '',
        fecha: DateTime.parse(m['fecha'] as String),
        total: (m['total'] as num?)?.toDouble() ?? 0,
        descuento: (m['descuento'] as num?)?.toDouble() ?? 0,
        metodoPago: (m['metodo_pago'] as String?) ?? 'EFECTIVO',
        valorPagado: (m['valor_pagado'] as num?)?.toDouble() ?? 0,
        fechaVencimiento: (m['fecha_vencimiento'] as String?) == null
            ? null
            : DateTime.tryParse(m['fecha_vencimiento'] as String),
      );
}
class CuentaPorPagar {
  final int? id;
  final String proveedor;
  final String concepto;
  final DateTime fecha;
  final double valor;
  final double valorPagado;
  final DateTime? fechaVencimiento;

  const CuentaPorPagar({
    this.id,
    required this.proveedor,
    required this.concepto,
    required this.fecha,
    required this.valor,
    required this.valorPagado,
    this.fechaVencimiento,
  });

  double get saldoPendiente => (valor - valorPagado).clamp(0, double.infinity);
  String get estado {
    if (saldoPendiente <= 0) return 'PAGADA';
    if (fechaVencimiento != null && fechaVencimiento!.isBefore(DateTime.now())) return 'VENCIDA';
    if (valorPagado > 0) return 'PARCIAL';
    return 'PENDIENTE';
  }

  Map<String, Object?> aMap() => {
        'id': id,
        'proveedor': proveedor,
        'concepto': concepto,
        'fecha': fecha.toIso8601String().split('T').first,
        'valor': valor,
        'valor_pagado': valorPagado,
        'fecha_vencimiento': fechaVencimiento?.toIso8601String().split('T').first,
      };

  factory CuentaPorPagar.desdeMapa(Map<String, Object?> m) => CuentaPorPagar(
        id: m['id'] as int?,
        proveedor: (m['proveedor'] as String?) ?? '',
        concepto: (m['concepto'] as String?) ?? '',
        fecha: DateTime.parse(m['fecha'] as String),
        valor: (m['valor'] as num?)?.toDouble() ?? 0,
        valorPagado: (m['valor_pagado'] as num?)?.toDouble() ?? 0,
        fechaVencimiento: (m['fecha_vencimiento'] as String?) == null
            ? null
            : DateTime.tryParse(m['fecha_vencimiento'] as String),
      );
}
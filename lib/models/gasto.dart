class Gasto {
  final int? id;
  final String concepto;
  final String categoria;
  final double valor;
  final DateTime fecha;
  final String metodoPago;
  final String proveedor;
  final String descripcion;
  final String usuario;
  final DateTime creadoEn;

  const Gasto({
    this.id,
    required this.concepto,
    required this.categoria,
    required this.valor,
    required this.fecha,
    required this.metodoPago,
    this.proveedor = '',
    this.descripcion = '',
    required this.usuario,
    required this.creadoEn,
  });

  Map<String, Object?> aMap() => {
        'id': id,
        'concepto': concepto,
        'categoria': categoria,
        'valor': valor,
        'fecha': fecha.toIso8601String().split('T').first,
        'metodo_pago': metodoPago,
        'proveedor': proveedor,
        'descripcion': descripcion,
        'usuario': usuario,
        'creado_en': creadoEn.toIso8601String(),
      };

  factory Gasto.desdeMapa(Map<String, Object?> m) => Gasto(
        id: m['id'] as int?,
        concepto: (m['concepto'] as String?) ?? '',
        categoria: (m['categoria'] as String?) ?? '',
        valor: (m['valor'] as num?)?.toDouble() ?? 0,
        fecha: DateTime.parse(m['fecha'] as String),
        metodoPago: (m['metodo_pago'] as String?) ?? 'EFECTIVO',
        proveedor: (m['proveedor'] as String?) ?? '',
        descripcion: (m['descripcion'] as String?) ?? '',
        usuario: (m['usuario'] as String?) ?? '',
        creadoEn: DateTime.parse(m['creado_en'] as String),
      );
}
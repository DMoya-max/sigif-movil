class Producto {
  final int? id;
  final String nombre;
  final String? descripcion;
  final int precio; // COP enteros (Decimal con 0 decimales en Django)
  final int stock;
  final String categoria;
  final bool activo;
  final DateTime fechaCreacion;
  final DateTime fechaActualizacion;

  const Producto({
    this.id,
    required this.nombre,
    this.descripcion,
    required this.precio,
    required this.stock,
    required this.categoria,
    required this.activo,
    required this.fechaCreacion,
    required this.fechaActualizacion,
  });

  bool get stockBajo => activo && stock > 0 && stock < 5;
  bool get agotado => activo && stock == 0;

  Producto copyWith({
    int? id,
    String? nombre,
    String? descripcion,
    int? precio,
    int? stock,
    String? categoria,
    bool? activo,
    DateTime? fechaCreacion,
    DateTime? fechaActualizacion,
  }) {
    return Producto(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      precio: precio ?? this.precio,
      stock: stock ?? this.stock,
      categoria: categoria ?? this.categoria,
      activo: activo ?? this.activo,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
    );
  }

  Map<String, Object?> aMap() => {
        'id': id,
        'nombre': nombre,
        'descripcion': descripcion,
        'precio': precio,
        'stock': stock,
        'categoria': categoria,
        'activo': activo ? 1 : 0,
        'fecha_creacion': fechaCreacion.toIso8601String(),
        'fecha_actualizacion': fechaActualizacion.toIso8601String(),
      };

  factory Producto.desdeMapa(Map<String, Object?> m) => Producto(
        id: m['id'] as int?,
        nombre: (m['nombre'] as String?) ?? '',
        descripcion: m['descripcion'] as String?,
        precio: (m['precio'] as int?) ?? 0,
        stock: (m['stock'] as int?) ?? 0,
        categoria: (m['categoria'] as String?) ?? '',
        activo: (m['activo'] as int?) == 1,
        fechaCreacion: DateTime.parse(m['fecha_creacion'] as String),
        fechaActualizacion: DateTime.parse(m['fecha_actualizacion'] as String),
      );
}
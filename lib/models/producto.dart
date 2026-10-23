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

  /// Serialización para SQLite local.
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

  /// Deserialización desde SQLite local.
  factory Producto.desdeMapa(Map<String, Object?> m) => Producto.fromJson(m);

  /// Deserialización desde la API REST (`https://sigif-final.vercel.app/api/productos/`).
  factory Producto.fromJson(Map<String, dynamic> json) {
    final rawPrecio = json['precio'];
    final precio = rawPrecio is int
        ? rawPrecio
        : rawPrecio is num
            ? rawPrecio.round()
            : double.tryParse(rawPrecio?.toString() ?? '0')?.round() ?? 0;

    final rawStock = json['stock'];
    final stock = rawStock is int
        ? rawStock
        : rawStock is num
            ? rawStock.round()
            : int.tryParse(rawStock?.toString() ?? '0') ?? 0;

    final rawActivo = json['activo'];
    final activo = rawActivo is bool
        ? rawActivo
        : rawActivo is num
            ? rawActivo != 0
            : true;

    final ahora = DateTime.now();
    final fechaCreacion = DateTime.tryParse(
          json['fecha_creacion']?.toString() ?? '',
        ) ??
        ahora;
    final fechaActualizacion = DateTime.tryParse(
          json['fecha_actualizacion']?.toString() ?? '',
        ) ??
        ahora;

    return Producto(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? ''),
      nombre: json['nombre']?.toString() ?? '',
      descripcion: json['descripcion']?.toString(),
      precio: precio,
      stock: stock,
      categoria: json['categoria']?.toString() ?? '',
      activo: activo,
      fechaCreacion: fechaCreacion,
      fechaActualizacion: fechaActualizacion,
    );
  }

  /// Serialización hacia JSON para la API REST (POST / PUT / PATCH).
  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        'descripcion': (descripcion == null || descripcion!.trim().isEmpty)
            ? null
            : descripcion!.trim(),
        'precio': precio.toString(),
        'stock': stock,
        'categoria': categoria,
        'activo': activo,
      };
}

class Usuario {
  final int? id;
  final String nombre;
  final String documento;
  final String contra; // hash PBKDF2
  final String telefono;
  final String correo;
  final bool activo;
  final DateTime? fechaInicio;
  final String cargo; // SuperAdmin | Admin | Empleado
  final bool esSuperadminPrincipal;

  const Usuario({
    this.id,
    required this.nombre,
    required this.documento,
    required this.contra,
    required this.telefono,
    required this.correo,
    required this.activo,
    this.fechaInicio,
    required this.cargo,
    required this.esSuperadminPrincipal,
  });

  bool get esSuperAdmin => cargo == 'SuperAdmin';
  bool get esAdmin => cargo == 'Admin';
  bool get esEmpleado => cargo == 'Empleado';
  bool get puedeGestionarUsuarios => (cargo == 'SuperAdmin' || cargo == 'Admin');
  bool get puedeCrearGastos => (cargo == 'SuperAdmin' || cargo == 'Admin');
  bool get puedeVerAuditoria => (cargo == 'SuperAdmin' || cargo == 'Admin');
  bool get puedeVerConfiguracion => (cargo == 'SuperAdmin' || cargo == 'Admin');

  Usuario copyWith({
    int? id,
    String? nombre,
    String? documento,
    String? contra,
    String? telefono,
    String? correo,
    bool? activo,
    DateTime? fechaInicio,
    String? cargo,
    bool? esSuperadminPrincipal,
  }) {
    return Usuario(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      documento: documento ?? this.documento,
      contra: contra ?? this.contra,
      telefono: telefono ?? this.telefono,
      correo: correo ?? this.correo,
      activo: activo ?? this.activo,
      fechaInicio: fechaInicio ?? this.fechaInicio,
      cargo: cargo ?? this.cargo,
      esSuperadminPrincipal: esSuperadminPrincipal ?? this.esSuperadminPrincipal,
    );
  }

  Map<String, Object?> aMap() => {
        'id': id,
        'nombre': nombre,
        'documento': documento,
        'contra': contra,
        'telefono': telefono,
        'correo': correo,
        'activo': activo ? 1 : 0,
        'fecha_inicio': fechaInicio?.toIso8601String().split('T').first,
        'cargo': cargo,
        'es_superadmin_principal': esSuperadminPrincipal ? 1 : 0,
      };

  factory Usuario.desdeMapa(Map<String, Object?> m) => Usuario(
        id: m['id'] as int?,
        nombre: (m['nombre'] as String?) ?? '',
        documento: (m['documento'] as String?) ?? '',
        contra: (m['contra'] as String?) ?? '',
        telefono: (m['telefono'] as String?) ?? '',
        correo: (m['correo'] as String?) ?? '',
        activo: (m['activo'] as int?) == 1,
        fechaInicio: (m['fecha_inicio'] as String?) == null
            ? null
            : DateTime.tryParse(m['fecha_inicio'] as String),
        cargo: (m['cargo'] as String?) ?? 'Empleado',
        esSuperadminPrincipal: (m['es_superadmin_principal'] as int?) == 1,
      );
}
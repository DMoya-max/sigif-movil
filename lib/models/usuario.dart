class Usuario {
  final int? id;
  final String nombre;
  final String documento;
  final String contra; // hash PBKDF2 o vacío si viene de la API (write_only)
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
    this.contra = '',
    required this.telefono,
    required this.correo,
    required this.activo,
    this.fechaInicio,
    required this.cargo,
    this.esSuperadminPrincipal = false,
  });

  bool get esSuperAdmin => cargo == 'SuperAdmin';
  bool get esAdmin => cargo == 'Admin';
  bool get esEmpleado => cargo == 'Empleado';
  bool get puedeGestionarUsuarios => (cargo == 'SuperAdmin' || cargo == 'Admin');
  bool get puedeGestionarEstadoProductos =>
      (cargo == 'SuperAdmin' || cargo == 'Admin');
  bool get puedeCrearGastos => (cargo == 'SuperAdmin' || cargo == 'Admin');
  bool get puedeVerAuditoria => (cargo == 'SuperAdmin' || cargo == 'Admin');
  bool get puedeVerConfiguracion => (cargo == 'SuperAdmin' || cargo == 'Admin');

  // ===========================================================================
  // MATRIZ DE PERMISOS Y ESCALADA DE ROLES (idéntica a apps/usuarios/views.py)
  // ===========================================================================

  /// Devuelve `null` si este usuario (`actor`) puede editar a [target],
  /// o el mensaje de error exacto del proyecto si NO tiene permiso.
  String? motivoRechazoEditar(Usuario target) {
    // 1. El SuperAdmin principal no puede ser editado por ningún otro usuario
    if (target.esSuperadminPrincipal && target.id != id) {
      return 'No tienes permiso para modificar al SuperAdmin principal.';
    }
    // 2. Un Empleado solo puede editar su propio perfil
    if (esEmpleado && target.id != id) {
      return 'Solo tienes permiso para editar tu propio perfil.';
    }
    // 3. Un Admin no puede modificar a un SuperAdmin ni a otro Admin
    if (esAdmin) {
      if (target.esSuperAdmin) {
        return 'Un Admin no puede modificar a un SuperAdmin.';
      }
      if (target.esAdmin && target.id != id) {
        return 'Un Admin no puede modificar a otro Admin.';
      }
    }
    return null;
  }

  bool puedeEditarUsuario(Usuario target) => motivoRechazoEditar(target) == null;

  /// Devuelve `null` si este usuario (`actor`) puede activar/desactivar a [target],
  /// o el mensaje de error exacto del proyecto (`cambiar_estado_usuario`).
  String? motivoRechazoCambiarEstado(Usuario target) {
    if (esEmpleado) {
      return 'No tienes permiso para cambiar el estado de los usuarios.';
    }
    if (target.id == id) {
      return 'No puedes desactivar tu propio usuario.';
    }
    if (target.esSuperadminPrincipal || target.esSuperAdmin) {
      return 'El SuperAdmin no puede ser desactivado.';
    }
    if (esAdmin && target.esAdmin) {
      return 'Un Admin no puede desactivar a otro Admin.';
    }
    return null;
  }

  bool puedeCambiarEstadoUsuario(Usuario target) =>
      motivoRechazoCambiarEstado(target) == null;

  /// Devuelve `null` si este usuario (`actor`) puede eliminar a [target],
  /// o el mensaje de error exacto del proyecto (`eliminar_usuario`).
  String? motivoRechazoEliminar(Usuario target) {
    if (esEmpleado) {
      return 'No tienes permiso para eliminar usuarios.';
    }
    if (target.id == id) {
      return 'No puedes eliminar tu propio usuario.';
    }
    if (target.esSuperadminPrincipal || target.esSuperAdmin) {
      return 'No se puede eliminar al SuperAdmin.';
    }
    if (esAdmin && target.esAdmin) {
      return 'Un Admin no puede eliminar a otro Admin.';
    }
    return null;
  }

  bool puedeEliminarUsuario(Usuario target) =>
      motivoRechazoEliminar(target) == null;

  /// Indica si este usuario (`actor`) puede modificar el campo Cargo/Rol de [target].
  /// - En creación (`target == null`): SuperAdmin y Admin pueden elegir rol (según sus límites).
  /// - En edición (`target != null`): Nadie puede cambiar su propio rol, ni el del SuperAdmin principal, ni un Empleado.
  bool puedeCambiarCargo({Usuario? target}) {
    if (esEmpleado) return false;
    if (target != null) {
      if (target.id == id) return false; // Propio usuario nunca cambia su rol
      if (target.esSuperadminPrincipal) return false;
      if (esAdmin && (target.esSuperAdmin || target.esAdmin)) return false;
    }
    return esSuperAdmin || esAdmin;
  }

  /// Lista de cargos que este usuario (`actor`) tiene permitido asignar.
  /// Un Admin jamás puede crear ni ascender a nadie a `SuperAdmin` (`@impedir_crear_superadmin`).
  List<String> cargosAsignables({Usuario? target}) {
    if (!puedeCambiarCargo(target: target)) {
      return [target?.cargo ?? cargo];
    }
    if (esSuperAdmin) {
      return const ['SuperAdmin', 'Admin', 'Empleado'];
    }
    // Admin solo puede asignar Admin o Empleado (nunca SuperAdmin)
    return const ['Admin', 'Empleado'];
  }

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

  /// Serialización para SQLite local.
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

  /// Deserialización desde SQLite local.
  factory Usuario.desdeMapa(Map<String, Object?> m) => Usuario.fromJson(m);

  /// Deserialización desde la API REST (`https://sigif-final.vercel.app/api/usuarios/`).
  factory Usuario.fromJson(Map<String, dynamic> json) {
    final rawActivo = json['activo'];
    final activo = rawActivo is bool
        ? rawActivo
        : rawActivo is num
            ? rawActivo != 0
            : true;

    final rawSuper = json['es_superadmin_principal'];
    final esSuper = rawSuper is bool
        ? rawSuper
        : rawSuper is num
            ? rawSuper != 0
            : false;

    final rawFecha = json['fecha_inicio']?.toString();

    return Usuario(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? ''),
      nombre: json['nombre']?.toString() ?? '',
      documento: json['documento']?.toString() ?? '',
      contra: json['contra']?.toString() ?? '',
      telefono: json['telefono']?.toString() ?? '',
      correo: json['correo']?.toString() ?? '',
      activo: activo,
      fechaInicio: (rawFecha == null || rawFecha.isEmpty)
          ? null
          : DateTime.tryParse(rawFecha),
      cargo: json['cargo']?.toString() ?? 'Empleado',
      esSuperadminPrincipal: esSuper,
    );
  }

  /// Serialización hacia JSON para la API REST (POST / PUT / PATCH).
  Map<String, dynamic> toJson({String? clavePlana}) {
    final map = <String, dynamic>{
      'nombre': nombre,
      'documento': documento,
      'telefono': telefono,
      'correo': correo,
      'activo': activo,
      'fecha_inicio': (fechaInicio ?? DateTime.now())
          .toIso8601String()
          .split('T')
          .first,
      'cargo': cargo,
    };
    if (clavePlana != null && clavePlana.trim().isNotEmpty) {
      map['contra'] = clavePlana.trim();
    } else if (contra.isNotEmpty) {
      map['contra'] = contra;
    }
    return map;
  }
}

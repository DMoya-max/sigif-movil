import 'package:sqflite/sqflite.dart';

import '../../models/empresa_config.dart';
import '../../models/usuario.dart';
import '../database.dart';
import 'auditoria_repository.dart';
import 'usuarios_repository.dart';

class ConfiguracionRepository {
  final Database _db;
  ConfiguracionRepository(this._db);

  static Future<ConfiguracionRepository> abrir() async =>
      ConfiguracionRepository(await AppDatabase.instance.db);

  Future<EmpresaConfig> obtener() async {
    final filas = await _db.query('empresa_config', limit: 1);
    if (filas.isEmpty) {
      return EmpresaConfig.porDefecto();
    }
    return EmpresaConfig.desdeMapa(filas.first);
  }

  String _limpiar(String? valor, {int max = 255}) {
    var limpio = (valor ?? '').trim().replaceAll('<', '').replaceAll('>', '');
    if (limpio.length > max) limpio = limpio.substring(0, max);
    return limpio;
  }

  /// Guarda los datos generales de la empresa.
  Future<void> guardarDatosEmpresa({
    required String nombreComercial,
    required String nit,
    required String direccion,
  }) async {
    final config = (await obtener()).copyWith(
      nombreComercial: _limpiar(nombreComercial, max: 150),
      nit: _limpiar(nit, max: 50),
      direccion: _limpiar(direccion, max: 255),
    );
    await _guardar(config);
  }

  /// Guarda la configuración de moneda/(correo de contacto). COP fijo.
  Future<void> guardarConfigSistema({
    required String impuesto,
    required String correoContacto,
  }) async {
    final config = (await obtener()).copyWith(
      moneda: 'COP (\$) - Pesos Colombianos',
      impuesto: _limpiar(impuesto, max: 10),
      correoContacto: correoContacto.trim().toLowerCase(),
    );
    await _guardar(config);
  }

  Future<void> _guardar(EmpresaConfig config) async {
    final filas = await _db.query('empresa_config', limit: 1);
    if (filas.isEmpty) {
      await _db.insert('empresa_config', config.aMap()..remove('id'));
    } else {
      await _db.update('empresa_config', config.aMap()..remove('id'));
    }
  }

  /// Actualiza el cargo de un usuario (Backups y Permisos).
  Future<String?> asignarCargo(Usuario actor, int usuarioId, String nuevoCargo) async {
    final validos = const ['SuperAdmin', 'Admin', 'Empleado'];
    if (!validos.contains(nuevoCargo)) return 'El rol seleccionado no es válido.';

    final userRepo = UsuariosRepository(_db);
    final target = await userRepo.obtenerPorId(usuarioId);
    if (target == null) return 'El usuario seleccionado no existe.';

    if (target.esSuperadminPrincipal) {
      return 'El SuperAdmin principal no puede modificarse.';
    }

    if (actor.cargo != 'SuperAdmin' && nuevoCargo == 'SuperAdmin') {
      await AuditoriaRepository(_db).registrar(
        usuario: actor.nombre,
        accion: 'INTENTO RECHAZADO DE ASIGNAR SUPERADMIN A USUARIO $usuarioId',
        modulo: 'CONFIGURACION',
      );
      return 'Solo el SuperAdmin puede asignar el rol de SuperAdmin.';
    }

    await _db.update('usuarios', {'cargo': nuevoCargo}, where: 'id = ?', whereArgs: [usuarioId]);
    await AuditoriaRepository(_db).registrar(
      usuario: actor.nombre,
      accion: 'ACTUALIZÓ EL CARGO DE ${target.nombre}: $nuevoCargo',
      modulo: 'CONFIGURACION',
    );
    return null;
  }
}
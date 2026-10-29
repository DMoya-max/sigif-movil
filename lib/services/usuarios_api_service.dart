import 'package:sqflite/sqflite.dart';

import '../db/database.dart';
import '../models/usuario.dart';
import 'api_client.dart';
import 'api_config.dart';
import 'password_service.dart';

/// Servicio REST para el módulo de Usuarios (`https://sigif-final.vercel.app/api/usuarios/`).
/// Implementa operaciones CRUD: GET (listar/obtener), POST (crear), PUT/PATCH (actualizar) y DELETE (eliminar).
class UsuariosApiService {
  UsuariosApiService._();
  static final UsuariosApiService instance = UsuariosApiService._();

  final ApiClient _api = ApiClient.instance;

  /// GET: Obtiene la lista de usuarios desde `/api/usuarios/`.
  Future<List<Usuario>> listar({String? q}) async {
    List<Usuario> lista = [];
    try {
      final rawList = await _api.getList(ApiConfig.usuariosEndpoint);
      lista = rawList.map(Usuario.fromJson).toList();

      // Sincronizar con caché SQLite local para reflejar exactamente los usuarios de la API
      final db = await AppDatabase.instance.db;
      await db.delete('usuarios');
      for (final u in lista) {
        await _guardarEnCacheLocal(db, u);
      }
    } catch (e) {
      // Fallback a caché SQLite si no hay red
      final db = await AppDatabase.instance.db;
      final filas = await db.query('usuarios', orderBy: 'id DESC');
      lista = filas.map(Usuario.desdeMapa).toList();
    }

    final termino = q?.trim().toLowerCase() ?? '';
    if (termino.isNotEmpty) {
      lista = lista.where((u) {
        return u.nombre.toLowerCase().contains(termino) ||
            u.documento.toLowerCase().contains(termino) ||
            u.cargo.toLowerCase().contains(termino) ||
            u.telefono.toLowerCase().contains(termino) ||
            u.correo.toLowerCase().contains(termino);
      }).toList();
    }

    return lista;
  }

  /// GET: Obtiene un usuario por su ID desde `/api/usuarios/{id}/`.
  Future<Usuario?> obtenerPorId(int id) async {
    try {
      final json = await _api.getMap('${ApiConfig.usuariosEndpoint}$id/');
      return Usuario.fromJson(json);
    } catch (_) {
      final db = await AppDatabase.instance.db;
      final filas = await db.query(
        'usuarios',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (filas.isEmpty) return null;
      return Usuario.desdeMapa(filas.first);
    }
  }

  /// POST: Crea un nuevo usuario mediante `POST /api/usuarios/`.
  Future<Usuario> crear(Usuario usuario, {required String clavePlana}) async {
    try {
      final payload = usuario.toJson(clavePlana: clavePlana);
      final creadoJson = await _api.postMap(
        ApiConfig.usuariosEndpoint,
        payload,
      );
      final creado = Usuario.fromJson(creadoJson);
      try {
        final db = await AppDatabase.instance.db;
        await _guardarEnCacheLocal(db, creado, clavePlana: clavePlana);
      } catch (_) {}
      return creado;
    } catch (e) {
      rethrow;
    }
  }

  /// PUT / PATCH: Actualiza un usuario existente mediante `/api/usuarios/{id}/`.
  Future<Usuario> actualizar(Usuario usuario, {String? nuevaClavePlana}) async {
    final id = usuario.id;
    if (id == null) {
      throw const ApiException('El usuario a editar no tiene un ID válido.');
    }

    try {
      final payload = usuario.toJson(clavePlana: nuevaClavePlana);
      final Map<String, dynamic> actualizadoJson;
      if (nuevaClavePlana != null && nuevaClavePlana.trim().isNotEmpty) {
        actualizadoJson = await _api.putMap(
          '${ApiConfig.usuariosEndpoint}$id/',
          payload,
        );
      } else {
        payload.remove('contra');
        actualizadoJson = await _api.patchMap(
          '${ApiConfig.usuariosEndpoint}$id/',
          payload,
        );
      }
      final actualizado = Usuario.fromJson(actualizadoJson);
      try {
        final db = await AppDatabase.instance.db;
        await _guardarEnCacheLocal(
          db,
          actualizado,
          clavePlana: nuevaClavePlana,
        );
      } catch (_) {}
      return actualizado;
    } catch (e) {
      rethrow;
    }
  }

  /// Activa o desactiva un usuario en la API.
  Future<Usuario> cambiarEstado(Usuario usuario, bool activo) async {
    if (usuario.id == null) {
      throw const ApiException('El usuario a editar no tiene un ID válido.');
    }

    await _api.postSesionWeb('cambiar_estado_usuario/${usuario.id}/');
    final actualizado = await obtenerPorId(usuario.id!);
    if (actualizado == null || actualizado.activo != activo) {
      throw const ApiException(
        'El servidor no confirmó el cambio de estado del usuario.',
      );
    }
    return actualizado;
  }

  /// DELETE: Elimina un usuario mediante `DELETE /api/usuarios/{id}/`.
  Future<void> eliminar(int id) async {
    try {
      await _api.delete('${ApiConfig.usuariosEndpoint}$id/');
      try {
        final db = await AppDatabase.instance.db;
        await db.delete('usuarios', where: 'id = ?', whereArgs: [id]);
      } catch (_) {}
    } catch (e) {
      rethrow;
    }
  }

  /// Valida unicidad de documento, teléfono y correo contra la lista actual de usuarios
  /// (idéntico a `clean_documento`, `clean_telefono` y `clean_correo` en `apps/usuarios/forms.py`).
  Future<String?> validarUnicidad({
    required String documento,
    required String telefono,
    required String correo,
    int? excluirId,
  }) async {
    final doc = documento.trim();
    final tel = telefono.trim();
    final corr = correo.trim().toLowerCase();

    final usuarios = await listar();
    for (final u in usuarios) {
      if (excluirId != null && u.id == excluirId) continue;
      if (doc.isNotEmpty && u.documento.trim() == doc) {
        return 'Este documento ya está registrado en el sistema.';
      }
      if (tel.isNotEmpty && u.telefono.trim() == tel) {
        return 'Este número de teléfono ya está registrado en el sistema.';
      }
      if (corr.isNotEmpty && u.correo.trim().toLowerCase() == corr) {
        return 'Este correo electrónico ya está registrado en el sistema.';
      }
    }
    return null;
  }

  Future<void> _guardarEnCacheLocal(
    Database db,
    Usuario u, {
    String? clavePlana,
  }) async {
    if (u.id == null) return;
    var contra = u.contra;
    if (clavePlana != null && clavePlana.trim().isNotEmpty) {
      contra = await PasswordService.crearHash(clavePlana.trim());
    } else if (contra.isEmpty) {
      contra = await PasswordService.crearHash('admin1234');
    }
    await db.insert(
      'usuarios',
      u.copyWith(contra: contra).aMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

import 'package:shared_preferences/shared_preferences.dart';

import '../db/repos/auditoria_repository.dart';
import '../db/repos/usuarios_repository.dart';
import '../models/usuario.dart';
import 'password_service.dart';

/// Resultado del inicio de sesión.
class ResultadoLogin {
  final bool success;
  final String message;
  final Usuario? usuario;

  const ResultadoLogin.success(this.usuario) : success = true, message = '';
  const ResultadoLogin.error(this.message) : success = false, usuario = null;
}

/// Gestiona la sesión local del usuario (equivalente a request.session en Django).
class SessionService {
  static const String _claveSesion = 'sigif_sesion_id';
  static const String _claveRecordar = 'sigif_recordar_sesion';

  Usuario? _usuario;
  bool recordarSesion = true;

  Usuario? get usuario => _usuario;
  bool get estaLogueado => _usuario != null;
  String get nombreUsuario => _usuario?.nombre ?? '';
  String get rolUsuario => _usuario?.cargo ?? '';

  static final SessionService instance = SessionService._();
  SessionService._();

  Future<void> cargarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    recordarSesion = prefs.getBool(_claveRecordar) ?? true;
    final id = prefs.getInt(_claveSesion);
    if (id == null) {
      _usuario = null;
      return;
    }
    final repo = await UsuariosRepository.abrir();
    final u = await repo.obtenerPorId(id);
    if (u != null && u.activo) {
      _usuario = u;
    } else {
      _usuario = null;
      await prefs.remove(_claveSesion);
    }
  }

  Future<ResultadoLogin> iniciarSesion(String correo, String clave) async {
    final repo = await UsuariosRepository.abrir();
    final user = await repo.buscarPorCorreo(correo.trim());

    if (user == null || !await PasswordService.verificar(clave, user.contra)) {
      await _auditarLogin(user?.nombre ?? correo, 'INTENTO FALLIDO DE INICIO DE SESIÓN');
      return const ResultadoLogin.error('Usuario o contraseña incorrecto');
    }

    if (!user.activo) {
      await _auditarLogin(user.nombre, 'INICIO DE SESIÓN RECHAZADO (USUARIO INACTIVO)');
      return const ResultadoLogin.error('Tu usuario está inactivo. Comunícate con un administrador.');
    }

    _usuario = user;
    sessionUsuario = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_claveRecordar, recordarSesion);
    if (recordarSesion) {
      await prefs.setInt(_claveSesion, user.id!);
    }
    await _auditarLogin(user.nombre, 'INICIÓ SESIÓN');
    return ResultadoLogin.success(user);
  }

  Future<void> cerrarSesion() async {
    final nombre = _usuario?.nombre ?? '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_claveSesion);
    _usuario = null;
    sessionUsuario = null;
    await _auditarLogin(nombre, 'CERRO SESION');
  }

  Future<void> _auditarLogin(String usuario, String accion) async {
    try {
      final aud = await AuditoriaRepository.abrir();
      await aud.registrar(usuario: usuario, accion: accion, modulo: 'USUARIOS');
    } catch (_) {}
  }

  /// Actualiza el usuario en memoria (tras editar perfil).
  void actualizarUsuario(Usuario nuevo) {
    _usuario = nuevo;
    sessionUsuario = nuevo;
  }

  /// Sincroniza rol/nombre de la sesión desde la BD (al entrar a pantallas).
  Future<Usuario?> refrescarSesion() async {
    if (_usuario == null) return null;
    final repo = await UsuariosRepository.abrir();
    final u = await repo.obtenerPorId(_usuario!.id!);
    if (u != null && u.activo) {
      _usuario = u;
      sessionUsuario = u;
    }
    return _usuario;
  }
}

/// Usuario actual global (equivalente a la sesión 'logueado' de Django).
Usuario? sessionUsuario;
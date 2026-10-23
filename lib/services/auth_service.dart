import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../db/repos/auditoria_repository.dart';
import '../db/repos/usuarios_repository.dart';
import '../models/usuario.dart';
import 'api_config.dart';
import 'usuarios_api_service.dart';

/// Resultado del inicio de sesión contra el backend.
class ResultadoLogin {
  final bool success;
  final String message;
  final String? token;
  final Usuario? usuario;

  const ResultadoLogin.success(this.usuario, {this.token})
      : success = true,
        message = '';

  const ResultadoLogin.error(this.message)
      : success = false,
        token = null,
        usuario = null;
}

/// Servicio de Autenticación (`AuthService` / `SessionService`) que consume el
/// endpoint POST de login de la API enviando `{"email": "...", "password": "..."}`.
class AuthService {
  static const String _claveSesion = 'sigif_sesion_id';
  static const String _claveRecordar = 'sigif_recordar_sesion';

  Usuario? _usuario;
  bool recordarSesion = true;

  Usuario? get usuario => _usuario;
  bool get estaLogueado => _usuario != null;
  String get nombreUsuario => _usuario?.nombre ?? '';
  String get rolUsuario => _usuario?.cargo ?? '';

  static final AuthService instance = AuthService._();
  AuthService._();

  /// Carga la sesión persistida al arrancar la aplicación.
  Future<void> cargarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    recordarSesion = prefs.getBool(_claveRecordar) ?? true;
    final id = prefs.getInt(_claveSesion);
    if (id == null) {
      _usuario = null;
      return;
    }

    try {
      await UsuariosApiService.instance.listar();
    } catch (_) {}

    final u = await UsuariosApiService.instance.obtenerPorId(id) ??
        await (await UsuariosRepository.abrir()).obtenerPorId(id);
    if (u != null && u.activo) {
      _usuario = u;
      sessionUsuario = u;
    } else {
      _usuario = null;
      await prefs.remove(_claveSesion);
    }
  }

  /// Realiza una petición POST al endpoint `/api/login/` enviando
  /// `{"email": email, "password": password}` para validar exactamente el correo
  /// y contraseña registrados en la base de datos del backend.
  Future<ResultadoLogin> login(String email, String password) async {
    final emailLimpio = email.trim().toLowerCase();

    if (emailLimpio.isEmpty || password.isEmpty) {
      return const ResultadoLogin.error('Credenciales inválidas');
    }

    try {
      final uri = ApiConfig.uri(ApiConfig.loginEndpoint, useWebProxy: true);
      final response = await http
          .post(
            uri,
            headers: const {
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'email': emailLimpio,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 20));

      final bodyText = utf8.decode(response.bodyBytes);
      final Map<String, dynamic> data = bodyText.isNotEmpty
          ? Map<String, dynamic>.from(jsonDecode(bodyText) as Map)
          : <String, dynamic>{};

      if (response.statusCode == 200 && data['usuario'] is Map) {
        final token = data['token']?.toString() ?? ApiConfig.defaultApiToken;
        await ApiConfig.guardarToken(token);

        final user = Usuario.fromJson(
          Map<String, dynamic>.from(data['usuario'] as Map),
        );

        _usuario = user;
        sessionUsuario = user;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_claveRecordar, recordarSesion);
        if (recordarSesion && user.id != null) {
          await prefs.setInt(_claveSesion, user.id!);
        }

        await _auditarLogin(user.nombre, 'INICIÓ SESIÓN');
        return ResultadoLogin.success(user, token: token);
      }

      if (response.statusCode == 403) {
        final detalle = data['detail']?.toString() ??
            'Tu usuario está inactivo. Comunícate con un administrador.';
        return ResultadoLogin.error(detalle);
      }

      final mensajeError = data['detail']?.toString() ?? 'Credenciales inválidas';
      return ResultadoLogin.error(mensajeError);
    } catch (e) {
      return const ResultadoLogin.error(
        'No se pudo conectar con el servidor de autenticación. Verifica tu conexión.',
      );
    }
  }

  /// Alias compatible con llamadas existentes en el proyecto.
  Future<ResultadoLogin> iniciarSesion(String correo, String clave) =>
      login(correo, clave);

  /// Cierra la sesión actual y limpia las credenciales almacenadas.
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

  /// Sincroniza rol/nombre de la sesión desde la API.
  Future<Usuario?> refrescarSesion() async {
    if (_usuario == null || _usuario!.id == null) return null;
    final u = await UsuariosApiService.instance.obtenerPorId(_usuario!.id!);
    if (u != null && u.activo) {
      _usuario = u;
      sessionUsuario = u;
    }
    return _usuario;
  }
}

/// Alias para mantener compatibilidad con todos los módulos de la app.
typedef SessionService = AuthService;

/// Usuario actual global.
Usuario? sessionUsuario;

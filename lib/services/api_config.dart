import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

/// Configuración centralizada de la API REST de SIGIF.
class ApiConfig {
  ApiConfig._();

  /// URL base oficial del backend desplegado en Vercel.
  static const String baseUrl = 'https://sigif-final.vercel.app/api/';

  /// Puente local CORS para Flutter Web (Chrome) que redirige hacia
  /// `https://sigif-final.vercel.app/api/` y valida login contra Supabase.
  static const String webProxyBaseUrl = 'http://127.0.0.1:8787/api/';

  /// Endpoints de recursos.
  static const String loginEndpoint = 'login/';
  static const String usuariosEndpoint = 'usuarios/';
  static const String productosEndpoint = 'productos/';
  static const String auditoriaEndpoint = 'auditoria/';
  static const String facturasEndpoint = 'facturas/';
  static const String tokenEndpoint = 'api-token-auth/';

  /// Token de autenticación DRF activo en el backend para operaciones protegidas.
  static const String defaultApiToken =
      'e075c35197a6be49916a4ad921c2512451a3f2d0';

  static const String _prefTokenKey = 'sigif_api_token';
  static String _tokenActual = defaultApiToken;

  static String get token => _tokenActual;

  static Future<void> inicializarToken() async {
    final prefs = await SharedPreferences.getInstance();
    final guardado = prefs.getString(_prefTokenKey);
    if (guardado != null && guardado.trim().isNotEmpty) {
      _tokenActual = guardado.trim();
    } else {
      _tokenActual = defaultApiToken;
    }
  }

  static Future<void> guardarToken(String nuevoToken) async {
    _tokenActual = nuevoToken.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefTokenKey, _tokenActual);
  }

  static Uri uri(
    String path, {
    Map<String, String>? queryParameters,
    bool useWebProxy = false,
  }) {
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    final root = (kIsWeb || useWebProxy) ? webProxyBaseUrl : baseUrl;
    final parsed = Uri.parse('$root$cleanPath');
    if (queryParameters == null || queryParameters.isEmpty) {
      return parsed;
    }
    return parsed.replace(queryParameters: queryParameters);
  }

  static Uri directUri(String path, [Map<String, String>? queryParameters]) {
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    final parsed = Uri.parse('$baseUrl$cleanPath');
    if (queryParameters == null || queryParameters.isEmpty) {
      return parsed;
    }
    return parsed.replace(queryParameters: queryParameters);
  }
}

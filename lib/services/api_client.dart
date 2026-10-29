import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import 'api_config.dart';

/// Excepción tipada para errores de red o respuestas HTTP no exitosas de la API.
class ApiException implements Exception {
  final int? statusCode;
  final String message;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Cliente HTTP centralizado para consumir la API REST (`https://sigif-final.vercel.app/api/`).
/// Implementa los métodos GET, POST, PUT, PATCH y DELETE con manejo de errores try-catch.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  final http.Client _http = http.Client();
  static const Duration _timeout = Duration(seconds: 20);
  String? _sessionCookie;
  String? _csrfToken;

  /// Asigna la cookie de sesión web usada por el backend para resolver el
  /// usuario SIGIF real y sus permisos de escritura.
  void establecerCookieSesion(String? cookie) {
    final valor = cookie?.trim();
    _sessionCookie = valor == null || valor.isEmpty ? null : valor;
    _csrfToken = _valorCookie('csrftoken');
  }

  /// Convierte una o varias cabeceras `Set-Cookie` en una cabecera `Cookie`.
  static String? cookiesDesdeSetCookie(String? setCookie) {
    if (setCookie == null || setCookie.trim().isEmpty) return null;

    final cookies = <String, String>{};
    final expresion = RegExp(r'(?:^|,\s*)([A-Za-z0-9_-]+)=([^;,\s]+)');
    for (final coincidencia in expresion.allMatches(setCookie)) {
      cookies[coincidencia.group(1)!] = coincidencia.group(2)!;
    }
    if (cookies.isEmpty) return null;
    return cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  static String? combinarCookies(String? anteriores, String? nuevas) {
    final cookies = <String, String>{};
    final expresion = RegExp(r'(?:^|;\s*)([A-Za-z0-9_-]+)=([^;,\s]+)');
    for (final fuente in [anteriores, nuevas]) {
      if (fuente == null) continue;
      for (final coincidencia in expresion.allMatches(fuente)) {
        cookies[coincidencia.group(1)!] = coincidencia.group(2)!;
      }
    }
    if (cookies.isEmpty) return null;
    return cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  void limpiarCookieSesion() {
    _sessionCookie = null;
    _csrfToken = null;
  }

  Future<void> postSesionWeb(
    String endpoint, {
    Map<String, String> body = const {},
  }) async {
    if (_sessionCookie == null || _csrfToken == null) {
      throw const ApiException('La sesión web no está autenticada.');
    }

    final request =
        http.Request(
            'POST',
            Uri.parse('https://sigif-final.vercel.app/$endpoint'),
          )
          ..followRedirects = false
          ..headers.addAll({
            'Accept': 'text/html',
            'Content-Type': 'application/x-www-form-urlencoded',
            'Cookie': _sessionCookie!,
            'Referer': 'https://sigif-final.vercel.app/',
            'X-CSRFToken': _csrfToken!,
          })
          ..bodyFields = {'csrfmiddlewaretoken': _csrfToken!, ...body};

    final response = await _http.send(request).timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 400) {
      throw ApiException(
        'El servidor no pudo actualizar el estado (HTTP ${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }
  }

  String? _valorCookie(String nombre) {
    final cookie = _sessionCookie;
    if (cookie == null) return null;
    for (final parte in cookie.split(';')) {
      final separador = parte.indexOf('=');
      if (separador <= 0) continue;
      if (parte.substring(0, separador).trim() == nombre) {
        return parte.substring(separador + 1).trim();
      }
    }
    return null;
  }

  Map<String, String> _headers({bool jsonBody = false, bool useAuth = true}) {
    final headers = <String, String>{'Accept': 'application/json'};
    if (jsonBody) {
      headers['Content-Type'] = 'application/json; charset=utf-8';
    }
    if (useAuth && ApiConfig.token.isNotEmpty) {
      headers['Authorization'] = 'Token ${ApiConfig.token}';
    }
    if (_sessionCookie != null) {
      headers['Cookie'] = _sessionCookie!;
    }
    if (_csrfToken != null) {
      headers['X-CSRFToken'] = _csrfToken!;
    }
    return headers;
  }

  Future<http.Response> _ejecutarConFallback(
    Future<http.Response> Function(Uri uri) peticion,
    String endpoint, {
    Map<String, String>? queryParameters,
  }) async {
    final primaryUri = ApiConfig.uri(
      endpoint,
      queryParameters: queryParameters,
    );
    try {
      return await peticion(primaryUri).timeout(_timeout);
    } catch (_) {
      if (kIsWeb) {
        final fallbackUri = ApiConfig.directUri(endpoint, queryParameters);
        return await peticion(fallbackUri).timeout(_timeout);
      }
      rethrow;
    }
  }

  /// GET que retorna una lista JSON (`List<Map<String, dynamic>>`).
  Future<List<Map<String, dynamic>>> getList(
    String endpoint, {
    Map<String, String>? queryParameters,
    bool useAuth = true,
  }) async {
    try {
      final response = await _ejecutarConFallback(
        (uri) => _http.get(uri, headers: _headers(useAuth: useAuth)),
        endpoint,
        queryParameters: queryParameters,
      );
      _verificarEstado(response);
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      if (decoded is Map && decoded['results'] is List) {
        return (decoded['results'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException(
        'Tiempo de espera agotado al conectar con el servidor.',
      );
    } catch (e) {
      throw ApiException('Error de conexión con la API: $e');
    }
  }

  /// GET que retorna un objeto JSON (`Map<String, dynamic>`).
  Future<Map<String, dynamic>> getMap(
    String endpoint, {
    bool useAuth = true,
  }) async {
    try {
      final response = await _ejecutarConFallback(
        (uri) => _http.get(uri, headers: _headers(useAuth: useAuth)),
        endpoint,
      );
      _verificarEstado(response);
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      throw const ApiException('Formato de respuesta inesperado del servidor.');
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException(
        'Tiempo de espera agotado al conectar con el servidor.',
      );
    } catch (e) {
      throw ApiException('Error de conexión con la API: $e');
    }
  }

  /// POST que envía un cuerpo JSON y retorna el objeto creado (`Map<String, dynamic>`).
  Future<Map<String, dynamic>> postMap(
    String endpoint,
    Map<String, dynamic> body, {
    bool useAuth = true,
  }) async {
    try {
      final response = await _ejecutarConFallback(
        (uri) => _http.post(
          uri,
          headers: _headers(jsonBody: true, useAuth: useAuth),
          body: jsonEncode(body),
        ),
        endpoint,
      );
      _verificarEstado(response);
      if (response.bodyBytes.isEmpty) return body;
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return body;
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException(
        'Tiempo de espera agotado al conectar con el servidor.',
      );
    } catch (e) {
      throw ApiException('Error de conexión con la API: $e');
    }
  }

  /// PUT para actualización completa de un recurso.
  Future<Map<String, dynamic>> putMap(
    String endpoint,
    Map<String, dynamic> body, {
    bool useAuth = true,
  }) async {
    try {
      final response = await _ejecutarConFallback(
        (uri) => _http.put(
          uri,
          headers: _headers(jsonBody: true, useAuth: useAuth),
          body: jsonEncode(body),
        ),
        endpoint,
      );
      _verificarEstado(response);
      if (response.bodyBytes.isEmpty) return body;
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return body;
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException(
        'Tiempo de espera agotado al conectar con el servidor.',
      );
    } catch (e) {
      throw ApiException('Error de conexión con la API: $e');
    }
  }

  /// PATCH para actualización parcial de un recurso.
  Future<Map<String, dynamic>> patchMap(
    String endpoint,
    Map<String, dynamic> body, {
    bool useAuth = true,
  }) async {
    try {
      final response = await _ejecutarConFallback(
        (uri) => _http.patch(
          uri,
          headers: _headers(jsonBody: true, useAuth: useAuth),
          body: jsonEncode(body),
        ),
        endpoint,
      );
      _verificarEstado(response);
      if (response.bodyBytes.isEmpty) return body;
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return body;
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException(
        'Tiempo de espera agotado al conectar con el servidor.',
      );
    } catch (e) {
      throw ApiException('Error de conexión con la API: $e');
    }
  }

  /// DELETE para eliminar un recurso por su endpoint (`usuarios/1/`, `productos/1/`).
  Future<void> delete(String endpoint, {bool useAuth = true}) async {
    try {
      final response = await _ejecutarConFallback(
        (uri) => _http.delete(uri, headers: _headers(useAuth: useAuth)),
        endpoint,
      );
      _verificarEstado(response);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException(
        'Tiempo de espera agotado al conectar con el servidor.',
      );
    } catch (e) {
      throw ApiException('Error de conexión con la API: $e');
    }
  }

  void _verificarEstado(http.Response response) {
    final code = response.statusCode;
    if (code >= 200 && code < 300) return;

    String detalle = 'Error HTTP $code';
    try {
      final text = utf8.decode(response.bodyBytes);
      if (text.trim().startsWith('{') || text.trim().startsWith('[')) {
        final decoded = jsonDecode(text);
        if (decoded is Map) {
          if (decoded['detail'] != null) {
            detalle = decoded['detail'].toString();
          } else if (decoded['error'] != null) {
            detalle = decoded['error'].toString();
          } else {
            final partes = <String>[];
            decoded.forEach((key, value) {
              if (value is List) {
                partes.add('$key: ${value.join(", ")}');
              } else {
                partes.add('$key: $value');
              }
            });
            if (partes.isNotEmpty) detalle = partes.join(' | ');
          }
        }
      } else if (code == 403) {
        detalle = 'Permiso denegado por el servidor (403).';
      } else if (code == 404) {
        detalle = 'Recurso no encontrado en el servidor (404).';
      } else if (code == 400) {
        detalle = 'Datos inválidos enviados al servidor (400).';
      }
    } catch (_) {}

    throw ApiException(detalle, statusCode: code);
  }
}

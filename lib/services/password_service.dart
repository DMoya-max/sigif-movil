import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

/// Gestiona el cifrado de contraseñas con PBKDF2-HMAC-SHA256.
/// El formato almacenado es `pbkdf2_sha256$<iteraciones>$<salt hex>$<hash hex>`,
/// equivalente al hash generado por Django, lo que permite portar usuarios.
class PasswordService {
  PasswordService._();

  static const int _iteraciones = 100000;
  static const int _bits = 256;
  static final Pbkdf2 _pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: _iteraciones,
    bits: _bits,
  );

  static Future<String> crearHash(String clave) async {
    final rng = Random.secure();
    final salt = List<int>.generate(16, (_) => rng.nextInt(256));
    final hash = await _derivar(clave, salt);
    return 'pbkdf2_sha256\$$_iteraciones\$${_hex(salt)}\$${_hex(hash)}';
  }

  static Future<bool> verificar(String clave, String hashAlmacenado) async {
    try {
      final partes = hashAlmacenado.split('\$');
      if (partes.length != 4 || partes[0] != 'pbkdf2_sha256') return false;
      final iteraciones = int.tryParse(partes[1]) ?? _iteraciones;
      final salt = _deHex(partes[2]);
      final hashEsperado = _deHex(partes[3]);
      final derivado = await _derivar(clave, salt, iteraciones: iteraciones);
      return _hashesIguales(derivado, hashEsperado);
    } catch (_) {
      return false;
    }
  }

  static Future<List<int>> _derivar(String clave, List<int> salt, {int? iteraciones}) async {
    final pbkdf2 = _iteraciones == iteraciones
        ? _pbkdf2
        : Pbkdf2(
            macAlgorithm: Hmac.sha256(),
            iterations: iteraciones ?? _iteraciones,
            bits: _bits,
          );
    final claveSecreta = await pbkdf2.deriveKeyFromPassword(
      password: clave,
      nonce: salt,
    );
    return claveSecreta.extractBytes();
  }

  static String _hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static List<int> _deHex(String hex) {
    if (hex.length.isOdd) return const [];
    return List<int>.generate(
      hex.length ~/ 2,
      (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16),
    );
  }

  static bool _hashesIguales(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  static String base64Verificacion(List<int> bytes) => base64Encode(bytes);
}
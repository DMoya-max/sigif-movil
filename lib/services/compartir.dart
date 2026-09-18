import 'dart:typed_data';

import 'compartir_io.dart' if (dart.library.js_interop) 'compartir_web.dart';

class Compartir {
  static Future<void> guardar({
    required Uint8List bytes,
    required String nombre,
    String mensaje = '',
  }) {
    return guardarArchivo(
      bytes: bytes,
      nombre: nombre,
      mensaje: mensaje,
    );
  }
}

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Descarga un archivo en el navegador (versión web).
Future<void> guardarArchivo({
  required Uint8List bytes,
  required String nombre,
  String mensaje = '',
}) async {
  final jsBytes = bytes.toJS;
  final blob = web.Blob(
    [jsBytes].toJS,
    web.BlobPropertyBag(type: _mime(nombre)),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = nombre
    ..style.display = 'none';
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}

String _mime(String nombre) {
  final ext = nombre.contains('.')
      ? nombre.substring(nombre.lastIndexOf('.') + 1).toLowerCase()
      : '';
  switch (ext) {
    case 'pdf':
      return 'application/pdf';
    case 'csv':
      return 'text/csv;charset=utf-8';
    default:
      return 'application/octet-stream';
  }
}
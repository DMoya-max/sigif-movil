import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Guarda y comparte un archivo usando los canales nativos (móvil/escritorio).
Future<void> guardarArchivo({
  required Uint8List bytes,
  required String nombre,
  String mensaje = '',
}) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$nombre');
  await file.writeAsBytes(bytes);
  await SharePlus.instance.share(
    ShareParams(files: [XFile(file.path)], text: mensaje),
  );
}
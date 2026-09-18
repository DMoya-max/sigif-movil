import 'dart:io' show Platform;

bool get esEntornoPruebas => Platform.environment['FLUTTER_TEST'] == 'true';
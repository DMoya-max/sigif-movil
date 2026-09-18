import 'package:flutter/material.dart';

import 'db/database.dart';
import 'screens/home/app_shell.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  inicializarSqflite();
  await SessionService.instance.cargarSesion();
  runApp(const SigifApp());
}

class SigifApp extends StatelessWidget {
  const SigifApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SIGIF',
      theme: AppTheme.tema(),
      home: SessionService.instance.estaLogueado
          ? AppShell(usuario: SessionService.instance.usuario!)
          : const LoginScreen(),
    );
  }
}
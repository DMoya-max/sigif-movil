import 'package:flutter/material.dart';

import '../models/usuario.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'home/app_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _cargando = false;
  bool _ocultarPassword = true;
  String? _mensajeError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _iniciarSesion() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _cargando = true;
      _mensajeError = null;
    });

    final resultado = await AuthService.instance.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    if (resultado.success && resultado.usuario != null) {
      setState(() => _cargando = false);
      _navegarAlDashboard(resultado.usuario!);
    } else {
      final errorMsg = resultado.message.isNotEmpty
          ? resultado.message
          : 'Credenciales inválidas';
      setState(() {
        _cargando = false;
        _mensajeError = errorMsg;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(errorMsg)),
              ],
            ),
            backgroundColor: ColoresSigif.peligro,
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  void _navegarAlDashboard(Usuario usuario) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => AppShell(usuario: usuario)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final anchoPantalla = MediaQuery.of(context).size.width;
    final esMovil = anchoPantalla < 480;
    final cardWidth = anchoPantalla * (esMovil ? 0.94 : 0.9);
    final constrainedWidth = cardWidth > 440 ? 440.0 : cardWidth;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF222938), Color(0xFF3A4A63), Color(0xFFF5F6FA)],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        alignment: Alignment.center,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(esMovil ? 12 : 16),
            child: Center(
              child: Card(
                elevation: 12,
                shadowColor: Colors.black26,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  width: constrainedWidth,
                  padding: EdgeInsets.symmetric(
                    horizontal: esMovil ? 20 : 28,
                    vertical: esMovil ? 24 : 30,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          'assets/img/logologin1.png',
                          height: esMovil ? 88 : 105,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) =>
                              FlutterLogo(size: esMovil ? 80 : 96),
                        ),
                      ),
                    const SizedBox(height: 8),
                    const Text(
                      'SIGIF',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: ColoresSigif.navy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Inventario y Facturación',
                      style: TextStyle(color: ColoresSigif.textoMitigado),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Inicio de sesión',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Ingrese el correo y contraseña registrados en el sistema',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54, fontSize: 13),
                    ),
                    const SizedBox(height: 18),
                    if (_mensajeError != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: ColoresSigif.peligro.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: ColoresSigif.peligro.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: ColoresSigif.peligro,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _mensajeError!,
                                style: const TextStyle(
                                  color: ColoresSigif.peligro,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Ingresa tu correo electrónico';
                              }
                              if (!v.contains('@') || !v.contains('.')) {
                                return 'Ingresa un correo electrónico válido';
                              }
                              return null;
                            },
                            decoration: const InputDecoration(
                              labelText: 'Correo electrónico',
                              hintText: 'ejemplo@correo.com',
                              prefixIcon: Icon(Icons.mail_outline),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _ocultarPassword,
                            onFieldSubmitted: (_) => _iniciarSesion(),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Ingresa tu contraseña';
                              }
                              return null;
                            },
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                tooltip: _ocultarPassword
                                    ? 'Mostrar contraseña'
                                    : 'Ocultar contraseña',
                                icon: Icon(
                                  _ocultarPassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _ocultarPassword = !_ocultarPassword;
                                  });
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _cargando ? null : _iniciarSesion,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ColoresSigif.azulPrimario,
                              ),
                              child: _cargando
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Text('Iniciar Sesión'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        ),
      ),
    );
  }
}

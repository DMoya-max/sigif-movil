import 'package:flutter/material.dart';

import '../models/usuario.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
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
  bool _mensajeInicial = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_mensajeInicial && SessionService.instance.recordarSesion == false) {
        _mensajeInicial = false;
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _cargando = true);
    final resultado = await SessionService.instance
        .iniciarSesion(_emailController.text, _passwordController.text);
    if (!mounted) return;

    if (resultado.success) {
      final usuario = resultado.usuario!;
      setState(() => _cargando = false);
      _irAlInicio(usuario);
    } else {
      setState(() => _cargando = false);
      notificar(context, resultado.message, error: true);
    }
  }

  void _irAlInicio(Usuario usuario) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => AppShell(usuario: usuario)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final anchoPantalla = MediaQuery.of(context).size.width;
    final cardWidth = anchoPantalla * 0.9;
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Card(
              elevation: 12,
              shadowColor: Colors.black26,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: constrainedWidth,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/img/logologin.png',
                        height: 96,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const FlutterLogo(size: 96),
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
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Ingrese su correo y contraseña',
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 18),

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
                                return 'Ingresa tu correo';
                              }
                              if (!v.contains('@')) return 'Correo inválido';
                              return null;
                            },
                            decoration: const InputDecoration(
                              labelText: 'Correo electrónico',
                              prefixIcon: Icon(Icons.mail_outline),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            onFieldSubmitted: (_) => _onLogin(),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Ingresa tu contraseña';
                              }
                              return null;
                            },
                            decoration: const InputDecoration(
                              labelText: 'Contraseña',
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _cargando ? null : _onLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ColoresSigif.azulPrimario,
                              ),
                              child: _cargando
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2.5),
                                    )
                                  : const Text('Ingresar'),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Sesión por defecto: admin@sigif.com / admin1234',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 11.5, color: ColoresSigif.textoMitigado),
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
    );
  }
}
import 'package:flutter/material.dart';

import '../../core/sanitizacion.dart';
import '../../db/repos/auditoria_repository.dart';
import '../../models/usuario.dart';
import '../../services/auth_service.dart';
import '../../services/usuarios_api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Perfil del usuario en sesión: visualización + edición de datos propios
/// (con documento y rol en solo lectura igual que `editar_usuarios.html`).
class UsuarioPerfilScreen extends StatefulWidget {
  final Usuario usuario;

  const UsuarioPerfilScreen({super.key, required this.usuario});

  @override
  State<UsuarioPerfilScreen> createState() => _UsuarioPerfilScreenState();
}

class _UsuarioPerfilScreenState extends State<UsuarioPerfilScreen> {
  late Usuario _usuario;
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  late final TextEditingController _documento;
  late final TextEditingController _telefono;
  late final TextEditingController _correo;
  final _clave = TextEditingController();
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _usuario = widget.usuario;
    _nombre = TextEditingController(text: _usuario.nombre);
    _documento = TextEditingController(text: _usuario.documento);
    _telefono = TextEditingController(text: _usuario.telefono);
    _correo = TextEditingController(text: _usuario.correo);
  }

  @override
  void dispose() {
    _nombre.dispose();
    _documento.dispose();
    _telefono.dispose();
    _correo.dispose();
    _clave.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _guardando = true);

    final nombreLimpio = Sanitizacion.limpiarNonNull(_nombre.text.trim())
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .join(' ');
    final telefono = _telefono.text.trim();
    final correo = _correo.text.trim().toLowerCase();

    try {
      final errorUnicidad = await UsuariosApiService.instance.validarUnicidad(
        documento: _usuario.documento,
        telefono: telefono,
        correo: correo,
        excluirId: _usuario.id,
      );
      if (errorUnicidad != null) {
        if (!mounted) return;
        setState(() => _guardando = false);
        notificar(context, errorUnicidad, error: true);
        return;
      }

      // SEGURIDAD: el propio usuario nunca puede alterar su documento, su rol ni su estado activo
      final actualizado = await UsuariosApiService.instance.actualizar(
        Usuario(
          id: _usuario.id,
          nombre: nombreLimpio,
          documento: _usuario.documento,
          contra: _usuario.contra,
          telefono: telefono,
          correo: correo,
          activo: _usuario.activo,
          fechaInicio: _usuario.fechaInicio,
          cargo: _usuario.cargo,
          esSuperadminPrincipal: _usuario.esSuperadminPrincipal,
        ),
        nuevaClavePlana: _clave.text.trim().isEmpty ? null : _clave.text.trim(),
      );

      try {
        final aud = await AuditoriaRepository.abrir();
        await aud.registrar(
          usuario: actualizado.nombre,
          accion: 'ACTUALIZÓ PERFIL/USUARIO: ${actualizado.nombre}',
          modulo: 'USUARIOS',
        );
      } catch (_) {}

      SessionService.instance.actualizarUsuario(actualizado);
      if (!mounted) return;
      setState(() {
        _usuario = actualizado;
        _guardando = false;
      });
      notificar(
        context,
        'El usuario ${actualizado.nombre} fue actualizado correctamente.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      notificar(context, 'Error: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar Perfil de Usuario')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: ColoresSigif.azulPrimario,
                  child: Text(
                    _usuario.nombre.isNotEmpty
                        ? _usuario.nombre[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _usuario.nombre,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_usuario.cargo} (Rol protegido)',
                    style: const TextStyle(
                      color: ColoresSigif.azulPrimario,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _nombre,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'El nombre del empleado es obligatorio para continuar.';
                    }
                    final texto = v.trim();
                    if (!RegExp(r'^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s]+$')
                        .hasMatch(texto)) {
                      return 'El nombre solo puede contener letras y espacios.';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                    labelText: 'Nombre del empleado *',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _documento,
                  readOnly: true,
                  enabled: false,
                  decoration: const InputDecoration(
                    labelText: 'Documento de identidad (solo lectura)',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _telefono,
                  keyboardType: TextInputType.phone,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'El teléfono es obligatorio para continuar.';
                    }
                    if (!RegExp(r'^\d+$').hasMatch(v.trim())) {
                      return 'El teléfono solo puede contener números.';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                    labelText: 'Teléfono de contacto *',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _correo,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'El correo electrónico es obligatorio para continuar.';
                    }
                    if (!v.contains('@') || !v.contains('.')) {
                      return 'Ingresa un correo electrónico válido.';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico *',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _clave,
                  obscureText: true,
                  validator: (v) {
                    if (v != null && v.isNotEmpty && v.length < 8) {
                      return 'La contraseña debe tener como mínimo 8 caracteres.';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                    labelText: 'Nueva contraseña (opcional)',
                    prefixIcon: Icon(Icons.key_outlined),
                    helperText:
                        'Deja este campo vacío si no deseas cambiar la contraseña.',
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _guardando ? null : _guardar,
                    icon: _guardando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_guardando ? 'Guardando...' : 'Guardar Cambios'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

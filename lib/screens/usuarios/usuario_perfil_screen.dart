import 'package:flutter/material.dart';

import '../../core/sanitizacion.dart';
import '../../db/database.dart';
import '../../db/repos/auditoria_repository.dart';
import '../../db/repos/usuarios_repository.dart';
import '../../models/usuario.dart';
import '../../services/auth_service.dart';
import '../../services/password_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Perfil del usuario en sesión: visualización + edición de datos propios.
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
    final repo = await UsuariosRepository.abrir();
    final db = await AppDatabase.instance.db;

    try {
      await repo.actualizar(Usuario(
        id: _usuario.id,
        nombre: Sanitizacion.limpiarNonNull(_nombre.text.trim()),
        documento: _documento.text.trim(),
        contra: _usuario.contra,
        telefono: _telefono.text.trim(),
        correo: _correo.text.trim().toLowerCase(),
        activo: _usuario.activo,
        fechaInicio: _usuario.fechaInicio,
        cargo: _usuario.cargo,
        esSuperadminPrincipal: _usuario.esSuperadminPrincipal,
      ));
      if (_clave.text.trim().isNotEmpty) {
        final hash = await PasswordService.crearHash(_clave.text);
        await db.update('usuarios', {'contra': hash},
            where: 'id = ?', whereArgs: [_usuario.id]);
      }
      await AuditoriaRepository(db).registrar(
        usuario: _usuario.nombre,
        accion: 'ACTUALIZÓ SU PERFIL',
        modulo: 'USUARIOS',
      );

      final actualizado = await repo.obtenerPorId(_usuario.id!);
      if (actualizado != null) {
        SessionService.instance.actualizarUsuario(actualizado);
        setState(() => _usuario = actualizado);
      }
      if (!mounted) return;
      notificar(context, 'Perfil actualizado');
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      notificar(context, 'Error: $e', error: true);
      return;
    }
    if (!mounted) return;
    setState(() => _guardando = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
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
                    _usuario.nombre.isNotEmpty ? _usuario.nombre[0].toUpperCase() : '?',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 10),
                Text(_usuario.nombre,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)),
                Text(_usuario.cargo,
                    style: const TextStyle(color: ColoresSigif.textoMitigado)),
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
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Ingresa el nombre' : null,
                  decoration: const InputDecoration(labelText: 'Nombre completo *'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _documento,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Ingresa el documento' : null,
                  decoration: const InputDecoration(labelText: 'Documento *'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _telefono,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Ingresa el teléfono' : null,
                  decoration: const InputDecoration(labelText: 'Teléfono *'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _correo,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Ingresa el correo';
                    if (!v.contains('@')) return 'Correo inválido';
                    return null;
                  },
                  decoration: const InputDecoration(labelText: 'Correo *'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _clave,
                  obscureText: true,
                  validator: (v) {
                    if (v != null && v.isNotEmpty && v.length < 6) {
                      return 'Mínimo 6 caracteres';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                    labelText: 'Nueva contraseña (opcional)',
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _guardando ? null : _guardar,
                    icon: _guardando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_guardando ? 'Guardando...' : 'Guardar cambios'),
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
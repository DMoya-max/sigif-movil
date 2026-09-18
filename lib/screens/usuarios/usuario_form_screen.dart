import 'package:flutter/material.dart';

import '../../core/constantes.dart';
import '../../core/sanitizacion.dart';
import '../../db/database.dart';
import '../../db/repos/auditoria_repository.dart';
import '../../db/repos/usuarios_repository.dart';
import '../../models/usuario.dart';
import '../../services/password_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Formulario de creación/edición de usuarios con reglas de escalada.
class UsuarioFormScreen extends StatefulWidget {
  final Usuario? usuario;
  final Usuario? actor;

  const UsuarioFormScreen({super.key, this.usuario, this.actor});

  @override
  State<UsuarioFormScreen> createState() => _UsuarioFormScreenState();
}

class _UsuarioFormScreenState extends State<UsuarioFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  late final TextEditingController _documento;
  late final TextEditingController _telefono;
  late final TextEditingController _correo;
  late final TextEditingController _clave;
  late String _cargo;
  bool _guardando = false;

  bool get _esNuevo => widget.usuario == null;

  bool _puedeSeleccionarCargo(Usuario? actor, Usuario? target) {
    if (target != null && target.esSuperadminPrincipal) return false;
    if (actor == null) return false;
    if (actor.cargo == 'SuperAdmin') return true;
    // Admin sólo gestiona Empleado
    return target == null || target.cargo == 'Empleado';
  }

  List<String> get _cargosPermitidos {
    if (!_puedeSeleccionarCargo(widget.actor, widget.usuario)) {
      return [_cargo];
    }
    if (widget.actor?.cargo == 'SuperAdmin') {
      return Constantes.cargos;
    }
    return [Constantes.rolEmpleado];
  }

  String? get _cargoInicial {
    final target = widget.usuario;
    if (target != null) return target.cargo;
    if (widget.actor?.cargo == 'SuperAdmin') return Constantes.rolEmpleado;
    return Constantes.rolEmpleado;
  }

  @override
  void initState() {
    super.initState();
    final u = widget.usuario;
    _nombre = TextEditingController(text: u?.nombre ?? '');
    _documento = TextEditingController(text: u?.documento ?? '');
    _telefono = TextEditingController(text: u?.telefono ?? '');
    _correo = TextEditingController(text: u?.correo ?? '');
    _clave = TextEditingController();
    _cargo = _cargoInicial!;
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
    final nombre = Sanitizacion.limpiarNonNull(_nombre.text.trim());
    final documento = _documento.text.trim();
    final telefono = _telefono.text.trim();
    final correo = _correo.text.trim().toLowerCase();

    try {
      if (_esNuevo) {
        final hash = await PasswordService.crearHash(_clave.text);
        await repo.crear(Usuario(
          nombre: nombre,
          documento: documento,
          contra: hash,
          telefono: telefono,
          correo: correo,
          activo: true,
          fechaInicio: DateTime.now(),
          cargo: _cargo,
          esSuperadminPrincipal: false,
        ));
      } else {
        final u = widget.usuario!;
        await repo.actualizar(Usuario(
          id: u.id,
          nombre: nombre,
          documento: documento,
          contra: u.contra,
          telefono: telefono,
          correo: correo,
          activo: u.activo,
          fechaInicio: u.fechaInicio,
          cargo: _puedeSeleccionarCargo(widget.actor, u) ? _cargo : u.cargo,
          esSuperadminPrincipal: u.esSuperadminPrincipal,
        ));
        if (_clave.text.trim().isNotEmpty) {
          final hash = await PasswordService.crearHash(_clave.text);
          await _dbRawNuevaClave(u.id!, hash);
        }
      }

      final aud = await AuditoriaRepository.abrir();
      await aud.registrar(
        usuario: widget.actor?.nombre ?? '',
        accion: _esNuevo
            ? 'CREÓ EL USUARIO $nombre ($_cargo)'
            : 'EDITÓ EL USUARIO $nombre',
        modulo: 'USUARIOS',
      );

      if (!mounted) return;
      notificar(context, _esNuevo ? 'Usuario creado' : 'Usuario actualizado');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      notificar(context, 'Error: $e', error: true);
      setState(() => _guardando = false);
    }
  }

  Future<void> _dbRawNuevaClave(int id, String hash) async {
    final db = await AppDatabase.instance.db;
    await db.update('usuarios', {'contra': hash}, where: 'id = ?', whereArgs: [id]);
  }

  String? _validarObligatorio(String? v, String campo) {
    if (v == null || v.trim().isEmpty) return 'Ingresa $campo';
    return null;
  }

  Future<String?> _validarUnico() async {
    final repo = await UsuariosRepository.abrir();
    final doc = _documento.text.trim();
    final tel = _telefono.text.trim();
    final corr = _correo.text.trim().toLowerCase();
    final id = widget.usuario?.id;
    if (await repo.existeDocumento(doc, excluirId: id)) return 'Documento ya registrado';
    if (await repo.existeTelefono(tel, excluirId: id)) return 'Teléfono ya registrado';
    if (await repo.existeCorreo(corr, excluirId: id)) return 'Correo ya registrado';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final esEditableRol = _puedeSeleccionarCargo(widget.actor, widget.usuario);
    return Scaffold(
      appBar: AppBar(
        title: Text(_esNuevo ? 'Nuevo usuario' : 'Editar usuario'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _nombre,
              textCapitalization: TextCapitalization.words,
              validator: (v) => _validarObligatorio(v, 'el nombre'),
              decoration: const InputDecoration(labelText: 'Nombre completo *'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _documento,
              keyboardType: TextInputType.text,
              validator: (v) => _validarObligatorio(v, 'el documento'),
              decoration: const InputDecoration(labelText: 'Documento *'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _telefono,
              keyboardType: TextInputType.phone,
              validator: (v) => _validarObligatorio(v, 'el teléfono'),
              decoration: const InputDecoration(labelText: 'Teléfono *'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _correo,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Ingresa el correo';
                if (!v.contains('@')) return 'Correo inválido';
                return null;
              },
              decoration: const InputDecoration(labelText: 'Correo *'),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _cargo,
              items: [
                for (final c in _cargosPermitidos)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              decoration: const InputDecoration(labelText: 'Cargo'),
              onChanged: esEditableRol
                  ? (v) => setState(() => _cargo = v!)
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _clave,
              obscureText: true,
              validator: (v) {
                if (_esNuevo && (v == null || v.isEmpty)) {
                  return 'La contraseña es obligatoria';
                }
                if (v != null && v.isNotEmpty && v.length < 6) {
                  return 'Mínimo 6 caracteres';
                }
                return null;
              },
              decoration: InputDecoration(
                labelText: _esNuevo
                    ? 'Contraseña *'
                    : 'Nueva contraseña (opcional)',
                helperText: _esNuevo ? null : 'Dejar vacío para conservar.',
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
                label: Text(_guardando ? 'Guardando...' : 'Guardar'),
              ),
            ),
            const SizedBox(height: 12),
            FutureBuilder<String?>(
              future: _validarUnico(),
              builder: (context, snap) {
                if (snap.data == null) return const SizedBox.shrink();
                return Text(
                  snap.data!,
                  style: const TextStyle(
                      color: ColoresSigif.peligro, fontSize: 12.5),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
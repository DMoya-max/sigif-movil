import 'package:flutter/material.dart';

import '../../core/constantes.dart';
import '../../core/sanitizacion.dart';
import '../../db/repos/auditoria_repository.dart';
import '../../models/usuario.dart';
import '../../services/auth_service.dart';
import '../../services/usuarios_api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Formulario de creación/edición de usuarios conectado a la API REST
/// con la matriz de permisos, escalada de roles y validaciones de unicidad del proyecto.
class UsuarioFormScreen extends StatefulWidget {
  final Usuario? usuario;
  final Usuario? actor;

  const UsuarioFormScreen({super.key, this.usuario, this.actor});

  @override
  State<UsuarioFormScreen> createState() => _UsuarioFormScreenState();
}

class _UsuarioFormScreenState extends State<UsuarioFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = UsuariosApiService.instance;
  late final TextEditingController _nombre;
  late final TextEditingController _documento;
  late final TextEditingController _telefono;
  late final TextEditingController _correo;
  late final TextEditingController _clave;
  late String _cargo;
  late bool _activo;
  bool _guardando = false;

  bool get _esNuevo => widget.usuario == null;

  Usuario? get _actor => widget.actor ?? SessionService.instance.usuario;

  bool get _esPropioUsuario =>
      !_esNuevo && _actor != null && widget.usuario?.id == _actor?.id;

  bool get _puedeEditarCargo =>
      _actor?.puedeCambiarCargo(target: widget.usuario) ?? false;

  bool get _puedeEditarEstado {
    if (_esNuevo) return true;
    final actor = _actor;
    final target = widget.usuario;
    if (actor == null || target == null) return false;
    return actor.puedeCambiarEstadoUsuario(target);
  }

  List<String> get _cargosDisponibles {
    final actor = _actor;
    if (actor == null) return [_cargo];
    final permitidos = actor.cargosAsignables(target: widget.usuario);
    if (!permitidos.contains(_cargo)) {
      return [...permitidos, _cargo];
    }
    return permitidos;
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
    _cargo = u?.cargo ?? Constantes.rolEmpleado;
    _activo = u?.activo ?? true;
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

    final actor = _actor;
    if (actor == null) {
      notificar(context, 'Debes iniciar sesión para continuar.', error: true);
      return;
    }

    // 1. Validación de permisos y escalada de privilegios (apps/usuarios/views.py + core/decoradores.py)
    if (_esNuevo) {
      if (!actor.puedeGestionarUsuarios) {
        notificar(
          context,
          'No tienes permisos para crear usuarios.',
          error: true,
        );
        return;
      }
      if (_cargo == Constantes.rolSuperAdmin && !actor.esSuperAdmin) {
        notificar(
          context,
          'Solo el SuperAdmin puede crear otro SuperAdmin.',
          error: true,
        );
        return;
      }
    } else {
      final target = widget.usuario!;
      final motivoRechazo = actor.motivoRechazoEditar(target);
      if (motivoRechazo != null) {
        notificar(context, motivoRechazo, error: true);
        return;
      }
      if (!_esPropioUsuario &&
          _cargo == Constantes.rolSuperAdmin &&
          target.cargo != Constantes.rolSuperAdmin &&
          !actor.esSuperAdmin) {
        notificar(
          context,
          'Un Administrador no puede asignar el rol de SuperAdmin.',
          error: true,
        );
        return;
      }
    }

    setState(() => _guardando = true);

    // Normalizar espacios múltiples del nombre igual que clean_nombre en Django
    final nombreLimpio = Sanitizacion.limpiarNonNull(_nombre.text.trim())
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .join(' ');
    // En edición el documento original no se altera (editar_usuarios.html)
    final documento = _esNuevo
        ? _documento.text.trim()
        : widget.usuario!.documento.trim();
    final telefono = _telefono.text.trim();
    final correo = _correo.text.trim().toLowerCase();
    final clave = _clave.text.trim();

    try {
      // 2. Validación de unicidad en el sistema (clean_documento, clean_telefono, clean_correo)
      final errorUnicidad = await _api.validarUnicidad(
        documento: documento,
        telefono: telefono,
        correo: correo,
        excluirId: widget.usuario?.id,
      );
      if (errorUnicidad != null) {
        if (!mounted) return;
        setState(() => _guardando = false);
        notificar(context, errorUnicidad, error: true);
        return;
      }

      if (_esNuevo) {
        await _api.crear(
          Usuario(
            nombre: nombreLimpio,
            documento: documento,
            telefono: telefono,
            correo: correo,
            activo: _activo,
            fechaInicio: DateTime.now(),
            cargo: _cargo,
            esSuperadminPrincipal: false,
          ),
          clavePlana: clave,
        );
      } else {
        final u = widget.usuario!;
        // Reglas de protección al guardar (apps/usuarios/views.py líneas 304-324):
        // - El propio usuario o un Empleado nunca cambia su rol.
        // - El SuperAdmin principal conserva siempre rol SuperAdmin y activo = true.
        var cargoFinal = _puedeEditarCargo ? _cargo : u.cargo;
        var activoFinal = _puedeEditarEstado ? _activo : u.activo;

        if (_esPropioUsuario || actor.esEmpleado) {
          cargoFinal = u.cargo;
        }
        if (u.esSuperadminPrincipal) {
          cargoFinal = Constantes.rolSuperAdmin;
          activoFinal = true;
        }

        final actualizado = await _api.actualizar(
          Usuario(
            id: u.id,
            nombre: nombreLimpio,
            documento: documento,
            contra: u.contra,
            telefono: telefono,
            correo: correo,
            activo: activoFinal,
            fechaInicio: u.fechaInicio ?? DateTime.now(),
            cargo: cargoFinal,
            esSuperadminPrincipal: u.esSuperadminPrincipal,
          ),
          nuevaClavePlana: clave.isEmpty ? null : clave,
        );

        if (_esPropioUsuario) {
          SessionService.instance.actualizarUsuario(actualizado);
        }
      }

      try {
        final aud = await AuditoriaRepository.abrir();
        await aud.registrar(
          usuario: actor.nombre,
          accion: _esNuevo
              ? 'CREO USUARIO: $nombreLimpio'
              : 'ACTUALIZÓ PERFIL/USUARIO: $nombreLimpio',
          modulo: 'USUARIOS',
        );
      } catch (_) {}

      if (!mounted) return;
      notificar(
        context,
        _esNuevo
            ? 'Usuario creado correctamente.'
            : 'El usuario $nombreLimpio fue actualizado correctamente.',
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      notificar(context, 'Error: $e', error: true);
      setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cargos = _cargosDisponibles;

    return Scaffold(
      appBar: AppBar(
        title: Text(_esNuevo ? 'Nuevo usuario' : 'Actualizar usuario'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _nombre,
              textCapitalization: TextCapitalization.words,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'El nombre del empleado es obligatorio para continuar.';
                }
                final texto = v.trim();
                if (!RegExp(r'^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s]+$').hasMatch(texto)) {
                  return 'El nombre solo puede contener letras y espacios.';
                }
                if (!RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ]').hasMatch(texto)) {
                  return 'El nombre debe contener al menos una letra.';
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
              readOnly: !_esNuevo,
              enabled: _esNuevo,
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'El documento de identidad es obligatorio para continuar.';
                }
                if (!RegExp(r'^\d+$').hasMatch(v.trim())) {
                  return 'El documento solo puede contener números.';
                }
                return null;
              },
              decoration: InputDecoration(
                labelText: 'Documento de identidad *',
                prefixIcon: const Icon(Icons.badge_outlined),
                helperText: _esNuevo
                    ? null
                    : 'El documento de identidad es de solo lectura al editar.',
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
            DropdownButtonFormField<String>(
              initialValue: _cargo,
              items: [
                for (final c in cargos)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              decoration: InputDecoration(
                labelText: 'Rol / Cargo en el sistema *',
                prefixIcon: const Icon(Icons.verified_user_outlined),
                helperText: !_puedeEditarCargo
                    ? 'No puedes modificar tu propio rol ni el de un nivel superior.'
                    : (_actor?.esAdmin == true
                        ? 'Como Admin puedes asignar Admin o Empleado (no SuperAdmin).'
                        : null),
              ),
              onChanged: _puedeEditarCargo
                  ? (v) {
                      if (v != null) setState(() => _cargo = v);
                    }
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _clave,
              obscureText: true,
              validator: (v) {
                if (_esNuevo && (v == null || v.isEmpty)) {
                  return 'La contraseña es obligatoria.';
                }
                if (v != null && v.isNotEmpty && v.length < 8) {
                  return 'La contraseña debe tener como mínimo 8 caracteres.';
                }
                return null;
              },
              decoration: InputDecoration(
                labelText: _esNuevo
                    ? 'Contraseña (mín. 8 caracteres) *'
                    : 'Contraseña (opcional)',
                prefixIcon: const Icon(Icons.key_outlined),
                helperText: _esNuevo
                    ? null
                    : 'Deja este campo vacío si no deseas cambiar la contraseña.',
              ),
            ),
            const SizedBox(height: 14),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Usuario activo en el sistema'),
              subtitle: Text(
                _puedeEditarEstado
                    ? 'Permite el acceso al sistema'
                    : 'No puedes desactivar tu propio usuario ni al SuperAdmin',
                style: TextStyle(
                  color: _puedeEditarEstado
                      ? ColoresSigif.textoMitigado
                      : ColoresSigif.textoMitigado.withValues(alpha: 0.8),
                ),
              ),
              value: _activo,
              onChanged: _puedeEditarEstado
                  ? (v) => setState(() => _activo = v)
                  : null,
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
    );
  }
}

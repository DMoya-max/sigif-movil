import 'package:flutter/material.dart';

import '../../db/repos/auditoria_repository.dart';
import '../../db/repos/usuarios_repository.dart';
import '../../models/usuario.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'usuario_form_screen.dart';
import 'usuario_perfil_screen.dart';

class UsuariosScreen extends StatefulWidget {
  const UsuariosScreen({super.key});

  @override
  State<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends State<UsuariosScreen> {
  final _busquedaController = TextEditingController();
  List<Usuario> _usuarios = [];
  bool _cargando = true;
  String _q = '';

  Usuario? get _actor => SessionService.instance.usuario;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final repo = await UsuariosRepository.abrir();
    final lista = await repo.listar(q: _q);
    if (!mounted) return;
    setState(() {
      _usuarios = lista;
      _cargando = false;
    });
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  /// Reglas de escalada (matriz de permisos del web):
  bool _puedeEditar(Usuario target) {
    final actor = _actor;
    if (actor == null) return false;
    if (target.esSuperadminPrincipal) return false;
    if (target.id == actor.id) return true;
    if (actor.cargo == 'SuperAdmin') return true;
    // Admin no toca Admin/SuperAdmin
    if (actor.cargo == 'Admin' && target.cargo == 'Empleado') return true;
    return false;
  }

  bool _puedeCambiarEstado(Usuario target) {
    final actor = _actor;
    if (actor == null) return false;
    if (target.esSuperadminPrincipal) return false;
    if (target.id == actor.id) return false; // no auto-desactivarse
    if (actor.cargo == 'SuperAdmin') return true;
    return actor.cargo == 'Admin' && target.cargo == 'Empleado';
  }

  Future<void> _abrirFormulario({Usuario? usuario}) async {
    final creado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => UsuarioFormScreen(usuario: usuario, actor: _actor),
      ),
    );
    if (creado == true) await _cargar();
  }

  Future<void> _cambiarEstado(Usuario usuario) async {
    final nuevoEstado = !usuario.activo;
    final ok = await confirmar(
      context,
      titulo: nuevoEstado ? 'Activar usuario' : 'Desactivar usuario',
      mensaje: nuevoEstado
          ? '¿Activar a ${usuario.nombre}?'
          : '¿Desactivar a ${usuario.nombre}? No podrá iniciar sesión.',
      textoConfirmar: nuevoEstado ? 'Activar' : 'Desactivar',
      peligro: !nuevoEstado,
    );
    if (!ok || !mounted) return;
    final repo = await UsuariosRepository.abrir();
    await repo.cambiarEstado(usuario.id!, nuevoEstado);
    final aud = await AuditoriaRepository.abrir();
    await aud.registrar(
      usuario: _actor?.nombre ?? '',
      accion: nuevoEstado
          ? 'ACTIVÓ EL USUARIO ${usuario.nombre}'
          : 'DESACTIVÓ EL USUARIO ${usuario.nombre}',
      modulo: 'USUARIOS',
    );
    if (!mounted) return;
    notificar(context,
        nuevoEstado ? 'Usuario activado' : 'Usuario desactivado');
    await _cargar();
  }

  Future<void> _verPerfil() async {
    final u = _actor;
    if (u == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UsuarioPerfilScreen(usuario: u),
      ),
    );
    await SessionService.instance.refrescarSesion();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final actor = _actor;
    final puedeCrear = actor?.cargo == 'SuperAdmin' || actor?.cargo == 'Admin';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TituloPagina(
          titulo: 'Usuarios',
          subtitulo: 'Gestiona las cuentas del sistema y sus roles.',
          acciones: [
            IconButton.outlined(
              tooltip: 'Mi perfil',
              icon: const Icon(Icons.account_circle_outlined),
              onPressed: _verPerfil,
            ),
            if (puedeCrear)
              ElevatedButton.icon(
                onPressed: () => _abrirFormulario(),
                icon: const Icon(Icons.person_add_alt_1, size: 18),
                label: const Text('Nuevo usuario'),
              ),
          ],
        ),
        TextField(
          controller: _busquedaController,
          onChanged: (v) {
            _q = v;
            _cargar();
          },
          decoration: const InputDecoration(
            hintText: 'Buscar por nombre, cargo, teléfono o correo...',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 16),
        if (_cargando)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_usuarios.isEmpty)
          EstadoVacio(
            icono: Icons.people_outline,
            titulo: 'Sin resultados',
            mensaje: 'No se encontraron usuarios con el filtro aplicado.',
          )
        else
          for (final u in _usuarios) _tarjetaUsuario(u),
      ],
    );
  }

  Widget _tarjetaUsuario(Usuario u) {
    final editable = _puedeEditar(u);
    final cambiable = _puedeCambiarEstado(u);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: u.esSuperAdmin
                  ? ColoresSigif.azulPrimario
                  : u.esAdmin
                      ? ColoresSigif.info
                      : ColoresSigif.textoMitigado,
              child: Text(
                u.nombre.isNotEmpty ? u.nombre[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(u.nombre,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (u.esSuperadminPrincipal) ...[
                        const SizedBox(width: 6),
                        const Tooltip(
                          message: 'SuperAdmin principal',
                          child: Icon(Icons.verified,
                              size: 16, color: ColoresSigif.azulPrimario),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('${u.cargo} · ${u.correo}',
                      style: const TextStyle(
                          fontSize: 12.5, color: ColoresSigif.textoMitigado)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: (u.activo ? ColoresSigif.exito : ColoresSigif.peligro)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                u.activo ? 'Activo' : 'Inactivo',
                style: TextStyle(
                  color: u.activo ? ColoresSigif.exito : ColoresSigif.peligro,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              onSelected: (opcion) {
                switch (opcion) {
                  case 'editar':
                    if (editable) _abrirFormulario(usuario: u);
                    break;
                  case 'estado':
                    if (cambiable) _cambiarEstado(u);
                    break;
                }
              },
              itemBuilder: (_) => [
                if (editable)
                  const PopupMenuItem(value: 'editar', child: Text('Editar')),
                if (cambiable)
                  PopupMenuItem(
                    value: 'estado',
                    child: Text(u.activo ? 'Desactivar' : 'Activar'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
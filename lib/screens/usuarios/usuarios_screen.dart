import 'package:flutter/material.dart';

import '../../db/repos/auditoria_repository.dart';
import '../../models/usuario.dart';
import '../../services/auth_service.dart';
import '../../services/usuarios_api_service.dart';
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
  final _api = UsuariosApiService.instance;
  late Future<List<Usuario>> _futuroUsuarios;
  String _q = '';

  Usuario? get _actor => SessionService.instance.usuario;

  @override
  void initState() {
    super.initState();
    _futuroUsuarios = _api.listar(q: _q);
  }

  Future<void> _cargar() async {
    final nuevoFuturo = _api.listar(q: _q);
    setState(() {
      _futuroUsuarios = nuevoFuturo;
    });
    await nuevoFuturo;
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  Future<void> _registrarIntentoRechazado(String accion) async {
    try {
      final aud = await AuditoriaRepository.abrir();
      await aud.registrar(
        usuario: _actor?.nombre ?? 'API',
        accion: accion,
        modulo: 'USUARIOS',
      );
    } catch (_) {}
  }

  Future<void> _abrirFormulario({Usuario? usuario}) async {
    final actor = _actor;
    if (actor == null) {
      notificar(context, 'Debes iniciar sesión para continuar.', error: true);
      return;
    }

    if (usuario == null) {
      if (!actor.puedeGestionarUsuarios) {
        notificar(
          context,
          'No tienes permisos para crear usuarios.',
          error: true,
        );
        return;
      }
    } else {
      final motivoRechazo = actor.motivoRechazoEditar(usuario);
      if (motivoRechazo != null) {
        await _registrarIntentoRechazado(
          'INTENTO RECHAZADO DE MODIFICAR USUARIO: ${usuario.nombre}',
        );
        if (!mounted) return;
        notificar(context, motivoRechazo, error: true);
        return;
      }
    }

    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => UsuarioFormScreen(usuario: usuario, actor: actor),
      ),
    );
    if (guardado == true) {
      if (usuario != null && usuario.id == actor.id) {
        await SessionService.instance.refrescarSesion();
      }
      await _cargar();
    }
  }

  Future<void> _cambiarEstado(Usuario usuario) async {
    if (usuario.id == null) return;
    final actor = _actor;
    if (actor == null) {
      notificar(context, 'Debes iniciar sesión para continuar.', error: true);
      return;
    }

    final motivoRechazo = actor.motivoRechazoCambiarEstado(usuario);
    if (motivoRechazo != null) {
      notificar(context, motivoRechazo, error: true);
      return;
    }

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

    try {
      await _api.cambiarEstado(usuario, nuevoEstado);
      try {
        final aud = await AuditoriaRepository.abrir();
        await aud.registrar(
          usuario: actor.nombre,
          accion:
              'CAMBIO ESTADO USUARIO: ${usuario.nombre} → ${nuevoEstado ? "ACTIVO" : "INACTIVO"}',
          modulo: 'USUARIOS',
        );
      } catch (_) {}
      if (!mounted) return;
      notificar(
        context,
        nuevoEstado
            ? 'El usuario ${usuario.nombre} ahora está activo.'
            : 'El usuario ${usuario.nombre} ahora está inactivo.',
      );
      await _cargar();
    } catch (e) {
      if (!mounted) return;
      notificar(context, 'Error al cambiar estado: $e', error: true);
    }
  }

  Future<void> _eliminar(Usuario usuario) async {
    if (usuario.id == null) return;
    final actor = _actor;
    if (actor == null) {
      notificar(context, 'Debes iniciar sesión para continuar.', error: true);
      return;
    }

    final motivoRechazo = actor.motivoRechazoEliminar(usuario);
    if (motivoRechazo != null) {
      notificar(context, motivoRechazo, error: true);
      return;
    }

    final ok = await confirmar(
      context,
      titulo: 'Eliminar usuario',
      mensaje:
          '¿Estás seguro de eliminar a "${usuario.nombre}" (${usuario.correo})? Esta acción se ejecutará en la API y no se puede deshacer.',
      textoConfirmar: 'Eliminar',
      peligro: true,
    );
    if (!ok || !mounted) return;

    try {
      await _api.eliminar(usuario.id!);
      try {
        final aud = await AuditoriaRepository.abrir();
        await aud.registrar(
          usuario: actor.nombre,
          accion: 'ELIMINÓ EL USUARIO ${usuario.nombre}',
          modulo: 'USUARIOS',
        );
      } catch (_) {}
      if (!mounted) return;
      notificar(context, 'Usuario "${usuario.nombre}" eliminado');
      await _cargar();
    } catch (e) {
      if (!mounted) return;
      notificar(context, 'Error al eliminar usuario: $e', error: true);
    }
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
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final anchoPantalla = MediaQuery.of(context).size.width;
    final esMovil = anchoPantalla < 600;
    final padHorizontal = esMovil
        ? 16.0
        : anchoPantalla < 960
            ? 24.0
            : 40.0;
    final puedeCrear = _actor?.puedeGestionarUsuarios ?? false;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: puedeCrear
          ? FloatingActionButton.extended(
              onPressed: () => _abrirFormulario(),
              backgroundColor: ColoresSigif.azulPrimario,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Nuevo usuario'),
            )
          : null,
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          padHorizontal,
          esMovil ? 14 : 10,
          padHorizontal,
          16,
        ),
        child: Column(
          children: [
            TituloPagina(
              titulo: 'Usuarios',
              subtitulo: esMovil
                  ? 'Gestión de cuentas conectada a la API REST'
                  : 'Gestión de cuentas conectada a https://sigif-final.vercel.app/api/usuarios/',
              acciones: [
                IconButton.outlined(
                  tooltip: 'Actualizar desde API',
                  icon: const Icon(Icons.refresh),
                  onPressed: _cargar,
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Mi perfil',
                  icon: const Icon(Icons.account_circle_outlined),
                  onPressed: _verPerfil,
                ),
                if (!esMovil && puedeCrear) ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _abrirFormulario(),
                    icon: const Icon(Icons.person_add_alt_1, size: 18),
                    label: const Text('Nuevo usuario'),
                  ),
                ],
              ],
            ),
            TextField(
              controller: _busquedaController,
              onChanged: (v) {
                _q = v;
                _cargar();
              },
              decoration: InputDecoration(
                hintText: esMovil
                    ? 'Buscar por nombre, documento o correo...'
                    : 'Buscar por nombre, documento, cargo, teléfono o correo...',
                prefixIcon: const Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: FutureBuilder<List<Usuario>>(
                future: _futuroUsuarios,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return EstadoVacio(
                      icono: Icons.cloud_off_outlined,
                      titulo: 'Error al consultar la API',
                      mensaje: '${snapshot.error}',
                      accion: ElevatedButton.icon(
                        onPressed: _cargar,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                      ),
                    );
                  }
                  final usuarios = snapshot.data ?? [];
                  if (usuarios.isEmpty) {
                    return const EstadoVacio(
                      icono: Icons.people_outline,
                      titulo: 'Sin resultados',
                      mensaje:
                          'No se encontraron usuarios con el filtro aplicado.',
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: _cargar,
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 88),
                      itemCount: usuarios.length,
                      itemBuilder: (context, index) {
                        return _tarjetaUsuario(
                          usuarios[index],
                          esMovil: esMovil,
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaUsuario(Usuario u, {required bool esMovil}) {
    final actor = _actor;
    final motivoEditar = actor?.motivoRechazoEditar(u);
    final motivoEstado = actor?.motivoRechazoCambiarEstado(u);
    final motivoEliminar = actor?.motivoRechazoEliminar(u);

    final puedeEditar = motivoEditar == null;
    final puedeEstado = motivoEstado == null;
    final puedeEliminar = motivoEliminar == null;

    final badgeEstado = Container(
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
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    final menuOpciones = PopupMenuButton<String>(
      onSelected: (opcion) {
        switch (opcion) {
          case 'editar':
            _abrirFormulario(usuario: u);
            break;
          case 'estado':
            _cambiarEstado(u);
            break;
          case 'eliminar':
            _eliminar(u);
            break;
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'editar',
          child: Row(
            children: [
              Icon(
                puedeEditar ? Icons.edit_outlined : Icons.lock_outline,
                size: 18,
                color: puedeEditar ? null : ColoresSigif.textoMitigado,
              ),
              const SizedBox(width: 8),
              Text(
                'Editar',
                style: TextStyle(
                  color: puedeEditar ? null : ColoresSigif.textoMitigado,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'estado',
          child: Row(
            children: [
              Icon(
                !puedeEstado
                    ? Icons.lock_outline
                    : (u.activo
                        ? Icons.person_off_outlined
                        : Icons.check_circle_outline),
                size: 18,
                color: puedeEstado ? null : ColoresSigif.textoMitigado,
              ),
              const SizedBox(width: 8),
              Text(
                u.activo ? 'Desactivar' : 'Activar',
                style: TextStyle(
                  color: puedeEstado ? null : ColoresSigif.textoMitigado,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'eliminar',
          child: Row(
            children: [
              Icon(
                puedeEliminar ? Icons.delete_outline : Icons.lock_outline,
                size: 18,
                color: puedeEliminar
                    ? ColoresSigif.peligro
                    : ColoresSigif.textoMitigado,
              ),
              const SizedBox(width: 8),
              Text(
                'Eliminar',
                style: TextStyle(
                  color: puedeEliminar
                      ? ColoresSigif.peligro
                      : ColoresSigif.textoMitigado,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final botonEditarMovil = IconButton(
      visualDensity: VisualDensity.compact,
      tooltip: puedeEditar ? 'Editar usuario' : motivoEditar,
      icon: Icon(
        puedeEditar ? Icons.edit_outlined : Icons.lock_outline,
        size: 20,
        color: puedeEditar
            ? ColoresSigif.azulPrimario
            : ColoresSigif.textoMitigado.withValues(alpha: 0.55),
      ),
      onPressed: () => _abrirFormulario(usuario: u),
    );

    final botonEliminarMovil = IconButton(
      visualDensity: VisualDensity.compact,
      tooltip: puedeEliminar ? 'Eliminar usuario' : motivoEliminar,
      icon: Icon(
        puedeEliminar ? Icons.delete_outline : Icons.lock_outline,
        size: 20,
        color: puedeEliminar
            ? ColoresSigif.peligro
            : ColoresSigif.textoMitigado.withValues(alpha: 0.45),
      ),
      onPressed: () => _eliminar(u),
    );

    if (esMovil) {
      // Diseño optimizado para pantallas iPhone (375–430px) y Samsung (360–412px)
      return Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: u.esSuperAdmin
                        ? ColoresSigif.azulPrimario
                        : u.esAdmin
                            ? ColoresSigif.info
                            : ColoresSigif.textoMitigado,
                    child: Text(
                      u.nombre.isNotEmpty ? u.nombre[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
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
                              child: Text(
                                u.nombre,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (u.esSuperadminPrincipal) ...[
                              const SizedBox(width: 5),
                              const Icon(
                                Icons.verified,
                                size: 15,
                                color: ColoresSigif.azulPrimario,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          u.correo,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: ColoresSigif.textoMitigado,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  badgeEstado,
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.only(top: 8),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Color(0xFFF1F5F9), width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              u.cargo,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: ColoresSigif.azulPrimario,
                              ),
                            ),
                          ),
                          if (u.documento.isNotEmpty)
                            Text(
                              'Doc: ${u.documento}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: ColoresSigif.textoMitigado,
                              ),
                            ),
                          if (u.telefono.isNotEmpty)
                            Text(
                              'Tel: ${u.telefono}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: ColoresSigif.textoMitigado,
                              ),
                            ),
                        ],
                      ),
                    ),
                    botonEditarMovil,
                    botonEliminarMovil,
                    menuOpciones,
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

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
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
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
                        child: Text(
                          u.nombre,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (u.esSuperadminPrincipal) ...[
                        const SizedBox(width: 6),
                        const Tooltip(
                          message: 'SuperAdmin principal',
                          child: Icon(
                            Icons.verified,
                            size: 16,
                            color: ColoresSigif.azulPrimario,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${u.cargo} · ${u.correo}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: ColoresSigif.textoMitigado,
                    ),
                  ),
                  if (u.documento.isNotEmpty || u.telefono.isNotEmpty)
                    Text(
                      'Doc: ${u.documento} · Tel: ${u.telefono}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: ColoresSigif.textoMitigado,
                      ),
                    ),
                ],
              ),
            ),
            badgeEstado,
            const SizedBox(width: 4),
            IconButton(
              tooltip: puedeEditar ? 'Editar usuario' : motivoEditar,
              icon: Icon(
                puedeEditar ? Icons.edit_outlined : Icons.lock_outline,
                size: 20,
                color: puedeEditar
                    ? ColoresSigif.azulPrimario
                    : ColoresSigif.textoMitigado.withValues(alpha: 0.55),
              ),
              onPressed: () => _abrirFormulario(usuario: u),
            ),
            IconButton(
              tooltip: puedeEliminar ? 'Eliminar usuario' : motivoEliminar,
              icon: Icon(
                puedeEliminar ? Icons.delete_outline : Icons.lock_outline,
                size: 20,
                color: puedeEliminar
                    ? ColoresSigif.peligro
                    : ColoresSigif.textoMitigado.withValues(alpha: 0.45),
              ),
              onPressed: () => _eliminar(u),
            ),
            menuOpciones,
          ],
        ),
      ),
    );
  }
}

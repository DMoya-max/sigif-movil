import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/constantes.dart';
import '../../core/formato.dart';
import '../../db/database.dart';
import '../../db/repos/auditoria_repository.dart';
import '../../db/repos/configuracion_repository.dart';
import '../../db/repos/usuarios_repository.dart';
import '../../models/empresa_config.dart';
import '../../models/usuario.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class ConfiguracionScreen extends StatefulWidget {
  const ConfiguracionScreen({super.key});

  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  late final TextEditingController _nit;
  late final TextEditingController _direccion;
  late final TextEditingController _impuesto;
  late final TextEditingController _correo;

  EmpresaConfig? _config;
  List<Usuario> _usuarios = [];
  bool _cargando = true;

  Usuario? get _actor => SessionService.instance.usuario;

  @override
  void initState() {
    super.initState();
    _nombre = TextEditingController();
    _nit = TextEditingController();
    _direccion = TextEditingController();
    _impuesto = TextEditingController();
    _correo = TextEditingController();
    _cargar();
  }

  @override
  void dispose() {
    _nombre.dispose();
    _nit.dispose();
    _direccion.dispose();
    _impuesto.dispose();
    _correo.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final repo = await ConfiguracionRepository.abrir();
    final config = await repo.obtener();
    final usuariosRepo = await UsuariosRepository.abrir();
    final usuarios = await usuariosRepo.listar();
    if (!mounted) return;
    setState(() {
      _config = config;
      _nombre.text = config.nombreComercial;
      _nit.text = config.nit;
      _direccion.text = config.direccion;
      _impuesto.text = config.impuesto;
      _correo.text = config.correoContacto;
      _usuarios = usuarios;
      _cargando = false;
    });
  }

  Future<void> _guardarEmpresa() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final repo = await ConfiguracionRepository.abrir();
    await repo.guardarDatosEmpresa(
      nombreComercial: _nombre.text,
      nit: _nit.text,
      direccion: _direccion.text,
    );
    await repo.guardarConfigSistema(
      impuesto: _impuesto.text,
      correoContacto: _correo.text,
    );
    final db = await AppDatabase.instance.db;
    final aud = AuditoriaRepository(db);
    await aud.registrar(
      usuario: _actor?.nombre ?? '',
      accion: 'ACTUALIZÓ LOS DATOS DE LA EMPRESA',
      modulo: 'CONFIGURACION',
    );
    if (!mounted) return;
    notificar(context, 'Configuración guardada');
    await _cargar();
  }

  Future<void> _cambiarCargo(Usuario target, String nuevoCargo) async {
    final repo = await ConfiguracionRepository.abrir();
    final error = await repo.asignarCargo(_actor!, target.id!, nuevoCargo);
    if (error != null) {
      if (!mounted) return;
      notificar(context, error, error: true);
      return;
    }
    if (target.id == _actor?.id) {
      await SessionService.instance.refrescarSesion();
    }
    if (!mounted) return;
    notificar(context, 'Cargo actualizado a $nuevoCargo');
    await _cargar();
  }

  Future<void> _exportarBackup() async {
    final dir = await getApplicationDocumentsDirectory();
    final bdPath = await _rutaBd();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final destino = File('${dir.path}/sigif_backup_$stamp.db');
    await File(bdPath).copy(destino.path);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(destino.path)],
        text: 'Copia de seguridad de la base de datos SIGIF',
      ),
    );
  }

  Future<String> _rutaBd() async {
    final ruta = await getDatabasesPath();
    return '$ruta/sigif.db';
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TituloPagina(
          titulo: 'Configuración',
          subtitulo: 'Datos de la empresa, copias de seguridad y permisos.',
        ),
        const Text('Datos de la empresa',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nombre,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Ingresa el nombre comercial'
                        : null,
                    decoration: const InputDecoration(
                        labelText: 'Nombre comercial *'),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _nit,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Ingresa el NIT'
                              : null,
                          decoration: const InputDecoration(labelText: 'NIT *'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _impuesto,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Ingresa el impuesto'
                              : null,
                          decoration: const InputDecoration(
                              labelText: 'Impuesto *'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _direccion,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Ingresa la dirección'
                        : null,
                    decoration: const InputDecoration(labelText: 'Dirección *'),
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
                    decoration: const InputDecoration(
                        labelText: 'Correo de contacto *'),
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Moneda: ${_config?.moneda}',
                        style: const TextStyle(
                            fontSize: 13, color: ColoresSigif.textoMitigado)),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: _guardarEmpresa,
                      icon: const Icon(Icons.save_outlined, size: 18),
                      label: const Text('Guardar datos de la empresa'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text('Permisos de roles',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Asigna el cargo de cada usuario (Solo SuperAdmin asigna SuperAdmin).',
            style: const TextStyle(color: ColoresSigif.textoMitigado, fontSize: 12.5)),
        const SizedBox(height: 12),
        for (final u in _usuarios) _tarjetaPermiso(u),
        const SizedBox(height: 24),
        const Text('Copias de seguridad',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Exporta una copia de la base de datos local (SQLite) para respaldar o transferir.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _exportarBackup,
                  icon: const Icon(Icons.save_alt_outlined, size: 18),
                  label: const Text('Exportar copia de seguridad (.db)'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Card(
          color: ColoresSigif.infoSuave,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    color: ColoresSigif.info, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'SIGIF funciona 100% offline con su base de datos local. '
                    'Última siembra de empresa: ${_config == null ? '-' : Formato.fecha(DateTime.now())}.',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _tarjetaPermiso(Usuario u) {
    final esPrincipal = u.esSuperadminPrincipal;
    final actor = _actor;
    final editable = !esPrincipal && actor != null;
    final puedeAsignarSuper = actor?.cargo == 'SuperAdmin';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(u.nombre,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14),
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (esPrincipal) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.verified,
                            size: 14, color: ColoresSigif.azulPrimario),
                      ],
                    ],
                  ),
                  Text(u.correo,
                      style: const TextStyle(
                          fontSize: 11.5, color: ColoresSigif.textoMitigado)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            DropdownButton<String>(
              value: u.cargo,
              underline: const SizedBox.shrink(),
              items: [
                for (final c in Constantes.cargos)
                  if (c != 'SuperAdmin' || puedeAsignarSuper)
                    DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: editable
                  ? (v) {
                      if (v != null && v != u.cargo) _cambiarCargo(u, v);
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
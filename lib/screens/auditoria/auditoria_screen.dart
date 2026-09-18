import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constantes.dart';
import '../../core/formato.dart';
import '../../db/repos/auditoria_repository.dart';
import '../../models/auditoria.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class AuditoriaScreen extends StatefulWidget {
  const AuditoriaScreen({super.key});

  @override
  State<AuditoriaScreen> createState() => _AuditoriaScreenState();
}

class _AuditoriaScreenState extends State<AuditoriaScreen> {
  final _buscarUsuario = TextEditingController();
  final _buscarAccion = TextEditingController();
  List<Auditoria> _registros = [];
  bool _cargando = true;
  String? _modulo;
  DateTime? _desde;
  DateTime? _hasta;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _buscarUsuario.dispose();
    _buscarAccion.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final repo = await AuditoriaRepository.abrir();
    final lista = await repo.listar(
      modulo: _modulo,
      usuario: _buscarUsuario.text,
      accion: _buscarAccion.text,
      fechaDesde: _desde,
      fechaHasta: _hasta,
      limite: 500,
    );
    if (!mounted) return;
    setState(() {
      _registros = lista;
      _cargando = false;
    });
  }

  Future<DateTime?> _elegirFecha(DateTime pr, {required bool esDesde}) async {
    return showDatePicker(
      context: context,
      initialDate: pr,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
  }

  Future<void> _exportarCsv() async {
    if (_registros.isEmpty) {
      notificar(context, 'No hay registros para exportar', error: true);
      return;
    }
    final buffer = StringBuffer()
      ..writeln('ID;Fecha;Usuario;Modulo;Accion');
    for (final a in _registros) {
      buffer.writeln(
          '${a.id};${Formato.fechaHora(a.fecha)};${_csv(a.usuario)};${a.modulo};${_csv(a.accion)}');
    }
    final dir = await getApplicationDocumentsDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/auditoria_$stamp.csv');
    await file.writeAsString(buffer.toString());

    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: 'Exportación de auditoría SIGIF'),
    );
  }

  String _csv(String v) => '"${v.replaceAll('"', "'")}"';

  void _limpiarFiltros() {
    setState(() {
      _modulo = null;
      _desde = null;
      _hasta = null;
      _buscarUsuario.clear();
      _buscarAccion.clear();
    });
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TituloPagina(
          titulo: 'Auditoría',
          subtitulo: 'Registro de acciones del sistema, con filtros.',
          acciones: [
            OutlinedButton.icon(
              onPressed: _exportarCsv,
              icon: const Icon(Icons.file_download_outlined, size: 18),
              label: const Text('Exportar CSV'),
            ),
          ],
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        initialValue: _modulo,
                        hint: const Text('Todas los módulos'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Todos')),
                          for (final m in Constantes.modulosAuditoria)
                            DropdownMenuItem(value: m, child: Text(m)),
                        ],
                        onChanged: (v) {
                          _modulo = v;
                          _cargar();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final d = await _elegirFecha(
                                    _desde ?? DateTime.now().subtract(const Duration(days: 30)),
                                    esDesde: true);
                                if (d != null) {
                                  setState(() => _desde = d);
                                  _cargar();
                                }
                              },
                              icon: const Icon(Icons.calendar_today_outlined, size: 16),
                              label: Text(_desde == null
                                  ? 'Desde'
                                  : Formato.fecha(_desde!)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final d = await _elegirFecha(
                                    _hasta ?? DateTime.now(),
                                    esDesde: false);
                                if (d != null) {
                                  setState(() => _hasta = d);
                                  _cargar();
                                }
                              },
                              icon: const Icon(Icons.calendar_today_outlined, size: 16),
                              label: Text(_hasta == null
                                  ? 'Hasta'
                                  : Formato.fecha(_hasta!)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Limpiar filtros',
                      icon: const Icon(Icons.filter_alt_off_outlined),
                      onPressed: _limpiarFiltros,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _buscarUsuario,
                        onChanged: (_) => _cargar(),
                        decoration: const InputDecoration(
                          labelText: 'Usuario',
                          prefixIcon: Icon(Icons.person_outline, size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _buscarAccion,
                        onChanged: (_) => _cargar(),
                        decoration: const InputDecoration(
                          labelText: 'Acción',
                          prefixIcon: Icon(Icons.search, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_cargando)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_registros.isEmpty)
          const EstadoVacio(
            icono: Icons.history,
            titulo: 'Sin registros',
            mensaje: 'No hay acciones de auditoría con los filtros aplicados.',
          )
        else
          for (final a in _registros)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: ColoresSigif.azulPrimario.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(a.modulo,
                          style: const TextStyle(
                              fontSize: 10.5,
                              color: ColoresSigif.azulPrimario,
                              fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.accion,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(
                            '${a.usuario} · ${Formato.fechaHora(a.fecha)}',
                            style: const TextStyle(
                                fontSize: 11.5,
                                color: ColoresSigif.textoMitigado),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
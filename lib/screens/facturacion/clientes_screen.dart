import 'package:flutter/material.dart';

import '../../core/formato.dart';
import '../../db/repos/clientes_repository.dart';
import '../../models/factura.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  final _busqueda = TextEditingController();
  List<Cliente> _clientes = [];
  bool _cargando = true;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final repo = await ClientesRepository.abrir();
    final lista = await repo.listar(q: _q);
    if (!mounted) return;
    setState(() {
      _clientes = lista;
      _cargando = false;
    });
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _verCliente(Cliente c) async {
    final repo = await ClientesRepository.abrir();
    final total = await repo.totalGastado(c.id!);
    final ultima = await repo.ultimaFecha(c.id!);
    final facturas = await repo.facturasDe(c.id!);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(c.nombre,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            Text(c.correo,
                style: const TextStyle(color: ColoresSigif.textoMitigado)),
            const SizedBox(height: 12),
            _fila('Total gastado', Formato.cop(total)),
            _fila('Compras', '${facturas.length}'),
            _fila('Última compra',
                ultima == null ? 'Sin compras' : Formato.fechaHora(ultima)),
            const SizedBox(height: 12),
            const Text('Facturas',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            if (facturas.isEmpty)
              const Text('Sin facturas.')
            else
              for (final f in facturas.take(10))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('#${f.id} · ${Formato.fecha(f.fecha)}',
                            style: const TextStyle(fontSize: 13)),
                      ),
                      Text(Formato.cop(f.total),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _fila(String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(etiqueta, style: const TextStyle(color: ColoresSigif.textoMitigado)),
          Text(valor, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TituloPagina(
          titulo: 'Clientes',
          subtitulo: 'Clientes registrados y su historial de compras.',
        ),
        TextField(
          controller: _busqueda,
          onChanged: (v) {
            _q = v;
            _cargar();
          },
          decoration: const InputDecoration(
            hintText: 'Buscar por nombre o correo...',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 16),
        if (_cargando)
          const Center(child: CircularProgressIndicator())
        else if (_clientes.isEmpty)
          const EstadoVacio(
            icono: Icons.people_outline,
            titulo: 'Sin clientes',
            mensaje: 'Los clientes se crean al realizar ventas.',
          )
        else
          for (final c in _clientes)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                onTap: () => _verCliente(c),
                leading: CircleAvatar(
                  backgroundColor: ColoresSigif.info.withValues(alpha: 0.12),
                  child: Text(
                    c.nombre.isNotEmpty ? c.nombre[0].toUpperCase() : '?',
                    style: const TextStyle(
                        color: ColoresSigif.info,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                title: Text(c.nombre,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14.5)),
                subtitle: Text(c.correo,
                    style: const TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
      ],
    );
  }
}
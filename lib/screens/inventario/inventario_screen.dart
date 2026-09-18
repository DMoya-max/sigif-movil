import 'package:flutter/material.dart';

import '../../core/formato.dart';
import '../../db/repos/inventario_repository.dart';
import '../../db/repos/productos_repository.dart';
import '../../models/inventario.dart';
import '../../models/producto.dart';
import '../../services/compartir.dart';
import '../../services/pdf_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'pos_screen.dart';
import 'registro_entrada_screen.dart';

class InventarioScreen extends StatelessWidget {
  const InventarioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: const [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Punto de venta'),
              Tab(text: 'Control de stock'),
              Tab(text: 'Historial de entradas'),
              Tab(text: 'Registrar entrada'),
            ],
          ),
          Divider(height: 1),
          Expanded(
            child: TabBarView(
              children: [
                PosScreen(),
                _ControlStock(),
                _HistorialEntradas(),
                RegistroEntradaScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlStock extends StatefulWidget {
  const _ControlStock();

  @override
  State<_ControlStock> createState() => _ControlStockState();
}

class _ControlStockState extends State<_ControlStock> {
  final _busqueda = TextEditingController();
  List<Producto> _productos = [];
  bool _cargando = true;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final repo = await ProductosRepository.abrir();
    final lista = await repo.listar(q: _q);
    if (!mounted) return;
    setState(() {
      _productos = lista;
      _cargando = false;
    });
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          controller: _busqueda,
          onChanged: (v) {
            _q = v;
            _cargar();
          },
          decoration: const InputDecoration(
            hintText: 'Buscar producto...',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 16),
        if (_cargando)
          const Center(child: CircularProgressIndicator())
        else if (_productos.isEmpty)
          const EstadoVacio(
            icono: Icons.inventory_2_outlined,
            titulo: 'Sin productos',
            mensaje: 'Registra productos o entradas para ver el control de stock.',
          )
        else
          for (final p in _productos)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.nombre,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 14.5)),
                          Text('${p.categoria} · ${Formato.cop(p.precio)}',
                              style: const TextStyle(
                                  fontSize: 12, color: ColoresSigif.textoMitigado)),
                        ],
                      ),
                    ),
                    Text('${p.stock}',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 8),
                    StockBadge(activo: p.activo, stock: p.stock),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

class _HistorialEntradas extends StatefulWidget {
  const _HistorialEntradas();

  @override
  State<_HistorialEntradas> createState() => _HistorialEntradasState();
}

class _HistorialEntradasState extends State<_HistorialEntradas> {
  List<EntradaInventario> _entradas = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final repo = await InventarioRepository.abrir();
    final lista = await repo.listarEntradas();
    if (!mounted) return;
    setState(() {
      _entradas = lista;
      _cargando = false;
    });
  }

  Future<void> _verDetalle(EntradaInventario e) async {
    final repo = await InventarioRepository.abrir();
    final detalles = await repo.detallesConProducto(e.id!);
    if (!mounted) return;
    await showModalBottomSheet(
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
            Row(
              children: [
                Expanded(
                  child: Text('Entrada ${e.numeroFactura()}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  tooltip: 'Exportar PDF',
                  onPressed: () async {
                    final bytes = await PdfService.generoTicketEntrada(e.id!);
                    await Compartir.guardar(
                      bytes: bytes,
                      nombre: 'entrada_${e.id}.pdf',
                      mensaje: 'Ticket de ${e.numeroFactura()}',
                    );
                  },
                ),
              ],
            ),
            Text('${e.proveedor} · ${Formato.fechaHora(e.fecha)}',
                style: const TextStyle(color: ColoresSigif.textoMitigado)),
            const SizedBox(height: 12),
            ...detalles.map((d) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('${d['producto_nombre']} × ${d['cantidad']}',
                            style: const TextStyle(fontSize: 13.5)),
                      ),
                      Text(Formato.cop(d['subtotal'] as num),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                )),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                Text(Formato.cop(e.total),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_entradas.isEmpty) {
      return const EstadoVacio(
        icono: Icons.history,
        titulo: 'Sin entradas',
        mensaje: 'Aún no se han registrado entradas de inventario.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        for (final e in _entradas)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              onTap: () => _verDetalle(e),
              leading: CircleAvatar(
                backgroundColor: ColoresSigif.azulPrimario.withValues(alpha: 0.12),
                child: const Icon(Icons.local_shipping_outlined,
                    color: ColoresSigif.azulPrimario),
              ),
              title: Text('${e.numeroFactura()} · ${e.proveedor}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
              subtitle: Text(
                '${e.usuario ?? ''} · ${Formato.fechaHora(e.fecha)}',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: Text(Formato.cop(e.total),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, color: ColoresSigif.exito)),
            ),
          ),
      ],
    );
  }
}
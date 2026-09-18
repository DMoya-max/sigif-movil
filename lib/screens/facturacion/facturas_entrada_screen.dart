import 'package:flutter/material.dart';

import '../../core/formato.dart';
import '../../db/repos/inventario_repository.dart';
import '../../models/inventario.dart';
import '../../services/compartir.dart';
import '../../services/pdf_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class FacturasEntradaScreen extends StatefulWidget {
  const FacturasEntradaScreen({super.key});

  @override
  State<FacturasEntradaScreen> createState() => _FacturasEntradaScreenState();
}

class _FacturasEntradaScreenState extends State<FacturasEntradaScreen> {
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

  Future<void> _verEntrada(EntradaInventario e) async {
    final repo = await InventarioRepository.abrir();
    final detalles = await repo.detallesConProducto(e.id!);
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
            Row(
              children: [
                Expanded(
                  child: Text(e.numeroFactura(),
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
                          style:
                              const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                )),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
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
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TituloPagina(
          titulo: 'Facturas de entrada',
          subtitulo: 'Compras de mercancía al inventario.',
        ),
        if (_cargando)
          const Center(child: CircularProgressIndicator())
        else if (_entradas.isEmpty)
          const EstadoVacio(
            icono: Icons.local_shipping_outlined,
            titulo: 'Sin entradas',
            mensaje: 'Aún no hay facturas de entrada registradas.',
          )
        else
          for (final e in _entradas)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                onTap: () => _verEntrada(e),
                leading: CircleAvatar(
                  backgroundColor:
                      ColoresSigif.azulPrimario.withValues(alpha: 0.12),
                  child: const Icon(Icons.local_shipping_outlined,
                      color: ColoresSigif.azulPrimario),
                ),
                title: Text('${e.numeroFactura()} · ${e.proveedor}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14.5)),
                subtitle: Text(
                  '${e.usuario ?? ''} · ${Formato.fechaHora(e.fecha)}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Text(Formato.cop(e.total),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: ColoresSigif.exito)),
              ),
            ),
      ],
    );
  }
}
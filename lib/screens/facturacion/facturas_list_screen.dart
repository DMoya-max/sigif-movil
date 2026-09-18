import 'package:flutter/material.dart';

import '../../core/constantes.dart';
import '../../core/formato.dart';
import '../../db/repos/clientes_repository.dart';
import '../../db/repos/facturas_repository.dart';
import '../../models/factura.dart';
import '../../services/pdf_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class FacturasListScreen extends StatefulWidget {
  const FacturasListScreen({super.key});

  @override
  State<FacturasListScreen> createState() => _FacturasListScreenState();
}

class _FacturasListScreenState extends State<FacturasListScreen> {
  List<Factura> _facturas = [];
  bool _cargando = true;
  String? _filtroEmpleado;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final repo = await FacturasRepository.abrir();
    final lista = await repo.listar(nombreEmpleado: _filtroEmpleado);
    if (!mounted) return;
    setState(() {
      _facturas = lista;
      _cargando = false;
    });
  }

  Future<void> _verDetalle(Factura f) async {
    final repo = await FacturasRepository.abrir();
    final detalles = await repo.detallesConProducto(f.id!);
    final clientes = await ClientesRepository.abrir();
    final cliente = await clientes.obtenerPorId(f.clienteId);
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
                  child: Text('Factura #${f.id}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                EstadoBadge(f.estadoPago),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  tooltip: 'Exportar PDF',
                  onPressed: () async {
                    final archivo = await PdfService.generoTicketFactura(f.id!);
                    await PdfService.compartirArchivo(
                        archivo, 'Factura #${f.id}');
                  },
                ),
              ],
            ),
            Text(
              '${cliente?.nombre ?? 'Cliente'} · ${Formato.fechaHora(f.fecha)}',
              style: const TextStyle(color: ColoresSigif.textoMitigado),
            ),
            const SizedBox(height: 12),
            ...detalles.map((d) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                            '${d['producto_nombre']} × ${d['cantidad']}',
                            style: const TextStyle(fontSize: 13.5)),
                      ),
                      Text(Formato.cop(d['subtotal'] as num),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                )),
            const Divider(),
            if (f.descuento > 0)
              _fila('Descuento', '-${Formato.cop(f.descuento)}',
                  color: ColoresSigif.exito),
            _fila('Subtotal', Formato.cop(f.total + f.descuento)),
            _fila('Total', Formato.cop(f.total), destacado: true),
            _fila('Método', Constantes.metodosPagoLabel[f.metodoPago] ?? f.metodoPago),
            _fila('Valor pagado', Formato.cop(f.valorPagado)),
            _fila('Saldo', Formato.cop(f.saldoPendiente)),
          ],
        ),
      ),
    );
  }

  Widget _fila(String etiqueta, String valor,
      {bool destacado = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(etiqueta,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: destacado ? FontWeight.w800 : FontWeight.w600)),
          Text(valor,
              style: TextStyle(
                  fontSize: destacado ? 16 : 13,
                  fontWeight: FontWeight.w800,
                  color: color)),
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
          titulo: 'Facturas',
          subtitulo: 'Historial completo de ventas registradas.',
        ),
        if (_cargando)
          const Center(child: CircularProgressIndicator())
        else if (_facturas.isEmpty)
          const EstadoVacio(
            icono: Icons.receipt_long_outlined,
            titulo: 'Sin facturas',
            mensaje: 'Aún no se han registrado ventas.',
          )
        else
          for (final f in _facturas)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                onTap: () => _verDetalle(f),
                leading: CircleAvatar(
                  backgroundColor:
                      ColoresSigif.azulPrimario.withValues(alpha: 0.12),
                  child: const Icon(Icons.receipt_outlined,
                      color: ColoresSigif.azulPrimario),
                ),
                title: Row(
                  children: [
                    Text('#${f.id}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14.5)),
                    const SizedBox(width: 8),
                    EstadoBadge(f.estadoPago),
                  ],
                ),
                subtitle: Text(
                  '${f.usuario} · ${Formato.fechaHora(f.fecha)}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Text(Formato.cop(f.total),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: ColoresSigif.azulPrimario)),
              ),
            ),
      ],
    );
  }
}
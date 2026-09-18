import 'package:flutter/material.dart';

import '../../core/formato.dart';
import '../../db/database.dart';
import '../../db/repos/facturas_repository.dart';
import '../../db/repos/inventario_repository.dart';
import '../../models/producto.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class ProductoDetalleScreen extends StatefulWidget {
  final Producto producto;

  const ProductoDetalleScreen({super.key, required this.producto});

  @override
  State<ProductoDetalleScreen> createState() => _ProductoDetalleScreenState();
}

class _ProductoDetalleScreenState extends State<ProductoDetalleScreen> {
  late final Future<_DatosDetalle> _datos;

  @override
  void initState() {
    super.initState();
    _datos = _cargar();
  }

  Future<_DatosDetalle> _cargar() async {
    final db = await AppDatabase.instance.db;
    final inv = InventarioRepository(db);
    final fac = FacturasRepository(db);
    final costoReciente = await inv.precioCompraReciente(widget.producto.id!);
    final vendidos = await fac.productosFacturados();

    double unidadesVendidas = 0;
    double ingresos = 0;
    for (final v in vendidos) {
      if (v['id'] == widget.producto.id) {
        unidadesVendidas = (v['unidades'] as num?)?.toDouble() ?? 0;
        ingresos = (v['ingresos'] as num?)?.toDouble() ?? 0;
        break;
      }
    }

    return _DatosDetalle(
      costoReciente: costoReciente,
      unidadesVendidas: unidadesVendidas,
      ingresos: ingresos,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.producto;
    return Scaffold(
      appBar: AppBar(title: Text(p.nombre)),
      body: FutureBuilder<_DatosDetalle>(
        future: _datos,
        builder: (context, snap) {
          final datos = snap.data;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.nombre,
                                    style: const TextStyle(
                                        fontSize: 20, fontWeight: FontWeight.w800)),
                                const SizedBox(height: 4),
                                Text(
                                    '${p.categoria} · Creado ${Formato.fecha(p.fechaCreacion)}',
                                    style: const TextStyle(
                                        fontSize: 12.5,
                                        color: ColoresSigif.textoMitigado)),
                              ],
                            ),
                          ),
                          StockBadge(activo: p.activo, stock: p.stock),
                        ],
                      ),
                      const Divider(height: 24),
                      _fila('Precio de venta', Formato.cop(p.precio)),
                      _fila('Stock actual', '${p.stock} unidades'),
                      _fila(
                          'Costo reciente de compra',
                          datos == null
                              ? '...'
                              : datos.costoReciente == null
                                  ? 'Sin compras registradas'
                                  : Formato.cop(datos.costoReciente!)),
                      const SizedBox(height: 4),
                      _fila('Unidades vendidas',
                          datos == null ? '...' : Formato.miles(datos.unidadesVendidas)),
                      _fila('Ingresos generados',
                          datos == null ? '...' : Formato.cop(datos.ingresos)),
                      if (p.descripcion != null && p.descripcion!.isNotEmpty) ...[
                        const Divider(height: 24),
                        Text('Descripción',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(p.descripcion!,
                            style: const TextStyle(color: ColoresSigif.textoCuerpo)),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _fila(String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(etiqueta, style: const TextStyle(color: ColoresSigif.textoMitigado)),
          Text(valor, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _DatosDetalle {
  final int? costoReciente;
  final double unidadesVendidas;
  final double ingresos;

  const _DatosDetalle({
    required this.costoReciente,
    required this.unidadesVendidas,
    required this.ingresos,
  });
}
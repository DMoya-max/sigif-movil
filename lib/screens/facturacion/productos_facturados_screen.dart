import 'package:flutter/material.dart';

import '../../core/formato.dart';
import '../../db/repos/facturas_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class ProductosFacturadosScreen extends StatefulWidget {
  const ProductosFacturadosScreen({super.key});

  @override
  State<ProductosFacturadosScreen> createState() =>
      _ProductosFacturadosScreenState();
}

class _ProductosFacturadosScreenState
    extends State<ProductosFacturadosScreen> {
  List<Map<String, Object?>> _dato = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final repo = await FacturasRepository.abrir();
    final lista = await repo.productosFacturados();
    if (!mounted) return;
    setState(() {
      _dato = lista;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TituloPagina(
          titulo: 'Productos facturados',
          subtitulo: 'Productos más vendidos, unidades e ingresos.',
        ),
        if (_cargando)
          const Center(child: CircularProgressIndicator())
        else if (_dato.isEmpty)
          const EstadoVacio(
            icono: Icons.bar_chart_outlined,
            titulo: 'Sin ventas',
            mensaje: 'Aún no hay productos facturados.',
          )
        else
          for (final d in _dato)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${d['nombre']}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 14)),
                          Text('${d['categoria']}',
                              style: const TextStyle(
                                  fontSize: 11.5,
                                  color: ColoresSigif.textoMitigado)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(Formato.cop(d['ingresos'] as num),
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: ColoresSigif.azulPrimario)),
                        Text(
                            '${d['unidades']} u · ${d['transacciones']} ventas',
                            style: const TextStyle(
                                fontSize: 11.5,
                                color: ColoresSigif.textoMitigado)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
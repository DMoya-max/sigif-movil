import 'package:flutter/material.dart';

import 'clientes_screen.dart';
import 'facturas_entrada_screen.dart';
import 'facturas_list_screen.dart';
import 'productos_facturados_screen.dart';

class FacturacionScreen extends StatelessWidget {
  const FacturacionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Facturas'),
              Tab(text: 'Clientes'),
              Tab(text: 'Productos facturados'),
              Tab(text: 'Facturas de entrada'),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              children: const [
                FacturasListScreen(),
                ClientesScreen(),
                ProductosFacturadosScreen(),
                FacturasEntradaScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
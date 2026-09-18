import 'package:flutter/material.dart';

import '../../core/formato.dart';
import '../../db/database.dart';
import '../../db/repos/auditoria_repository.dart';
import '../../db/repos/facturas_repository.dart';
import '../../db/repos/productos_repository.dart';
import '../../db/repos/usuarios_repository.dart';
import '../../models/auditoria.dart';
import '../../models/producto.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Future<_DatosDashboard>? _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = _cargar();
  }

  Future<_DatosDashboard> _cargar() async {
    final db = await AppDatabase.instance.db;
    final usuariosRepo = UsuariosRepository(db);
    final productosRepo = ProductosRepository(db);
    final facturasRepo = FacturasRepository(db);
    final auditoriaRepo = AuditoriaRepository(db);

    final usuarios = await usuariosRepo.contar();
    final productosActivos = await productosRepo.contarActivos();
    final stockBajo = await productosRepo.contarStockBajo();
    final agotados = await productosRepo.contarAgotados();
    final ventasMes = await facturasRepo.ventasDelMes();
    final recientes = await auditoriaRepo.recientes(4);

    final bajo = await productosRepo.listar(soloActivos: true);
    final alertas = bajo.where((p) => p.agotado || p.stockBajo).toList()
      ..sort((a, b) => a.stock.compareTo(b.stock));

    return _DatosDashboard(
      usuarios: usuarios,
      productosActivos: productosActivos,
      stockBajo: stockBajo,
      agotados: agotados,
      ventasMes: ventasMes,
      recientes: recientes,
      alertas: alertas,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DatosDashboard>(
      future: _futuro,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final datos = snap.data!;
        final usuario = SessionService.instance.usuario;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TituloPagina(
              titulo: 'Hola, ${usuario?.nombre ?? ''} 👋',
              subtitulo: 'Bienvenido a SIGIF. Aquí está el resumen de tu negocio.',
            ),
            _gridMetricas(datos),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: _tarjetaActividad(datos.recientes),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: _tarjetaAlertas(datos.alertas),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  Widget _gridMetricas(_DatosDashboard datos) {
    final cards = [
      MetricaCard(
        titulo: 'Usuarios',
        valor: '${datos.usuarios}',
        icono: Icons.people_outline,
        color: ColoresSigif.azulPrimario,
        subtitulo: 'registrados en el sistema',
      ),
      MetricaCard(
        titulo: 'Productos activos',
        valor: '${datos.productosActivos}',
        icono: Icons.inventory_2_outlined,
        color: ColoresSigif.info,
        subtitulo: 'en catálogo',
      ),
      MetricaCard(
        titulo: 'Stock bajo',
        valor: '${datos.stockBajo}',
        icono: Icons.warning_amber_outlined,
        color: ColoresSigif.advertencia,
        subtitulo: 'menos de 5 unidades',
      ),
      MetricaCard(
        titulo: 'Agotados',
        valor: '${datos.agotados}',
        icono: Icons.error_outline,
        color: ColoresSigif.peligro,
        subtitulo: 'sin existencias',
      ),
      MetricaCard(
        titulo: 'Ventas del mes',
        valor: Formato.cop(datos.ventasMes),
        icono: Icons.attach_money_outlined,
        color: ColoresSigif.exito,
        subtitulo: Formato.meses[DateTime.now().month],
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columnas = constraints.maxWidth >= 900
            ? 5
            : constraints.maxWidth >= 600
                ? 3
                : 2;
        return GridView.count(
          crossAxisCount: columnas,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: cards,
        );
      },
    );
  }

  Widget _tarjetaActividad(List<Auditoria> recientes) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history, color: ColoresSigif.azulPrimario, size: 20),
                const SizedBox(width: 8),
                const Text('Actividad reciente',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 12),
            if (recientes.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Aún no hay actividad registrada.',
                    style: TextStyle(color: ColoresSigif.textoMitigado)),
              )
            else
              for (final a in recientes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 6),
                        decoration: const BoxDecoration(
                          color: ColoresSigif.exito,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.accion,
                                style: const TextStyle(fontSize: 13.5),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text(
                              '${a.usuario} · ${Formato.fechaHora(a.fecha)}',
                              style: const TextStyle(
                                  fontSize: 11.5, color: ColoresSigif.textoMitigado),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaAlertas(List<Producto> alertas) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications_active_outlined,
                    color: ColoresSigif.advertencia, size: 20),
                const SizedBox(width: 8),
                const Text('Alertas de stock',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 12),
            if (alertas.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No hay productos con stock bajo o agotados.',
                    style: TextStyle(color: ColoresSigif.textoMitigado)),
              )
            else
              for (final p in alertas.take(6))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(p.nombre,
                            style: const TextStyle(fontSize: 13.5),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 8),
                      StockBadge(activo: p.activo, stock: p.stock),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _DatosDashboard {
  final int usuarios;
  final int productosActivos;
  final int stockBajo;
  final int agotados;
  final double ventasMes;
  final List<Auditoria> recientes;
  final List<Producto> alertas;

  const _DatosDashboard({
    required this.usuarios,
    required this.productosActivos,
    required this.stockBajo,
    required this.agotados,
    required this.ventasMes,
    required this.recientes,
    required this.alertas,
  });
}
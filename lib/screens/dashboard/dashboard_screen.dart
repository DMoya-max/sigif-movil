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

  // ===========================================================================
  // CARGAR DATOS
  // ===========================================================================

  Future<_DatosDashboard> _cargar() async {
    final db = await AppDatabase.instance.db;

    final usuariosRepo = UsuariosRepository(db);
    final productosRepo = ProductosRepository(db);
    final facturasRepo = FacturasRepository(db);
    final auditoriaRepo = AuditoriaRepository(db);

    final usuarios = await usuariosRepo.contar();

    final productosActivos =
        await productosRepo.contarActivos();

    final stockBajo =
        await productosRepo.contarStockBajo();

    final agotados =
        await productosRepo.contarAgotados();

    final ventasMes =
        await facturasRepo.ventasDelMes();

    final recientes =
        await auditoriaRepo.recientes(4);

    final bajo =
        await productosRepo.listar(soloActivos: true);

    final alertas = bajo
        .where(
          (p) => p.agotado || p.stockBajo,
        )
        .toList()
      ..sort(
        (a, b) => a.stock.compareTo(b.stock),
      );

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

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DatosDashboard>(
      future: _futuro,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No se pudo cargar el dashboard.\n\n${snap.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        if (!snap.hasData) {
          return const Center(
            child: Text(
              'No hay datos disponibles.',
            ),
          );
        }

        final datos = snap.data!;

        final usuario =
            SessionService.instance.usuario;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // =================================================================
            // ENCABEZADO
            // =================================================================

            TituloPagina(
              titulo:
                  'Hola, ${usuario?.nombre ?? ''}',
              subtitulo:
                  'Bienvenido a SIGIF. Aquí está el resumen de tu negocio.',
            ),

            const SizedBox(height: 20),

            // =================================================================
            // MÉTRICAS
            // =================================================================

            _gridMetricas(datos),

            const SizedBox(height: 20),

            // =================================================================
            // ACTIVIDAD RECIENTE
            // =================================================================

            _tarjetaActividad(
              datos.recientes,
            ),

            const SizedBox(height: 16),

            // =================================================================
            // ALERTAS DE STOCK
            // =================================================================

            _tarjetaAlertas(
              datos.alertas,
            ),

            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  // ===========================================================================
  // GRID DE MÉTRICAS
  // ===========================================================================

  Widget _gridMetricas(
    _DatosDashboard datos,
  ) {
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
        valor: Formato.cop(
          datos.ventasMes,
        ),
        icono: Icons.attach_money_outlined,
        color: ColoresSigif.exito,
        subtitulo:
            Formato.meses[
              DateTime.now().month
            ],
      ),
    ];

    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final columnas =
            constraints.maxWidth >= 1100
                ? 5
                : constraints.maxWidth >= 750
                    ? 3
                    : constraints.maxWidth >= 450
                        ? 2
                        : 1;

        return GridView.count(
          crossAxisCount: columnas,
          shrinkWrap: true,
          physics:
              const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio:
              columnas == 1
                  ? 3.0
                  : columnas == 2
                      ? 1.7
                      : 1.25,
          children: cards,
        );
      },
    );
  }

  // ===========================================================================
  // TARJETA ACTIVIDAD RECIENTE
  // ===========================================================================

  Widget _tarjetaActividad(
    List<Auditoria> recientes,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            // -----------------------------------------------------------------
            // TITULO
            // -----------------------------------------------------------------

            Row(
              children: [
                const Icon(
                  Icons.history,
                  color:
                      ColoresSigif.azulPrimario,
                  size: 20,
                ),

                const SizedBox(width: 8),

                const Expanded(
                  child: Text(
                    'Actividad reciente',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // -----------------------------------------------------------------
            // SIN ACTIVIDAD
            // -----------------------------------------------------------------

            if (recientes.isEmpty)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius:
                      BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.grey.shade200,
                  ),
                ),
                child: const Text(
                  'Aún no hay actividad registrada.',
                  softWrap: true,
                  style: TextStyle(
                    color:
                        ColoresSigif.textoMitigado,
                  ),
                ),
              )

            // -----------------------------------------------------------------
            // ACTIVIDADES
            // -----------------------------------------------------------------

            else
              for (final a in recientes)
                _filaActividad(a),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // FILA DE ACTIVIDAD
  // ===========================================================================

  Widget _filaActividad(
    Auditoria a,
  ) {
    return Container(
      width: double.infinity,
      margin:
          const EdgeInsets.only(bottom: 12),
      padding:
          const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius:
            BorderRadius.circular(10),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          // -------------------------------------------------------------------
          // PUNTO VERDE
          // -------------------------------------------------------------------

          Container(
            width: 8,
            height: 8,
            margin:
                const EdgeInsets.only(top: 6),
            decoration:
                const BoxDecoration(
              color: ColoresSigif.exito,
              shape: BoxShape.circle,
            ),
          ),

          const SizedBox(width: 12),

          // -------------------------------------------------------------------
          // INFORMACIÓN
          // -------------------------------------------------------------------

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  a.accion,
                  softWrap: true,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  'Usuario: ${a.usuario}',
                  softWrap: true,
                  style: const TextStyle(
                    fontSize: 12,
                    color:
                        ColoresSigif.textoMitigado,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  'Fecha: ${Formato.fechaHora(a.fecha)}',
                  softWrap: true,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color:
                        ColoresSigif.textoMitigado,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TARJETA ALERTAS DE STOCK
  // ===========================================================================

  Widget _tarjetaAlertas(
    List<Producto> alertas,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            // -----------------------------------------------------------------
            // TITULO
            // -----------------------------------------------------------------

            Row(
              children: [
                const Icon(
                  Icons.notifications_active_outlined,
                  color:
                      ColoresSigif.advertencia,
                  size: 20,
                ),

                const SizedBox(width: 8),

                const Expanded(
                  child: Text(
                    'Alertas de stock',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // -----------------------------------------------------------------
            // SIN ALERTAS
            // -----------------------------------------------------------------

            if (alertas.isEmpty)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius:
                      BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.grey.shade200,
                  ),
                ),
                child: const Text(
                  'No hay productos con stock bajo o agotados.',
                  softWrap: true,
                  style: TextStyle(
                    color:
                        ColoresSigif.textoMitigado,
                  ),
                ),
              )

            // -----------------------------------------------------------------
            // ALERTAS
            // -----------------------------------------------------------------

            else
              for (final p
                  in alertas.take(6))
                _filaAlerta(p),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // FILA DE ALERTA
  // ===========================================================================

  Widget _filaAlerta(
    Producto p,
  ) {
    return Container(
      width: double.infinity,
      margin:
          const EdgeInsets.only(bottom: 10),
      padding:
          const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius:
            BorderRadius.circular(10),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          // -------------------------------------------------------------------
          // PRODUCTO
          // -------------------------------------------------------------------

          Text(
            p.nombre,
            softWrap: true,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 10),

          // -------------------------------------------------------------------
          // STOCK
          // -------------------------------------------------------------------

          Row(
            children: [
              const Expanded(
                child: Text(
                  'Stock disponible',
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        ColoresSigif.textoMitigado,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              StockBadge(
                activo: p.activo,
                stock: p.stock,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// DATOS DEL DASHBOARD
// =============================================================================

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

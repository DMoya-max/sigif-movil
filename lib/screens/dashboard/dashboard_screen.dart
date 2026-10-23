import 'package:flutter/material.dart';

import '../../core/formato.dart';
import '../../db/database.dart';
import '../../db/repos/auditoria_repository.dart';
import '../../db/repos/facturas_repository.dart';
import '../../models/auditoria.dart';
import '../../models/producto.dart';
import '../../services/api_client.dart';
import '../../services/api_config.dart';
import '../../services/productos_api_service.dart';
import '../../services/usuarios_api_service.dart';

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
    // 1. Usuarios activos desde API
    final usuarios = await UsuariosApiService.instance.listar();
    final usuariosActivos = usuarios.where((u) => u.activo).length;

    // 2. Productos, stock bajo y agotados desde API
    final productos = await ProductosApiService.instance.listar();
    final productosActivosList = productos.where((p) => p.activo).toList();
    final totalProductos = productosActivosList.length;
    final stockBajo =
        productosActivosList.where((p) => p.stock > 0 && p.stock < 5).length;
    final agotados = productosActivosList.where((p) => p.stock == 0).length;

    // 3. Ventas del mes desde /api/facturas/ (con fallback local)
    double ventasMes = 0;
    try {
      final rawFacturas = await ApiClient.instance.getList('facturas/');
      final ahora = DateTime.now();
      for (final f in rawFacturas) {
        final fechaStr = f['fecha']?.toString() ?? '';
        final fecha = DateTime.tryParse(fechaStr)?.toLocal();
        if (fecha != null &&
            fecha.year == ahora.year &&
            fecha.month == ahora.month) {
          final totalRaw = f['total'];
          final total = totalRaw is num
              ? totalRaw.toDouble()
              : double.tryParse(totalRaw?.toString() ?? '0') ?? 0;
          ventasMes += total;
        }
      }
    } catch (_) {
      try {
        final db = await AppDatabase.instance.db;
        ventasMes = await FacturasRepository(db).ventasDelMes();
      } catch (_) {}
    }

    // 4. Actividad reciente (últimos 4 registros de /api/auditoria/)
    List<Auditoria> recientes = [];
    try {
      final rawAuditoria =
          await ApiClient.instance.getList(ApiConfig.auditoriaEndpoint);
      recientes = rawAuditoria.take(4).map(Auditoria.fromJson).toList();
    } catch (_) {
      try {
        final db = await AppDatabase.instance.db;
        recientes = await AuditoriaRepository(db).recientes(4);
      } catch (_) {}
    }

    return _DatosDashboard(
      usuariosActivos: usuariosActivos,
      productos: totalProductos,
      stockBajo: stockBajo,
      agotados: agotados,
      ventasMes: ventasMes,
      recientes: recientes,
      alertas: productosActivosList
          .where((p) => p.agotado || p.stockBajo)
          .toList(),
    );
  }

  Future<void> _refrescar() async {
    final nuevo = _cargar();
    setState(() {
      _futuro = nuevo;
    });
    await nuevo;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DatosDashboard>(
      future: _futuro,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snap.hasError || !snap.hasData) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'No se pudo cargar el dashboard.\n${snap.error ?? ''}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _refrescar,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          );
        }

        final datos = snap.data!;
        final anchoPantalla = MediaQuery.of(context).size.width;
        final esMovil = anchoPantalla < 600;
        final padHorizontal = esMovil
            ? 16.0
            : anchoPantalla < 960
                ? 24.0
                : 40.0;

        return RefreshIndicator(
          onRefresh: _refrescar,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              padHorizontal,
              esMovil ? 14 : 10,
              padHorizontal,
              esMovil ? 28 : 40,
            ),
            children: [
              // ===============================================================
              // CABECERA: Dashboard / Resumen general de tu negocio
              // ===============================================================
              Text(
                'Dashboard',
                style: TextStyle(
                  fontSize: esMovil ? 26 : 34,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A202C),
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Resumen general de tu negocio',
                style: TextStyle(
                  fontSize: esMovil ? 13.5 : 15,
                  color: const Color(0xFF64748B),
                ),
              ),
              SizedBox(height: esMovil ? 18 : 30),

              // ===============================================================
              // SECCIÓN DE ALERTAS SUPERIORES (si hay stock bajo o agotados)
              // ===============================================================
              if (datos.stockBajo > 0)
                _bannerAlerta(
                  texto:
                      'Hay ${datos.stockBajo} producto${datos.stockBajo == 1 ? '' : 's'} con stock bajo.',
                  fondo: const Color(0xFFFFFBEB),
                  borde: const Color(0xFFFDE68A),
                  colorTexto: const Color(0xFF92400E),
                ),
              if (datos.agotados > 0)
                _bannerAlerta(
                  texto:
                      'Hay ${datos.agotados} producto${datos.agotados == 1 ? '' : 's'} agotado${datos.agotados == 1 ? '' : 's'}.',
                  fondo: const Color(0xFFFFF1F2),
                  borde: const Color(0xFFFECDD3),
                  colorTexto: const Color(0xFF991B1B),
                ),

              // ===============================================================
              // TARJETAS DE MÉTRICAS (idénticas a style1.css .metricas)
              // ===============================================================
              _seccionMetricas(datos),

              SizedBox(height: esMovil ? 20 : 30),

              // ===============================================================
              // SECCIÓN INFERIOR: Actividad Reciente + Alertas del Sistema
              // ===============================================================
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth >= 820) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _panelActividadReciente(
                            datos.recientes,
                            compacto: false,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: _panelAlertasSistema(
                            datos,
                            compacto: false,
                          ),
                        ),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _panelActividadReciente(
                        datos.recientes,
                        compacto: esMovil,
                      ),
                      const SizedBox(height: 16),
                      _panelAlertasSistema(
                        datos,
                        compacto: esMovil,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _bannerAlerta({
    required String texto,
    required Color fondo,
    required Color borde,
    required Color colorTexto,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borde),
      ),
      child: Text(
        texto,
        style: TextStyle(color: colorTexto, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _seccionMetricas(_DatosDashboard datos) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ancho = constraints.maxWidth;
        final esMovil = ancho < 560;
        // En iPhone (375–430px) y Samsung (360–412px) mostramos 2 columnas
        // para las 4 primeras métricas y ancho completo para Ventas del Mes.
        final columnas = ancho >= 900
            ? 4
            : ancho >= 310
                ? 2
                : 1;
        final gap = esMovil ? 12.0 : 20.0;
        final anchoItem =
            (ancho - (gap * (columnas - 1))) / columnas;

        final tarjetas = [
          // Card 1: Usuarios Activos -> linear-gradient(135deg, #e3f2fd 0%, #bbdefb 100%)
          _TarjetaMetricaWeb(
            titulo: 'Usuarios Activos',
            valor: '${datos.usuariosActivos}',
            compacto: esMovil,
            gradiente: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
            ),
          ),
          // Card 2: Productos -> #ffffff
          _TarjetaMetricaWeb(
            titulo: 'Productos',
            valor: '${datos.productos}',
            compacto: esMovil,
            colorFondo: Colors.white,
          ),
          // Card 3: Stock Bajo -> linear-gradient(135deg, #fffbeb 0%, #fef3c7 100%)
          _TarjetaMetricaWeb(
            titulo: 'Stock Bajo',
            valor: '${datos.stockBajo}',
            compacto: esMovil,
            gradiente: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
            ),
          ),
          // Card 4: Agotados -> linear-gradient(135deg, #fff1f2 0%, #fecdd3 100%)
          _TarjetaMetricaWeb(
            titulo: 'Agotados',
            valor: '${datos.agotados}',
            compacto: esMovil,
            gradiente: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFF1F2), Color(0xFFFECDD3)],
            ),
          ),
          // Card 5: Ventas del Mes -> #ffffff
          _TarjetaMetricaWeb(
            titulo: 'Ventas del Mes',
            valor: '\$${Formato.miles(datos.ventasMes)}',
            compacto: esMovil,
            colorFondo: Colors.white,
          ),
        ];

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < tarjetas.length; i++)
              SizedBox(
                width: (columnas == 2 && i == tarjetas.length - 1)
                    ? ancho
                    : anchoItem,
                child: tarjetas[i],
              ),
          ],
        );
      },
    );
  }

  Widget _panelActividadReciente(
    List<Auditoria> recientes, {
    required bool compacto,
  }) {
    return Container(
      padding: EdgeInsets.all(compacto ? 16 : 25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 15,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'REGISTRO DEL SISTEMA',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.9,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Actividad Reciente',
                      style: TextStyle(
                        color: const Color(0xFF1A202C),
                        fontSize: compacto ? 17.5 : 19.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${recientes.length}',
                  style: const TextStyle(
                    color: Color(0xFF3A56E4),
                    fontSize: 12.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (recientes.isEmpty)
            const Text(
              'No hay actividades registradas todavía.',
              style: TextStyle(
                color: Color(0xFF2D3748),
                fontSize: 15,
              ),
            )
          else
            for (var i = 0; i < recientes.length; i++)
              _itemActividadWeb(
                recientes[i],
                esUltimo: i == recientes.length - 1,
              ),
        ],
      ),
    );
  }

  Widget _itemActividadWeb(Auditoria a, {required bool esUltimo}) {
    final f = a.fecha;
    final fechaTexto =
        '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year} '
        '${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: esUltimo
            ? null
            : const Border(
                bottom: BorderSide(color: Color(0xFFF1F3F4), width: 1),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.show_chart,
              size: 18,
              color: Color(0xFF0369A1),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontFamily: 'Segoe UI',
                      fontSize: 14,
                      height: 1.4,
                    ),
                    children: [
                      TextSpan(
                        text: '${a.usuario} ',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      TextSpan(
                        text: a.accion,
                        style: const TextStyle(
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        a.modulo.toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    Text(
                      fechaTexto,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _panelAlertasSistema(
    _DatosDashboard datos, {
    required bool compacto,
  }) {
    final hayAlertas = datos.stockBajo > 0 || datos.agotados > 0;
    return Container(
      padding: EdgeInsets.all(compacto ? 16 : 25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 15,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Alertas del Sistema',
            style: TextStyle(
              color: const Color(0xFF1A202C),
              fontSize: compacto ? 17.5 : 19.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          if (!hayAlertas)
            const Text(
              'No hay alertas de stock.',
              style: TextStyle(
                color: Color(0xFF2D3748),
                fontSize: 15.2,
              ),
            )
          else ...[
            if (datos.stockBajo > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 35,
                      height: 35,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFEE2E2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFB91C1C),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Stock bajo: ${datos.stockBajo} producto${datos.stockBajo == 1 ? '' : 's'}.',
                        style: const TextStyle(
                          color: Color(0xFF2D3748),
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (datos.agotados > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 35,
                      height: 35,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFBE9E7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.error_outline,
                        color: Color(0xFFD84315),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Agotados: ${datos.agotados} producto${datos.agotados == 1 ? '' : 's'}.',
                        style: const TextStyle(
                          color: Color(0xFF2D3748),
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _TarjetaMetricaWeb extends StatelessWidget {
  final String titulo;
  final String valor;
  final Gradient? gradiente;
  final Color? colorFondo;
  final bool compacto;

  const _TarjetaMetricaWeb({
    required this.titulo,
    required this.valor,
    this.gradiente,
    this.colorFondo,
    this.compacto = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compacto ? 14 : 20,
        vertical: compacto ? 16 : 25,
      ),
      decoration: BoxDecoration(
        color: gradiente == null ? (colorFondo ?? Colors.white) : null,
        gradient: gradiente,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 15,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compacto ? 13.5 : 16.5,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF2D3748),
            ),
          ),
          SizedBox(height: compacto ? 8 : 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valor,
              style: TextStyle(
                fontSize: compacto ? 28 : 38,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A202C),
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DatosDashboard {
  final int usuariosActivos;
  final int productos;
  final int stockBajo;
  final int agotados;
  final double ventasMes;
  final List<Auditoria> recientes;
  final List<Producto> alertas;

  const _DatosDashboard({
    required this.usuariosActivos,
    required this.productos,
    required this.stockBajo,
    required this.agotados,
    required this.ventasMes,
    required this.recientes,
    required this.alertas,
  });
}

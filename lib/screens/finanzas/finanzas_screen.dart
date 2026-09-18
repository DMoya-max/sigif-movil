import 'package:flutter/material.dart';

import '../../core/constantes.dart';
import '../../core/formato.dart';
import '../../db/repos/gastos_repository.dart';
import '../../models/gasto.dart';
import '../../services/auth_service.dart';
import '../../services/finanzas_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'gasto_form_screen.dart';

class FinanzasScreen extends StatefulWidget {
  const FinanzasScreen({super.key});

  @override
  State<FinanzasScreen> createState() => _FinanzasScreenState();
}

class _FinanzasScreenState extends State<FinanzasScreen> {
  Periodo _periodo = Periodo.mes();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Finanzas',
                    style: TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                _SelectorPeriodo(
                  periodo: _periodo,
                  onChanged: (p) => setState(() => _periodo = p),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'P&G'),
              Tab(text: 'Gastos'),
              Tab(text: 'Ventas por categoría'),
              Tab(text: 'Rentabilidad'),
              Tab(text: 'Caja / Conciliación'),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              children: [
                _ResumenTab(periodo: _periodo),
                _GastosTab(periodo: _periodo),
                _VentasCategoriaTab(periodo: _periodo),
                _RentabilidadTab(periodo: _periodo),
                _CajaTab(periodo: _periodo),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Selector de periodo
// ---------------------------------------------------------------------
class _SelectorPeriodo extends StatefulWidget {
  final Periodo periodo;
  final ValueChanged<Periodo> onChanged;

  const _SelectorPeriodo({required this.periodo, required this.onChanged});

  @override
  State<_SelectorPeriodo> createState() => _SelectorPeriodoState();
}

class _SelectorPeriodoState extends State<_SelectorPeriodo> {
  static const _opciones = {
    'hoy': 'Hoy',
    'semana': 'Semana',
    'mes': 'Mes',
    'ano': 'Año',
    'personalizado': 'Personalizado',
  };

  Future<void> _seleccionarOp(String opcion) async {
    switch (opcion) {
      case 'hoy':
        widget.onChanged(Periodo.hoy());
      case 'semana':
        widget.onChanged(Periodo.semana());
      case 'mes':
        widget.onChanged(Periodo.mes());
      case 'ano':
        widget.onChanged(Periodo.anio());
      case 'personalizado':
        final ahora = DateTime.now();
        final desde = await showDatePicker(
          context: context,
          initialDate: DateTime(ahora.year, ahora.month, 1),
          firstDate: DateTime(ahora.year - 5),
          lastDate: ahora,
        );
        if (desde == null) return;
        if (!mounted) return;
        final hasta = await showDatePicker(
          context: context,
          initialDate: ahora,
          firstDate: desde,
          lastDate: DateTime(ahora.year + 5),
        );
        if (hasta == null) return;
        widget.onChanged(Periodo.personalizado(desde, hasta));
    }
  }

  @override
  Widget build(BuildContext context) {
    final actual = widget.periodo.opcion;
    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final e in _opciones.entries)
          ChoiceChip(
            label: Text(e.value),
            selected: actual == e.key,
            onSelected: (_) => _seleccionarOp(e.key),
          ),
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Text(
            '${Formato.fecha(widget.periodo.inicio)} – ${Formato.fecha(widget.periodo.fin)}',
            style: const TextStyle(
                fontSize: 12.5, color: ColoresSigif.textoMitigado),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// P&G
// ---------------------------------------------------------------------
class _ResumenTab extends StatelessWidget {
  final Periodo periodo;
  const _ResumenTab({required this.periodo});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ResumenFinanciero>(
      future: FinanzasService.abrir().then((s) => s.resumen(periodo)),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final r = snap.data!;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _gridResumenPyg(r),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _CardLista(
                    titulo: 'Ventas por día',
                    filas: [
                      for (final e in r.porDia.entries)
                        (e.key, Formato.cop(e.value)),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _CardLista(
                    titulo: 'Gastos por categoría',
                    filas: [
                      for (final g in _gastosPorCategoria(r.gastos))
                        (Constantes.categoriasGasto[g.key] ?? g.key,
                            Formato.cop(g.value)),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _CardLista(
                    titulo: 'Ventas por método',
                    filas: [
                      for (final e in r.metodosPago.entries)
                        (Constantes.metodosPagoLabel[e.key] ?? e.key,
                            Formato.cop(e.value)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  List<MapEntry<String, double>> _gastosPorCategoria(List<Gasto> gastos) {
    final mapa = <String, double>{};
    for (final g in gastos) {
      mapa[g.categoria] = (mapa[g.categoria] ?? 0) + g.valor;
    }
    final lista = mapa.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return lista;
  }

  Widget _gridResumenPyg(ResumenFinanciero r) {
    final tarjetas = [
      MetricaCard(
          titulo: 'Ingresos',
          valor: Formato.cop(r.ingresos),
          icono: Icons.trending_up,
          color: ColoresSigif.exito),
      MetricaCard(
          titulo: 'Costos de venta',
          valor: Formato.cop(r.costos),
          icono: Icons.shopping_cart_outlined,
          color: ColoresSigif.advertencia),
      MetricaCard(
          titulo: 'Gastos',
          valor: Formato.cop(r.gastosTotal),
          icono: Icons.receipt_long_outlined,
          color: ColoresSigif.peligro),
      MetricaCard(
          titulo: 'Utilidad bruta',
          valor: Formato.cop(r.utilidadBruta),
          icono: Icons.account_balance_outlined,
          color: ColoresSigif.azulPrimario),
      MetricaCard(
          titulo: 'Utilidad neta',
          valor: Formato.cop(r.utilidadNeta),
          icono: Icons.savings_outlined,
          color: ColoresSigif.info),
      MetricaCard(
          titulo: 'Margen neto',
          valor: '${r.margen.toStringAsFixed(1)}%',
          icono: Icons.percent,
          color: ColoresSigif.verde),
      MetricaCard(
          titulo: 'Ventas',
          valor: '${r.ventas}',
          icono: Icons.receipt_outlined,
          color: ColoresSigif.textoOscuro),
      MetricaCard(
          titulo: 'Ticket promedio',
          valor: Formato.cop(r.ticketPromedio),
          icono: Icons.confirmation_number_outlined,
          color: ColoresSigif.advertencia),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final cols = constraints.maxWidth >= 1200
          ? 4
          : constraints.maxWidth >= 700
              ? 3
              : 2;
      return GridView.count(
        crossAxisCount: cols,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        children: tarjetas,
      );
    });
  }
}

class _CardLista extends StatelessWidget {
  final String titulo;
  final List<(String, String)> filas;

  const _CardLista({required this.titulo, required this.filas});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            if (filas.isEmpty)
              const Text('Sin datos en el periodo.',
                  style: TextStyle(color: ColoresSigif.textoMitigado))
            else
              for (final (k, v) in filas)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(k,
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis),
                      ),
                      Text(v,
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
}

// ---------------------------------------------------------------------
// Gastos
// ---------------------------------------------------------------------
class _GastosTab extends StatefulWidget {
  final Periodo periodo;
  const _GastosTab({required this.periodo});

  @override
  State<_GastosTab> createState() => _GastosTabState();
}

class _GastosTabState extends State<_GastosTab> {
  late Future<List<Gasto>> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = _cargar();
  }

  @override
  void didUpdateWidget(covariant _GastosTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.periodo.opcion != widget.periodo.opcion) {
      _futuro = _cargar();
    }
  }

  Future<List<Gasto>> _cargar() async {
    final repo = await GastosRepository.abrir();
    return repo.listar(inicio: widget.periodo.inicio, fin: widget.periodo.fin);
  }

  bool get _puedeGestionar =>
      SessionService.instance.usuario?.puedeCrearGastos ?? false;

  Future<void> _crear() async {
    final creado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const GastoFormScreen()),
    );
    if (creado == true) setState(() => _futuro = _cargar());
  }

  Future<void> _editar(Gasto g) async {
    final editado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => GastoFormScreen(gasto: g)),
    );
    if (editado == true) setState(() => _futuro = _cargar());
  }

  Future<void> _eliminar(Gasto g) async {
    final ok = await confirmar(
      context,
      titulo: 'Eliminar gasto',
      mensaje: '¿Eliminar "${g.concepto}" por ${Formato.cop(g.valor)}?',
      textoConfirmar: 'Eliminar',
      peligro: true,
    );
    if (!ok || !mounted) return;
    final repo = await GastosRepository.abrir();
    await repo.eliminar(g.id!);
    await repo.auditar(SessionService.instance.nombreUsuario,
        'ELIMINÓ EL GASTO ${g.concepto}');
    if (!mounted) return;
    notificar(context, 'Gasto eliminado');
    setState(() => _futuro = _cargar());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Gasto>>(
      future: _futuro,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final gastos = snap.data ?? [];
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Gastos del periodo',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                if (_puedeGestionar)
                  ElevatedButton.icon(
                    onPressed: _crear,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Nuevo gasto'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (gastos.isEmpty)
              const EstadoVacio(
                icono: Icons.receipt_long_outlined,
                titulo: 'Sin gastos',
                mensaje: 'No hay gastos registrados en este periodo.',
              )
            else
              for (final g in gastos)
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: ColoresSigif.peligro.withValues(alpha: 0.12),
                      child: const Icon(Icons.payments_outlined,
                          color: ColoresSigif.peligro),
                    ),
                    title: Text(g.concepto,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14.5)),
                    subtitle: Text(
                      '${Constantes.categoriasGasto[g.categoria] ?? g.categoria} · ${Formato.fecha(g.fecha)} · ${Constantes.metodosPagoLabel[g.metodoPago] ?? g.metodoPago}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: _puedeGestionar
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(Formato.cop(g.valor),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800)),
                              PopupMenuButton<String>(
                                onSelected: (op) {
                                  if (op == 'editar') _editar(g);
                                  if (op == 'eliminar') _eliminar(g);
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                      value: 'editar', child: Text('Editar')),
                                  PopupMenuItem(
                                      value: 'eliminar', child: Text('Eliminar')),
                                ],
                              ),
                            ],
                          )
                        : Text(Formato.cop(g.valor),
                            style: const TextStyle(
                                fontWeight: FontWeight.w800)),
                  ),
                ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------
// Ventas por categoría
// ---------------------------------------------------------------------
class _VentasCategoriaTab extends StatelessWidget {
  final Periodo periodo;
  const _VentasCategoriaTab({required this.periodo});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, Object?>>>(
      future: FinanzasService.abrir().then((s) => s.ventasPorCategoria(periodo)),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final lista = snap.data ?? [];
        if (lista.isEmpty) {
          return const EstadoVacio(
            icono: Icons.category_outlined,
            titulo: 'Sin ventas',
            mensaje: 'No hay ventas por categoría en este periodo.',
          );
        }
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            for (final c in lista)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${c['categoria']}',
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w800)),
                          Text(
                              'Margen ${(c['margen'] as num).toStringAsFixed(1)}%',
                              style: const TextStyle(
                                  color: ColoresSigif.exito,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _fila('Ingresos', Formato.cop(c['ingresos'] as num)),
                      _fila('Costos', Formato.cop(c['costos'] as num)),
                      _fila('Ganancia', Formato.cop(c['ganancia'] as num)),
                      _fila('Unidades', '${c['unidades']}'),
                      _fila('Transacciones', '${c['transacciones']}'),
                      _fila('SKUs', '${c['total_skus']}'),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _fila(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: const TextStyle(color: ColoresSigif.textoMitigado)),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Rentabilidad
// ---------------------------------------------------------------------
class _RentabilidadTab extends StatelessWidget {
  final Periodo periodo;
  const _RentabilidadTab({required this.periodo});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, Object?>>>(
      future: FinanzasService.abrir().then((s) => s.rentabilidad(periodo)),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final lista = snap.data ?? [];
        if (lista.isEmpty) {
          return const EstadoVacio(
            icono: Icons.leaderboard_outlined,
            titulo: 'Sin datos',
            mensaje: 'No hay productos vendidos en este periodo.',
          );
        }
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            for (final p in lista)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${p['nombre']}',
                          style: const TextStyle(
                              fontSize: 14.5, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                              'Ganancia: ${Formato.cop(p['ganancia'] as num)} · Margen ${(p['margen'] as num).toStringAsFixed(1)}%',
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  color: ColoresSigif.exito)),
                          Text(
                              'Rotación: ${(p['rotacion'] as num).toStringAsFixed(1)}%',
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  color: ColoresSigif.textoMitigado)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                          'Vendidos: ${p['cantidad']} · Stock actual: ${p['stock']}',
                          style: const TextStyle(
                              fontSize: 12.5,
                              color: ColoresSigif.textoMitigado)),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------
// Caja / Conciliación
// ---------------------------------------------------------------------
class _CajaTab extends StatelessWidget {
  final Periodo periodo;
  const _CajaTab({required this.periodo});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, Object?>>(
      future: FinanzasService.abrir().then((s) => s.cajaConciliacion(periodo)),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final d = snap.data!;
        final cortes = (d['cortes_diarios'] as List)
            .cast<Map<String, Object?>>();
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _gridResumen(d),
            const SizedBox(height: 20),
            const Text('Cortes diarios',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            if (cortes.isEmpty)
              const EstadoVacio(
                icono: Icons.balance_outlined,
                titulo: 'Sin movimiento',
                mensaje: 'No hay cortes diarios en este periodo.',
              )
            else
              for (final c in cortes)
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${c['fecha']}',
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w800)),
                            Text('${c['num_ventas']} ventas · ${c['num_gastos']} gastos',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: ColoresSigif.textoMitigado)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _fila('Efectivo (ventas)',
                            Formato.cop(c['ventas_efectivo'] as num)),
                        _fila('Tarjeta', Formato.cop(c['ventas_tarjeta'] as num)),
                        _fila('Transferencia',
                            Formato.cop(c['ventas_transferencia'] as num)),
                        _fila('Crédito', Formato.cop(c['ventas_credito'] as num)),
                        _fila('Entradas totales',
                            Formato.cop(c['total_entradas'] as num)),
                        _fila('Gastos en efectivo',
                            Formato.cop(c['gastos_efectivo'] as num)),
                        _fila('Gastos otros',
                            Formato.cop(c['gastos_otros'] as num)),
                        const Divider(height: 14),
                        _fila('Saldo caja efectivo',
                            Formato.cop(c['saldo_caja_efectivo'] as num),
                            color: ColoresSigif.exito),
                        _fila('Flujo neto',
                            Formato.cop(c['total_neto'] as num),
                            color: ColoresSigif.azulPrimario),
                      ],
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }

  Widget _fila(String k, String v, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: const TextStyle(color: ColoresSigif.textoMitigado)),
          Text(v,
              style:
                  TextStyle(fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  Widget _gridResumen(Map<String, Object?> d) {
    final cards = [
      MetricaCard(
          titulo: 'Efectivo en ventas',
          valor: Formato.cop(d['total_efectivo_ventas'] as num),
          icono: Icons.payments_outlined,
          color: ColoresSigif.exito),
      MetricaCard(
          titulo: 'Tarjeta',
          valor: Formato.cop(d['total_tarjeta_ventas'] as num),
          icono: Icons.credit_card_outlined,
          color: ColoresSigif.azulPrimario),
      MetricaCard(
          titulo: 'Transferencia',
          valor: Formato.cop(d['total_transf_ventas'] as num),
          icono: Icons.account_balance_outlined,
          color: ColoresSigif.info),
      MetricaCard(
          titulo: 'Crédito (por cobrar)',
          valor: Formato.cop(d['total_credito_ventas'] as num),
          icono: Icons.schedule_outlined,
          color: ColoresSigif.advertencia),
      MetricaCard(
          titulo: 'Gastos efectivo',
          valor: Formato.cop(d['total_gastos_efectivo'] as num),
          icono: Icons.shopping_basket_outlined,
          color: ColoresSigif.peligro),
      MetricaCard(
          titulo: 'Saldo efectivo en caja',
          valor: Formato.cop(d['saldo_efectivo_en_caja'] as num),
          icono: Icons.savings_outlined,
          color: ColoresSigif.verde),
      MetricaCard(
          titulo: 'Cuentas por cobrar',
          valor: Formato.cop(d['cuentas_pendientes'] as num),
          icono: Icons.hourglass_empty_outlined,
          color: ColoresSigif.advertencia),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final cols = constraints.maxWidth >= 1200
          ? 4
          : constraints.maxWidth >= 700
              ? 3
              : 2;
      return GridView.count(
        crossAxisCount: cols,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        children: cards,
      );
    });
  }
}
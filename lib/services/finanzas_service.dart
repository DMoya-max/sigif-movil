import 'package:sqflite/sqflite.dart';

import '../db/database.dart';
import '../db/repos/gastos_repository.dart';
import '../models/factura.dart';
import '../models/gasto.dart';
import '../models/inventario.dart';

/// Clase que representa un periodo de filtrado (equivalente a `_periodo`).
class Periodo {
  final DateTime inicio;
  final DateTime fin;
  final String opcion;

  const Periodo({required this.inicio, required this.fin, required this.opcion});

  static Periodo hoy() {
    final now = DateTime.now();
    return Periodo(inicio: _inicioDia(now), fin: _finDia(now), opcion: 'hoy');
  }

  static Periodo semana() {
    final now = DateTime.now();
    final inicio = _inicioDia(now.subtract(Duration(days: now.weekday - 1)));
    return Periodo(inicio: inicio, fin: _finDia(now), opcion: 'semana');
  }

  static Periodo mes() {
    final now = DateTime.now();
    return Periodo(inicio: DateTime(now.year, now.month, 1), fin: _finDia(now), opcion: 'mes');
  }

  static Periodo anio() {
    final now = DateTime.now();
    return Periodo(inicio: DateTime(now.year, 1, 1), fin: _finDia(now), opcion: 'ano');
  }

  static Periodo personalizado(DateTime desde, DateTime hasta) =>
      Periodo(inicio: _inicioDia(desde), fin: _finDia(hasta), opcion: 'personalizado');

  static DateTime _inicioDia(DateTime d) => DateTime(d.year, d.month, d.day);
  static DateTime _finDia(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59);
}

/// Resumen financiero consolidado del periodo (equivale a `_resumen`).
class ResumenFinanciero {
  final List<Factura> facturas;
  final List<Gasto> gastos;
  final double ingresos;
  final double costos;
  final double gastosTotal;
  final double utilidadBruta;
  final double utilidadNeta;
  final double margen;
  final int ventas;
  final double ticketPromedio;
  final List<Map<String, Object?>> productos;
  final Map<String, double> porDia;
  final Map<String, double> metodosPago;

  const ResumenFinanciero({
    required this.facturas,
    required this.gastos,
    required this.ingresos,
    required this.costos,
    required this.gastosTotal,
    required this.utilidadBruta,
    required this.utilidadNeta,
    required this.margen,
    required this.ventas,
    required this.ticketPromedio,
    required this.productos,
    required this.porDia,
    required this.metodosPago,
  });
}

class FinanzasService {
  final Database _db;
  FinanzasService(this._db);

  static Future<FinanzasService> abrir() async =>
      FinanzasService(await AppDatabase.instance.db);

  String _pd(int v, int n) => v.toString().padLeft(n, '0');

  String _isoDiaSalida(DateTime d) => '${_pd(d.year, 4)}-${_pd(d.month, 2)}-${_pd(d.day, 2)}';

  /// Consulta las facturas del periodo (fecha >= inicio && fecha < fin+1).
  Future<List<Factura>> _facturasPeriodo(Periodo p) async {
    final filas = await _db.query(
      'facturas',
      where: 'fecha >= ? AND fecha < ?',
      whereArgs: [p.inicio.toIso8601String(), p.fin.add(const Duration(days: 1)).toIso8601String()],
      orderBy: 'fecha',
    );
    return filas.map(Factura.desdeMapa).toList();
  }

  Future<List<DetalleFactura>> _detallesDe(List<int> facturaIds) async {
    if (facturaIds.isEmpty) return [];
    final lugar = List.filled(facturaIds.length, '?').join(',');
    final filas = await _db.rawQuery(
      'SELECT * FROM detalle_factura WHERE factura_id IN ($lugar)',
      facturaIds,
    );
    return filas.map(DetalleFactura.desdeMapa).toList();
  }

  Future<List<DetalleEntradaInventario>> _comprasDeProductos(List<int> productIds) async {
    if (productIds.isEmpty) return [];
    final lugar = List.filled(productIds.length, '?').join(',');
    final filas = await _db.rawQuery(
      'SELECT d.*, e.fecha AS entrada_fecha '
      'FROM detalle_entrada_inventario d '
      'JOIN entrada_inventario e ON e.id = d.entrada_id '
      'WHERE d.producto_id IN ($lugar) ORDER BY d.producto_id, e.fecha DESC, d.id DESC',
      productIds,
    );
    return filas.map(DetalleEntradaInventario.desdeMapa).toList();
  }

  Future<Map<int, String>> _nombresProductos(List<int> ids) async {
    final map = <int, String>{};
    if (ids.isEmpty) return map;
    final lugar = List.filled(ids.length, '?').join(',');
    final filas = await _db.rawQuery('SELECT id, nombre FROM productos WHERE id IN ($lugar)', ids);
    for (final f in filas) {
      map[f['id'] as int] = (f['nombre'] as String) ?? '';
    }
    return map;
  }

  Future<ResumenFinanciero> resumen(Periodo p) async {
    final facturas = await _facturasPeriodo(p);
    final ingresos = facturas.fold<double>(0, (a, f) => a + f.valorPagado);

    final detalles = await _detallesDe(facturas.map((f) => f.id!).toList());
    final productIds = detalles.map((d) => d.productoId).toSet().toList();
    final compras = await _comprasDeProductos(productIds);
    final nombres = await _nombresProductos(productIds);

    // Mapa producto -> [compras]
    final comprasPorProducto = <int, List<DetalleEntradaInventario>>{};
    for (final c in compras) {
      comprasPorProducto.putIfAbsent(c.productoId, () => []).add(c);
    }

    // Costos + agrupación por producto
    var costos = 0.0;
    final productos = <int, Map<String, Object?>>{};
    for (final det in detalles) {
      var unitario = 0;
      final lista = comprasPorProducto[det.productoId] ?? [];
      if (lista.isNotEmpty) {
        unitario = lista.first.precio;
      }
      final costoLinea = (unitario * det.cantidad).toDouble();
      costos += costoLinea;

      final item = productos.putIfAbsent(det.productoId, () => {
        'producto_id': det.productoId,
        'nombre': nombres[det.productoId] ?? '',
        'cantidad': 0,
        'ingresos': 0.0,
        'costos': 0.0,
        'ganancia': 0.0,
        'margen': 0.0,
        'stock': 0,
      });
      item['cantidad'] = (item['cantidad'] as int) + det.cantidad;
      item['ingresos'] = (item['ingresos'] as double) + det.subtotal;
      item['costos'] = (item['costos'] as double) + costoLinea;
    }

    final listaProductos = <Map<String, Object?>>[];
    for (final item in productos.values) {
      final ingresosP = item['ingresos'] as double;
      final costosP = item['costos'] as double;
      item['ganancia'] = ingresosP - costosP;
      item['margen'] = ingresosP > 0 ? (ingresosP - costosP) / ingresosP * 100 : 0.0;
      item['rotacion'] = 0.0;
      listaProductos.add(item);
    }

    // Gastos del periodo
    final gastosRepo = GastosRepository(_db);
    final gastos = await gastosRepo.listar(inicio: p.inicio, fin: p.fin);
    final gastosTotal = gastos.fold<double>(0, (a, g) => a + g.valor);

    final utilidadBruta = ingresos - costos;
    final utilidadNeta = utilidadBruta - gastosTotal;
    final margen = ingresos > 0 ? utilidadNeta / ingresos * 100 : 0.0;
    final ticketPromedio = facturas.isNotEmpty ? ingresos / facturas.length : 0.0;

    // Por día y por método de pago
    final porDia = <String, double>{};
    for (final f in facturas) {
      final clave = '${_pd(f.fecha.month, 2)}/${_pd(f.fecha.day, 2)}';
      porDia[clave] = (porDia[clave] ?? 0) + f.valorPagado;
    }
    for (final g in gastos) {
      final clave = '${_pd(g.fecha.month, 2)}/${_pd(g.fecha.day, 2)}';
      porDia[clave] = (porDia[clave] ?? 0) - g.valor;
    }

    final metodos = <String, double>{};
    for (final f in facturas) {
      metodos[f.metodoPago] = (metodos[f.metodoPago] ?? 0) + f.valorPagado;
    }

    return ResumenFinanciero(
      facturas: facturas,
      gastos: gastos,
      ingresos: ingresos,
      costos: costos,
      gastosTotal: gastosTotal,
      utilidadBruta: utilidadBruta,
      utilidadNeta: utilidadNeta,
      margen: margen,
      ventas: facturas.length,
      ticketPromedio: ticketPromedio,
      productos: listaProductos,
      porDia: porDia,
      metodosPago: metodos,
    );
  }

  /// Ventas por categoría de producto (equivale a `ventas_categoria`).
  Future<List<Map<String, Object?>>> ventasPorCategoria(Periodo p) async {
    final r = await resumen(p);
    final catMap = <String, Map<String, Object?>>{};

    final facturaIds = r.facturas.map((f) => f.id!).toList();
    if (facturaIds.isNotEmpty) {
      final lugar = List.filled(facturaIds.length, '?').join(',');
      final filas = await _db.rawQuery(
        'SELECT df.producto_id, df.cantidad, df.subtotal, p.categoria, p.nombre AS pnombre, df.factura_id '
        'FROM detalle_factura df JOIN productos p ON p.id = df.producto_id '
        'WHERE df.factura_id IN ($lugar)',
        facturaIds,
      );
      final productIds = filas.map((f) => f['producto_id'] as int).toSet().toList();
      final compras = await _comprasDeProductos(productIds);
      final comprasPor = <int, List<DetalleEntradaInventario>>{};
      for (final c in compras) {
        comprasPor.putIfAbsent(c.productoId, () => []).add(c);
      }

      for (final f in filas) {
        final cat = ((f['categoria'] as String?) ?? '').isEmpty ? 'Repuestos Generales' : (f['categoria'] as String);
        final entry = catMap.putIfAbsent(cat!, () => {
          'categoria': cat,
          'ingresos': 0.0,
          'costos': 0.0,
          'unidades': 0,
          'facturas': <int>{},
          'productos': <String>{},
        });
        entry['ingresos'] = (entry['ingresos'] as double) + (f['subtotal'] as num).toDouble();
        entry['unidades'] = (entry['unidades'] as int) + (f['cantidad'] as int);
        (entry['facturas'] as Set<int>).add(f['factura_id'] as int);
        (entry['productos'] as Set<String>).add((f['pnombre'] as String?) ?? '');
        final comprasLista = comprasPor[f['producto_id']] ?? [];
        final unitario = comprasLista.isNotEmpty ? comprasLista.first.precio : 0;
        entry['costos'] = (entry['costos'] as double) + (unitario * (f['cantidad'] as int)).toDouble();
      }
    }

    final resultado = <Map<String, Object?>>[];
    var totalUnidades = 0;
    for (final e in catMap.values) {
      final ingresos = e['ingresos'] as double;
      final costos = e['costos'] as double;
      e['ganancia'] = ingresos - costos;
      e['margen'] = ingresos > 0 ? (ingresos - costos) / ingresos * 100 : 0.0;
      e['transacciones'] = (e['facturas'] as Set<int>).length;
      e['total_skus'] = (e['productos'] as Set<String>).length;
      e.remove('facturas');
      e.remove('productos');
      totalUnidades += e['unidades'] as int;
      resultado.add(e);
    }
    resultado.sort((a, b) => ((b['ingresos'] as double)).compareTo(a['ingresos'] as double));
    return resultado;
  }

  /// Rentabilidad: agrega rotación por producto (equivale a `rentabilidad`).
  Future<List<Map<String, Object?>>> rentabilidad(Periodo p) async {
    final r = await resumen(p);
    final lista = List<Map<String, Object?>>.from(r.productos);

    final productIds = lista.map((x) => x['producto_id'] as int).toList();
    final stocks = <int, int>{};
    if (productIds.isNotEmpty) {
      final lugar = List.filled(productIds.length, '?').join(',');
      final filas = await _db.rawQuery('SELECT id, stock FROM productos WHERE id IN ($lugar)', productIds);
      for (final f in filas) {
        stocks[f['id'] as int] = (f['stock'] as int?) ?? 0;
      }
    }

    for (final item in lista) {
      final pid = item['producto_id'] as int;
      final vendidos = item['cantidad'] as int;
      final stockActual = stocks[pid] ?? 0;
      final total = stockActual + vendidos;
      item['rotacion'] = total > 0 ? vendidos / total * 100 : 0.0;
    }

    lista.sort((a, b) => ((b['ganancia'] as double)).compareTo(a['ganancia'] as double));
    return lista;
  }

  /// Caja y conciliación: cortes diarios por método de pago.
  Future<Map<String, Object?>> cajaConciliacion(Periodo p) async {
    final r = await resumen(p);

    final dias = <String, Map<String, Object?>>{};
    var totEfVentas = 0.0, totTarjVentas = 0.0, totTransfVentas = 0.0, totCredVentas = 0.0;
    var totEfGastos = 0.0, totOtrosGastos = 0.0;

    for (final f in r.facturas) {
      final clave = _isoDiaSalida(f.fecha);
      final entry = dias.putIfAbsent(clave, () => _cajaVacio(clave));
      entry['total_entradas'] = (entry['total_entradas'] as double) + f.valorPagado;
      entry['num_ventas'] = (entry['num_ventas'] as int) + 1;
      switch (f.metodoPago) {
        case 'EFECTIVO':
          entry['ventas_efectivo'] = (entry['ventas_efectivo'] as double) + f.valorPagado;
          totEfVentas += f.valorPagado;
          break;
        case 'TARJETA':
          entry['ventas_tarjeta'] = (entry['ventas_tarjeta'] as double) + f.valorPagado;
          totTarjVentas += f.valorPagado;
          break;
        case 'TRANSFERENCIA':
          entry['ventas_transferencia'] = (entry['ventas_transferencia'] as double) + f.valorPagado;
          totTransfVentas += f.valorPagado;
          break;
        default:
          entry['ventas_credito'] = (entry['ventas_credito'] as double) + f.valorPagado;
          totCredVentas += f.valorPagado;
      }
    }

    for (final g in r.gastos) {
      final clave = _isoDiaSalida(g.fecha);
      final entry = dias.putIfAbsent(clave, () => _cajaVacio(clave));
      entry['total_salidas'] = (entry['total_salidas'] as double) + g.valor;
      entry['num_gastos'] = (entry['num_gastos'] as int) + 1;
      if (g.metodoPago == 'EFECTIVO') {
        entry['gastos_efectivo'] = (entry['gastos_efectivo'] as double) + g.valor;
        totEfGastos += g.valor;
      } else {
        entry['gastos_otros'] = (entry['gastos_otros'] as double) + g.valor;
        totOtrosGastos += g.valor;
      }
    }

    final cortes = dias.values.toList()
      ..sort((a, b) => (b['fecha'] as String).compareTo(a['fecha'] as String));
    for (final c in cortes) {
      c['saldo_caja_efectivo'] = (c['ventas_efectivo'] as double) - (c['gastos_efectivo'] as double);
      c['total_neto'] = (c['total_entradas'] as double) - (c['total_salidas'] as double);
    }

    final cuentasPendientes =
        r.facturas.fold<double>(0, (a, f) => a + f.saldoPendiente);

    return {
      'cortes_diarios': cortes,
      'total_efectivo_ventas': totEfVentas,
      'total_tarjeta_ventas': totTarjVentas,
      'total_transf_ventas': totTransfVentas,
      'total_credito_ventas': totCredVentas,
      'total_gastos_efectivo': totEfGastos,
      'total_gastos_otros': totOtrosGastos,
      'saldo_efectivo_en_caja': totEfVentas - totEfGastos,
      'cuentas_pendientes': cuentasPendientes,
    };
  }

  Map<String, Object?> _cajaVacio(String fecha) => {
        'fecha': fecha,
        'ventas_efectivo': 0.0,
        'ventas_tarjeta': 0.0,
        'ventas_transferencia': 0.0,
        'ventas_credito': 0.0,
        'total_entradas': 0.0,
        'gastos_efectivo': 0.0,
        'gastos_otros': 0.0,
        'total_salidas': 0.0,
        'saldo_caja_efectivo': 0.0,
        'total_neto': 0.0,
        'num_ventas': 0,
        'num_gastos': 0,
      };
}
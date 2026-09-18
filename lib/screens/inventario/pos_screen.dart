import 'package:flutter/material.dart';

import '../../core/constantes.dart';
import '../../core/descuentos.dart';
import '../../core/formato.dart';
import '../../db/database.dart';
import '../../db/repos/clientes_repository.dart';
import '../../db/repos/facturas_repository.dart';
import '../../db/repos/productos_repository.dart';
import '../../models/factura.dart';
import '../../models/producto.dart';
import '../../services/auth_service.dart';
import '../../services/compartir.dart';
import '../../services/pdf_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _ProductoCarrito {
  Producto producto;
  int cantidad;

  _ProductoCarrito(this.producto, this.cantidad);
}

/// Carrito del punto de venta a nivel de módulo: sobrevive a la navegación
/// entre secciones aunque la pantalla se reconstruya para recargar datos.
final List<_ProductoCarrito> _carritoPos = [];

class _PosScreenState extends State<PosScreen> {
  final _busqueda = TextEditingController();
  final _codigoDescuento = TextEditingController();
  final _nuevoClienteNombre = TextEditingController();
  final _nuevoClienteCorreo = TextEditingController();

  List<Producto> _productos = [];
  List<Cliente> _clientes = [];
  String _clienteModo = 'final'; // final | existente | nuevo
  int? _clienteId;
  String _metodoPago = 'EFECTIVO';
  DateTime? _fechaVencimiento;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final db = await AppDatabase.instance.db;
    final prods = await ProductosRepository(db).listar();
    final clientes = await ClientesRepository(db).listar();
    if (!mounted) return;
    setState(() {
      _productos = prods;
      _clientes = clientes;
      // Refresca los datos de los productos que ya están en el carrito.
      for (final item in _carritoPos) {
        final fresco = prods.where((p) => p.id == item.producto.id).toList();
        if (fresco.isNotEmpty) item.producto = fresco.first;
      }
    });
  }

  @override
  void dispose() {
    _busqueda.dispose();
    _codigoDescuento.dispose();
    _nuevoClienteNombre.dispose();
    _nuevoClienteCorreo.dispose();
    super.dispose();
  }

  List<Producto> get _filtrados {
    final q = _busqueda.text.trim().toLowerCase();
    if (q.isEmpty) return _productos;
    return _productos
        .where((p) =>
            p.nombre.toLowerCase().contains(q) ||
            (p.categoria.toLowerCase().contains(q)))
        .toList();
  }

  void _agregar(Producto p) {
    if (!p.activo) {
      notificar(context, '"${p.nombre}" está desactivado y no se puede vender.',
          error: true);
      return;
    }
    if (p.stock <= 0) {
      notificar(context, 'No hay stock disponible de "${p.nombre}".', error: true);
      return;
    }
    final existente = _carritoPos.where((c) => c.producto.id == p.id).toList();
    final enCarrito = existente.isEmpty ? 0 : existente.first.cantidad;
    if (enCarrito >= p.stock) {
      notificar(context, 'Solo hay ${p.stock} u. disponibles de "${p.nombre}".',
          error: true);
      return;
    }
    setState(() {
      if (existente.isNotEmpty) {
        existente.first.cantidad++;
      } else {
        _carritoPos.add(_ProductoCarrito(p, 1));
      }
    });
  }

  void _cambiarCantidad(_ProductoCarrito item, int delta) {
    final nueva = item.cantidad + delta;
    if (nueva <= 0) {
      setState(() => _carritoPos.remove(item));
      return;
    }
    if (nueva > item.producto.stock) {
      notificar(context, 'Solo hay ${item.producto.stock} u. disponibles.',
          error: true);
      return;
    }
    setState(() => item.cantidad = nueva);
  }

  // ------------------------------------------------------------------
  // Totales (misma lógica del backend)
  // ------------------------------------------------------------------
  int get _subtotal =>
      _carritoPos.fold<int>(0, (a, c) => a + (c.producto.precio * c.cantidad));

  int get _pctDescuento =>
      Descuentos.porcentajeCodigo(_codigoDescuento.text);

  int get _valorDescuento => _subtotal * _pctDescuento ~/ 100;

  int get _totalFinal => _subtotal - _valorDescuento;

  double get _baseGravable => _totalFinal / 1.19;

  double get _iva => _totalFinal - _baseGravable;

  Future<void> _confirmarVenta() async {
    if (_carritoPos.isEmpty) {
      notificar(context, 'El carrito está vacío', error: true);
      return;
    }
    if (_clienteModo == 'nuevo' &&
        (_nuevoClienteNombre.text.trim().isEmpty ||
            _nuevoClienteCorreo.text.trim().isEmpty)) {
      notificar(context, 'Indica nombre y correo del cliente nuevo', error: true);
      return;
    }

    final ok = await confirmar(
      context,
      titulo: 'Confirmar venta',
      mensaje: 'Total a cobrar: ${Formato.cop(_totalFinal)}\n'
          'Método: ${Constantes.metodosPagoLabel[_metodoPago] ?? _metodoPago}',
      textoConfirmar: 'Confirmar',
      colorConfirmar: ColoresSigif.exito,
    );
    if (!ok || !mounted) return;

    final repo = await FacturasRepository.abrir();
    final resultado = await repo.confirmarVenta(
      productos: [
        for (final c in _carritoPos) {'id': c.producto.id, 'cantidad': c.cantidad},
      ],
      nombreUsuario: SessionService.instance.nombreUsuario,
      clienteId: _clienteModo == 'existente' ? _clienteId : null,
      nombreCliente: _clienteModo == 'nuevo' ? _nuevoClienteNombre.text : null,
      correoCliente: _clienteModo == 'nuevo' ? _nuevoClienteCorreo.text : null,
      codigoDescuento: _codigoDescuento.text,
      metodoPago: _metodoPago,
      fechaVencimiento: _metodoPago == 'CREDITO' ? _fechaVencimiento : null,
    );

    if (!mounted) return;
    if (resultado.success) {
      await _mostrarTicket(resultado.facturaId!);
      _limpiarVenta();
    } else {
      notificar(context, resultado.message, error: true);
    }
  }

  Future<void> _mostrarTicket(int facturaId) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        icon: const Icon(Icons.check_circle,
            color: ColoresSigif.exito, size: 44),
        title: const Text('¡Venta realizada!'),
        content: Text(
          'La factura #$facturaId fue registrada. '
          'Puedes exportar el ticket en PDF.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final bytes = await PdfService.generoTicketFactura(facturaId);
              if (!ctx.mounted) return;
              await Compartir.guardar(
                bytes: bytes,
                nombre: 'factura_$facturaId.pdf',
                mensaje: 'Factura #$facturaId',
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Compartir PDF'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Listo'),
          ),
        ],
      ),
    );
  }

  void _limpiarVenta() {
    setState(() {
      _carritoPos.clear();
      _clienteModo = 'final';
      _clienteId = null;
      _metodoPago = 'EFECTIVO';
      _fechaVencimiento = null;
      _codigoDescuento.clear();
      _nuevoClienteNombre.clear();
      _nuevoClienteCorreo.clear();
    });
  }

  Future<void> _elegirFechaVencimiento(BuildContext ctx) async {
    final d = await showDatePicker(
      context: ctx,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (d != null) setState(() => _fechaVencimiento = d);
  }

  Widget _contCatalogo() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _busqueda,
            decoration: const InputDecoration(
              hintText: 'Buscar producto...',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 14),
          const Text('Catálogo de ventas',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Expanded(
            child: _filtrados.isEmpty
                ? const EstadoVacio(
                    icono: Icons.search_off,
                    titulo: 'Sin productos',
                    mensaje: 'No hay productos que coincidan.',
                  )
                : GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 200,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.8,
                    ),
                    itemCount: _filtrados.length,
                    itemBuilder: (context, i) {
                      final p = _filtrados[i];
                      return Opacity(
                        opacity: p.activo ? 1 : 0.55,
                        child: Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(p.nombre,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13.5),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                                ),
                                const SizedBox(height: 4),
                                Text(p.categoria,
                                    style: const TextStyle(
                                        fontSize: 10.5,
                                        color: ColoresSigif.textoMitigado)),
                                const Spacer(),
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(Formato.cop(p.precio),
                                            style: const TextStyle(
                                                fontWeight:
                                                    FontWeight.w800)),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      flex: 2,
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerRight,
                                        child: StockBadge(
                                            activo: p.activo, stock: p.stock),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                SizedBox(
                                  width: double.infinity,
                                  height: 32,
                                  child: FilledButton.icon(
                                    onPressed: p.activo
                                        ? () => _agregar(p)
                                        : null,
                                    icon: const Icon(
                                        Icons.add_shopping_cart,
                                        size: 15),
                                    label: const Text('Agregar',
                                        style:
                                            TextStyle(fontSize: 12.5)),
                                    style: FilledButton.styleFrom(
                                        padding: EdgeInsets.zero),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// Barra inferior con total y botón "Ver carrito" (layout móvil).
  Widget _barraVerCarrito(BuildContext ctx) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: ColoresSigif.tarjeta,
        border: const Border(top: BorderSide(color: ColoresSigif.borde)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total',
                    style: const TextStyle(
                        fontSize: 12, color: ColoresSigif.textoMitigado)),
                Text(Formato.cop(_totalFinal),
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: ColoresSigif.textoOscuro)),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: () => _abrirCarrito(ctx),
            icon: Badge(
              label: Text('${_carritoPos.length}'),
              child: const Icon(Icons.shopping_cart_outlined, size: 20),
            ),
            label: const Text('Ver carrito'),
          ),
        ],
      ),
    );
  }

  void _abrirCarrito(BuildContext ctx) {
    showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFBFBFF),
      showDragHandle: true,
      builder: (sheetCtx) => FractionallySizedBox(
        heightFactor: 0.9,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            _PanelPago(
              carrito: _carritoPos,
              subtotal: _subtotal,
              pctDescuento: _pctDescuento,
              valorDescuento: _valorDescuento,
              totalFinal: _totalFinal,
              baseGravable: _baseGravable,
              iva: _iva,
              clienteModo: _clienteModo,
              clienteId: _clienteId,
              clientes: _clientes,
              codigoDescuento: _codigoDescuento,
              nuevoClienteNombre: _nuevoClienteNombre,
              nuevoClienteCorreo: _nuevoClienteCorreo,
              metodoPago: _metodoPago,
              fechaVencimiento: _fechaVencimiento,
              onClienteModoChanged: (v) => setState(() => _clienteModo = v),
              onClienteIdChanged: (v) => setState(() => _clienteId = v),
              onElegirFecha: () => _elegirFechaVencimiento(sheetCtx),
              onMetodoPagoChanged: (m) {
                setState(() {
                  _metodoPago = m;
                  if (m != 'CREDITO') _fechaVencimiento = null;
                });
              },
onCambiarCantidad: (item, delta) => _cambiarCantidad(item, delta),
              onCodigoDescuentoChanged: (_) => setState(() {}),
              onConfirmar: _confirmarVenta,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final esAncho = constraints.maxWidth >= 780;
        final panel = _PanelPago(
          carrito: _carritoPos,
          subtotal: _subtotal,
          pctDescuento: _pctDescuento,
          valorDescuento: _valorDescuento,
          totalFinal: _totalFinal,
          baseGravable: _baseGravable,
          iva: _iva,
          clienteModo: _clienteModo,
          clienteId: _clienteId,
          clientes: _clientes,
          codigoDescuento: _codigoDescuento,
          nuevoClienteNombre: _nuevoClienteNombre,
          nuevoClienteCorreo: _nuevoClienteCorreo,
          metodoPago: _metodoPago,
          fechaVencimiento: _fechaVencimiento,
          onClienteModoChanged: (v) => setState(() => _clienteModo = v),
          onClienteIdChanged: (v) => setState(() => _clienteId = v),
          onElegirFecha: () => _elegirFechaVencimiento(context),
          onMetodoPagoChanged: (m) {
            setState(() {
              _metodoPago = m;
              if (m != 'CREDITO') _fechaVencimiento = null;
            });
          },
          onCambiarCantidad: (item, delta) => _cambiarCantidad(item, delta),
          onCodigoDescuentoChanged: (_) => setState(() {}),
          onConfirmar: _confirmarVenta,
        );

        if (esAncho) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 3, child: _contCatalogo()),
              const VerticalDivider(width: 1),
              Expanded(
                flex: 2,
                child: Container(
                  color: const Color(0xFFFBFBFF),
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [panel],
                  ),
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            Expanded(child: _contCatalogo()),
            _barraVerCarrito(context),
          ],
        );
      },
    );
  }
}

/// Panel de pago: cliente, carrito, método de pago, totales y confirmar.
class _PanelPago extends StatelessWidget {
  final List<_ProductoCarrito> carrito;
  final int subtotal;
  final int pctDescuento;
  final int valorDescuento;
  final int totalFinal;
  final double baseGravable;
  final double iva;
  final String clienteModo;
  final int? clienteId;
  final List<Cliente> clientes;
  final TextEditingController codigoDescuento;
  final TextEditingController nuevoClienteNombre;
  final TextEditingController nuevoClienteCorreo;
  final String metodoPago;
  final DateTime? fechaVencimiento;
  final ValueChanged<String> onClienteModoChanged;
  final ValueChanged<int?> onClienteIdChanged;
  final Future<void> Function() onElegirFecha;
  final ValueChanged<String> onMetodoPagoChanged;
  final void Function(_ProductoCarrito item, int delta) onCambiarCantidad;
  final ValueChanged<String> onCodigoDescuentoChanged;
  final VoidCallback onConfirmar;

  const _PanelPago({
    required this.carrito,
    required this.subtotal,
    required this.pctDescuento,
    required this.valorDescuento,
    required this.totalFinal,
    required this.baseGravable,
    required this.iva,
    required this.clienteModo,
    required this.clienteId,
    required this.clientes,
    required this.codigoDescuento,
    required this.nuevoClienteNombre,
    required this.nuevoClienteCorreo,
    required this.metodoPago,
    required this.fechaVencimiento,
    required this.onClienteModoChanged,
    required this.onClienteIdChanged,
    required this.onElegirFecha,
    required this.onMetodoPagoChanged,
    required this.onCambiarCantidad,
    required this.onCodigoDescuentoChanged,
    required this.onConfirmar,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Cliente',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                      value: 'final', label: Text('Consumidor final')),
                  ButtonSegment(value: 'existente', label: Text('Existe')),
                  ButtonSegment(value: 'nuevo', label: Text('Nuevo')),
                ],
                selected: {clienteModo},
                showSelectedIcon: false,
                onSelectionChanged: (s) => onClienteModoChanged(s.first),
              ),
              const SizedBox(height: 10),
              if (clienteModo == 'existente')
                DropdownButtonFormField<int?>(
                  initialValue: clienteId,
                  items: [
                    for (final c in clientes)
                      DropdownMenuItem(value: c.id, child: Text(c.nombre)),
                  ],
                  decoration:
                      const InputDecoration(labelText: 'Selecciona cliente'),
                  onChanged: onClienteIdChanged,
                ),
              if (clienteModo == 'nuevo') ...[
                TextFormField(
                  controller: nuevoClienteNombre,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                      labelText: 'Nombre del cliente *'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: nuevoClienteCorreo,
                  keyboardType: TextInputType.emailAddress,
                  decoration:
                      const InputDecoration(labelText: 'Correo del cliente *'),
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: codigoDescuento,
                onChanged: onCodigoDescuentoChanged,
                decoration: InputDecoration(
                  labelText: 'Código de descuento',
                  suffixIcon: pctDescuento > 0
                      ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text('-$pctDescuento%',
                              style: const TextStyle(
                                  color: ColoresSigif.exito,
                                  fontWeight: FontWeight.w800)),
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 6),
          child: Text('Carrito',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
        if (carrito.isEmpty)
          const EstadoVacio(
            icono: Icons.shopping_cart_outlined,
            titulo: 'Carrito vacío',
            mensaje: 'Presiona "Agregar" en un producto.',
          )
        else
          for (final c in carrito)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.producto.nombre,
                            style: const TextStyle(
                                fontSize: 13.5, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        Text(
                            '${Formato.cop(c.producto.precio)} · Sub: ${Formato.cop(c.producto.precio * c.cantidad)}',
                            style: const TextStyle(
                                fontSize: 11,
                                color: ColoresSigif.textoMitigado)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                    onPressed: () => onCambiarCantidad(c, -1),
                  ),
                  Text('${c.cantidad}',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    onPressed:
                        c.cantidad >= c.producto.stock ? null : () => onCambiarCantidad(c, 1),
                  ),
                ],
              ),
            ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Método de pago',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final m in Constantes.metodosPagoFactura)
                    ChoiceChip(
                      label: Text(Constantes.metodosPagoLabel[m] ?? m),
                      selected: metodoPago == m,
                      onSelected: (_) => onMetodoPagoChanged(m),
                    ),
                ],
              ),
              if (metodoPago == 'CREDITO') ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        fechaVencimiento == null
                            ? 'Fecha de vencimiento: no definida'
                            : 'Vence: ${Formato.fecha(fechaVencimiento!)}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    TextButton(
                      onPressed: onElegirFecha,
                      child: const Text('Elegir fecha'),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              _lineaTotal('Subtotal', Formato.cop(subtotal)),
              if (pctDescuento > 0)
                _lineaTotal('Descuento ($pctDescuento%)',
                    '-${Formato.cop(valorDescuento)}',
                    color: ColoresSigif.exito),
              _lineaTotal('Total', Formato.cop(totalFinal), destacado: true),
              const SizedBox(height: 4),
              Text(
                'Base gravable: ${Formato.cop(baseGravable)} · IVA: ${Formato.cop(iva)}',
                style: const TextStyle(
                    fontSize: 11.5, color: ColoresSigif.textoMitigado),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: onConfirmar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColoresSigif.exito,
                  ),
                  icon: const Icon(Icons.check_circle_outline, size: 20),
                  label: Text('Confirmar venta · ${Formato.cop(totalFinal)}'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _lineaTotal(String etiqueta, String valor,
      {bool destacado = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(etiqueta,
              style: TextStyle(
                  fontSize: destacado ? 16 : 13.5,
                  fontWeight: destacado ? FontWeight.w800 : FontWeight.w600)),
          Text(valor,
              style: TextStyle(
                  fontSize: destacado ? 17 : 13.5,
                  fontWeight: FontWeight.w800,
                  color: color)),
        ],
      ),
    );
  }
}
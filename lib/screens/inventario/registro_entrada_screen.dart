import 'package:flutter/material.dart';

import '../../core/constantes.dart';
import '../../core/formato.dart';
import '../../db/repos/inventario_repository.dart';
import '../../db/repos/productos_repository.dart';
import '../../models/producto.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class _ItemEntrada {
  bool esNuevo = false;
  int? productoId;
  final TextEditingController cantidad;
  final TextEditingController precioCompra;
  final TextEditingController precioVenta;
  final TextEditingController nombre;
  final TextEditingController descripcion;
  String categoria;

  _ItemEntrada()
      : cantidad = TextEditingController(),
        precioCompra = TextEditingController(),
        precioVenta = TextEditingController(),
        nombre = TextEditingController(),
        descripcion = TextEditingController(),
        categoria = Constantes.categoriasProducto.first;

  void dispose() {
    cantidad.dispose();
    precioCompra.dispose();
    precioVenta.dispose();
    nombre.dispose();
    descripcion.dispose();
  }
}

class RegistroEntradaScreen extends StatefulWidget {
  const RegistroEntradaScreen({super.key});

  @override
  State<RegistroEntradaScreen> createState() => _RegistroEntradaScreenState();
}

class _RegistroEntradaScreenState extends State<RegistroEntradaScreen> {
  final _proveedor = TextEditingController();
  final _documento = TextEditingController();
  final _observaciones = TextEditingController();
  final List<_ItemEntrada> _items = [_ItemEntrada()];
  List<Producto> _productos = [];
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargarProductos();
  }

  Future<void> _cargarProductos() async {
    final repo = await ProductosRepository.abrir();
    final lista = await repo.listar(soloActivos: true);
    if (!mounted) return;
    setState(() => _productos = lista);
  }

  @override
  void dispose() {
    _proveedor.dispose();
    _documento.dispose();
    _observaciones.dispose();
    for (final i in _items) {
      i.dispose();
    }
    super.dispose();
  }

  void _agregarItem() {
    setState(() => _items.add(_ItemEntrada()));
  }

  void _quitarItem(int index) {
    if (_items.length <= 1) return;
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

  Future<void> _guardar() async {
    if (_proveedor.text.trim().isEmpty) {
      notificar(context, 'El proveedor es obligatorio', error: true);
      return;
    }

    final items = <Map<String, Object?>>[];
    for (final item in _items) {
      final cantidad = int.tryParse(item.cantidad.text) ?? 0;
      final precio = int.tryParse(item.precioCompra.text) ?? 0;
      final precioVenta = int.tryParse(item.precioVenta.text) ?? 0;

      if (item.esNuevo) {
        if (item.nombre.text.trim().isEmpty) {
          notificar(context, 'Indica el nombre del producto nuevo', error: true);
          return;
        }
        items.add({
          'nombre': item.nombre.text,
          'categoria': item.categoria,
          'descripcion': item.descripcion.text,
          'activo': true,
          'cantidad': cantidad,
          'precio': precio,
          'precio_venta': precioVenta,
        });
      } else {
        if (item.productoId == null) {
          notificar(context, 'Selecciona un producto', error: true);
          return;
        }
        items.add({
          'producto_id': item.productoId,
          'cantidad': cantidad,
          'precio': precio,
          'precio_venta': precioVenta,
        });
      }
    }

    setState(() => _guardando = true);
    final repo = await InventarioRepository.abrir();
    final resultado = await repo.registrarEntrada(
      proveedor: _proveedor.text,
      documento: _documento.text,
      observaciones: _observaciones.text,
      nombreUsuario: SessionService.instance.nombreUsuario,
      items: items,
    );

    if (!mounted) return;
    setState(() => _guardando = false);
    if (resultado.success) {
      notificar(context, resultado.message);
      _limpiar();
    } else {
      notificar(context, resultado.message, error: true);
    }
  }

  void _limpiar() {
    _proveedor.clear();
    _documento.clear();
    _observaciones.clear();
    for (final i in _items) {
      i.dispose();
    }
    setState(() {
      _items
        ..clear()
        ..add(_ItemEntrada());
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      children: [
        TituloPagina(
          titulo: 'Registrar entrada',
          subtitulo: 'Agrega productos al inventario (existentes o nuevos).',
          acciones: [
            OutlinedButton.icon(
              onPressed: _agregarItem,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Agregar producto'),
            ),
          ],
        ),
        TextFormField(
          controller: _proveedor,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Proveedor *',
            prefixIcon: Icon(Icons.business_outlined),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _documento,
                decoration: const InputDecoration(labelText: 'No. documento'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _observaciones,
                decoration: const InputDecoration(labelText: 'Observaciones'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        for (var i = 0; i < _items.length; i++) _tarjetaItem(_items[i], i),
        const SizedBox(height: 20),
        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _guardando ? null : _guardar,
            style: ElevatedButton.styleFrom(
              backgroundColor: ColoresSigif.exito,
            ),
            icon: _guardando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  )
                : const Icon(Icons.inventory_2_outlined),
            label: Text(_guardando ? 'Registrando...' : 'Registrar entrada'),
          ),
        ),
      ],
    );
  }

  Widget _tarjetaItem(_ItemEntrada item, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Producto ${index + 1}',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: 'Quitar',
                  onPressed: () => _quitarItem(index),
                ),
              ],
            ),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Existente')),
                ButtonSegment(value: true, label: Text('Nuevo producto')),
              ],
              selected: {item.esNuevo},
              onSelectionChanged: (s) =>
                  setState(() => item.esNuevo = s.first),
              showSelectedIcon: false,
            ),
            const SizedBox(height: 12),
            if (!item.esNuevo)
              DropdownButtonFormField<int?>(
                initialValue: item.productoId,
                items: [
                  for (final p in _productos)
                    DropdownMenuItem(
                      value: p.id,
                      child: Text('${p.nombre} (${p.stock} u)'),
                    ),
                ],
                decoration: const InputDecoration(labelText: 'Selecciona producto *'),
                onChanged: (v) => setState(() => item.productoId = v),
              )
            else ...[
              TextFormField(
                controller: item.nombre,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nombre del producto *'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: item.categoria,
                items: [
                  for (final c in Constantes.categoriasProducto)
                    DropdownMenuItem(value: c, child: Text(c)),
                ],
                decoration: const InputDecoration(labelText: 'Categoría'),
                onChanged: (v) => setState(() => item.categoria = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: item.descripcion,
                decoration: const InputDecoration(labelText: 'Descripción'),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: item.cantidad,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Cantidad *'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: item.precioCompra,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Costo unitario *',
                      prefixText: r'$ ',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: item.precioVenta,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Precio venta *',
                      prefixText: r'$ ',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Subtotal: ${Formato.cop(_subtotalItem(item))}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  double _subtotalItem(_ItemEntrada item) {
    final cant = int.tryParse(item.cantidad.text) ?? 0;
    final precio = int.tryParse(item.precioCompra.text) ?? 0;
    return (cant * precio).toDouble();
  }
}
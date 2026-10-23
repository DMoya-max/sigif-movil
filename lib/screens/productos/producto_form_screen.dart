import 'package:flutter/material.dart';

import '../../core/constantes.dart';
import '../../core/sanitizacion.dart';
import '../../db/repos/auditoria_repository.dart';
import '../../models/producto.dart';
import '../../services/auth_service.dart';
import '../../services/productos_api_service.dart';
import '../../widgets/common.dart';

/// Formulario de creación y edición de productos conectado a la API REST.
class ProductoFormScreen extends StatefulWidget {
  final Producto? producto;

  const ProductoFormScreen({super.key, this.producto});

  @override
  State<ProductoFormScreen> createState() => _ProductoFormScreenState();
}

class _ProductoFormScreenState extends State<ProductoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = ProductosApiService.instance;
  late final TextEditingController _nombre;
  late final TextEditingController _descripcion;
  late final TextEditingController _precio;
  late final TextEditingController _stock;
  late String _categoria;
  late bool _activo;
  bool _guardando = false;

  bool get _esNuevo => widget.producto == null;

  @override
  void initState() {
    super.initState();
    final p = widget.producto;
    _nombre = TextEditingController(text: p?.nombre ?? '');
    _descripcion = TextEditingController(text: p?.descripcion ?? '');
    _precio = TextEditingController(text: p != null ? '${p.precio}' : '');
    _stock = TextEditingController(text: p != null ? '${p.stock}' : '0');
    final catInicial = p?.categoria;
    _categoria = (catInicial != null &&
            Constantes.categoriasProducto.contains(catInicial))
        ? catInicial
        : Constantes.categoriasProducto.first;
    _activo = p?.activo ?? true;
  }

  @override
  void dispose() {
    _nombre.dispose();
    _descripcion.dispose();
    _precio.dispose();
    _stock.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _guardando = true);

    final ahora = DateTime.now();
    final nombre = Sanitizacion.limpiarNonNull(_nombre.text.trim());
    final descripcion = Sanitizacion.limpiar(_descripcion.text.trim());
    final precio = int.parse(_precio.text.trim());
    final stock = int.tryParse(_stock.text.trim()) ?? 0;

    try {
      if (_esNuevo) {
        await _api.crear(
          Producto(
            nombre: nombre,
            descripcion: descripcion,
            precio: precio,
            stock: stock,
            categoria: _categoria,
            activo: _activo,
            fechaCreacion: ahora,
            fechaActualizacion: ahora,
          ),
        );
      } else {
        final actual = widget.producto!;
        await _api.actualizar(
          Producto(
            id: actual.id,
            nombre: nombre,
            descripcion: descripcion,
            precio: precio,
            stock: stock,
            categoria: _categoria,
            activo: _activo,
            fechaCreacion: actual.fechaCreacion,
            fechaActualizacion: ahora,
          ),
        );
      }

      try {
        final aud = await AuditoriaRepository.abrir();
        await aud.registrar(
          usuario: SessionService.instance.nombreUsuario.isEmpty
              ? 'API'
              : SessionService.instance.nombreUsuario,
          accion: _esNuevo
              ? 'CREÓ EL PRODUCTO $nombre'
              : 'EDITÓ EL PRODUCTO $nombre',
          modulo: 'PRODUCTOS',
        );
      } catch (_) {}

      if (!mounted) return;
      notificar(
        context,
        _esNuevo
            ? 'Producto creado correctamente'
            : 'Producto actualizado correctamente',
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      notificar(context, 'Error: $e', error: true);
    }
  }

  String? _validarEntero(String? v, String campo, {bool permitirCero = false}) {
    if (v == null || v.trim().isEmpty) return 'Ingresa $campo';
    final n = int.tryParse(v.trim());
    if (n == null) return '$campo debe ser un número entero';
    if (!permitirCero && n <= 0) return '$campo debe ser mayor a cero';
    if (permitirCero && n < 0) return '$campo no puede ser negativo';
    return null;
  }

  String? _validarTextoSeguro(
    String? v, {
    required String etiqueta,
    required bool obligatorio,
  }) {
    final texto = v?.trim() ?? '';
    if (obligatorio && texto.isEmpty) {
      return '$etiqueta es obligatorio.';
    }
    if (texto.contains('<') || texto.contains('>')) {
      return '$etiqueta no puede contener los caracteres < y >.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_esNuevo ? 'Nuevo producto' : 'Editar producto'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _nombre,
              textCapitalization: TextCapitalization.words,
              validator: (v) => _validarTextoSeguro(
                v,
                etiqueta: 'El nombre del producto',
                obligatorio: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Nombre del producto *',
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _categoria,
              items: [
                for (final c in Constantes.categoriasProducto)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              decoration: const InputDecoration(labelText: 'Categoría *'),
              onChanged: (v) => setState(() => _categoria = v!),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _precio,
              keyboardType: TextInputType.number,
              validator: (v) => _validarEntero(v, 'El precio'),
              decoration: const InputDecoration(
                labelText: 'Precio unitario (\$) *',
                prefixText: r'$ ',
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _stock,
              keyboardType: TextInputType.number,
              validator: (v) =>
                  _validarEntero(v, 'El stock', permitirCero: true),
              decoration: const InputDecoration(
                labelText: 'Stock disponible (unidades) *',
                prefixIcon: Icon(Icons.inventory_2_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _descripcion,
              minLines: 2,
              maxLines: 4,
              validator: (v) => _validarTextoSeguro(
                v,
                etiqueta: 'La descripción',
                obligatorio: false,
              ),
              decoration: const InputDecoration(
                labelText: 'Descripción del producto',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 14),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Producto activo'),
              subtitle: Text(
                (SessionService.instance.usuario
                            ?.puedeGestionarEstadoProductos ??
                        true)
                    ? 'Visible en el catálogo y punto de venta'
                    : 'Solo Admin o SuperAdmin pueden activar/desactivar productos',
              ),
              value: _activo,
              onChanged: (SessionService.instance.usuario
                          ?.puedeGestionarEstadoProductos ??
                      true)
                  ? (v) => setState(() => _activo = v)
                  : null,
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _guardando ? null : _guardar,
                icon: _guardando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_guardando ? 'Guardando...' : 'Guardar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

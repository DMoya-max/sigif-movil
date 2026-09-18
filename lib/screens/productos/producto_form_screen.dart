import 'package:flutter/material.dart';

import '../../core/constantes.dart';
import '../../db/repos/auditoria_repository.dart';
import '../../db/repos/productos_repository.dart';
import '../../models/producto.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Formulario de edición de productos. La creación y el stock se gestionan
/// exclusivamente desde Inventario → Registrar entrada.
class ProductoFormScreen extends StatefulWidget {
  final Producto producto;

  const ProductoFormScreen({super.key, required this.producto});

  @override
  State<ProductoFormScreen> createState() => _ProductoFormScreenState();
}

class _ProductoFormScreenState extends State<ProductoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  late final TextEditingController _descripcion;
  late final TextEditingController _precio;
  late String _categoria;
  late bool _activo;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final p = widget.producto;
    _nombre = TextEditingController(text: p.nombre);
    _descripcion = TextEditingController(text: p.descripcion ?? '');
    _precio = TextEditingController(text: '${p.precio}');
    _categoria = p.categoria;
    _activo = p.activo;
  }

  @override
  void dispose() {
    _nombre.dispose();
    _descripcion.dispose();
    _precio.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _guardando = true);

    final repo = await ProductosRepository.abrir();
    try {
      await repo.actualizar(
        widget.producto.id!,
        nombre: _nombre.text,
        categoria: _categoria,
        descripcion: _descripcion.text,
        precio: int.parse(_precio.text),
        activo: _activo,
      );
      final aud = await AuditoriaRepository.abrir();
      await aud.registrar(
        usuario: SessionService.instance.nombreUsuario,
        accion: 'EDITÓ EL PRODUCTO ${_nombre.text}',
        modulo: 'PRODUCTOS',
      );
      if (!mounted) return;
      notificar(context, 'Producto actualizado');
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
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar producto')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _nombre,
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Ingresa el nombre' : null,
              decoration: const InputDecoration(labelText: 'Nombre *'),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _categoria,
              items: [
                for (final c in Constantes.categoriasProducto)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              decoration: const InputDecoration(labelText: 'Categoría'),
              onChanged: (v) => setState(() => _categoria = v!),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _precio,
              keyboardType: TextInputType.number,
              validator: (v) => _validarEntero(v, 'el precio'),
              decoration: const InputDecoration(
                labelText: 'Precio de venta *',
                prefixText: r'$ ',
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: ColoresSigif.azulPrimario.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2_outlined,
                      size: 18, color: ColoresSigif.azulPrimario),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Stock actual: ${widget.producto.stock} u. Se actualiza '
                      'desde Inventario → Registrar entrada.',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _descripcion,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 14),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Producto activo'),
              subtitle: const Text('Visible en el punto de venta'),
              value: _activo,
              onChanged: (v) => setState(() => _activo = v),
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
                            color: Colors.white, strokeWidth: 2.5),
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
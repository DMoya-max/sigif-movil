import 'package:flutter/material.dart';

import '../../core/constantes.dart';
import '../../core/formato.dart';
import '../../db/repos/gastos_repository.dart';
import '../../models/gasto.dart';
import '../../services/auth_service.dart';
import '../../widgets/common.dart';

class GastoFormScreen extends StatefulWidget {
  final Gasto? gasto;

  const GastoFormScreen({super.key, this.gasto});

  @override
  State<GastoFormScreen> createState() => _GastoFormScreenState();
}

class _GastoFormScreenState extends State<GastoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _concepto;
  late final TextEditingController _valor;
  late final TextEditingController _proveedor;
  late final TextEditingController _descripcion;
  late String _categoria;
  late String _metodoPago;
  late DateTime _fecha;
  bool _guardando = false;

  bool get _esNuevo => widget.gasto == null;

  @override
  void initState() {
    super.initState();
    final g = widget.gasto;
    _concepto = TextEditingController(text: g?.concepto ?? '');
    _valor = TextEditingController(text: g != null ? '${g.valor.round()}' : '');
    _proveedor = TextEditingController(text: g?.proveedor ?? '');
    _descripcion = TextEditingController(text: g?.descripcion ?? '');
    _categoria = g?.categoria ?? 'OTROS';
    _metodoPago = g?.metodoPago ?? 'EFECTIVO';
    _fecha = g?.fecha ?? DateTime.now();
  }

  @override
  void dispose() {
    _concepto.dispose();
    _valor.dispose();
    _proveedor.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _guardando = true);
    final repo = await GastosRepository.abrir();
    try {
      if (_esNuevo) {
        final id = await repo.crear(
          concepto: _concepto.text,
          categoria: _categoria,
          valor: double.parse(_valor.text),
          fecha: _fecha,
          metodoPago: _metodoPago,
          proveedor: _proveedor.text,
          descripcion: _descripcion.text,
          usuario: SessionService.instance.nombreUsuario,
        );
        await repo.auditar(SessionService.instance.nombreUsuario,
            'CREÓ EL GASTO ${_concepto.text} (#$id)');
      } else {
        final g = widget.gasto!;
        await repo.actualizar(Gasto(
          id: g.id,
          concepto: _concepto.text,
          categoria: _categoria,
          valor: double.parse(_valor.text),
          fecha: _fecha,
          metodoPago: _metodoPago,
          proveedor: _proveedor.text,
          descripcion: _descripcion.text,
          usuario: g.usuario,
          creadoEn: g.creadoEn,
        ));
        await repo.auditar(SessionService.instance.nombreUsuario,
            'EDITÓ EL GASTO ${_concepto.text}');
      }
      if (!mounted) return;
      notificar(context, _esNuevo ? 'Gasto registrado' : 'Gasto actualizado');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      notificar(context, 'Error: $e', error: true);
      setState(() => _guardando = false);
    }
  }

  Future<void> _elegirFecha() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(DateTime.now().year - 5),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _fecha = d);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_esNuevo ? 'Nuevo gasto' : 'Editar gasto')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _concepto,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Ingresa el concepto' : null,
              decoration: const InputDecoration(labelText: 'Concepto *'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _valor,
              keyboardType: TextInputType.number,
              validator: (v) {
                final n = double.tryParse(v ?? '');
                if (n == null || n <= 0) return 'Ingresa un valor válido';
                return null;
              },
              decoration: const InputDecoration(
                  labelText: 'Valor *', prefixText: r'$ '),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _categoria,
              items: [
                for (final e in Constantes.categoriasGasto.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              decoration: const InputDecoration(labelText: 'Categoría'),
              onChanged: (v) => setState(() => _categoria = v!),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _metodoPago,
              items: [
                for (final m in Constantes.metodosPagoGasto)
                  DropdownMenuItem(
                      value: m,
                      child: Text(Constantes.metodosPagoLabel[m] ?? m)),
              ],
              decoration: const InputDecoration(labelText: 'Método de pago'),
              onChanged: (v) => setState(() => _metodoPago = v!),
            ),
            const SizedBox(height: 14),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: Text('Fecha: ${Formato.fecha(_fecha)}'),
              onTap: _elegirFecha,
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _proveedor,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Proveedor'),
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
            const SizedBox(height: 24),
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
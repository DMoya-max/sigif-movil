import 'package:flutter/material.dart';

import '../../core/formato.dart';
import '../../db/repos/auditoria_repository.dart';
import '../../db/repos/productos_repository.dart';
import '../../models/producto.dart';
import '../../models/usuario.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'producto_detalle_screen.dart';
import 'producto_form_screen.dart';

class ProductosScreen extends StatefulWidget {
  const ProductosScreen({super.key});

  @override
  State<ProductosScreen> createState() => _ProductosScreenState();
}

class _ProductosScreenState extends State<ProductosScreen> {
  static const _porPagina = 20;

  final _busqueda = TextEditingController();
  final List<Producto> _productos = [];
  bool _cargando = true;
  bool _tieneMas = false;
  int _pagina = 1;
  String _q = '';

  Usuario? get _actor => SessionService.instance.usuario;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _cargar({bool reiniciar = false}) async {
    if (reiniciar) _pagina = 1;
    setState(() => _cargando = true);
    final repo = await ProductosRepository.abrir();
    final lista = await repo.listarPaginado(q: _q, porPagina: _porPagina, pagina: _pagina);
    final total = await repo.contar(q: _q);
    if (!mounted) return;
    setState(() {
      if (reiniciar || _pagina == 1) {
        _productos.clear();
      }
      _productos.addAll(lista);
      _tieneMas = (_pagina * _porPagina) < total;
      _cargando = false;
    });
  }

  Future<void> _editar(Producto p) async {
    final editado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ProductoFormScreen(producto: p)),
    );
    if (editado == true) await _cargar();
  }

  Future<void> _verDetalle(Producto p) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProductoDetalleScreen(producto: p)),
    );
    await _cargar();
  }

  Future<void> _cambiarEstado(Producto p) async {
    final activar = !p.activo;
    final ok = await confirmar(
      context,
      titulo: activar ? 'Activar producto' : 'Desactivar producto',
      mensaje: activar
          ? '¿Activar "${p.nombre}"?'
          : '¿Desactivar "${p.nombre}"? No aparecerá en el punto de venta.',
      textoConfirmar: activar ? 'Activar' : 'Desactivar',
      peligro: !activar,
    );
    if (!ok || !mounted) return;
    final repo = await ProductosRepository.abrir();
    await repo.activarDesactivar(p.id!, activar);
    final aud = await AuditoriaRepository.abrir();
    await aud.registrar(
      usuario: _actor?.nombre ?? '',
      accion: activar ? 'ACTIVÓ EL PRODUCTO ${p.nombre}' : 'DESACTIVÓ EL PRODUCTO ${p.nombre}',
      modulo: 'PRODUCTOS',
    );
    if (!mounted) return;
    notificar(context, activar ? 'Producto activado' : 'Producto desactivado');
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: TituloPagina(
            titulo: 'Productos',
            subtitulo:
                'Catálogo de productos. Los productos y su stock se crean desde Inventario → Registrar entrada.',
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: _busqueda,
            onChanged: (v) {
              _q = v;
              _cargar(reiniciar: true);
            },
            decoration: const InputDecoration(
              hintText: 'Buscar por nombre, descripción o categoría...',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _cargando
              ? const Center(child: CircularProgressIndicator())
              : _productos.isEmpty
                  ? EstadoVacio(
                      icono: Icons.inventory_2_outlined,
                      titulo: _q.isEmpty ? 'Sin productos' : 'Sin resultados',
                      mensaje: _q.isEmpty
                          ? 'Crea productos y carga su stock desde Inventario → Registrar entrada.'
                          : 'No se encontraron productos para "$_q".',
                    )
                  : RefreshIndicator(
                      onRefresh: () => _cargar(reiniciar: true),
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        children: [
                          for (final p in _productos) _tarjetaProducto(p),
                          if (_tieneMas)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Center(
                                child: OutlinedButton(
                                  onPressed: () {
                                    _pagina++;
                                    _cargar();
                                  },
                                  child: const Text('Cargar más'),
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _tarjetaProducto(Producto p) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () => _verDetalle(p),
        leading: CircleAvatar(
          backgroundColor: ColoresSigif.azulPrimario.withValues(alpha: 0.12),
          child: const Icon(Icons.build, color: ColoresSigif.azulPrimario),
        ),
        title: Text(p.nombre,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        subtitle: Text(
          '${p.categoria} · Stock: ${p.stock}',
          style: const TextStyle(fontSize: 12.5),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(Formato.cop(p.precio),
                style: const TextStyle(
                    fontWeight: FontWeight.w800, color: ColoresSigif.textoOscuro)),
            const SizedBox(width: 8),
            StockBadge(activo: p.activo, stock: p.stock),
            PopupMenuButton<String>(
              onSelected: (op) {
                if (op == 'editar') _editar(p);
                if (op == 'estado') _cambiarEstado(p);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'editar', child: Text('Editar')),
                PopupMenuItem(
                  value: 'estado',
                  child: Text(p.activo ? 'Desactivar' : 'Activar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
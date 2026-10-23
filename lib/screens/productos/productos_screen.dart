import 'package:flutter/material.dart';

import '../../core/formato.dart';
import '../../db/repos/auditoria_repository.dart';
import '../../models/producto.dart';
import '../../models/usuario.dart';
import '../../services/auth_service.dart';
import '../../services/productos_api_service.dart';
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
  final _busqueda = TextEditingController();
  final _api = ProductosApiService.instance;
  late Future<List<Producto>> _futuroProductos;
  String _q = '';

  Usuario? get _actor => SessionService.instance.usuario;

  @override
  void initState() {
    super.initState();
    _futuroProductos = _api.listar(q: _q);
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final nuevoFuturo = _api.listar(q: _q);
    setState(() {
      _futuroProductos = nuevoFuturo;
    });
    await nuevoFuturo;
  }

  Future<void> _abrirFormulario({Producto? producto}) async {
    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ProductoFormScreen(producto: producto)),
    );
    if (guardado == true) await _cargar();
  }

  Future<void> _verDetalle(Producto p) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProductoDetalleScreen(producto: p)),
    );
    await _cargar();
  }

  bool get _puedeGestionarEstado =>
      _actor?.puedeGestionarEstadoProductos ?? false;

  Future<void> _cambiarEstado(Producto p) async {
    if (p.id == null) return;
    if (!_puedeGestionarEstado) {
      notificar(
        context,
        'No tienes permitido realizar esta acción.',
        error: true,
      );
      return;
    }
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

    try {
      await _api.cambiarEstado(p, activar);
      try {
        final aud = await AuditoriaRepository.abrir();
        await aud.registrar(
          usuario: _actor?.nombre ?? 'API',
          accion: activar
              ? 'ACTIVO EL PRODUCTO: ${p.nombre}'
              : 'INACTIVO EL PRODUCTO: ${p.nombre}',
          modulo: 'PRODUCTOS',
        );
      } catch (_) {}
      if (!mounted) return;
      notificar(context, activar ? 'Producto activado' : 'Producto desactivado');
      await _cargar();
    } catch (e) {
      if (!mounted) return;
      notificar(context, 'Error al cambiar estado: $e', error: true);
    }
  }

  Future<void> _eliminar(Producto p) async {
    if (p.id == null) return;
    if (!_puedeGestionarEstado) {
      notificar(
        context,
        'No tienes permitido realizar esta acción.',
        error: true,
      );
      return;
    }
    final ok = await confirmar(
      context,
      titulo: 'Eliminar producto',
      mensaje:
          '¿Estás seguro de eliminar "${p.nombre}"? Esta acción se ejecutará en la API y no se puede deshacer.',
      textoConfirmar: 'Eliminar',
      peligro: true,
    );
    if (!ok || !mounted) return;

    try {
      await _api.eliminar(p.id!);
      try {
        final aud = await AuditoriaRepository.abrir();
        await aud.registrar(
          usuario: _actor?.nombre ?? 'API',
          accion: 'ELIMINÓ EL PRODUCTO ${p.nombre}',
          modulo: 'PRODUCTOS',
        );
      } catch (_) {}
      if (!mounted) return;
      notificar(context, 'Producto "${p.nombre}" eliminado');
      await _cargar();
    } catch (e) {
      if (!mounted) return;
      notificar(context, 'Error al eliminar producto: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final anchoPantalla = MediaQuery.of(context).size.width;
    final esMovil = anchoPantalla < 600;
    final padHorizontal = esMovil
        ? 16.0
        : anchoPantalla < 960
            ? 24.0
            : 40.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        backgroundColor: ColoresSigif.azulPrimario,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo producto'),
      ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          padHorizontal,
          esMovil ? 14 : 10,
          padHorizontal,
          16,
        ),
        child: Column(
          children: [
            TituloPagina(
              titulo: 'Productos',
              subtitulo: esMovil
                  ? 'Catálogo conectado a la API REST'
                  : 'Catálogo conectado a https://sigif-final.vercel.app/api/productos/',
              acciones: [
                IconButton.outlined(
                  tooltip: 'Actualizar desde API',
                  icon: const Icon(Icons.refresh),
                  onPressed: _cargar,
                ),
                if (!esMovil) ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _abrirFormulario(),
                    icon: const Icon(Icons.add_box_outlined, size: 18),
                    label: const Text('Nuevo producto'),
                  ),
                ],
              ],
            ),
            TextField(
              controller: _busqueda,
              onChanged: (v) {
                _q = v;
                _cargar();
              },
              decoration: InputDecoration(
                hintText: esMovil
                    ? 'Buscar por nombre o categoría...'
                    : 'Buscar por nombre, descripción o categoría...',
                prefixIcon: const Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: FutureBuilder<List<Producto>>(
                future: _futuroProductos,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return EstadoVacio(
                      icono: Icons.cloud_off_outlined,
                      titulo: 'Error al consultar la API',
                      mensaje: '${snapshot.error}',
                      accion: ElevatedButton.icon(
                        onPressed: _cargar,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                      ),
                    );
                  }
                  final productos = snapshot.data ?? [];
                  if (productos.isEmpty) {
                    return EstadoVacio(
                      icono: Icons.inventory_2_outlined,
                      titulo: _q.isEmpty ? 'Sin productos' : 'Sin resultados',
                      mensaje: _q.isEmpty
                          ? 'Usa el botón "Nuevo producto" para crear el primero en la API.'
                          : 'No se encontraron productos para "$_q".',
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: _cargar,
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 88),
                      itemCount: productos.length,
                      itemBuilder: (context, index) {
                        return _tarjetaProducto(
                          productos[index],
                          esMovil: esMovil,
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaProducto(Producto p, {required bool esMovil}) {
    final menuOpciones = PopupMenuButton<String>(
      onSelected: (op) {
        switch (op) {
          case 'editar':
            _abrirFormulario(producto: p);
            break;
          case 'estado':
            _cambiarEstado(p);
            break;
          case 'eliminar':
            _eliminar(p);
            break;
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'editar',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 18),
              SizedBox(width: 8),
              Text('Editar'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'estado',
          child: Row(
            children: [
              Icon(
                p.activo
                    ? Icons.visibility_off_outlined
                    : Icons.check_circle_outline,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(p.activo ? 'Desactivar' : 'Activar'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'eliminar',
          child: Row(
            children: [
              Icon(
                Icons.delete_outline,
                size: 18,
                color: ColoresSigif.peligro,
              ),
              SizedBox(width: 8),
              Text(
                'Eliminar',
                style: TextStyle(color: ColoresSigif.peligro),
              ),
            ],
          ),
        ),
      ],
    );

    if (esMovil) {
      // Diseño móvil para iPhone (375–430px) y Samsung (360–412px)
      return Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _verDetalle(p),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor:
                          ColoresSigif.azulPrimario.withValues(alpha: 0.12),
                      child: const Icon(
                        Icons.build,
                        color: ColoresSigif.azulPrimario,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.nombre,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${p.categoria} · Stock: ${p.stock}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: ColoresSigif.textoMitigado,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    StockBadge(activo: p.activo, stock: p.stock),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.only(top: 8),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Color(0xFFF1F5F9), width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          Formato.cop(p.precio),
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: ColoresSigif.textoOscuro,
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Editar producto',
                        icon: const Icon(
                          Icons.edit_outlined,
                          size: 20,
                          color: ColoresSigif.azulPrimario,
                        ),
                        onPressed: () => _abrirFormulario(producto: p),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Eliminar producto',
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 20,
                          color: ColoresSigif.peligro,
                        ),
                        onPressed: () => _eliminar(p),
                      ),
                      menuOpciones,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () => _verDetalle(p),
        leading: CircleAvatar(
          backgroundColor: ColoresSigif.azulPrimario.withValues(alpha: 0.12),
          child: const Icon(Icons.build, color: ColoresSigif.azulPrimario),
        ),
        title: Text(
          p.nombre,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        subtitle: Text(
          '${p.categoria} · Stock: ${p.stock}',
          style: const TextStyle(fontSize: 12.5),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              Formato.cop(p.precio),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: ColoresSigif.textoOscuro,
              ),
            ),
            const SizedBox(width: 8),
            StockBadge(activo: p.activo, stock: p.stock),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Editar producto',
              icon: const Icon(
                Icons.edit_outlined,
                size: 20,
                color: ColoresSigif.azulPrimario,
              ),
              onPressed: () => _abrirFormulario(producto: p),
            ),
            IconButton(
              tooltip: 'Eliminar producto',
              icon: const Icon(
                Icons.delete_outline,
                size: 20,
                color: ColoresSigif.peligro,
              ),
              onPressed: () => _eliminar(p),
            ),
            menuOpciones,
          ],
        ),
      ),
    );
  }
}

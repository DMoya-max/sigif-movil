import 'package:flutter/material.dart';

import '../core/constantes.dart';
import '../theme/app_theme.dart';

/// Tarjeta de métrica para dashboards.
class MetricaCard extends StatelessWidget {
  final String titulo;
  final String valor;
  final IconData icono;
  final Color color;
  final String? subtitulo;

  const MetricaCard({
    super.key,
    required this.titulo,
    required this.valor,
    required this.icono,
    required this.color,
    this.subtitulo,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icono, color: color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, color: ColoresSigif.textoMitigado)),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(valor,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: ColoresSigif.textoOscuro)),
                  ),
                  if (subtitulo != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitulo!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: ColoresSigif.textoMitigado)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Insignia de estado de pago/factura.
class EstadoBadge extends StatelessWidget {
  final String estado;
  final bool compacto;

  const EstadoBadge(this.estado, {super.key, this.compacto = true});

  @override
  Widget build(BuildContext context) {
    final color = _colorPara(estado);
    final label = Constantes.estadoPagoLabel[estado] ?? estado;
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compacto ? 8 : 12, vertical: compacto ? 3 : 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 11.5, fontWeight: FontWeight.w700),
      ),
    );
  }

  Color _colorPara(String estado) {
    switch (estado) {
      case Constantes.estadoPagada:
        return ColoresSigif.exito;
      case Constantes.estadoVencida:
        return ColoresSigif.peligro;
      case Constantes.estadoParcial:
        return ColoresSigif.advertencia;
      default:
        return ColoresSigif.info;
    }
  }
}

/// Insignia de estado stock (Disponible / Stock bajo / Agotado).
class StockBadge extends StatelessWidget {
  final bool activo;
  final int stock;

  const StockBadge({super.key, required this.activo, required this.stock});

  @override
  Widget build(BuildContext context) {
    String label;
    var color = ColoresSigif.exito;
    if (!activo) {
      label = 'Inactivo';
      color = ColoresSigif.textoMitigado;
    } else if (stock == 0) {
      label = 'Agotado';
      color = ColoresSigif.peligro;
    } else if (stock < 5) {
      label = 'Stock bajo ($stock)';
      color = ColoresSigif.advertencia;
    } else {
      label = 'Disponible';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11.5, fontWeight: FontWeight.w700)),
    );
  }
}

/// Encabezado consistente de cada pantalla del módulo.
class TituloPagina extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  final List<Widget> acciones;

  const TituloPagina({
    super.key,
    required this.titulo,
    this.subtitulo,
    this.acciones = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo,
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: ColoresSigif.textoOscuro)),
                  if (subtitulo != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitulo!,
                        style: const TextStyle(
                            fontSize: 14, color: ColoresSigif.textoMitigado)),
                  ],
                ],
              ),
            ),
            ...acciones,
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

/// Estado vacío amigable.
class EstadoVacio extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String mensaje;

  const EstadoVacio({
    super.key,
    required this.icono,
    required this.titulo,
    required this.mensaje,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 56, color: ColoresSigif.textoMitigado),
            const SizedBox(height: 12),
            Text(titulo,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: ColoresSigif.textoOscuro)),
            const SizedBox(height: 4),
            Text(mensaje,
                textAlign: TextAlign.center,
                style: const TextStyle(color: ColoresSigif.textoMitigado)),
          ],
        ),
      ),
    );
  }
}

/// Diálogo de confirmación reutilizable.
Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  String textoConfirmar = 'Confirmar',
  Color colorConfirmar = ColoresSigif.azulPrimario,
  bool peligro = false,
}) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(titulo),
      content: Text(mensaje),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: peligro ? ColoresSigif.peligro : colorConfirmar,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(textoConfirmar),
        ),
      ],
    ),
  );
  return res ?? false;
}

/// Muestra un SnackBar de éxito o error.
void notificar(BuildContext context, String mensaje, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(mensaje),
      backgroundColor: error ? ColoresSigif.peligro : ColoresSigif.exito,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Encabezado de ficha / detalle con avatar.
class FichaUsuario extends StatelessWidget {
  final String nombre;
  final String rol;
  final String? correo;

  const FichaUsuario({super.key, required this.nombre, required this.rol, this.correo});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: ColoresSigif.azulPrimario,
          child: Text(
            nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(nombre,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
              Text(correo ?? rol,
                  style: const TextStyle(
                      fontSize: 12, color: ColoresSigif.textoMitigado)),
            ],
          ),
        ),
      ],
    );
  }
}
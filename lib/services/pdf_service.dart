import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../core/formato.dart';
import '../db/repos/clientes_repository.dart';
import '../db/repos/configuracion_repository.dart';
import '../db/repos/facturas_repository.dart';
import '../db/repos/inventario_repository.dart';
import '../models/empresa_config.dart';
import '../models/factura.dart';
import '../models/inventario.dart';

/// Genera tickets PDF de factura y entrada de inventario (estampados con la
/// paleta SIGIF) y los comparte/guarda en el dispositivo.
class PdfService {
  PdfService._();

  /// Genera y comparte el ticket PDF de una factura de venta.
  static Future<File> generoTicketFactura(int facturaId) async {
    final repo = await FacturasRepository.abrir();
    final factura = await repo.obtenerPorId(facturaId);
    if (factura == null) {
      throw StateError('La factura no existe');
    }
    final detalles = await repo.detallesConProducto(facturaId);
    final clientes = await ClientesRepository.abrir();
    final cliente = await clientes.obtenerPorId(factura.clienteId);
    final configRepo = await ConfiguracionRepository.abrir();
    final empresa = await configRepo.obtener();

    final document = pw.Document();
    document.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (_) => _contenidoFactura(
        empresa: empresa,
        factura: factura,
        detalles: detalles,
        nombreCliente: cliente?.nombre ?? 'Cliente',
      ),
    ));

    return _guardarDocumento(document, 'factura_$facturaId.pdf');
  }

  /// Genera y comparte el ticket PDF de una entrada de inventario.
  static Future<File> generoTicketEntrada(int entradaId) async {
    final repo = await InventarioRepository.abrir();
    final entrada = await repo.obtenerEntrada(entradaId);
    if (entrada == null) {
      throw StateError('La entrada no existe');
    }
    final detalles = await repo.detallesConProducto(entradaId);
    final configRepo = await ConfiguracionRepository.abrir();
    final empresa = await configRepo.obtener();

    final document = pw.Document();
    document.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (_) => _contenidoEntrada(empresa, entrada, detalles),
    ));

    return _guardarDocumento(document, 'entrada_$entradaId.pdf');
  }

  static Future<File> _guardarDocumento(pw.Document doc, String nombre) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$nombre');
    final bytes = await doc.save();
    await file.writeAsBytes(bytes);
    return file;
  }

  /// Comparte un archivo generado por los canales del SO.
  static Future<void> compartirArchivo(File archivo, String mensaje) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(archivo.path)], text: mensaje),
    );
  }

  // ------------------------------------------------------------------
  // Construcción del documento
  // ------------------------------------------------------------------

  static pw.Widget _contenidoFactura({
    required EmpresaConfig empresa,
    required Factura factura,
    required List<Map<String, Object?>> detalles,
    required String nombreCliente,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(empresa.nombreComercial,
            style: pw.TextStyle(
                fontSize: 18, fontWeight: pw.FontWeight.bold, color: _azul)),
        pw.Text('NIT: ${empresa.nit}'),
        pw.Text(empresa.direccion),
        pw.SizedBox(height: 8),
        _divisor(),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('FACTURA #${factura.id}',
                style:
                    const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
            pw.Text(Formato.fechaHora(factura.fecha)),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Text('Cliente: $nombreCliente'),
        pw.Text('Usuario: ${factura.usuario}'),
        pw.Text('Estado: ${factura.estadoPago}'),
        pw.SizedBox(height: 12),
        _divisor(),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headers: ['Producto', 'Cant.', 'Precio', 'Subtotal'],
          data: detalles.map((d) {
            return [
              d['producto_nombre'] ?? 'Producto',
              '${d['cantidad']}',
              Formato.cop(d['precio'] as num),
              Formato.cop(d['subtotal'] as num),
            ];
          }).toList(),
          headerStyle:
              pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: _azul),
          cellStyle: const pw.TextStyle(fontSize: 10),
          cellAlignments: {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.centerRight,
            2: pw.Alignment.centerRight,
            3: pw.Alignment.centerRight,
          },
          border: pw.TableBorder(
            horizontalInside:
                pw.BorderSide(color: PdfColors.grey300),
          ),
        ),
        pw.SizedBox(height: 16),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('Subtotal: ${Formato.cop(factura.total + factura.descuento)}'),
              pw.Text('Descuento: ${Formato.cop(factura.descuento)}'),
              pw.Text('Total: ${Formato.cop(factura.total)}',
                  style: const pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 15)),
              pw.Text('Base gravable: ${Formato.cop(factura.baseGravable)}'),
              pw.Text(
                  'IVA (${empresa.impuesto.replaceAll('%', '')}%): ${Formato.cop(factura.iva)}'),
              pw.SizedBox(height: 4),
              pw.Text('Método de pago: ${factura.metodoPago}'),
              pw.Text('Valor pagado: ${Formato.cop(factura.valorPagado)}'),
            ],
          ),
        ),
        pw.SizedBox(height: 24),
        pw.Center(
          child: pw.Column(
            children: [
              pw.Text('¡Gracias por su compra!',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: _verde)),
              pw.Text(empresa.correoContacto, style: const pw.TextStyle(fontSize: 9)),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _contenidoEntrada(
    EmpresaConfig empresa,
    EntradaInventario entrada,
    List<Map<String, Object?>> detalles,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(empresa.nombreComercial,
            style: pw.TextStyle(
                fontSize: 18, fontWeight: pw.FontWeight.bold, color: _azul)),
        pw.Text('NIT: ${empresa.nit}'),
        pw.Text(empresa.direccion),
        pw.SizedBox(height: 8),
        _divisor(),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('ENTRADA ${entrada.numeroFactura()}',
                style:
                    const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
            pw.Text(Formato.fechaHora(entrada.fecha)),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Text('Proveedor: ${entrada.proveedor}'),
        pw.Text('Documento: ${entrada.documento ?? '-'}'),
        pw.Text('Usuario: ${entrada.usuario ?? '-'}'),
        if ((entrada.observaciones ?? '').isNotEmpty)
          pw.Text('Observaciones: ${entrada.observaciones}'),
        pw.SizedBox(height: 12),
        _divisor(),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headers: ['Producto', 'Cant.', 'Costo', 'Subtotal'],
          data: detalles.map((d) {
            return [
              d['producto_nombre'] ?? 'Producto',
              '${d['cantidad']}',
              Formato.cop(d['precio'] as num),
              Formato.cop(d['subtotal'] as num),
            ];
          }).toList(),
          headerStyle:
              pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: _azul),
          cellStyle: const pw.TextStyle(fontSize: 10),
          cellAlignments: {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.centerRight,
            2: pw.Alignment.centerRight,
            3: pw.Alignment.centerRight,
          },
          border: pw.TableBorder(
            horizontalInside:
                pw.BorderSide(color: PdfColors.grey300),
          ),
        ),
        pw.SizedBox(height: 16),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('TOTAL: ${Formato.cop(entrada.total)}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 15)),
        ),
      ],
    );
  }

  static pw.Widget _divisor() =>
      pw.Divider(color: _azulClaro, height: 1, thickness: 1.5);

  static const PdfColor _azul = PdfColor.fromInt(0xFF3A56E4);
  static const PdfColor _azulClaro = PdfColor.fromInt(0xFF5C7CFA);
  static const PdfColor _verde = PdfColor.fromInt(0xFF059669);
}
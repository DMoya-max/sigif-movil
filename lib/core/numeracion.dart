/// Números de factura de entrada generados automáticamente: ENT-00001
class Numeracion {
  Numeracion._();

  static String facturaEntrada(int id) => 'ENT-${id.toString().padLeft(5, '0')}';
}
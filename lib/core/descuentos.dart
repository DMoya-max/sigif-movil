/// Fuente única de verdad para los códigos de descuento.
/// Tal y como ocurre en el backend Django (core/descuentos.py), el
/// porcentaje nunca se confía al cliente; se calcula aquí.
class Descuentos {
  Descuentos._();

  static const Map<String, int> codigos = {
    'DESC10': 10,
    'DESCUENTO10': 10,
    'PROMO20': 20,
    'SUPER30': 30,
    'OFERTA50': 50,
  };

  /// Devuelve el porcentaje asociado a un código, o 0 si no es válido.
  static int porcentajeCodigo(String? codigo) {
    if (codigo == null || codigo.trim().isEmpty) return 0;
    return codigos[codigo.trim().toUpperCase()] ?? 0;
  }
}
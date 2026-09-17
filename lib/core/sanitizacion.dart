/// Saneamiento anti-XSS: elimina los caracteres `<` y `>` de los textos
/// antes de persistirlos, replicando el patrón usado en los modelos Django.
class Sanitizacion {
  Sanitizacion._();

  static String? limpiar(String? valor) {
    if (valor == null) return null;
    return valor.replaceAll('<', '').replaceAll('>', '');
  }

  static String limpiarNonNull(String valor) => valor.replaceAll('<', '').replaceAll('>', '');

  /// Recorta un texto a un máximo de caracteres.
  static String acotar(String valor, int maximo) {
    if (valor.length <= maximo) return valor;
    return valor.substring(0, maximo);
  }
}
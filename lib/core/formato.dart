import 'package:intl/intl.dart';

/// Utilidades de formato COP (pesos colombianos) y fechas, equivalentes a
/// `formato_cop()` y a los formatos usados en las plantillas Django.
class Formato {
  Formato._();

  /// Formatea un valor numérico como moneda colombiana:
  /// ejemplo: `$ 1.234.567 COP`.
  static String cop(num valor) {
    final entero = valor.round();
    final formateado = NumberFormat('#,##0', 'en_US')
        .format(entero)
        .replaceAll(',', '.');
    return '\$ $formateado COP';
  }

  /// Fecha y hora corta: dd/mm/yyyy HH:MM
  static String fechaHora(DateTime fecha) {
    final local = fecha.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$d/$m/${local.year} $h:$min';
  }

  /// Fecha corta: dd/mm/yyyy
  static String fecha(DateTime fecha) {
    final local = fecha.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    return '$d/$m/${local.year}';
  }

  /// Fecha ISO para BD: yyyy-MM-dd
  static String fechaIso(DateTime fecha) {
    final local = fecha.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    return '${local.year}-$m-$d';
  }

  /// Fecha/hora ISO para BD: yyyy-MM-dd HH:mm:ss
  static String fechaHoraIso(DateTime fecha) {
    final local = fecha.toLocal();
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(local);
  }

  static DateTime? parseFecha(String? iso) {
    if (iso == null || iso.trim().isEmpty) return null;
    return DateTime.tryParse(iso);
  }

  /// Formatea una cantidad entera con separador de miles (1.234).
  static String miles(num valor) {
    final s = valor.round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write('.');
      buffer.write(s[i]);
    }
    return buffer.toString();
  }

  /// Nombres de meses en español (índice 1 = enero).
  static const List<String> meses = [
    '',
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];
}
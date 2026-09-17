class Auditoria {
  final int? id;
  final String usuario;
  final String accion;
  final String modulo;
  final DateTime fecha;

  const Auditoria({
    this.id,
    required this.usuario,
    required this.accion,
    required this.modulo,
    required this.fecha,
  });

  Map<String, Object?> aMap() => {
        'id': id,
        'usuario': usuario,
        'accion': accion,
        'modulo': modulo,
        'fecha': fecha.toIso8601String(),
      };

  factory Auditoria.desdeMapa(Map<String, Object?> m) => Auditoria(
        id: m['id'] as int?,
        usuario: (m['usuario'] as String?) ?? '',
        accion: (m['accion'] as String?) ?? '',
        modulo: (m['modulo'] as String?) ?? '',
        fecha: DateTime.parse(m['fecha'] as String),
      );
}
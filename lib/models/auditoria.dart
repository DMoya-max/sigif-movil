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

  factory Auditoria.desdeMapa(Map<String, Object?> m) => Auditoria.fromJson(m);

  factory Auditoria.fromJson(Map<String, dynamic> json) => Auditoria(
        id: json['id'] is int
            ? json['id'] as int
            : int.tryParse(json['id']?.toString() ?? ''),
        usuario: json['usuario']?.toString() ?? '',
        accion: json['accion']?.toString() ?? '',
        modulo: json['modulo']?.toString() ?? '',
        fecha: DateTime.tryParse(json['fecha']?.toString() ?? '')?.toLocal() ??
            DateTime.now(),
      );
}

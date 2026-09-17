import '../core/constantes.dart';

class EmpresaConfig {
  final int? id;
  final String nombreComercial;
  final String nit;
  final String direccion;
  final String moneda;
  final String impuesto;
  final String correoContacto;

  const EmpresaConfig({
    this.id,
    required this.nombreComercial,
    required this.nit,
    required this.direccion,
    required this.moneda,
    required this.impuesto,
    required this.correoContacto,
  });

  factory EmpresaConfig.porDefecto() => const EmpresaConfig(
        nombreComercial: Constantes.empresaNombre,
        nit: Constantes.empresaNit,
        direccion: Constantes.empresaDireccion,
        moneda: Constantes.empresaMoneda,
        impuesto: Constantes.empresaImpuesto,
        correoContacto: Constantes.empresaCorreo,
      );

  EmpresaConfig copyWith({
    int? id,
    String? nombreComercial,
    String? nit,
    String? direccion,
    String? moneda,
    String? impuesto,
    String? correoContacto,
  }) =>
      EmpresaConfig(
        id: id ?? this.id,
        nombreComercial: nombreComercial ?? this.nombreComercial,
        nit: nit ?? this.nit,
        direccion: direccion ?? this.direccion,
        moneda: moneda ?? this.moneda,
        impuesto: impuesto ?? this.impuesto,
        correoContacto: correoContacto ?? this.correoContacto,
      );

  Map<String, Object?> aMap() => {
        'id': id,
        'nombre_comercial': nombreComercial,
        'nit': nit,
        'direccion': direccion,
        'moneda': moneda,
        'impuesto': impuesto,
        'correo_contacto': correoContacto,
      };

  factory EmpresaConfig.desdeMapa(Map<String, Object?> m) => EmpresaConfig(
        id: m['id'] as int?,
        nombreComercial: (m['nombre_comercial'] as String?) ?? '',
        nit: (m['nit'] as String?) ?? '',
        direccion: (m['direccion'] as String?) ?? '',
        moneda: (m['moneda'] as String?) ?? '',
        impuesto: (m['impuesto'] as String?) ?? '',
        correoContacto: (m['correo_contacto'] as String?) ?? '',
      );
}
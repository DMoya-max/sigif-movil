/// Constantes globales de SIGIF, espejo de las definiciones del proyecto Django.
class Constantes {
  Constantes._();

  // ------------------------------------------------------------------
  // Roles de usuario (Usuarios.CARGOS)
  // ------------------------------------------------------------------
  static const List<String> cargos = ['SuperAdmin', 'Admin', 'Empleado'];

  static const String rolSuperAdmin = 'SuperAdmin';
  static const String rolAdmin = 'Admin';
  static const String rolEmpleado = 'Empleado';

  // ------------------------------------------------------------------
  // Categorías de productos (Producto.CATEGORIAS)
  // ------------------------------------------------------------------
  static const List<String> categoriasProducto = [
    'Frenos',
    'Motor',
    'Transmisión',
    'Lubricantes y Fluidos',
    'Suspensión',
    'Eléctrico',
    'Llantas y Ruedas',
    'Dirección',
    'Carrocería',
    'Accesorios',
    'Filtros',
    'Repuestos Generales',
    'Insumos de Taller',
  ];

  // ------------------------------------------------------------------
  // Métodos de pago (Factura.METODOS_PAGO / Gasto.METODOS_PAGO)
  // ------------------------------------------------------------------
  static const List<String> metodosPagoFactura = [
    'EFECTIVO',
    'TARJETA',
    'TRANSFERENCIA',
    'CREDITO',
  ];

  static const List<String> metodosPagoGasto = [
    'EFECTIVO',
    'TRANSFERENCIA',
    'TARJETA',
    'CREDITO',
    'OTRO',
  ];

  static const Map<String, String> metodosPagoLabel = {
    'EFECTIVO': 'Efectivo',
    'TARJETA': 'Tarjeta',
    'TRANSFERENCIA': 'Transferencia',
    'CREDITO': 'Crédito',
    'OTRO': 'Otro',
  };

  // ------------------------------------------------------------------
  // Categorías de gastos (Gasto.CATEGORIAS)
  // ------------------------------------------------------------------
  static const Map<String, String> categoriasGasto = {
    'ARRIENDO': 'Arriendo',
    'SERVICIOS': 'Servicios públicos',
    'REPUESTOS': 'Compra de repuestos',
    'INSUMOS': 'Insumos',
    'NOMINA': 'Nómina',
    'TRANSPORTE': 'Transporte',
    'PUBLICIDAD': 'Publicidad',
    'IMPUESTOS': 'Impuestos',
    'MANTENIMIENTO': 'Mantenimiento',
    'OTROS': 'Otros',
  };

  // ------------------------------------------------------------------
  // Estados de pago / factura (derivados)
  // ------------------------------------------------------------------
  static const String estadoPagada = 'PAGADA';
  static const String estadoVencida = 'VENCIDA';
  static const String estadoParcial = 'PARCIAL';
  static const String estadoPendiente = 'PENDIENTE';

  static const Map<String, String> estadoPagoLabel = {
    estadoPagada: 'Pagada',
    estadoVencida: 'Vencida',
    estadoParcial: 'Parcialmente pagada',
    estadoPendiente: 'Pendiente',
  };

  // ------------------------------------------------------------------
  // Módulos de auditoría (Auditoria.MODULOS)
  // ------------------------------------------------------------------
  static const List<String> modulosAuditoria = [
    'USUARIOS',
    'PRODUCTOS',
    'INVENTARIO',
    'FACTURACION',
    'FINANZAS',
    'CONFIGURACION',
  ];

  // ------------------------------------------------------------------
  // Cliente por defecto (Consumidor Final)
  // ------------------------------------------------------------------
  static const String consumidorFinalCorreo = 'consumidorfinal@pos.com';
  static const String consumidorFinalNombre = 'Consumidor Final';

  // ------------------------------------------------------------------
  // Empresa por defecto (EmpresaConfig defaults)
  // ------------------------------------------------------------------
  static const String empresaNombre = 'SIGIF';
  static const String empresaNit = '900.123.456-7';
  static const String empresaDireccion = 'CASA DE MOYA "LA AURORA"';
  static const String empresaMoneda = r'COP ($) - Pesos Colombianos';
  static const String empresaImpuesto = '19%';
  static const String empresaCorreo = 'soporte@sigif.com';

  // ------------------------------------------------------------------
  // SuperAdmin principal por defecto (siembra inicial)
  // ------------------------------------------------------------------
  static const String adminCorreo = 'admin@sigif.com';
  static const String adminClave = 'admin1234';
  static const String adminNombre = 'Administrador';
  static const String adminDocumento = '0000000001';
  static const String adminTelefono = '3000000000';

  static const double ivaTasa = 0.19;
}
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../core/constantes.dart';
import '../services/password_service.dart';

/// Inicializa el factory de SQLite multiplataforma (Android/iOS reales y
/// desktop Linux/Windows/macOS para pruebas durante el desarrollo).
void inicializarSqflite() {
  if (databaseFactory == null) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}

/// Base de datos local de SIGIF: replica el esquema de los modelos Django.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const String _nombreBd = 'sigif.db';
  static const int _version = 1;

  Database? _db;

  Future<Database> get db async {
    _db ??= await _abrir();
    return _db!;
  }

  Future<Database> _abrir() async {
    inicializarSqflite();
    final dir = await getDatabasesPath();
    final ruta = p.join(dir, _nombreBd);
    return openDatabase(
      ruta,
      version: _version,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _crearEsquemaYSembrar,
    );
  }

  Future<void> _crearEsquemaYSembrar(Database db, int version) async {
    await db.execute('''
      CREATE TABLE usuarios (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        documento TEXT NOT NULL UNIQUE,
        contra TEXT NOT NULL,
        telefono TEXT NOT NULL UNIQUE,
        correo TEXT NOT NULL UNIQUE,
        activo INTEGER NOT NULL DEFAULT 1,
        fecha_inicio TEXT,
        cargo TEXT NOT NULL DEFAULT 'Empleado',
        es_superadmin_principal INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE productos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        descripcion TEXT,
        precio INTEGER NOT NULL DEFAULT 0,
        stock INTEGER NOT NULL DEFAULT 0,
        categoria TEXT NOT NULL,
        activo INTEGER NOT NULL DEFAULT 1,
        fecha_creacion TEXT NOT NULL,
        fecha_actualizacion TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE clientes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        correo TEXT NOT NULL UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE facturas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cliente_id INTEGER NOT NULL,
        usuario TEXT,
        fecha TEXT NOT NULL,
        total REAL NOT NULL,
        descuento REAL NOT NULL DEFAULT 0,
        metodo_pago TEXT NOT NULL DEFAULT 'EFECTIVO',
        valor_pagado REAL NOT NULL DEFAULT 0,
        fecha_vencimiento TEXT,
        FOREIGN KEY (cliente_id) REFERENCES clientes (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE detalle_factura (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        factura_id INTEGER NOT NULL,
        producto_id INTEGER NOT NULL,
        cantidad INTEGER NOT NULL,
        precio INTEGER NOT NULL,
        subtotal INTEGER NOT NULL,
        FOREIGN KEY (factura_id) REFERENCES facturas (id) ON DELETE CASCADE,
        FOREIGN KEY (producto_id) REFERENCES productos (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE entrada_inventario (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        proveedor TEXT NOT NULL,
        documento TEXT,
        usuario TEXT,
        observaciones TEXT,
        fecha TEXT NOT NULL,
        total REAL NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE detalle_entrada_inventario (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entrada_id INTEGER NOT NULL,
        producto_id INTEGER NOT NULL,
        cantidad INTEGER NOT NULL,
        precio INTEGER NOT NULL,
        subtotal INTEGER NOT NULL,
        FOREIGN KEY (entrada_id) REFERENCES entrada_inventario (id) ON DELETE CASCADE,
        FOREIGN KEY (producto_id) REFERENCES productos (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE gastos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        concepto TEXT NOT NULL,
        categoria TEXT NOT NULL,
        valor REAL NOT NULL,
        fecha TEXT NOT NULL,
        metodo_pago TEXT NOT NULL DEFAULT 'EFECTIVO',
        proveedor TEXT NOT NULL DEFAULT '',
        descripcion TEXT NOT NULL DEFAULT '',
        usuario TEXT NOT NULL,
        creado_en TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE cuentas_por_pagar (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        proveedor TEXT NOT NULL,
        concepto TEXT NOT NULL,
        fecha TEXT NOT NULL,
        valor REAL NOT NULL,
        valor_pagado REAL NOT NULL DEFAULT 0,
        fecha_vencimiento TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE auditoria (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        usuario TEXT NOT NULL,
        accion TEXT NOT NULL,
        modulo TEXT NOT NULL,
        fecha TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE empresa_config (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre_comercial TEXT NOT NULL,
        nit TEXT NOT NULL,
        direccion TEXT NOT NULL,
        moneda TEXT NOT NULL,
        impuesto TEXT NOT NULL,
        correo_contacto TEXT NOT NULL
      )
    ''');

    await _sembrar(db);
  }

  Future<void> _sembrar(Database db) async {
    final ahora = DateTime.now();
    if (await db.query('usuarios').then((r) => r.isEmpty)) {
      final hash = await PasswordService.crearHash(Constantes.adminClave);
      await db.insert('usuarios', {
        'nombre': Constantes.adminNombre,
        'documento': Constantes.adminDocumento,
        'contra': hash,
        'telefono': Constantes.adminTelefono,
        'correo': Constantes.adminCorreo,
        'activo': 1,
        'fecha_inicio': ahora.toIso8601String().split('T').first,
        'cargo': Constantes.rolSuperAdmin,
        'es_superadmin_principal': 1,
      });
    }

    if (await db.query('empresa_config').then((r) => r.isEmpty)) {
      await db.insert('empresa_config', {
        'nombre_comercial': Constantes.empresaNombre,
        'nit': Constantes.empresaNit,
        'direccion': Constantes.empresaDireccion,
        'moneda': Constantes.empresaMoneda,
        'impuesto': Constantes.empresaImpuesto,
        'correo_contacto': Constantes.empresaCorreo,
      });
    }

    final consumidor = await db.query(
      'clientes',
      where: "correo = ?",
      whereArgs: [Constantes.consumidorFinalCorreo],
    );
    if (consumidor.isEmpty) {
      await db.insert('clientes', {
        'nombre': Constantes.consumidorFinalNombre,
        'correo': Constantes.consumidorFinalCorreo,
      });
    }
  }

  Future<void> cerrar() async {
    await _db?.close();
    _db = null;
  }
}
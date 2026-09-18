import 'package:flutter_test/flutter_test.dart';
import 'package:sigif_flutter/core/descuentos.dart';
import 'package:sigif_flutter/core/formato.dart';
import 'package:sigif_flutter/services/password_service.dart';

void main() {
  group('PasswordService', () {
    test('crearHash y verificar generan un hash válido', () async {
      final hash = await PasswordService.crearHash('admin1234');
      final partes = hash.split(r'$');
      expect(partes.length, 4);
      expect(partes[0], 'pbkdf2_sha256');
      expect(int.parse(partes[1]), 100000);
      expect(await PasswordService.verificar('admin1234', hash), isTrue);
      expect(await PasswordService.verificar('otraClave', hash), isFalse);
    });

    test('verificar rechaza hashes malformados', () async {
      expect(await PasswordService.verificar('x', 'no-es-un-hash'), isFalse);
      expect(await PasswordService.verificar('x', ''), isFalse);
    });
  });

  group('Descuentos', () {
    test('porcentajeCodigo reconoce códigos en mayúsculas y minúsculas',
        () {
      expect(Descuentos.porcentajeCodigo('DESC10'), 10);
      expect(Descuentos.porcentajeCodigo('descuento10'), 10);
      expect(Descuentos.porcentajeCodigo('  promo20 '), 20);
      expect(Descuentos.porcentajeCodigo('SUPER30'), 30);
      expect(Descuentos.porcentajeCodigo('OFERTA50'), 50);
    });

    test('porcentajeCodigo devuelve 0 para códigos inválidos', () {
      expect(Descuentos.porcentajeCodigo('NOEXISTE'), 0);
      expect(Descuentos.porcentajeCodigo(null), 0);
      expect(Descuentos.porcentajeCodigo(''), 0);
    });
  });

  group('Formato', () {
    test('cop formatea con separador de miles y sufijo COP', () {
      expect(Formato.cop(1234), '\$ 1.234 COP');
      expect(Formato.cop(0), '\$ 0 COP');
      expect(Formato.cop(1234567.89), '\$ 1.234.568 COP');
    });

    test('miles formatea con separador de miles', () {
      expect(Formato.miles(1500), '1.500');
      expect(Formato.miles(42), '42');
    });
  });
}
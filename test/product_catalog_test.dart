import 'package:flutter_test/flutter_test.dart';
import 'package:rodzinna_lista_zakupow/data/product_catalog.dart';

void main() {
  test('katalog podpowiedzi ma duży zestaw produktów', () {
    final names = productCatalog.map((item) => item.name).toSet();

    expect(productCatalog.length, greaterThan(180));
    expect(
      names,
      containsAll(['Chleb', 'Mleko', 'Kurczak', 'Papier toaletowy']),
    );
  });
}

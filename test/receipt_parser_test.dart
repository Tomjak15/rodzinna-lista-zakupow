import 'package:flutter_test/flutter_test.dart';
import 'package:rodzinna_lista_zakupow/utils/receipt_parser.dart';

void main() {
  test('parser paragonu odczytuje produkty i sume', () {
    final parsed = parseReceiptText('''
PARAGON FISKALNY
CHLEB 1 szt. 4,99
MLEKO 2 l 7,80
MARWIT MARCHEW 1 kg 5,50
SUMA PLN 18,29
''');

    expect(parsed.items, hasLength(3));
    expect(parsed.items.map((item) => item.name), [
      'CHLEB',
      'MLEKO',
      'MARWIT MARCHEW',
    ]);
    expect(parsed.items[1].quantity, 2);
    expect(parsed.items[1].unit, 'l');
    expect(parsed.total, 18.29);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:rodzinna_lista_zakupow/utils/receipt_parser.dart';

void main() {
  test('parser paragonu odczytuje sklep produkty i sume', () {
    final parsed = parseReceiptText('''
BIEDRONKA
PARAGON FISKALNY
1234567890123 4,99
CHLEB 1 szt. 4,99
MLEKO 2 l 7,80
MARWIT MARCHEW 1 kg 5,50
SUMA PLN 18,29
''');

    expect(parsed.storeName, 'Biedronka');
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

  test('parser paragonu nie zapisuje przypadkowych numerow jako produktow', () {
    final parsed = parseReceiptText('''
LIDL
NIP 1234567890
NR PARAGONU 998877
TERMINAL 123456
SER 200 g 8,99
DO ZAPLATY 8,99 PLN
''');

    expect(parsed.storeName, 'Lidl');
    expect(parsed.items.map((item) => item.name), ['SER']);
    expect(parsed.total, 8.99);
  });
}

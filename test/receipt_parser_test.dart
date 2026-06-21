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
      'Chleb',
      'Mleko',
      'Marwit Marchew',
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
    expect(parsed.items.map((item) => item.name), ['Ser']);
    expect(parsed.total, 8.99);
  });

  test('parser paragonu czyta produkty z literami VAT i sume', () {
    final parsed = parseReceiptText('''
LIDL
MLEKO 3,2% 1L A 4,29
CHLEB WIEJSKI B 5,99
2 x BANAN KG 7,50
SUMA PLN 17,78
KARTA 17,78
''');

    expect(parsed.storeName, 'Lidl');
    expect(parsed.total, 17.78);
    expect(parsed.items.map((item) => item.name), contains('Mleko 3,2%'));
    expect(parsed.items.map((item) => item.name), contains('Chleb Wiejski'));
    expect(parsed.items.any((item) => item.name.contains('Banan')), isTrue);
  });

  test('parser paragonu czyta sume zapisana ze spacja', () {
    final parsed = parseReceiptText('''
ŻABKA
PARAGON FISKALNY
HOT DOG 1 szt 8 99 A
NAPOJ COLA 500 ml 6 50 B
DO ZAPŁATY
15 49
KARTA 15 49
''');

    expect(parsed.storeName, 'Żabka');
    expect(parsed.total, 15.49);
    expect(parsed.items.map((item) => item.name), contains('Hot Dog'));
    expect(parsed.items.map((item) => item.name), contains('Napoj Cola'));
  });

  test('parser paragonu czyta produkt rozbity na nazwe i cene', () {
    final parsed = parseReceiptText('''
LIDL
CHLEB ŻYTNI
1 szt x 5,99 5,99 A
MASŁO EXTRA
1 x 7,99 A
RAZEM PLN 13,98
''');

    expect(parsed.items.map((item) => item.name), contains('Chleb Żytni'));
    expect(parsed.items.map((item) => item.name), contains('Masło Extra'));
    expect(
      parsed.items.firstWhere((item) => item.name == 'Chleb Żytni').price,
      5.99,
    );
    expect(parsed.total, 13.98);
  });

  test('parser paragonu czyta produkty wazone z cena za kg', () {
    final parsed = parseReceiptText('''
BIEDRONKA
BANAN 0,456 kg x 4,99 2,28 A
POMIDOR 0,354 KG 8,99/kg 3,18 B
SUMA PLN 5,46
''');

    final banana = parsed.items.firstWhere((item) => item.name == 'Banan');
    final tomato = parsed.items.firstWhere((item) => item.name == 'Pomidor');

    expect(banana.quantity, 0.456);
    expect(banana.unit, 'kg');
    expect(banana.price, 2.28);
    expect(tomato.quantity, 0.354);
    expect(tomato.unit, 'kg');
    expect(tomato.price, 3.18);
    expect(parsed.total, 5.46);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:rodzinna_lista_zakupow/utils/product_category.dart';

void main() {
  test('kategorie robia sie automatycznie po nazwie produktu', () {
    expect(categoryForProduct('chleb zytni'), 'Pieczywo');
    expect(categoryForProduct('pierś z kurczaka'), 'Mięso i wędliny');
    expect(categoryForProduct('marchew'), 'Warzywa');
    expect(categoryForProduct('płatki kukurydziane'), 'Sypkie i makarony');
    expect(categoryForProduct('mąka kukurydziana'), 'Sypkie i makarony');
    expect(categoryForProduct('chrupki kukurydziane'), 'Słodycze i przekąski');
    expect(categoryForProduct('kukurydza w puszce'), 'Warzywa');
    expect(categoryForProduct('losowy produkt'), 'Inne');
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:rodzinna_lista_zakupow/utils/ingredient_parser.dart';

void main() {
  group('parseIngredientLines', () {
    test('rozpoznaje popularne sposoby wpisywania składników', () {
      final ingredients = parseIngredientLines('''
marchew; 200; gramów
mleko 1,5 l
2 jajka
ryż 1 szklanka
cukier
''');

      expect(ingredients.length, 5);
      expect(ingredients[0].name, 'marchew');
      expect(ingredients[0].quantity, 200);
      expect(ingredients[0].unit, 'g');
      expect(ingredients[1].name, 'mleko');
      expect(ingredients[1].quantity, 1.5);
      expect(ingredients[1].unit, 'l');
      expect(ingredients[2].name, 'jajka');
      expect(ingredients[2].quantity, 2);
      expect(ingredients[2].unit, 'szt.');
      expect(ingredients[3].name, 'ryż');
      expect(ingredients[3].quantity, 1);
      expect(ingredients[3].unit, 'szklanka');
      expect(ingredients[4].name, 'cukier');
      expect(ingredients[4].quantity, 1);
      expect(ingredients[4].unit, 'szt.');
    });

    test('łączy takie same składniki i normalizuje jednostki', () {
      final ingredients = parseIngredientLines('''
marchew 200 g
marchew; 300; gramów
2 jajka
jajka 3 sztuki
''');

      expect(ingredients.length, 2);
      expect(ingredients[0].name, 'marchew');
      expect(ingredients[0].quantity, 500);
      expect(ingredients[0].unit, 'g');
      expect(ingredients[1].name, 'jajka');
      expect(ingredients[1].quantity, 5);
      expect(ingredients[1].unit, 'szt.');
    });
  });
}

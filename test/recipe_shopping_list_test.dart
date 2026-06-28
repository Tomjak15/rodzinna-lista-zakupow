import 'package:flutter_test/flutter_test.dart';
import 'package:rodzinna_lista_zakupow/app/app_state.dart';
import 'package:rodzinna_lista_zakupow/data/local_store.dart';
import 'package:rodzinna_lista_zakupow/models/ingredient_draft.dart';
import 'package:rodzinna_lista_zakupow/models/recipe_scan_result.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('przepis na 1 porcje dodany na 4 porcje mnozy skladniki', () async {
    final store = await LocalStore.create();
    final appState = AppState(store: store);
    addTearDown(appState.dispose);

    await appState.createFamily(familyName: 'Dom', memberName: 'Tomek');
    await appState.addMealWithRecipe(
      mealName: 'Owsianka',
      instructions: 'Wymieszaj.',
      baseServings: 1,
      ingredients: const [
        IngredientDraft(name: 'platki owsiane', quantity: 50, unit: 'g'),
      ],
    );

    final recipe = appState.data.activeRecipes.single;
    await appState.addRecipesToShoppingList(
      recipeIds: [recipe.id],
      servings: 4,
    );

    expect(appState.data.activeShoppingItems.single.quantity, 200);
  });

  test('przepis na 4 porcje dodany na 1 porcje dzieli skladniki', () async {
    final store = await LocalStore.create();
    final appState = AppState(store: store);
    addTearDown(appState.dispose);

    await appState.createFamily(familyName: 'Dom', memberName: 'Tomek');
    await appState.addMealWithRecipe(
      mealName: 'Makaron',
      instructions: 'Ugotuj.',
      baseServings: 4,
      ingredients: const [
        IngredientDraft(name: 'makaron', quantity: 400, unit: 'g'),
      ],
    );

    final recipe = appState.data.activeRecipes.single;
    await appState.addRecipesToShoppingList(
      recipeIds: [recipe.id],
      servings: 1,
    );

    expect(appState.data.activeShoppingItems.single.quantity, 100);
  });

  test(
    'dodawanie skladnikow do listy zwraca liczbe realnie dodanych pozycji',
    () async {
      final store = await LocalStore.create();
      final appState = AppState(store: store);
      addTearDown(appState.dispose);

      await appState.createFamily(familyName: 'Dom', memberName: 'Tomek');

      final added = await appState.addIngredientsToShoppingList(const [
        IngredientDraft(name: 'cukier', quantity: 100, unit: 'g'),
        IngredientDraft(name: '', quantity: 1, unit: 'szt.'),
      ]);

      expect(added, 1);
      expect(appState.data.activeShoppingItems.single.name, 'cukier');
    },
  );

  test('skan przepisu bez liczby porcji bazowych startuje od 1', () {
    final draft = RecipeScanDraft.fromJson(const {
      'name': 'Jajecznica',
      'ingredients': [
        {'name': 'jajka', 'quantity': 2, 'unit': 'szt.'},
      ],
    });

    expect(draft.baseServings, 1);
  });
}

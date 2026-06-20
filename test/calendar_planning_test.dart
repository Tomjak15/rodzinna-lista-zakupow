import 'package:flutter_test/flutter_test.dart';
import 'package:rodzinna_lista_zakupow/app/app_state.dart';
import 'package:rodzinna_lista_zakupow/data/local_store.dart';
import 'package:rodzinna_lista_zakupow/models/ingredient_draft.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('plan posiłku dodaje składniki do listy zakupów', () async {
    final store = await LocalStore.create();
    final appState = AppState(store: store);
    addTearDown(appState.dispose);

    await appState.createFamily(
      familyName: 'Dom',
      memberName: 'Tomek',
    );
    await appState.addMealWithRecipe(
      mealName: 'Makaron z serem',
      instructions: 'Ugotuj makaron i dodaj ser.',
      baseServings: 2,
      ingredients: const [
        IngredientDraft(name: 'makaron', quantity: 200, unit: 'g'),
        IngredientDraft(name: 'ser', quantity: 80, unit: 'g'),
      ],
    );

    final meal = appState.data.activeMeals.single;
    final recipe = appState.mainRecipeFor(meal)!;
    await appState.addMealPlanToCalendar(
      date: DateTime(2026, 6, 21),
      meal: meal,
      recipeIds: [recipe.id],
      servings: 4,
    );

    expect(appState.mealPlansForDate(DateTime(2026, 6, 21)), hasLength(1));
    expect(
      appState.data.activeShoppingItems
          .firstWhere((item) => item.name == 'makaron')
          .quantity,
      400,
    );
    expect(
      appState.data.activeShoppingItems
          .firstWhere((item) => item.name == 'ser')
          .quantity,
      160,
    );
  });

  test('twórca rodziny może dodać osobę do kalendarza', () async {
    final store = await LocalStore.create();
    final appState = AppState(store: store);
    addTearDown(appState.dispose);

    await appState.createFamily(familyName: 'Dom', memberName: 'Tomek');
    await appState.addCalendarMember(name: 'Mama');

    expect(appState.isFamilyCreator, isTrue);
    expect(appState.data.activeMembers.map((member) => member.name), [
      'Tomek',
      'Mama',
    ]);
  });
}

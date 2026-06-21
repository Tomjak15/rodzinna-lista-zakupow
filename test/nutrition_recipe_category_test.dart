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

  test('licznik kcal zapisuje cel i wpis dnia', () async {
    final store = await LocalStore.create();
    final appState = AppState(store: store);
    addTearDown(appState.dispose);

    await appState.createFamily(familyName: 'Dom', memberName: 'Tomek');
    final memberId = appState.data.currentMember!.id;

    await appState.saveNutritionGoal(dailyCalories: 2400, dailyProtein: 140);
    await appState.addNutritionEntry(
      date: DateTime(2026, 6, 21),
      calories: 620,
      protein: 42,
      note: 'Obiad',
    );

    expect(appState.nutritionGoalForMember(memberId)!.dailyCalories, 2400);
    expect(
      appState.nutritionEntriesForDate(DateTime(2026, 6, 21)),
      hasLength(1),
    );
    expect(
      appState.nutritionEntriesForDate(DateTime(2026, 6, 21)).single.protein,
      42,
    );
  });

  test('przepis mozna przeniesc miedzy kategoriami imion', () async {
    final store = await LocalStore.create();
    final appState = AppState(store: store);
    addTearDown(appState.dispose);

    await appState.createFamily(familyName: 'Dom', memberName: 'Tomek');
    await appState.addMealWithRecipe(
      mealName: 'Kotleciki',
      category: 'Anna',
      instructions: 'Usmaz.',
      baseServings: 4,
      ingredients: const [
        IngredientDraft(name: 'Kurczak', quantity: 500, unit: 'g'),
      ],
    );

    final recipe = appState.data.activeRecipes.single;
    expect(recipe.category, 'Anna');

    await appState.updateRecipeCategory(recipe: recipe, category: 'Kaja');

    final moved = appState.data.activeRecipes.single;
    expect(moved.category, 'Kaja');
    expect(moved.toRemote()['recipe_category'], 'Kaja');
  });
}

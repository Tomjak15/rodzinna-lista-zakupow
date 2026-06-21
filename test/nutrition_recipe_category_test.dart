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

  test('kategorie przepisow maja typy posilkow przed imionami', () {
    expect(AppState.recipeCategories.take(6), [
      'Śniadania',
      'Obiady',
      'Kolacje',
      'Przekąski',
      'Desery',
      'Napoje',
    ]);
    expect(
      AppState.recipeCategories.indexOf('Przekąski'),
      lessThan(AppState.recipeCategories.indexOf('Anna')),
    );
  });

  test('licznik zdrowia zapisuje cel i makro wpisu dnia', () async {
    final store = await LocalStore.create();
    final appState = AppState(store: store);
    addTearDown(appState.dispose);

    await appState.createFamily(familyName: 'Dom', memberName: 'Tomek');
    final memberId = appState.data.currentMember!.id;
    await appState.addCalendarMember(name: 'Anna');
    final anna = appState.data.activeMembers.firstWhere(
      (member) => member.name == 'Anna',
    );

    await appState.saveNutritionGoal(
      dailyCalories: 2400,
      dailyProtein: 140,
      dailyFat: 80,
      dailyCarbs: 260,
    );
    await appState.saveNutritionGoal(
      memberId: anna.id,
      dailyCalories: 1800,
      dailyProtein: 90,
      dailyFat: 60,
      dailyCarbs: 180,
    );
    await appState.addNutritionEntry(
      date: DateTime(2026, 6, 21),
      calories: 620,
      protein: 42,
      fat: 18,
      carbs: 74,
      note: 'Obiad',
    );
    await appState.addTrainingEntry(
      memberId: anna.id,
      date: DateTime(2026, 6, 21),
      durationMinutes: 45,
      activity: 'Silownia',
      note: 'Nogi',
    );

    expect(appState.nutritionGoalForMember(memberId)!.dailyCalories, 2400);
    expect(appState.nutritionGoalForMember(anna.id)!.dailyProtein, 90);
    expect(appState.nutritionGoalForMember(memberId)!.dailyFat, 80);
    expect(appState.nutritionGoalForMember(anna.id)!.dailyCarbs, 180);
    expect(
      appState.nutritionEntriesForDate(DateTime(2026, 6, 21)),
      hasLength(1),
    );
    expect(
      appState.nutritionEntriesForDate(DateTime(2026, 6, 21)).single.protein,
      42,
    );
    expect(
      appState.nutritionEntriesForDate(DateTime(2026, 6, 21)).single.fat,
      18,
    );
    expect(
      appState.nutritionEntriesForDate(DateTime(2026, 6, 21)).single.carbs,
      74,
    );
    expect(
      appState.trainingEntriesForDate(DateTime(2026, 6, 21)),
      hasLength(1),
    );
    expect(
      appState.trainingEntriesForDate(DateTime(2026, 6, 21)).single.toRemote(),
      containsPair('duration_minutes', 45),
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
      caloriesPerServing: 500,
      proteinPerServing: 35,
      fatPerServing: 12,
      carbsPerServing: 55,
      ingredients: const [
        IngredientDraft(name: 'Kurczak', quantity: 500, unit: 'g'),
      ],
    );

    final recipe = appState.data.activeRecipes.single;
    expect(recipe.category, 'Anna');
    expect(recipe.caloriesPerServing, 500);
    expect(recipe.proteinPerServing, 35);
    expect(recipe.fatPerServing, 12);
    expect(recipe.carbsPerServing, 55);
    expect(recipe.toRemote()['calories_per_serving'], 500);
    expect(recipe.toRemote()['protein_per_serving'], 35);
    expect(recipe.toRemote()['fat_per_serving'], 12);
    expect(recipe.toRemote()['carbs_per_serving'], 55);

    await appState.updateRecipeCategory(recipe: recipe, category: 'Kaja');

    final moved = appState.data.activeRecipes.single;
    expect(moved.category, 'Kaja');
    expect(moved.toRemote()['recipe_category'], 'Kaja');
  });

  test('zdrowie liczy makro z procentu porcji przepisu', () async {
    final store = await LocalStore.create();
    final appState = AppState(store: store);
    addTearDown(appState.dispose);

    await appState.createFamily(familyName: 'Dom', memberName: 'Tomek');
    await appState.addMealWithRecipe(
      mealName: 'Kurczak z ryzem',
      category: 'Tomek',
      instructions: 'Ugotuj.',
      baseServings: 2,
      caloriesPerServing: 500,
      proteinPerServing: 35,
      fatPerServing: 20,
      carbsPerServing: 45,
      ingredients: const [
        IngredientDraft(name: 'Kurczak', quantity: 200, unit: 'g'),
        IngredientDraft(name: 'Ryz', quantity: 100, unit: 'g'),
      ],
    );

    final recipe = appState.data.activeRecipes.single;
    await appState.addNutritionEntryFromRecipe(
      date: DateTime(2026, 6, 21),
      recipe: recipe,
      servingPercent: 80,
    );

    final entry = appState
        .nutritionEntriesForDate(DateTime(2026, 6, 21))
        .single;
    expect(entry.calories, 400);
    expect(entry.protein, 28);
    expect(entry.fat, 16);
    expect(entry.carbs, 36);
    expect(entry.note, 'Kurczak z ryzem (80% porcji)');
  });
}

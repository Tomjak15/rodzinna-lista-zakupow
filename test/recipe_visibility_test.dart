import 'package:flutter_test/flutter_test.dart';
import 'package:rodzinna_lista_zakupow/models/entities.dart';

void main() {
  test('glowny przepis zostaje widoczny nawet bez rekordu obiadu', () {
    final now = DateTime.utc(2026, 6, 28);
    final recipe = Recipe(
      id: 'recipe-1',
      familyId: 'family-1',
      mealId: 'missing-meal-1',
      parentRecipeId: null,
      name: 'Nalesniki',
      category: 'Sniadania',
      instructions: 'Wymieszaj i usmaz.',
      baseServings: 2,
      caloriesPerServing: 400,
      proteinPerServing: 18,
      fatPerServing: 12,
      carbsPerServing: 55,
      createdAt: now,
      updatedAt: now,
      createdBy: 'member-1',
      isDeleted: false,
      syncStatus: SyncStatus.synced,
    );

    final data = AppData.empty().copyWith(recipes: [recipe]);
    final visibleMeals = data.activeRecipeMeals;

    expect(data.activeMeals, isEmpty);
    expect(visibleMeals, hasLength(1));
    expect(visibleMeals.single.id, 'missing-meal-1');
    expect(visibleMeals.single.name, 'Nalesniki');
    expect(visibleMeals.single.syncStatus, SyncStatus.synced);
  });

  test('istniejacy obiad nie jest dublowany przez przepis', () {
    final now = DateTime.utc(2026, 6, 28);
    final meal = Meal(
      id: 'meal-1',
      familyId: 'family-1',
      name: 'Makaron',
      createdAt: now,
      updatedAt: now,
      createdBy: 'member-1',
      isDeleted: false,
      syncStatus: SyncStatus.synced,
    );
    final recipe = Recipe(
      id: 'recipe-1',
      familyId: 'family-1',
      mealId: 'meal-1',
      parentRecipeId: null,
      name: 'Makaron',
      category: 'Obiady',
      instructions: 'Ugotuj.',
      baseServings: 2,
      caloriesPerServing: 500,
      proteinPerServing: 20,
      fatPerServing: 15,
      carbsPerServing: 75,
      createdAt: now,
      updatedAt: now,
      createdBy: 'member-1',
      isDeleted: false,
      syncStatus: SyncStatus.synced,
    );

    final data = AppData.empty().copyWith(meals: [meal], recipes: [recipe]);

    expect(data.activeRecipeMeals, hasLength(1));
    expect(data.activeRecipeMeals.single.id, 'meal-1');
  });
}

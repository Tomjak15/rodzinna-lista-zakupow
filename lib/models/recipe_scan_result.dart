import 'ingredient_draft.dart';

class RecipeScanDraft {
  const RecipeScanDraft({
    required this.name,
    required this.category,
    required this.instructions,
    required this.baseServings,
    required this.caloriesPerServing,
    required this.proteinPerServing,
    required this.fatPerServing,
    required this.carbsPerServing,
    required this.ingredients,
  });

  factory RecipeScanDraft.fromJson(Map<String, dynamic> json) {
    final rawIngredients = json['ingredients'];
    final ingredients = rawIngredients is List
        ? rawIngredients
              .whereType<Map>()
              .map(
                (item) => IngredientDraft(
                  name: (item['name'] ?? '').toString().trim(),
                  quantity: _toDouble(item['quantity']),
                  unit: (item['unit'] ?? 'szt.').toString().trim(),
                ),
              )
              .where((item) => item.name.isNotEmpty && item.quantity > 0)
              .toList(growable: false)
        : <IngredientDraft>[];

    return RecipeScanDraft(
      name: (json['name'] ?? '').toString().trim(),
      category: (json['category'] ?? 'Obiady').toString().trim(),
      instructions: (json['instructions'] ?? '').toString().trim(),
      baseServings: _toInt(json['baseServings'], fallback: 1).clamp(1, 99),
      caloriesPerServing: _toInt(json['caloriesPerServing']),
      proteinPerServing: _toDouble(json['proteinPerServing']),
      fatPerServing: _toDouble(json['fatPerServing']),
      carbsPerServing: _toDouble(json['carbsPerServing']),
      ingredients: ingredients,
    );
  }

  final String name;
  final String category;
  final String instructions;
  final int baseServings;
  final int caloriesPerServing;
  final double proteinPerServing;
  final double fatPerServing;
  final double carbsPerServing;
  final List<IngredientDraft> ingredients;
}

int _toInt(Object? value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  return int.tryParse((value ?? '').toString().trim()) ?? fallback;
}

double _toDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse((value ?? '').toString().replaceAll(',', '.')) ?? 0;
}

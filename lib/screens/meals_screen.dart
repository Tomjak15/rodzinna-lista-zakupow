import 'dart:math';

import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../app/app_state.dart';
import '../models/entities.dart';
import '../models/ingredient_draft.dart';
import '../models/recipe_scan_result.dart';
import '../services/recipe_ai_service.dart';
import '../services/recipe_scanner.dart';
import '../utils/ingredient_parser.dart';

class MealsScreen extends StatefulWidget {
  const MealsScreen({super.key});

  @override
  State<MealsScreen> createState() => _MealsScreenState();
}

class _MealsScreenState extends State<MealsScreen> {
  String _selectedCategory = 'Wszystkie';
  bool _aiScanning = false;

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    final allMeals = [...appState.data.activeMeals]
      ..sort((a, b) => a.name.compareTo(b.name));
    final meals = _selectedCategory == 'Wszystkie'
        ? allMeals
        : allMeals
              .where(
                (meal) =>
                    appState.mainRecipeFor(meal)?.category == _selectedCategory,
              )
              .toList();

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 96),
        children: [
          _RecipeCategoryBar(
            selectedCategory: _selectedCategory,
            onChanged: (category) =>
                setState(() => _selectedCategory = category),
          ),
          if (meals.isEmpty)
            const _EmptyMeals()
          else
            ...meals.map((meal) => _MealTile(meal: meal)),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'scan-recipe-ai',
            onPressed: _aiScanning ? null : () => _scanRecipeWithAi(context),
            icon: _aiScanning
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.document_scanner_outlined),
            label: const Text('Skanuj AI'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'add-recipe',
            onPressed: () => _openMealDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Dodaj przepis'),
          ),
        ],
      ),
    );
  }

  Future<void> _scanRecipeWithAi(BuildContext context) async {
    final appState = AppScope.of(context);
    if (!appState.backendConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Najpierw ustaw serwer synchronizacji.')),
      );
      return;
    }

    setState(() => _aiScanning = true);
    try {
      final RecipeImageScanResult? imageScan;
      final String? pastedText;
      if (recipeCameraScannerSupported) {
        imageScan = await scanRecipeFromCamera();
        pastedText = null;
      } else {
        imageScan = null;
        pastedText = await _openRecipeTextScanDialog(context);
      }
      if (!context.mounted ||
          (imageScan == null && (pastedText == null || pastedText.isEmpty))) {
        return;
      }

      final service = RecipeAiService(appState.serverUrl);
      try {
        final scanDraft = await service.scanRecipe(
          text: imageScan?.text ?? pastedText,
          imageData: imageScan?.imageData,
          imageMimeType: imageScan?.imageMimeType,
        );
        if (!context.mounted) {
          return;
        }
        await _openMealDialog(
          context,
          initialDraft: _RecipeDraft.fromScan(scanDraft),
        );
      } finally {
        service.dispose();
      }
    } on RecipeScanException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on RecipeAiException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nie udało się zeskanować przepisu: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _aiScanning = false);
      }
    }
  }
}

Future<String?> _openRecipeTextScanDialog(BuildContext context) async {
  final controller = TextEditingController();
  final value = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Wklej przepis'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: TextField(
          controller: controller,
          autofocus: true,
          minLines: 8,
          maxLines: 14,
          decoration: const InputDecoration(
            labelText: 'Tekst przepisu',
            hintText: 'Nazwa, składniki, porcje i przygotowanie',
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Anuluj'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text('Skanuj AI'),
        ),
      ],
    ),
  );
  controller.dispose();
  return value;
}

class _RecipeCategoryBar extends StatelessWidget {
  const _RecipeCategoryBar({
    required this.selectedCategory,
    required this.onChanged,
  });

  final String selectedCategory;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: recipeCategoryNames
            .map(
              (category) => FilterChip(
                selected: selectedCategory == category,
                label: Text(category),
                onSelected: (_) => onChanged(category),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _MealTile extends StatelessWidget {
  const _MealTile({required this.meal});

  final Meal meal;

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    final mainRecipe = appState.mainRecipeFor(meal);
    final subRecipes = mainRecipe == null
        ? <Recipe>[]
        : appState.subRecipesFor(mainRecipe);

    return Card(
      child: ExpansionTile(
        title: Text(
          meal.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: mainRecipe == null
            ? const Text('Brak przepisu głównego')
            : Text(
                '${mainRecipe.category} - ${mainRecipe.baseServings} porcje bazowe - ${_recipeNutritionText(mainRecipe)} - ${subRecipes.length} dodatków',
              ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          if (mainRecipe != null) ...[
            _RecipeDetails(recipe: mainRecipe),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => _openAddToShoppingDialog(
                    context,
                    mainRecipe: mainRecipe,
                    subRecipes: subRecipes,
                  ),
                  icon: const Icon(Icons.playlist_add),
                  label: const Text('Dodaj do listy zakupów'),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      _openRecipeDialog(context, recipe: mainRecipe),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edytuj przepis'),
                ),
                IconButton(
                  tooltip: 'Usuń przepis',
                  onPressed: () => _confirmDeleteMeal(context, meal),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const Divider(height: 28),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Dodatki / podprzepisy',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            if (subRecipes.isEmpty)
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Brak dodatków'),
              )
            else
              ...subRecipes.map((recipe) => _SubRecipeRow(recipe: recipe)),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _openSubRecipeDialog(
                  context,
                  meal: meal,
                  parentRecipe: mainRecipe,
                ),
                icon: const Icon(Icons.add),
                label: const Text('Dodaj podprzepis'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecipeDetails extends StatelessWidget {
  const _RecipeDetails({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    final ingredients = appState.ingredientsForRecipe(recipe.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                recipe.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            _SyncDot(status: recipe.syncStatus),
          ],
        ),
        Text(
          'Autor: ${appState.memberById(recipe.createdBy)?.name ?? 'Rodzina'} - ${recipe.category}',
          style: Theme.of(context).textTheme.labelMedium,
        ),
        if (recipe.caloriesPerServing > 0 || recipe.proteinPerServing > 0) ...[
          const SizedBox(height: 6),
          Text(
            _recipeNutritionText(recipe),
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: AppState.recipeCategories
              .map(
                (category) => ChoiceChip(
                  selected: recipe.category == category,
                  label: Text(category),
                  onSelected: recipe.category == category
                      ? null
                      : (_) => appState.updateRecipeCategory(
                          recipe: recipe,
                          category: category,
                        ),
                ),
              )
              .toList(),
        ),
        if (recipe.instructions.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(recipe.instructions),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: ingredients
              .map(
                (ingredient) => Chip(
                  label: Text(
                    '${ingredient.name}: ${formatQuantity(ingredient.quantity)} ${ingredient.unit}',
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _SubRecipeRow extends StatelessWidget {
  const _SubRecipeRow({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    final ingredientCount = appState.ingredientsForRecipe(recipe.id).length;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.rice_bowl_outlined),
      title: Text(recipe.name),
      subtitle: Text(
        '${recipe.category} - ${recipe.baseServings} porcje bazowe - ${_recipeNutritionText(recipe)} - $ingredientCount składników',
      ),
      trailing: Wrap(
        spacing: 2,
        children: [
          _SyncDot(status: recipe.syncStatus),
          IconButton(
            tooltip: 'Edytuj',
            onPressed: () => _openRecipeDialog(context, recipe: recipe),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Usuń',
            onPressed: () => appState.deleteRecipe(recipe),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

class _SyncDot extends StatelessWidget {
  const _SyncDot({required this.status});

  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    if (status == SyncStatus.synced) {
      return const SizedBox.shrink();
    }
    return Tooltip(
      message: status == SyncStatus.failed
          ? 'Nie udało się zsynchronizować'
          : 'Oczekuje na synchronizację',
      child: Icon(
        status == SyncStatus.failed
            ? Icons.cloud_off_outlined
            : Icons.schedule_outlined,
        size: 20,
        color: status == SyncStatus.failed
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.secondary,
      ),
    );
  }
}

class _EmptyMeals extends StatelessWidget {
  const _EmptyMeals();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.restaurant_menu_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'Nie ma jeszcze przepisów',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecipeDraft {
  const _RecipeDraft({
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

  factory _RecipeDraft.fromScan(RecipeScanDraft draft) {
    final category = AppState.recipeCategories.contains(draft.category)
        ? draft.category
        : AppState.defaultRecipeCategory;
    return _RecipeDraft(
      name: draft.name,
      category: category,
      instructions: draft.instructions,
      baseServings: draft.baseServings,
      caloriesPerServing: draft.caloriesPerServing,
      proteinPerServing: draft.proteinPerServing,
      fatPerServing: draft.fatPerServing,
      carbsPerServing: draft.carbsPerServing,
      ingredients: draft.ingredients,
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

class _RecipeDialog extends StatefulWidget {
  const _RecipeDialog({
    required this.title,
    this.recipe,
    this.initialDraft,
    this.initialIngredients,
  });

  final String title;
  final Recipe? recipe;
  final _RecipeDraft? initialDraft;
  final List<IngredientDraft>? initialIngredients;

  @override
  State<_RecipeDialog> createState() => _RecipeDialogState();
}

class _RecipeDialogState extends State<_RecipeDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late String _category;
  late final TextEditingController _instructionsController;
  late final TextEditingController _servingsController;
  late final TextEditingController _caloriesController;
  late final TextEditingController _proteinController;
  late final TextEditingController _fatController;
  late final TextEditingController _carbsController;
  late final List<_IngredientLineController> _ingredientLines;

  @override
  void initState() {
    super.initState();
    final recipe = widget.recipe;
    final initialDraft = widget.initialDraft;
    _nameController = TextEditingController(
      text: recipe?.name ?? initialDraft?.name ?? '',
    );
    _category = AppState.recipeCategories.contains(recipe?.category)
        ? recipe!.category
        : AppState.recipeCategories.contains(initialDraft?.category)
        ? initialDraft!.category
        : AppState.defaultRecipeCategory;
    _instructionsController = TextEditingController(
      text: recipe?.instructions ?? initialDraft?.instructions ?? '',
    );
    _servingsController = TextEditingController(
      text:
          recipe?.baseServings.toString() ??
          initialDraft?.baseServings.toString() ??
          '4',
    );
    _caloriesController = TextEditingController(
      text:
          recipe?.caloriesPerServing.toString() ??
          (initialDraft == null || initialDraft.caloriesPerServing == 0
              ? ''
              : initialDraft.caloriesPerServing.toString()),
    );
    _proteinController = TextEditingController(
      text: recipe != null && recipe.proteinPerServing > 0
          ? formatQuantity(recipe.proteinPerServing)
          : initialDraft != null && initialDraft.proteinPerServing > 0
          ? formatQuantity(initialDraft.proteinPerServing)
          : '',
    );
    _fatController = TextEditingController(
      text: recipe != null && recipe.fatPerServing > 0
          ? formatQuantity(recipe.fatPerServing)
          : initialDraft != null && initialDraft.fatPerServing > 0
          ? formatQuantity(initialDraft.fatPerServing)
          : '',
    );
    _carbsController = TextEditingController(
      text: recipe != null && recipe.carbsPerServing > 0
          ? formatQuantity(recipe.carbsPerServing)
          : initialDraft != null && initialDraft.carbsPerServing > 0
          ? formatQuantity(initialDraft.carbsPerServing)
          : '',
    );
    final initialIngredients =
        widget.initialIngredients ?? initialDraft?.ingredients ?? const [];
    _ingredientLines = initialIngredients.isEmpty
        ? [_IngredientLineController()]
        : initialIngredients
              .map((ingredient) => _IngredientLineController.from(ingredient))
              .toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _instructionsController.dispose();
    _servingsController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _fatController.dispose();
    _carbsController.dispose();
    for (final line in _ingredientLines) {
      line.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Nazwa'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Wpisz nazwę'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _category,
                  decoration: const InputDecoration(labelText: 'Kategoria'),
                  items: AppState.recipeCategories
                      .map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _category = value ?? _category),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _servingsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Liczba porcji bazowych',
                  ),
                  validator: (value) {
                    final parsed = int.tryParse(value ?? '') ?? 0;
                    return parsed <= 0 ? 'Podaj liczbę porcji' : null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _caloriesController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Kcal na porcję',
                          suffixText: 'kcal',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _proteinController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Białko na porcję',
                          suffixText: 'g',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _fatController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Tłuszcze na porcję',
                          suffixText: 'g',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _carbsController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Węglowodany na porcję',
                          suffixText: 'g',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _instructionsController,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Opis przygotowania',
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Składniki',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(height: 8),
                ...List.generate(
                  _ingredientLines.length,
                  (index) => _IngredientLineEditor(
                    line: _ingredientLines[index],
                    canRemove: _ingredientLines.length > 1,
                    onRemove: () => _removeIngredientLine(index),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _addIngredientLine,
                    icon: const Icon(Icons.add),
                    label: const Text('Dodaj składnik'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Anuluj'),
        ),
        FilledButton(onPressed: _save, child: const Text('Zapisz')),
      ],
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final ingredients = _ingredientLines
        .map((line) => line.toDraft())
        .whereType<IngredientDraft>()
        .toList();
    if (ingredients.isEmpty) {
      return;
    }
    Navigator.pop(
      context,
      _RecipeDraft(
        name: _nameController.text.trim(),
        category: _category,
        instructions: _instructionsController.text.trim(),
        baseServings: max(1, int.tryParse(_servingsController.text) ?? 1),
        caloriesPerServing: _parseInt(_caloriesController.text),
        proteinPerServing: _parseDouble(_proteinController.text),
        fatPerServing: _parseDouble(_fatController.text),
        carbsPerServing: _parseDouble(_carbsController.text),
        ingredients: ingredients,
      ),
    );
  }

  void _addIngredientLine() {
    setState(() {
      _ingredientLines.add(_IngredientLineController());
    });
  }

  void _removeIngredientLine(int index) {
    setState(() {
      final removed = _ingredientLines.removeAt(index);
      removed.dispose();
    });
  }
}

class _IngredientLineController {
  _IngredientLineController()
    : nameController = TextEditingController(),
      quantityController = TextEditingController(text: '1'),
      unitController = TextEditingController(text: 'szt.');

  _IngredientLineController.from(IngredientDraft ingredient)
    : nameController = TextEditingController(text: ingredient.name),
      quantityController = TextEditingController(
        text: formatQuantity(ingredient.quantity),
      ),
      unitController = TextEditingController(text: ingredient.unit);

  final TextEditingController nameController;
  final TextEditingController quantityController;
  final TextEditingController unitController;

  IngredientDraft? toDraft() {
    final name = nameController.text.trim();
    final quantity =
        double.tryParse(quantityController.text.replaceAll(',', '.')) ?? 0;
    if (name.isEmpty || quantity <= 0) {
      return null;
    }
    return IngredientDraft(
      name: name,
      quantity: quantity,
      unit: unitController.text.trim().isEmpty
          ? 'szt.'
          : unitController.text.trim(),
    );
  }

  void dispose() {
    nameController.dispose();
    quantityController.dispose();
    unitController.dispose();
  }
}

class _IngredientLineEditor extends StatelessWidget {
  const _IngredientLineEditor({
    required this.line,
    required this.canRemove,
    required this.onRemove,
  });

  final _IngredientLineController line;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5DDCE)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          TextFormField(
            controller: line.nameController,
            decoration: const InputDecoration(labelText: 'Składnik'),
            textInputAction: TextInputAction.next,
            validator: (value) =>
                value == null || value.trim().isEmpty ? 'Wpisz składnik' : null,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: line.quantityController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Ilość'),
                  validator: (value) {
                    final parsed =
                        double.tryParse((value ?? '').replaceAll(',', '.')) ??
                        0;
                    return parsed <= 0 ? 'Podaj ilość' : null;
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: line.unitController,
                  decoration: const InputDecoration(labelText: 'Jednostka'),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Usuń składnik',
                onPressed: canRemove ? onRemove : null,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddToShoppingDialog extends StatefulWidget {
  const _AddToShoppingDialog({
    required this.mainRecipe,
    required this.subRecipes,
  });

  final Recipe mainRecipe;
  final List<Recipe> subRecipes;

  @override
  State<_AddToShoppingDialog> createState() => _AddToShoppingDialogState();
}

class _AddToShoppingDialogState extends State<_AddToShoppingDialog> {
  late final TextEditingController _servingsController;
  bool _includeMain = true;
  late final Set<String> _selectedSubRecipes;
  final Set<String> _excludedIngredientKeys = {};
  String? _selectionError;

  @override
  void initState() {
    super.initState();
    _servingsController = TextEditingController(
      text: widget.mainRecipe.baseServings.toString(),
    );
    _selectedSubRecipes = widget.subRecipes.map((recipe) => recipe.id).toSet();
  }

  @override
  void dispose() {
    _servingsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    final servings = max(1, int.tryParse(_servingsController.text) ?? 1);
    final recipeIds = _selectedRecipeIds();
    final neededIngredients = _neededIngredients(
      appState: appState,
      recipeIds: recipeIds,
      servings: servings,
    );

    return AlertDialog(
      title: const Text('Dodaj do listy zakupów'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _servingsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Liczba porcji'),
                onChanged: (_) => setState(() => _selectionError = null),
              ),
              const SizedBox(height: 12),
              if (widget.subRecipes.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _includeMain = true;
                            _selectedSubRecipes.clear();
                            _selectionError = null;
                          });
                        },
                        icon: const Icon(Icons.restaurant_outlined),
                        label: const Text('Tylko główny'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () {
                          setState(() {
                            _includeMain = true;
                            _selectedSubRecipes
                              ..clear()
                              ..addAll(
                                widget.subRecipes.map((recipe) => recipe.id),
                              );
                            _selectionError = null;
                          });
                        },
                        icon: const Icon(Icons.done_all),
                        label: const Text('Cały obiad'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _includeMain,
                onChanged: (value) => setState(() {
                  _includeMain = value ?? true;
                  _selectionError = null;
                }),
                title: Text(widget.mainRecipe.name),
                subtitle: const Text('Przepis główny'),
              ),
              const Divider(),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Dodatki / podprzepisy',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(height: 4),
              if (widget.subRecipes.isEmpty)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Brak dodatków'),
                )
              else
                ...widget.subRecipes.map(
                  (recipe) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _selectedSubRecipes.contains(recipe.id),
                    onChanged: (value) {
                      setState(() {
                        if (value ?? false) {
                          _selectedSubRecipes.add(recipe.id);
                        } else {
                          _selectedSubRecipes.remove(recipe.id);
                        }
                        _selectionError = null;
                      });
                    },
                    title: Text(recipe.name),
                  ),
                ),
              const Divider(),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Zaznacz składniki, których nie chcesz dodawać',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(height: 4),
              if (neededIngredients.isEmpty)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Brak składników do dodania'),
                )
              else
                ...neededIngredients.map((ingredient) {
                  final key = _ingredientKey(ingredient);
                  return CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _excludedIngredientKeys.contains(key),
                    onChanged: (value) {
                      setState(() {
                        if (value ?? false) {
                          _excludedIngredientKeys.add(key);
                        } else {
                          _excludedIngredientKeys.remove(key);
                        }
                        _selectionError = null;
                      });
                    },
                    title: Text(ingredient.name),
                    subtitle: Text(
                      '${formatQuantity(ingredient.quantity)} ${ingredient.unit}',
                    ),
                  );
                }),
              if (_selectionError != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _selectionError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Anuluj'),
        ),
        FilledButton(onPressed: _save, child: const Text('Dodaj')),
      ],
    );
  }

  void _save() {
    final recipeIds = _selectedRecipeIds();
    if (recipeIds.isEmpty) {
      setState(() {
        _selectionError = 'Wybierz przepis albo dodatek';
      });
      return;
    }
    final servings = max(1, int.tryParse(_servingsController.text) ?? 1);
    final ingredientsToAdd =
        _neededIngredients(
              appState: AppScope.of(context),
              recipeIds: recipeIds,
              servings: servings,
            )
            .where(
              (ingredient) =>
                  !_excludedIngredientKeys.contains(_ingredientKey(ingredient)),
            )
            .toList();
    if (ingredientsToAdd.isEmpty) {
      setState(() {
        _selectionError = 'Wszystkie składniki są zaznaczone do pominięcia';
      });
      return;
    }
    Navigator.pop(context, ingredientsToAdd);
  }

  List<String> _selectedRecipeIds() {
    return [if (_includeMain) widget.mainRecipe.id, ..._selectedSubRecipes];
  }

  List<IngredientDraft> _neededIngredients({
    required AppState appState,
    required List<String> recipeIds,
    required int servings,
  }) {
    final selectedRecipes = appState.data.activeRecipes
        .where((recipe) => recipeIds.contains(recipe.id))
        .toList();
    final scaledIngredients = <IngredientDraft>[];
    for (final recipe in selectedRecipes) {
      final factor = servings / max(1, recipe.baseServings);
      for (final ingredient in appState.ingredientsForRecipe(recipe.id)) {
        scaledIngredients.add(
          IngredientDraft(
            name: ingredient.name,
            quantity: ingredient.quantity * factor,
            unit: ingredient.unit,
          ),
        );
      }
    }
    return mergeIngredientDrafts(scaledIngredients);
  }
}

Future<void> _openMealDialog(
  BuildContext context, {
  _RecipeDraft? initialDraft,
}) async {
  final draft = await showDialog<_RecipeDraft>(
    context: context,
    builder: (_) =>
        _RecipeDialog(title: 'Nowy obiad', initialDraft: initialDraft),
  );
  if (draft == null || !context.mounted) {
    return;
  }
  await AppScope.of(context).addMealWithRecipe(
    mealName: draft.name,
    category: draft.category,
    instructions: draft.instructions,
    baseServings: draft.baseServings,
    caloriesPerServing: draft.caloriesPerServing,
    proteinPerServing: draft.proteinPerServing,
    fatPerServing: draft.fatPerServing,
    carbsPerServing: draft.carbsPerServing,
    ingredients: draft.ingredients,
  );
}

Future<void> _openRecipeDialog(
  BuildContext context, {
  required Recipe recipe,
}) async {
  final appState = AppScope.of(context);
  final draft = await showDialog<_RecipeDraft>(
    context: context,
    builder: (_) => _RecipeDialog(
      title: recipe.isSubRecipe ? 'Edytuj podprzepis' : 'Edytuj przepis',
      recipe: recipe,
      initialIngredients: appState
          .ingredientsForRecipe(recipe.id)
          .map(
            (ingredient) => IngredientDraft(
              name: ingredient.name,
              quantity: ingredient.quantity,
              unit: ingredient.unit,
            ),
          )
          .toList(),
    ),
  );
  if (draft == null || !context.mounted) {
    return;
  }
  await AppScope.of(context).updateRecipe(
    recipe: recipe,
    name: draft.name,
    category: draft.category,
    instructions: draft.instructions,
    baseServings: draft.baseServings,
    caloriesPerServing: draft.caloriesPerServing,
    proteinPerServing: draft.proteinPerServing,
    fatPerServing: draft.fatPerServing,
    carbsPerServing: draft.carbsPerServing,
    ingredients: draft.ingredients,
  );
}

Future<void> _openSubRecipeDialog(
  BuildContext context, {
  required Meal meal,
  required Recipe parentRecipe,
}) async {
  final draft = await showDialog<_RecipeDraft>(
    context: context,
    builder: (_) => const _RecipeDialog(title: 'Nowy podprzepis'),
  );
  if (draft == null || !context.mounted) {
    return;
  }
  await AppScope.of(context).addSubRecipe(
    meal: meal,
    parentRecipe: parentRecipe,
    name: draft.name,
    category: draft.category,
    instructions: draft.instructions,
    baseServings: draft.baseServings,
    caloriesPerServing: draft.caloriesPerServing,
    proteinPerServing: draft.proteinPerServing,
    fatPerServing: draft.fatPerServing,
    carbsPerServing: draft.carbsPerServing,
    ingredients: draft.ingredients,
  );
}

Future<void> _openAddToShoppingDialog(
  BuildContext context, {
  required Recipe mainRecipe,
  required List<Recipe> subRecipes,
}) async {
  final ingredientsToAdd = await showDialog<List<IngredientDraft>>(
    context: context,
    builder: (_) =>
        _AddToShoppingDialog(mainRecipe: mainRecipe, subRecipes: subRecipes),
  );
  if (ingredientsToAdd == null ||
      !context.mounted ||
      ingredientsToAdd.isEmpty) {
    return;
  }
  await AppScope.of(context).addIngredientsToShoppingList(ingredientsToAdd);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Składniki dodane do listy zakupów')),
    );
  }
}

Future<void> _confirmDeleteMeal(BuildContext context, Meal meal) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Usunąć przepis?'),
      content: Text('Przepis "${meal.name}" zostanie ukryty z listy.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Anuluj'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Usuń'),
        ),
      ],
    ),
  );
  if (confirmed == true && context.mounted) {
    await AppScope.of(context).deleteMeal(meal);
  }
}

const recipeCategoryNames = ['Wszystkie', ...AppState.recipeCategories];

String _recipeNutritionText(Recipe recipe) {
  return '${recipe.caloriesPerServing} kcal / '
      '${formatQuantity(recipe.proteinPerServing)} g białka / '
      '${formatQuantity(recipe.fatPerServing)} g tł. / '
      '${formatQuantity(recipe.carbsPerServing)} g węgli na porcję';
}

int _parseInt(String value) {
  return int.tryParse(value.trim().replaceAll(',', '.')) ?? 0;
}

double _parseDouble(String value) {
  return double.tryParse(value.trim().replaceAll(',', '.')) ?? 0;
}

String _ingredientKey(IngredientDraft ingredient) {
  return '${normalizeName(ingredient.name)}|${normalizeName(normalizeIngredientUnit(ingredient.unit))}';
}

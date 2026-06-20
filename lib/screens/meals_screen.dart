import 'dart:math';

import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../models/entities.dart';
import '../models/ingredient_draft.dart';
import '../utils/ingredient_parser.dart';

class MealsScreen extends StatelessWidget {
  const MealsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    final meals = [...appState.data.activeMeals]
      ..sort((a, b) => a.name.compareTo(b.name));

    return Scaffold(
      body: meals.isEmpty
          ? const _EmptyMeals()
          : ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 96),
              itemCount: meals.length,
              itemBuilder: (context, index) => _MealTile(meal: meals[index]),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openMealDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Dodaj obiad'),
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
                '${mainRecipe.baseServings} porcje bazowe • ${subRecipes.length} dodatków',
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
                  tooltip: 'Usuń obiad',
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
        '${recipe.baseServings} porcje bazowe • $ingredientCount składników',
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
              'Nie ma jeszcze obiadów',
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
    required this.instructions,
    required this.baseServings,
    required this.ingredients,
  });

  final String name;
  final String instructions;
  final int baseServings;
  final List<IngredientDraft> ingredients;
}

class _RecipeDialog extends StatefulWidget {
  const _RecipeDialog({
    required this.title,
    this.recipe,
    this.initialIngredients,
  });

  final String title;
  final Recipe? recipe;
  final String? initialIngredients;

  @override
  State<_RecipeDialog> createState() => _RecipeDialogState();
}

class _RecipeDialogState extends State<_RecipeDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _instructionsController;
  late final TextEditingController _servingsController;
  late final TextEditingController _ingredientsController;
  late List<IngredientDraft> _parsedIngredients;

  @override
  void initState() {
    super.initState();
    final recipe = widget.recipe;
    _nameController = TextEditingController(text: recipe?.name ?? '');
    _instructionsController = TextEditingController(
      text: recipe?.instructions ?? '',
    );
    _servingsController = TextEditingController(
      text: recipe?.baseServings.toString() ?? '4',
    );
    _ingredientsController = TextEditingController(
      text: widget.initialIngredients ?? '',
    );
    _parsedIngredients = parseIngredientLines(_ingredientsController.text);
    _ingredientsController.addListener(_refreshParsedIngredients);
  }

  @override
  void dispose() {
    _ingredientsController.removeListener(_refreshParsedIngredients);
    _nameController.dispose();
    _instructionsController.dispose();
    _servingsController.dispose();
    _ingredientsController.dispose();
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
                TextFormField(
                  controller: _instructionsController,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Opis przygotowania',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _ingredientsController,
                  minLines: 5,
                  maxLines: 9,
                  keyboardType: TextInputType.multiline,
                  decoration: const InputDecoration(
                    labelText: 'Składniki',
                    hintText: 'marchew 200 g\n2 jajka\nryż; 1; szklanka',
                  ),
                  validator: (value) =>
                      parseIngredientLines(value ?? '').isEmpty
                      ? 'Dodaj przynajmniej jeden składnik'
                      : null,
                ),
                const SizedBox(height: 8),
                _IngredientPreview(ingredients: _parsedIngredients),
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
    final ingredients = parseIngredientLines(_ingredientsController.text);
    Navigator.pop(
      context,
      _RecipeDraft(
        name: _nameController.text.trim(),
        instructions: _instructionsController.text.trim(),
        baseServings: max(1, int.tryParse(_servingsController.text) ?? 1),
        ingredients: ingredients,
      ),
    );
  }

  void _refreshParsedIngredients() {
    setState(() {
      _parsedIngredients = parseIngredientLines(_ingredientsController.text);
    });
  }
}

class _IngredientPreview extends StatelessWidget {
  const _IngredientPreview({required this.ingredients});

  final List<IngredientDraft> ingredients;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    if (ingredients.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Wpisz każdy składnik w osobnej linii',
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: ingredients
            .map(
              (ingredient) => InputChip(
                avatar: const Icon(Icons.check, size: 16),
                label: Text(
                  '${ingredient.name}: ${formatQuantity(ingredient.quantity)} ${ingredient.unit}',
                ),
              ),
            )
            .toList(),
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
    return AlertDialog(
      title: const Text('Dodaj do listy zakupów'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _servingsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Liczba porcji'),
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
    final recipeIds = <String>[
      if (_includeMain) widget.mainRecipe.id,
      ..._selectedSubRecipes,
    ];
    if (recipeIds.isEmpty) {
      setState(() {
        _selectionError = 'Wybierz przepis albo dodatek';
      });
      return;
    }
    final servings = max(1, int.tryParse(_servingsController.text) ?? 1);
    Navigator.pop(context, (recipeIds: recipeIds, servings: servings));
  }
}

Future<void> _openMealDialog(BuildContext context) async {
  final draft = await showDialog<_RecipeDraft>(
    context: context,
    builder: (_) => const _RecipeDialog(title: 'Nowy obiad'),
  );
  if (draft == null || !context.mounted) {
    return;
  }
  await AppScope.of(context).addMealWithRecipe(
    mealName: draft.name,
    instructions: draft.instructions,
    baseServings: draft.baseServings,
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
      initialIngredients: recipeIngredientsToText(
        appState.ingredientsForRecipe(recipe.id),
      ),
    ),
  );
  if (draft == null || !context.mounted) {
    return;
  }
  await AppScope.of(context).updateRecipe(
    recipe: recipe,
    name: draft.name,
    instructions: draft.instructions,
    baseServings: draft.baseServings,
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
    instructions: draft.instructions,
    baseServings: draft.baseServings,
    ingredients: draft.ingredients,
  );
}

Future<void> _openAddToShoppingDialog(
  BuildContext context, {
  required Recipe mainRecipe,
  required List<Recipe> subRecipes,
}) async {
  final result = await showDialog<({List<String> recipeIds, int servings})>(
    context: context,
    builder: (_) =>
        _AddToShoppingDialog(mainRecipe: mainRecipe, subRecipes: subRecipes),
  );
  if (result == null || !context.mounted || result.recipeIds.isEmpty) {
    return;
  }
  await AppScope.of(context).addRecipesToShoppingList(
    recipeIds: result.recipeIds,
    servings: result.servings,
  );
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
      title: const Text('Usunąć obiad?'),
      content: Text('Obiad „${meal.name}” zostanie ukryty z listy.'),
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

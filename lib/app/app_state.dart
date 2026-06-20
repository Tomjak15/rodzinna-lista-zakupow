import 'dart:async';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../config/backend_config.dart';
import '../data/local_store.dart';
import '../data/sync_service.dart';
import '../models/entities.dart';
import '../models/ingredient_draft.dart';
import '../utils/ingredient_parser.dart';

class AppState extends ChangeNotifier {
  AppState({required LocalStore store}) : _store = store;

  final LocalStore _store;
  SyncService? _syncService;
  final _connectivity = Connectivity();
  final _uuid = const Uuid();
  final _random = Random();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _periodicSyncTimer;
  Timer? _syncDebounce;

  AppData _data = AppData.empty();
  bool _initialized = false;
  bool _online = true;
  bool _syncing = false;
  DateTime? _lastSyncAt;
  String? _lastSyncError;
  String _serverUrl = BackendConfig.normalizedServerUrl;

  AppData get data => _data;
  bool get initialized => _initialized;
  bool get hasFamily => _data.family != null && !_data.family!.isDeleted;
  bool get online => _online;
  bool get syncing => _syncing;
  bool get backendConfigured => _syncService != null;
  String get serverUrl => _serverUrl;
  DateTime? get lastSyncAt => _lastSyncAt;
  String? get lastSyncError => _lastSyncError;
  int get pendingCount => _data.pendingCount;

  Future<void> initialize() async {
    _data = await _store.loadAll();
    _serverUrl = _normalizeServerUrl(
      _store.loadServerUrl() ?? BackendConfig.normalizedServerUrl,
    );
    _rebuildSyncService();
    _lastSyncAt = _store.loadLastSyncAt();
    _online = _isOnline(await _connectivity.checkConnectivity());
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      result,
    ) {
      final wasOffline = !_online;
      _online = _isOnline(result);
      notifyListeners();
      if (wasOffline && _online) {
        unawaited(syncNow());
      }
    });
    _periodicSyncTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (_online) {
        unawaited(syncNow());
      }
    });
    _initialized = true;
    notifyListeners();
    if (_online) {
      unawaited(syncNow());
    }
  }

  Future<void> createFamily({
    required String familyName,
    required String memberName,
    String? email,
    String? phone,
    String? avatar,
  }) async {
    final now = DateTime.now().toUtc();
    final memberId = _uuid.v4();
    final familyId = _uuid.v4();
    final family = Family(
      id: familyId,
      familyId: familyId,
      name: familyName.trim(),
      code: _generateFamilyCode(),
      createdAt: now,
      updatedAt: now,
      createdBy: memberId,
      isDeleted: false,
      syncStatus: SyncStatus.pending,
      createOnSync: true,
    );
    final member = Member(
      id: memberId,
      familyId: familyId,
      name: memberName.trim(),
      email: nullableString(email),
      phone: nullableString(phone),
      avatar: nullableString(avatar),
      createdAt: now,
      updatedAt: now,
      createdBy: memberId,
      isDeleted: false,
      syncStatus: SyncStatus.pending,
    );
    _data = AppData.empty().copyWith(
      family: family,
      currentMember: member,
      members: [member],
    );
    await _persist(scheduleSync: true);
  }

  Future<void> joinFamily({
    required String code,
    required String memberName,
    String? email,
    String? phone,
    String? avatar,
  }) async {
    final now = DateTime.now().toUtc();
    final normalizedCode = code.trim().toUpperCase();
    final memberId = _uuid.v4();
    final temporaryFamilyId = _uuid.v4();
    final family = Family(
      id: temporaryFamilyId,
      familyId: temporaryFamilyId,
      name: 'Rodzina $normalizedCode',
      code: normalizedCode,
      createdAt: now,
      updatedAt: now,
      createdBy: memberId,
      isDeleted: false,
      syncStatus: SyncStatus.pending,
      createOnSync: false,
    );
    final member = Member(
      id: memberId,
      familyId: temporaryFamilyId,
      name: memberName.trim(),
      email: nullableString(email),
      phone: nullableString(phone),
      avatar: nullableString(avatar),
      createdAt: now,
      updatedAt: now,
      createdBy: memberId,
      isDeleted: false,
      syncStatus: SyncStatus.pending,
    );
    _data = AppData.empty().copyWith(
      family: family,
      currentMember: member,
      members: [member],
    );
    await _persist(scheduleSync: true);
  }

  Future<void> addShoppingItem({
    required String name,
    required double quantity,
    required String unit,
  }) async {
    final now = DateTime.now().toUtc();
    _mergeShoppingItem(name: name, quantity: quantity, unit: unit, now: now);
    await _persist(scheduleSync: true);
  }

  Future<void> updateShoppingItem({
    required ShoppingItem item,
    required String name,
    required double quantity,
    required String unit,
  }) async {
    final now = DateTime.now().toUtc();
    _data = _data.copyWith(
      shoppingItems: _data.shoppingItems
          .map(
            (entry) => entry.id == item.id
                ? entry.copyWith(
                    name: name.trim(),
                    quantity: quantity,
                    unit: normalizeIngredientUnit(unit),
                    updatedAt: now,
                    syncStatus: SyncStatus.pending,
                  )
                : entry,
          )
          .toList(),
    );
    await _persist(scheduleSync: true);
  }

  Future<void> toggleShoppingItem(ShoppingItem item) async {
    final now = DateTime.now().toUtc();
    _data = _data.copyWith(
      shoppingItems: _data.shoppingItems
          .map(
            (entry) => entry.id == item.id
                ? entry.copyWith(
                    isPurchased: !entry.isPurchased,
                    updatedAt: now,
                    syncStatus: SyncStatus.pending,
                  )
                : entry,
          )
          .toList(),
    );
    await _persist(scheduleSync: true);
  }

  Future<void> deleteShoppingItem(ShoppingItem item) async {
    final now = DateTime.now().toUtc();
    _data = _data.copyWith(
      shoppingItems: _data.shoppingItems
          .map(
            (entry) => entry.id == item.id
                ? entry.copyWith(
                    isDeleted: true,
                    updatedAt: now,
                    syncStatus: SyncStatus.pending,
                  )
                : entry,
          )
          .toList(),
    );
    await _persist(scheduleSync: true);
  }

  Future<void> addMealWithRecipe({
    required String mealName,
    required String instructions,
    required int baseServings,
    required List<IngredientDraft> ingredients,
  }) async {
    final family = _data.family;
    final member = _data.currentMember;
    if (family == null || member == null) {
      return;
    }
    final now = DateTime.now().toUtc();
    final mealId = _uuid.v4();
    final recipeId = _uuid.v4();
    final meal = Meal(
      id: mealId,
      familyId: family.id,
      name: mealName.trim(),
      createdAt: now,
      updatedAt: now,
      createdBy: member.id,
      isDeleted: false,
      syncStatus: SyncStatus.pending,
    );
    final recipe = Recipe(
      id: recipeId,
      familyId: family.id,
      mealId: mealId,
      parentRecipeId: null,
      name: mealName.trim(),
      instructions: instructions.trim(),
      baseServings: max(1, baseServings),
      createdAt: now,
      updatedAt: now,
      createdBy: member.id,
      isDeleted: false,
      syncStatus: SyncStatus.pending,
    );
    _data = _data.copyWith(
      meals: [..._data.meals, meal],
      recipes: [..._data.recipes, recipe],
      recipeIngredients: [
        ..._data.recipeIngredients,
        ..._ingredientEntities(recipeId, ingredients, now),
      ],
    );
    await _persist(scheduleSync: true);
  }

  Future<void> addSubRecipe({
    required Meal meal,
    required Recipe parentRecipe,
    required String name,
    required String instructions,
    required int baseServings,
    required List<IngredientDraft> ingredients,
  }) async {
    final family = _data.family;
    final member = _data.currentMember;
    if (family == null || member == null) {
      return;
    }
    final now = DateTime.now().toUtc();
    final recipeId = _uuid.v4();
    final recipe = Recipe(
      id: recipeId,
      familyId: family.id,
      mealId: meal.id,
      parentRecipeId: parentRecipe.id,
      name: name.trim(),
      instructions: instructions.trim(),
      baseServings: max(1, baseServings),
      createdAt: now,
      updatedAt: now,
      createdBy: member.id,
      isDeleted: false,
      syncStatus: SyncStatus.pending,
    );
    _data = _data.copyWith(
      recipes: [..._data.recipes, recipe],
      recipeIngredients: [
        ..._data.recipeIngredients,
        ..._ingredientEntities(recipeId, ingredients, now),
      ],
    );
    await _persist(scheduleSync: true);
  }

  Future<void> updateRecipe({
    required Recipe recipe,
    required String name,
    required String instructions,
    required int baseServings,
    required List<IngredientDraft> ingredients,
  }) async {
    final now = DateTime.now().toUtc();
    final updatedRecipes = _data.recipes
        .map(
          (entry) => entry.id == recipe.id
              ? entry.copyWith(
                  name: name.trim(),
                  instructions: instructions.trim(),
                  baseServings: max(1, baseServings),
                  updatedAt: now,
                  syncStatus: SyncStatus.pending,
                )
              : entry,
        )
        .toList();
    final updatedMeals = recipe.parentRecipeId == null
        ? _data.meals
              .map(
                (meal) => meal.id == recipe.mealId
                    ? meal.copyWith(
                        name: name.trim(),
                        updatedAt: now,
                        syncStatus: SyncStatus.pending,
                      )
                    : meal,
              )
              .toList()
        : _data.meals;

    final hiddenOldIngredients = _data.recipeIngredients
        .map(
          (entry) => entry.recipeId == recipe.id && !entry.isDeleted
              ? entry.copyWith(
                  isDeleted: true,
                  updatedAt: now,
                  syncStatus: SyncStatus.pending,
                )
              : entry,
        )
        .toList();

    _data = _data.copyWith(
      meals: updatedMeals,
      recipes: updatedRecipes,
      recipeIngredients: [
        ...hiddenOldIngredients,
        ..._ingredientEntities(recipe.id, ingredients, now),
      ],
    );
    await _persist(scheduleSync: true);
  }

  Future<void> deleteRecipe(Recipe recipe) async {
    final now = DateTime.now().toUtc();
    _data = _data.copyWith(
      recipes: _data.recipes
          .map(
            (entry) => entry.id == recipe.id
                ? entry.copyWith(
                    isDeleted: true,
                    updatedAt: now,
                    syncStatus: SyncStatus.pending,
                  )
                : entry,
          )
          .toList(),
      recipeIngredients: _data.recipeIngredients
          .map(
            (entry) => entry.recipeId == recipe.id
                ? entry.copyWith(
                    isDeleted: true,
                    updatedAt: now,
                    syncStatus: SyncStatus.pending,
                  )
                : entry,
          )
          .toList(),
    );
    await _persist(scheduleSync: true);
  }

  Future<void> deleteMeal(Meal meal) async {
    final now = DateTime.now().toUtc();
    final recipeIds = _data.recipes
        .where((recipe) => recipe.mealId == meal.id)
        .map((recipe) => recipe.id)
        .toSet();
    _data = _data.copyWith(
      meals: _data.meals
          .map(
            (entry) => entry.id == meal.id
                ? entry.copyWith(
                    isDeleted: true,
                    updatedAt: now,
                    syncStatus: SyncStatus.pending,
                  )
                : entry,
          )
          .toList(),
      recipes: _data.recipes
          .map(
            (entry) => entry.mealId == meal.id
                ? entry.copyWith(
                    isDeleted: true,
                    updatedAt: now,
                    syncStatus: SyncStatus.pending,
                  )
                : entry,
          )
          .toList(),
      recipeIngredients: _data.recipeIngredients
          .map(
            (entry) => recipeIds.contains(entry.recipeId)
                ? entry.copyWith(
                    isDeleted: true,
                    updatedAt: now,
                    syncStatus: SyncStatus.pending,
                  )
                : entry,
          )
          .toList(),
    );
    await _persist(scheduleSync: true);
  }

  Future<void> addRecipesToShoppingList({
    required List<String> recipeIds,
    required int servings,
  }) async {
    final selectedRecipes = _data.activeRecipes
        .where((recipe) => recipeIds.contains(recipe.id))
        .toList();
    if (selectedRecipes.isEmpty) {
      return;
    }

    final scaledIngredients = <IngredientDraft>[];
    for (final recipe in selectedRecipes) {
      final factor = servings / max(1, recipe.baseServings);
      for (final ingredient in ingredientsForRecipe(recipe.id)) {
        scaledIngredients.add(
          IngredientDraft(
            name: ingredient.name,
            quantity: ingredient.quantity * factor,
            unit: ingredient.unit,
          ),
        );
      }
    }

    final groupedIngredients = mergeIngredientDrafts(scaledIngredients);
    if (groupedIngredients.isEmpty) {
      return;
    }

    final now = DateTime.now().toUtc();
    for (final item in groupedIngredients) {
      _mergeShoppingItem(
        name: item.name,
        quantity: item.quantity,
        unit: item.unit,
        now: now,
      );
    }
    await _persist(scheduleSync: true);
  }

  Recipe? mainRecipeFor(Meal meal) {
    for (final recipe in _data.activeRecipes) {
      if (recipe.mealId == meal.id && recipe.parentRecipeId == null) {
        return recipe;
      }
    }
    return null;
  }

  List<Recipe> subRecipesFor(Recipe parentRecipe) {
    return _data.activeRecipes
        .where((recipe) => recipe.parentRecipeId == parentRecipe.id)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  List<RecipeIngredient> ingredientsForRecipe(String recipeId) {
    return _data.activeRecipeIngredients
        .where((ingredient) => ingredient.recipeId == recipeId)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<void> syncNow() async {
    final syncService = _syncService;
    if (_syncing || syncService == null || !_online || _data.family == null) {
      if (syncService == null) {
        _lastSyncError = 'Serwer synchronizacji nie jest skonfigurowany.';
      }
      notifyListeners();
      return;
    }

    _syncing = true;
    _lastSyncError = null;
    notifyListeners();
    try {
      _data = await syncService.sync(_data);
      _lastSyncAt = DateTime.now();
      await _store.saveAll(_data);
      await _store.saveLastSyncAt(_lastSyncAt!);
    } catch (error) {
      _lastSyncError = error.toString();
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  Future<void> updateServerUrl(String value) async {
    _serverUrl = _normalizeServerUrl(value);
    _rebuildSyncService();
    _lastSyncError = null;
    await _store.saveServerUrl(_serverUrl);
    notifyListeners();
    if (_online && _syncService != null) {
      unawaited(syncNow());
    }
  }

  Future<void> resetLocalData() async {
    _data = AppData.empty();
    _lastSyncAt = null;
    _lastSyncError = null;
    _serverUrl = BackendConfig.normalizedServerUrl;
    _rebuildSyncService();
    await _store.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _periodicSyncTimer?.cancel();
    _syncDebounce?.cancel();
    _syncService?.dispose();
    super.dispose();
  }

  List<RecipeIngredient> _ingredientEntities(
    String recipeId,
    List<IngredientDraft> ingredients,
    DateTime now,
  ) {
    final family = _data.family;
    final member = _data.currentMember;
    if (family == null || member == null) {
      return [];
    }
    return mergeIngredientDrafts(ingredients)
        .where((item) => item.name.trim().isNotEmpty && item.quantity > 0)
        .map(
          (item) => RecipeIngredient(
            id: _uuid.v4(),
            familyId: family.id,
            recipeId: recipeId,
            name: item.name.trim(),
            quantity: item.quantity,
            unit: normalizeIngredientUnit(item.unit),
            createdAt: now,
            updatedAt: now,
            createdBy: member.id,
            isDeleted: false,
            syncStatus: SyncStatus.pending,
          ),
        )
        .toList();
  }

  void _mergeShoppingItem({
    required String name,
    required double quantity,
    required String unit,
    required DateTime now,
  }) {
    final family = _data.family;
    final member = _data.currentMember;
    if (family == null ||
        member == null ||
        name.trim().isEmpty ||
        quantity <= 0) {
      return;
    }

    final cleanUnit = normalizeIngredientUnit(unit);
    final existingIndex = _data.shoppingItems.indexWhere(
      (item) =>
          !item.isDeleted &&
          normalizeName(item.name) == normalizeName(name) &&
          normalizeName(item.unit) == normalizeName(cleanUnit),
    );

    if (existingIndex != -1) {
      final updated = [..._data.shoppingItems];
      final existing = updated[existingIndex];
      updated[existingIndex] = existing.copyWith(
        quantity: existing.quantity + quantity,
        isPurchased: false,
        authorName: member.name,
        updatedAt: now,
        syncStatus: SyncStatus.pending,
      );
      _data = _data.copyWith(shoppingItems: updated);
      return;
    }

    _data = _data.copyWith(
      shoppingItems: [
        ..._data.shoppingItems,
        ShoppingItem(
          id: _uuid.v4(),
          familyId: family.id,
          name: name.trim(),
          quantity: quantity,
          unit: cleanUnit,
          authorName: member.name,
          isPurchased: false,
          createdAt: now,
          updatedAt: now,
          createdBy: member.id,
          isDeleted: false,
          syncStatus: SyncStatus.pending,
        ),
      ],
    );
  }

  Future<void> _persist({required bool scheduleSync}) async {
    await _store.saveAll(_data);
    notifyListeners();
    if (scheduleSync) {
      _scheduleSync();
    }
  }

  void _scheduleSync() {
    _syncDebounce?.cancel();
    _syncDebounce = Timer(const Duration(milliseconds: 600), () {
      unawaited(syncNow());
    });
  }

  bool _isOnline(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }

  void _rebuildSyncService() {
    _syncService?.dispose();
    _syncService = _serverUrl.startsWith('http')
        ? SyncService(_serverUrl)
        : null;
  }

  String _normalizeServerUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  String _generateFamilyCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(6, (_) => chars[_random.nextInt(chars.length)]).join();
  }
}

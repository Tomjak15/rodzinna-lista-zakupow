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

class AppActionException implements Exception {
  const AppActionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AppState extends ChangeNotifier {
  AppState({required LocalStore store}) : _store = store;

  static const _continuousSyncInterval = Duration(seconds: 8);
  static const recipeMealCategories = [
    'Śniadania',
    'Obiady',
    'Kolacje',
    'Przekąski',
    'Desery',
    'Napoje',
  ];
  static const recipeOwnerCategories = ['Anna', 'Kaja', 'Maciej', 'Tomek'];
  static const recipeCategories = [
    ...recipeMealCategories,
    ...recipeOwnerCategories,
  ];
  static const defaultRecipeCategory = 'Obiady';
  static const _legacyBrokenServerUrls = {
    'https://rodzinna-lista-zakupow--tomjak15.replit.app',
    'https://breezy-rivers-remain.loca.lt',
    'https://travel-authentication-measured-income.trycloudflare.com',
    'https://create-anonymous-nickel-researchers.trycloudflare.com',
    'https://15d2bff4298c6914-83-21-102-8.serveousercontent.com',
  };

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
  bool get hasFamily =>
      _data.family != null &&
      !_data.family!.isDeleted &&
      _data.currentMember != null &&
      !_data.currentMember!.isDeleted;
  bool get online => _online;
  bool get syncing => _syncing;
  bool get backendConfigured => _syncService != null;
  String get serverUrl => _serverUrl;
  DateTime? get lastSyncAt => _lastSyncAt;
  String? get lastSyncError => _lastSyncError;
  int get pendingCount => _data.pendingCount;
  bool get isFamilyCreator =>
      _data.family != null &&
      _data.currentMember != null &&
      _data.family!.createdBy == _data.currentMember!.id;

  Future<void> initialize() async {
    _data = await _store.loadAll();
    final storedServerUrl = _normalizeServerUrl(_store.loadServerUrl() ?? '');
    _serverUrl = _normalizeServerUrl(
      storedServerUrl.isEmpty || _isLegacyBrokenServerUrl(storedServerUrl)
          ? BackendConfig.normalizedServerUrl
          : storedServerUrl,
    );
    if (storedServerUrl.isNotEmpty &&
        storedServerUrl != _serverUrl &&
        _isLegacyBrokenServerUrl(storedServerUrl)) {
      await _store.saveServerUrl(_serverUrl);
    }
    final dataServerUrl = _normalizeServerUrl(_store.loadDataServerUrl() ?? '');
    if (_shouldResyncAfterServerChange(dataServerUrl)) {
      _data = _dataMarkedPendingForServerChange(_data);
      await _store.saveAll(_data);
      await _store.saveDataServerUrl(_serverUrl);
    }
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
    _periodicSyncTimer = Timer.periodic(_continuousSyncInterval, (_) {
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
    final draftData = AppData.empty().copyWith(
      family: family,
      currentMember: member,
      members: [member],
    );
    final syncService = _syncService;
    if (syncService != null && _online) {
      try {
        final syncedData = await syncService.sync(draftData);
        if (syncedData.family?.syncStatus != SyncStatus.synced ||
            syncedData.currentMember?.syncStatus != SyncStatus.synced) {
          throw const AppActionException(
            'Serwer nie potwierdził utworzenia rodziny.',
          );
        }
        await _replaceAfterRemoteSync(syncedData);
        return;
      } catch (error) {
        throw AppActionException(
          'Nie udało się utworzyć rodziny na serwerze: $error',
        );
      }
    }

    _data = draftData;
    await _persist(scheduleSync: true);
  }

  Future<void> joinFamily({
    required String code,
    required String memberName,
    String? email,
    String? phone,
    String? avatar,
  }) async {
    final syncService = _syncService;
    if (syncService == null) {
      throw const AppActionException(
        'Najpierw wpisz adres serwera w ustawieniach.',
      );
    }
    if (!_online) {
      throw const AppActionException('Dołączenie do rodziny wymaga internetu.');
    }

    final now = DateTime.now().toUtc();
    final normalizedCode = code.trim().toUpperCase();
    final memberId = _uuid.v4();

    Family? remoteFamily;
    try {
      remoteFamily = await syncService.findFamilyByCode(normalizedCode);
    } catch (error) {
      throw AppActionException('Nie udało się sprawdzić kodu rodziny: $error');
    }
    if (remoteFamily == null) {
      throw const AppActionException('Nie znaleziono rodziny z takim kodem.');
    }

    final member = Member(
      id: memberId,
      familyId: remoteFamily.id,
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
    final draftData = AppData.empty().copyWith(
      family: remoteFamily.copyWith(
        syncStatus: SyncStatus.synced,
        createOnSync: false,
      ),
      currentMember: member,
      members: [member],
    );

    try {
      final syncedData = await syncService.sync(draftData);
      if (syncedData.currentMember?.syncStatus != SyncStatus.synced) {
        throw const AppActionException(
          'Serwer znalazł rodzinę, ale nie zapisał członka.',
        );
      }
      await _replaceAfterRemoteSync(syncedData);
    } catch (error) {
      throw AppActionException('Nie udało się dołączyć do rodziny: $error');
    }
  }

  Future<void> addCalendarMember({required String name}) async {
    final family = _data.family;
    final creator = _data.currentMember;
    if (family == null || creator == null) {
      return;
    }
    if (!isFamilyCreator) {
      throw const AppActionException(
        'Tylko twórca rodziny może dodawać osoby do kalendarza.',
      );
    }
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      return;
    }
    final now = DateTime.now().toUtc();
    final member = Member(
      id: _uuid.v4(),
      familyId: family.id,
      name: cleanName,
      email: null,
      phone: null,
      avatar: null,
      createdAt: now,
      updatedAt: now,
      createdBy: creator.id,
      isDeleted: false,
      syncStatus: SyncStatus.pending,
    );
    _data = _data.copyWith(members: [..._data.members, member]);
    await _persist(scheduleSync: true);
  }

  Future<void> leaveFamily() async {
    final member = _data.currentMember;
    final family = _data.family;
    if (member == null || family == null) {
      await resetLocalData();
      return;
    }

    if (family.syncStatus != SyncStatus.synced || _syncService == null) {
      await _resetFamilyDataAfterLeaving();
      return;
    }

    if (!_online) {
      throw const AppActionException(
        'Opuszczenie rodziny wymaga internetu, żeby serwer też usunął Cię z rodziny.',
      );
    }

    final removalData = _dataWithRemovedMember(
      data: _data,
      memberId: member.id,
      now: DateTime.now().toUtc(),
    );
    try {
      await _syncService!.sync(removalData);
      await _resetFamilyDataAfterLeaving();
    } catch (error) {
      throw AppActionException('Nie udało się opuścić rodziny: $error');
    }
  }

  Future<void> removeFamilyMember(Member member) async {
    final currentMember = _data.currentMember;
    if (currentMember == null || _data.family == null) {
      return;
    }
    if (!isFamilyCreator) {
      throw const AppActionException(
        'Tylko twórca rodziny może wyrzucać osoby.',
      );
    }
    if (member.id == currentMember.id) {
      throw const AppActionException(
        'Nie możesz wyrzucić siebie. Użyj opcji opuszczenia rodziny.',
      );
    }

    _data = _dataWithRemovedMember(
      data: _data,
      memberId: member.id,
      now: DateTime.now().toUtc(),
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

  bool isFavoriteProduct(String name, String unit) {
    final cleanName = normalizeName(name);
    final cleanUnit = normalizeName(normalizeIngredientUnit(unit));
    return _data.activeFavoriteProducts.any(
      (product) =>
          normalizeName(product.name) == cleanName &&
          normalizeName(product.unit) == cleanUnit,
    );
  }

  Future<void> toggleFavoriteProduct({
    required String name,
    required double quantity,
    required String unit,
  }) async {
    final family = _data.family;
    final member = _data.currentMember;
    final cleanName = name.trim();
    if (family == null || member == null || cleanName.isEmpty) {
      return;
    }

    final now = DateTime.now().toUtc();
    final cleanUnit = normalizeIngredientUnit(unit);
    final index = _data.favoriteProducts.indexWhere(
      (product) =>
          normalizeName(product.name) == normalizeName(cleanName) &&
          normalizeName(product.unit) == normalizeName(cleanUnit),
    );

    if (index == -1) {
      _data = _data.copyWith(
        favoriteProducts: [
          ..._data.favoriteProducts,
          FavoriteProduct(
            id: _uuid.v4(),
            familyId: family.id,
            name: cleanName,
            quantity: quantity <= 0 ? 1 : quantity,
            unit: cleanUnit,
            createdAt: now,
            updatedAt: now,
            createdBy: member.id,
            isDeleted: false,
            syncStatus: SyncStatus.pending,
          ),
        ],
      );
      await _persist(scheduleSync: true);
      return;
    }

    final updated = [..._data.favoriteProducts];
    final product = updated[index];
    updated[index] = product.copyWith(
      familyId: family.id,
      quantity: quantity <= 0 ? product.quantity : quantity,
      unit: cleanUnit,
      updatedAt: now,
      createdBy: product.createdBy.isEmpty ? member.id : product.createdBy,
      isDeleted: !product.isDeleted,
      syncStatus: SyncStatus.pending,
    );
    _data = _data.copyWith(favoriteProducts: updated);
    await _persist(scheduleSync: true);
  }

  Future<void> addFavoriteProductToShoppingList(FavoriteProduct product) async {
    await addShoppingItem(
      name: product.name,
      quantity: product.quantity,
      unit: product.unit,
    );
  }

  Future<void> addReceipt({
    required String storeName,
    required DateTime purchasedAt,
    required double total,
    required List<ReceiptItem> items,
    String rawText = '',
    String? imageData,
    String? imageMimeType,
  }) async {
    final family = _data.family;
    final member = _data.currentMember;
    if (family == null || member == null) {
      return;
    }
    final now = DateTime.now().toUtc();
    final receipt = Receipt(
      id: _uuid.v4(),
      familyId: family.id,
      storeName: storeName.trim().isEmpty ? 'Sklep' : storeName.trim(),
      purchasedAt: purchasedAt.toUtc(),
      total: total,
      rawText: rawText.trim(),
      imageData: nullableString(imageData),
      imageMimeType: nullableString(imageMimeType),
      items: items,
      createdAt: now,
      updatedAt: now,
      createdBy: member.id,
      isDeleted: false,
      syncStatus: SyncStatus.pending,
    );
    _data = _data.copyWith(receipts: [..._data.receipts, receipt]);
    await _persist(scheduleSync: true);
  }

  Future<void> deleteReceipt(Receipt receipt) async {
    final now = DateTime.now().toUtc();
    _data = _data.copyWith(
      receipts: _data.receipts
          .map(
            (entry) => entry.id == receipt.id
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

  Future<void> addReceiptItemsToShoppingList(Receipt receipt) async {
    final now = DateTime.now().toUtc();
    var addedAny = false;
    for (final item in receipt.items) {
      if (item.name.trim().isEmpty || item.quantity <= 0) {
        continue;
      }
      _mergeShoppingItem(
        name: item.name,
        quantity: item.quantity,
        unit: item.unit,
        now: now,
      );
      addedAny = true;
    }
    if (addedAny) {
      await _persist(scheduleSync: true);
    }
  }

  Future<void> addMealWithRecipe({
    required String mealName,
    String category = defaultRecipeCategory,
    required String instructions,
    required int baseServings,
    int caloriesPerServing = 0,
    double proteinPerServing = 0,
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
      category: _cleanRecipeCategory(category),
      instructions: instructions.trim(),
      baseServings: max(1, baseServings),
      caloriesPerServing: max(0, caloriesPerServing),
      proteinPerServing: max(0, proteinPerServing).toDouble(),
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
    String category = defaultRecipeCategory,
    required String instructions,
    required int baseServings,
    int caloriesPerServing = 0,
    double proteinPerServing = 0,
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
      category: _cleanRecipeCategory(category),
      instructions: instructions.trim(),
      baseServings: max(1, baseServings),
      caloriesPerServing: max(0, caloriesPerServing),
      proteinPerServing: max(0, proteinPerServing).toDouble(),
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
    String? category,
    required String instructions,
    required int baseServings,
    int caloriesPerServing = 0,
    double proteinPerServing = 0,
    required List<IngredientDraft> ingredients,
  }) async {
    final now = DateTime.now().toUtc();
    final updatedRecipes = _data.recipes
        .map(
          (entry) => entry.id == recipe.id
              ? entry.copyWith(
                  name: name.trim(),
                  category: _cleanRecipeCategory(category ?? entry.category),
                  instructions: instructions.trim(),
                  baseServings: max(1, baseServings),
                  caloriesPerServing: max(0, caloriesPerServing),
                  proteinPerServing: max(0, proteinPerServing).toDouble(),
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

  Future<void> updateRecipeCategory({
    required Recipe recipe,
    required String category,
  }) async {
    final now = DateTime.now().toUtc();
    _data = _data.copyWith(
      recipes: _data.recipes
          .map(
            (entry) => entry.id == recipe.id
                ? entry.copyWith(
                    category: _cleanRecipeCategory(category),
                    updatedAt: now,
                    syncStatus: SyncStatus.pending,
                  )
                : entry,
          )
          .toList(),
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
      mealPlans: _data.mealPlans
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
    );
    await _persist(scheduleSync: true);
  }

  Future<void> addRecipesToShoppingList({
    required List<String> recipeIds,
    required int servings,
  }) async {
    final now = DateTime.now().toUtc();
    if (!_mergeRecipesToShoppingList(
      recipeIds: recipeIds,
      servings: servings,
      now: now,
    )) {
      return;
    }
    await _persist(scheduleSync: true);
  }

  Future<void> addMealPlanToCalendar({
    required DateTime date,
    required Meal meal,
    required List<String> recipeIds,
    required int servings,
  }) async {
    final family = _data.family;
    final member = _data.currentMember;
    if (family == null || member == null || recipeIds.isEmpty) {
      return;
    }
    final now = DateTime.now().toUtc();
    final cleanServings = max(1, servings);
    final addedToShopping = _mergeRecipesToShoppingList(
      recipeIds: recipeIds,
      servings: cleanServings,
      now: now,
    );
    if (!addedToShopping) {
      return;
    }
    final plan = MealPlan(
      id: _uuid.v4(),
      familyId: family.id,
      date: _dateOnlyUtc(date),
      mealId: meal.id,
      recipeIds: recipeIds,
      servings: cleanServings,
      createdAt: now,
      updatedAt: now,
      createdBy: member.id,
      isDeleted: false,
      syncStatus: SyncStatus.pending,
    );
    _data = _data.copyWith(mealPlans: [..._data.mealPlans, plan]);
    await _persist(scheduleSync: true);
  }

  Future<void> deleteMealPlan(MealPlan plan) async {
    final now = DateTime.now().toUtc();
    _data = _data.copyWith(
      mealPlans: _data.mealPlans
          .map(
            (entry) => entry.id == plan.id
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

  Future<void> addCalendarEvent({
    required DateTime date,
    required String title,
    required String notes,
    required String? memberId,
    required bool isFamilyWide,
  }) async {
    final family = _data.family;
    final member = _data.currentMember;
    if (family == null || member == null || title.trim().isEmpty) {
      return;
    }
    final now = DateTime.now().toUtc();
    final event = CalendarEvent(
      id: _uuid.v4(),
      familyId: family.id,
      date: _dateOnlyUtc(date),
      title: title.trim(),
      notes: notes.trim(),
      memberId: isFamilyWide ? null : memberId,
      isFamilyWide: isFamilyWide,
      createdAt: now,
      updatedAt: now,
      createdBy: member.id,
      isDeleted: false,
      syncStatus: SyncStatus.pending,
    );
    _data = _data.copyWith(calendarEvents: [..._data.calendarEvents, event]);
    await _persist(scheduleSync: true);
  }

  Future<void> updateCalendarEvent({
    required CalendarEvent event,
    required DateTime date,
    required String title,
    required String notes,
    required String? memberId,
    required bool isFamilyWide,
  }) async {
    final now = DateTime.now().toUtc();
    _data = _data.copyWith(
      calendarEvents: _data.calendarEvents
          .map(
            (entry) => entry.id == event.id
                ? entry.copyWith(
                    date: _dateOnlyUtc(date),
                    title: title.trim(),
                    notes: notes.trim(),
                    memberId: isFamilyWide ? null : memberId,
                    clearMemberId: isFamilyWide,
                    isFamilyWide: isFamilyWide,
                    updatedAt: now,
                    syncStatus: SyncStatus.pending,
                  )
                : entry,
          )
          .toList(),
    );
    await _persist(scheduleSync: true);
  }

  Future<void> deleteCalendarEvent(CalendarEvent event) async {
    final now = DateTime.now().toUtc();
    _data = _data.copyWith(
      calendarEvents: _data.calendarEvents
          .map(
            (entry) => entry.id == event.id
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

  Future<void> saveNutritionGoal({
    String? memberId,
    required int dailyCalories,
    required double dailyProtein,
  }) async {
    final family = _data.family;
    final member = _data.currentMember;
    if (family == null || member == null) {
      return;
    }
    final targetMemberId = memberId ?? member.id;
    if (targetMemberId != member.id && !isFamilyCreator) {
      throw const AppActionException(
        'Tylko glowa rodziny moze ustawiac cele innych osob.',
      );
    }
    final now = DateTime.now().toUtc();
    final index = _data.nutritionGoals.indexWhere(
      (goal) => !goal.isDeleted && goal.memberId == targetMemberId,
    );
    if (index == -1) {
      _data = _data.copyWith(
        nutritionGoals: [
          ..._data.nutritionGoals,
          NutritionGoal(
            id: _uuid.v4(),
            familyId: family.id,
            memberId: targetMemberId,
            dailyCalories: max(0, dailyCalories),
            dailyProtein: max(0, dailyProtein).toDouble(),
            createdAt: now,
            updatedAt: now,
            createdBy: member.id,
            isDeleted: false,
            syncStatus: SyncStatus.pending,
          ),
        ],
      );
      await _persist(scheduleSync: true);
      return;
    }

    final updated = [..._data.nutritionGoals];
    final current = updated[index];
    updated[index] = current.copyWith(
      dailyCalories: max(0, dailyCalories),
      dailyProtein: max(0, dailyProtein).toDouble(),
      updatedAt: now,
      syncStatus: SyncStatus.pending,
    );
    _data = _data.copyWith(nutritionGoals: updated);
    await _persist(scheduleSync: true);
  }

  Future<void> addNutritionEntry({
    required DateTime date,
    required int calories,
    required double protein,
    required String note,
  }) async {
    final family = _data.family;
    final member = _data.currentMember;
    if (family == null || member == null || (calories <= 0 && protein <= 0)) {
      return;
    }
    final now = DateTime.now().toUtc();
    final entry = NutritionEntry(
      id: _uuid.v4(),
      familyId: family.id,
      memberId: member.id,
      date: _dateOnlyUtc(date),
      calories: max(0, calories),
      protein: max(0, protein),
      note: note.trim(),
      createdAt: now,
      updatedAt: now,
      createdBy: member.id,
      isDeleted: false,
      syncStatus: SyncStatus.pending,
    );
    _data = _data.copyWith(
      nutritionEntries: [..._data.nutritionEntries, entry],
    );
    await _persist(scheduleSync: true);
  }

  Future<void> addNutritionEntryFromRecipe({
    required DateTime date,
    required Recipe recipe,
    required double servingPercent,
  }) async {
    final multiplier = max(0.0, servingPercent) / 100;
    await addNutritionEntry(
      date: date,
      calories: (recipe.caloriesPerServing * multiplier).round(),
      protein: recipe.proteinPerServing * multiplier,
      note: '${recipe.name} (${_formatNumber(servingPercent)}% porcji)',
    );
  }

  Future<void> deleteNutritionEntry(NutritionEntry entry) async {
    final now = DateTime.now().toUtc();
    _data = _data.copyWith(
      nutritionEntries: _data.nutritionEntries
          .map(
            (item) => item.id == entry.id
                ? item.copyWith(
                    isDeleted: true,
                    updatedAt: now,
                    syncStatus: SyncStatus.pending,
                  )
                : item,
          )
          .toList(),
    );
    await _persist(scheduleSync: true);
  }

  Future<void> addTrainingEntry({
    String? memberId,
    required DateTime date,
    required int durationMinutes,
    required String activity,
    required String note,
  }) async {
    final family = _data.family;
    final member = _data.currentMember;
    if (family == null || member == null || durationMinutes <= 0) {
      return;
    }
    final targetMemberId = memberId ?? member.id;
    if (targetMemberId != member.id && !isFamilyCreator) {
      throw const AppActionException(
        'Tylko glowa rodziny moze dopisywac treningi innych osob.',
      );
    }
    final now = DateTime.now().toUtc();
    final entry = TrainingEntry(
      id: _uuid.v4(),
      familyId: family.id,
      memberId: targetMemberId,
      date: _dateOnlyUtc(date),
      activity: activity.trim().isEmpty ? 'Trening' : activity.trim(),
      durationMinutes: max(0, durationMinutes),
      note: note.trim(),
      createdAt: now,
      updatedAt: now,
      createdBy: member.id,
      isDeleted: false,
      syncStatus: SyncStatus.pending,
    );
    _data = _data.copyWith(trainingEntries: [..._data.trainingEntries, entry]);
    await _persist(scheduleSync: true);
  }

  Future<void> deleteTrainingEntry(TrainingEntry entry) async {
    final member = _data.currentMember;
    if (member == null || (entry.memberId != member.id && !isFamilyCreator)) {
      return;
    }
    final now = DateTime.now().toUtc();
    _data = _data.copyWith(
      trainingEntries: _data.trainingEntries
          .map(
            (item) => item.id == entry.id
                ? item.copyWith(
                    isDeleted: true,
                    updatedAt: now,
                    syncStatus: SyncStatus.pending,
                  )
                : item,
          )
          .toList(),
    );
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

  List<MealPlan> mealPlansForDate(DateTime date) {
    final cleanDate = _dateOnlyUtc(date);
    return _data.activeMealPlans
        .where((plan) => _isSameUtcDate(plan.date, cleanDate))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  List<CalendarEvent> calendarEventsForDate(DateTime date) {
    final cleanDate = _dateOnlyUtc(date);
    return _data.activeCalendarEvents
        .where((event) => _isSameUtcDate(event.date, cleanDate))
        .toList()
      ..sort((a, b) => a.title.compareTo(b.title));
  }

  List<NutritionEntry> nutritionEntriesForDate(DateTime date) {
    final cleanDate = _dateOnlyUtc(date);
    return _data.activeNutritionEntries
        .where((entry) => _isSameUtcDate(entry.date, cleanDate))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  List<TrainingEntry> trainingEntriesForDate(DateTime date) {
    final cleanDate = _dateOnlyUtc(date);
    return _data.activeTrainingEntries
        .where((entry) => _isSameUtcDate(entry.date, cleanDate))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  NutritionGoal? nutritionGoalForMember(String memberId) {
    for (final goal in _data.activeNutritionGoals) {
      if (goal.memberId == memberId) {
        return goal;
      }
    }
    return null;
  }

  Meal? mealById(String id) {
    for (final meal in _data.activeMeals) {
      if (meal.id == id) {
        return meal;
      }
    }
    return null;
  }

  Member? memberById(String id) {
    for (final member in _data.activeMembers) {
      if (member.id == id) {
        return member;
      }
    }
    return null;
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
      if (_data.family?.syncStatus == SyncStatus.synced) {
        await _store.saveDataServerUrl(_serverUrl);
      }
    } catch (error) {
      _lastSyncError = error.toString();
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  Future<void> _replaceAfterRemoteSync(AppData data) async {
    _data = data;
    _lastSyncAt = DateTime.now();
    _lastSyncError = null;
    await _store.saveAll(_data);
    await _store.saveLastSyncAt(_lastSyncAt!);
    if (_data.family?.syncStatus == SyncStatus.synced) {
      await _store.saveDataServerUrl(_serverUrl);
    }
    notifyListeners();
  }

  Future<void> updateServerUrl(String value) async {
    final nextServerUrl = _normalizeServerUrl(value);
    final serverChanged = nextServerUrl != _serverUrl;
    _serverUrl = nextServerUrl;
    if (serverChanged && _data.family != null) {
      _data = _dataMarkedPendingForServerChange(_data);
      await _store.saveAll(_data);
      await _store.saveDataServerUrl(_serverUrl);
    }
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

  Future<void> _resetFamilyDataAfterLeaving() async {
    final previousServerUrl = _serverUrl;
    await resetLocalData();
    if (previousServerUrl != _serverUrl) {
      await updateServerUrl(previousServerUrl);
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _periodicSyncTimer?.cancel();
    _syncDebounce?.cancel();
    _syncService?.dispose();
    super.dispose();
  }

  bool _mergeRecipesToShoppingList({
    required List<String> recipeIds,
    required int servings,
    required DateTime now,
  }) {
    final selectedRecipes = _data.activeRecipes
        .where((recipe) => recipeIds.contains(recipe.id))
        .toList();
    if (selectedRecipes.isEmpty) {
      return false;
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
      return false;
    }

    for (final item in groupedIngredients) {
      _mergeShoppingItem(
        name: item.name,
        quantity: item.quantity,
        unit: item.unit,
        now: now,
      );
    }
    return true;
  }

  AppData _dataWithRemovedMember({
    required AppData data,
    required String memberId,
    required DateTime now,
  }) {
    final updatedMembers = data.members
        .map(
          (entry) => entry.id == memberId
              ? entry.copyWith(
                  isDeleted: true,
                  updatedAt: now,
                  syncStatus: SyncStatus.pending,
                )
              : entry,
        )
        .toList();
    final updatedCurrentMember = data.currentMember?.id == memberId
        ? data.currentMember!.copyWith(
            isDeleted: true,
            updatedAt: now,
            syncStatus: SyncStatus.pending,
          )
        : data.currentMember;
    final updatedEvents = data.calendarEvents
        .map(
          (entry) => entry.memberId == memberId && !entry.isDeleted
              ? entry.copyWith(
                  isDeleted: true,
                  updatedAt: now,
                  syncStatus: SyncStatus.pending,
                )
              : entry,
        )
        .toList();
    final updatedNutritionGoals = data.nutritionGoals
        .map(
          (entry) => entry.memberId == memberId && !entry.isDeleted
              ? entry.copyWith(
                  isDeleted: true,
                  updatedAt: now,
                  syncStatus: SyncStatus.pending,
                )
              : entry,
        )
        .toList();
    final updatedNutritionEntries = data.nutritionEntries
        .map(
          (entry) => entry.memberId == memberId && !entry.isDeleted
              ? entry.copyWith(
                  isDeleted: true,
                  updatedAt: now,
                  syncStatus: SyncStatus.pending,
                )
              : entry,
        )
        .toList();
    final updatedTrainingEntries = data.trainingEntries
        .map(
          (entry) => entry.memberId == memberId && !entry.isDeleted
              ? entry.copyWith(
                  isDeleted: true,
                  updatedAt: now,
                  syncStatus: SyncStatus.pending,
                )
              : entry,
        )
        .toList();

    return data.copyWith(
      currentMember: updatedCurrentMember,
      members: updatedMembers,
      calendarEvents: updatedEvents,
      nutritionGoals: updatedNutritionGoals,
      nutritionEntries: updatedNutritionEntries,
      trainingEntries: updatedTrainingEntries,
    );
  }

  AppData _dataMarkedPendingForServerChange(AppData data) {
    final familyCreator =
        data.family != null &&
        data.currentMember != null &&
        data.family!.createdBy == data.currentMember!.id;

    return data.copyWith(
      family: data.family?.copyWith(
        syncStatus: SyncStatus.pending,
        createOnSync: familyCreator,
      ),
      currentMember: data.currentMember?.copyWith(
        syncStatus: SyncStatus.pending,
      ),
      members: data.members
          .map((item) => item.copyWith(syncStatus: SyncStatus.pending))
          .toList(),
      shoppingItems: data.shoppingItems
          .map((item) => item.copyWith(syncStatus: SyncStatus.pending))
          .toList(),
      meals: data.meals
          .map((item) => item.copyWith(syncStatus: SyncStatus.pending))
          .toList(),
      recipes: data.recipes
          .map((item) => item.copyWith(syncStatus: SyncStatus.pending))
          .toList(),
      recipeIngredients: data.recipeIngredients
          .map((item) => item.copyWith(syncStatus: SyncStatus.pending))
          .toList(),
      mealPlans: data.mealPlans
          .map((item) => item.copyWith(syncStatus: SyncStatus.pending))
          .toList(),
      calendarEvents: data.calendarEvents
          .map((item) => item.copyWith(syncStatus: SyncStatus.pending))
          .toList(),
      nutritionGoals: data.nutritionGoals
          .map((item) => item.copyWith(syncStatus: SyncStatus.pending))
          .toList(),
      nutritionEntries: data.nutritionEntries
          .map((item) => item.copyWith(syncStatus: SyncStatus.pending))
          .toList(),
      trainingEntries: data.trainingEntries
          .map((item) => item.copyWith(syncStatus: SyncStatus.pending))
          .toList(),
      favoriteProducts: data.favoriteProducts
          .map((item) => item.copyWith(syncStatus: SyncStatus.pending))
          .toList(),
      receipts: data.receipts
          .map((item) => item.copyWith(syncStatus: SyncStatus.pending))
          .toList(),
    );
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

  bool _isLegacyBrokenServerUrl(String value) {
    return _legacyBrokenServerUrls.contains(value.toLowerCase());
  }

  bool _shouldResyncAfterServerChange(String dataServerUrl) {
    return _data.family != null &&
        _serverUrl.startsWith('http') &&
        dataServerUrl != _serverUrl;
  }

  String _generateFamilyCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(6, (_) => chars[_random.nextInt(chars.length)]).join();
  }

  String _cleanRecipeCategory(String category) {
    final clean = category.trim();
    if (recipeCategories.contains(clean)) {
      return clean;
    }
    return defaultRecipeCategory;
  }

  DateTime _dateOnlyUtc(DateTime date) {
    final local = date.toLocal();
    return DateTime.utc(local.year, local.month, local.day);
  }

  bool _isSameUtcDate(DateTime first, DateTime second) {
    return first.toUtc().year == second.toUtc().year &&
        first.toUtc().month == second.toUtc().month &&
        first.toUtc().day == second.toUtc().day;
  }
}

String _formatNumber(num value) {
  if (value % 1 == 0) {
    return value.toInt().toString();
  }
  return value.toStringAsFixed(1);
}

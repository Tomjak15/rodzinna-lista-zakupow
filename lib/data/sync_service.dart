import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/entities.dart';

class SyncService {
  SyncService(this._baseUrl);

  final String _baseUrl;
  final _client = http.Client();

  void dispose() {
    _client.close();
  }

  Future<AppData> sync(AppData data) async {
    var next = await _syncFamily(data);
    final family = next.family;
    if (family == null || family.syncStatus != SyncStatus.synced) {
      return next;
    }

    final familyId = family.id;
    final members = await _pushList<Member>(
      table: 'members',
      familyId: familyId,
      local: next.members,
      toRemote: (item) => item.toRemote(),
      statusOf: (item) => item.syncStatus,
      withStatus: (item, status) => item.copyWith(syncStatus: status),
      familyIdOf: (item) => item.familyId,
    );
    final shoppingItems = await _pushList<ShoppingItem>(
      table: 'shopping_items',
      familyId: familyId,
      local: next.shoppingItems,
      toRemote: (item) => item.toRemote(),
      statusOf: (item) => item.syncStatus,
      withStatus: (item, status) => item.copyWith(syncStatus: status),
      familyIdOf: (item) => item.familyId,
    );
    final meals = await _pushList<Meal>(
      table: 'meals',
      familyId: familyId,
      local: next.meals,
      toRemote: (item) => item.toRemote(),
      statusOf: (item) => item.syncStatus,
      withStatus: (item, status) => item.copyWith(syncStatus: status),
      familyIdOf: (item) => item.familyId,
    );
    final recipes = await _pushList<Recipe>(
      table: 'recipes',
      familyId: familyId,
      local: next.recipes,
      toRemote: (item) => item.toRemote(),
      statusOf: (item) => item.syncStatus,
      withStatus: (item, status) => item.copyWith(syncStatus: status),
      familyIdOf: (item) => item.familyId,
    );
    final recipeIngredients = await _pushList<RecipeIngredient>(
      table: 'recipe_ingredients',
      familyId: familyId,
      local: next.recipeIngredients,
      toRemote: (item) => item.toRemote(),
      statusOf: (item) => item.syncStatus,
      withStatus: (item, status) => item.copyWith(syncStatus: status),
      familyIdOf: (item) => item.familyId,
    );
    final mealPlans = await _pushList<MealPlan>(
      table: 'meal_plans',
      familyId: familyId,
      local: next.mealPlans,
      toRemote: (item) => item.toRemote(),
      statusOf: (item) => item.syncStatus,
      withStatus: (item, status) => item.copyWith(syncStatus: status),
      familyIdOf: (item) => item.familyId,
    );
    final calendarEvents = await _pushList<CalendarEvent>(
      table: 'calendar_events',
      familyId: familyId,
      local: next.calendarEvents,
      toRemote: (item) => item.toRemote(),
      statusOf: (item) => item.syncStatus,
      withStatus: (item, status) => item.copyWith(syncStatus: status),
      familyIdOf: (item) => item.familyId,
    );

    next = next.copyWith(
      members: members,
      shoppingItems: shoppingItems,
      meals: meals,
      recipes: recipes,
      recipeIngredients: recipeIngredients,
      mealPlans: mealPlans,
      calendarEvents: calendarEvents,
    );

    final pulledMembers = await _pullList<Member>(
      table: 'members',
      familyId: familyId,
      local: next.members,
      fromRemote: Member.fromRemote,
      idOf: (item) => item.id,
      updatedAtOf: (item) => item.updatedAt,
      statusOf: (item) => item.syncStatus,
    );
    final pulledShoppingItems = await _pullList<ShoppingItem>(
      table: 'shopping_items',
      familyId: familyId,
      local: next.shoppingItems,
      fromRemote: ShoppingItem.fromRemote,
      idOf: (item) => item.id,
      updatedAtOf: (item) => item.updatedAt,
      statusOf: (item) => item.syncStatus,
    );
    final pulledMeals = await _pullList<Meal>(
      table: 'meals',
      familyId: familyId,
      local: next.meals,
      fromRemote: Meal.fromRemote,
      idOf: (item) => item.id,
      updatedAtOf: (item) => item.updatedAt,
      statusOf: (item) => item.syncStatus,
    );
    final pulledRecipes = await _pullList<Recipe>(
      table: 'recipes',
      familyId: familyId,
      local: next.recipes,
      fromRemote: Recipe.fromRemote,
      idOf: (item) => item.id,
      updatedAtOf: (item) => item.updatedAt,
      statusOf: (item) => item.syncStatus,
    );
    final pulledRecipeIngredients = await _pullList<RecipeIngredient>(
      table: 'recipe_ingredients',
      familyId: familyId,
      local: next.recipeIngredients,
      fromRemote: RecipeIngredient.fromRemote,
      idOf: (item) => item.id,
      updatedAtOf: (item) => item.updatedAt,
      statusOf: (item) => item.syncStatus,
    );
    final pulledMealPlans = await _pullList<MealPlan>(
      table: 'meal_plans',
      familyId: familyId,
      local: next.mealPlans,
      fromRemote: MealPlan.fromRemote,
      idOf: (item) => item.id,
      updatedAtOf: (item) => item.updatedAt,
      statusOf: (item) => item.syncStatus,
    );
    final pulledCalendarEvents = await _pullList<CalendarEvent>(
      table: 'calendar_events',
      familyId: familyId,
      local: next.calendarEvents,
      fromRemote: CalendarEvent.fromRemote,
      idOf: (item) => item.id,
      updatedAtOf: (item) => item.updatedAt,
      statusOf: (item) => item.syncStatus,
    );

    final currentMember = _refreshCurrentMember(
      next.currentMember,
      pulledMembers,
    );

    return next.copyWith(
      currentMember: currentMember,
      members: pulledMembers,
      shoppingItems: pulledShoppingItems,
      meals: pulledMeals,
      recipes: pulledRecipes,
      recipeIngredients: pulledRecipeIngredients,
      mealPlans: pulledMealPlans,
      calendarEvents: pulledCalendarEvents,
    );
  }

  Future<AppData> _syncFamily(AppData data) async {
    final family = data.family;
    if (family == null || family.syncStatus == SyncStatus.synced) {
      return data;
    }

    try {
      if (!family.createOnSync) {
        final remote = await findFamilyByCode(family.code);
        if (remote == null) {
          return data.copyWith(
            family: family.copyWith(syncStatus: SyncStatus.failed),
          );
        }
        return _remapFamilyId(data, remote);
      }

      await _putJson('/api/families/${family.id}', family.toRemote());
      return data.copyWith(
        family: family.copyWith(syncStatus: SyncStatus.synced),
      );
    } catch (_) {
      return data.copyWith(
        family: family.copyWith(syncStatus: SyncStatus.failed),
      );
    }
  }

  Future<Family?> findFamilyByCode(String code) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/families/code/${Uri.encodeComponent(code)}'),
    );
    if (response.statusCode == 404) {
      return null;
    }
    _ensureSuccess(response);
    return Family.fromRemote(_decodeObject(response.body));
  }

  AppData _remapFamilyId(AppData data, Family remoteFamily) {
    final familyId = remoteFamily.id;
    final members = data.members
        .map(
          (item) =>
              item.copyWith(familyId: familyId, syncStatus: SyncStatus.pending),
        )
        .toList();
    final currentMember = data.currentMember?.copyWith(
      familyId: familyId,
      syncStatus: SyncStatus.pending,
    );

    return data.copyWith(
      family: remoteFamily.copyWith(
        familyId: familyId,
        syncStatus: SyncStatus.synced,
        createOnSync: false,
      ),
      currentMember: currentMember,
      members: members,
      shoppingItems: data.shoppingItems
          .map(
            (item) => item.copyWith(
              familyId: familyId,
              syncStatus: SyncStatus.pending,
            ),
          )
          .toList(),
      meals: data.meals
          .map(
            (item) => item.copyWith(
              familyId: familyId,
              syncStatus: SyncStatus.pending,
            ),
          )
          .toList(),
      recipes: data.recipes
          .map(
            (item) => item.copyWith(
              familyId: familyId,
              syncStatus: SyncStatus.pending,
            ),
          )
          .toList(),
      recipeIngredients: data.recipeIngredients
          .map(
            (item) => item.copyWith(
              familyId: familyId,
              syncStatus: SyncStatus.pending,
            ),
          )
          .toList(),
      mealPlans: data.mealPlans
          .map(
            (item) => item.copyWith(
              familyId: familyId,
              syncStatus: SyncStatus.pending,
            ),
          )
          .toList(),
      calendarEvents: data.calendarEvents
          .map(
            (item) => item.copyWith(
              familyId: familyId,
              syncStatus: SyncStatus.pending,
            ),
          )
          .toList(),
    );
  }

  Member? _refreshCurrentMember(Member? current, List<Member> members) {
    if (current == null) {
      return null;
    }
    return members.firstWhere(
      (member) => member.id == current.id,
      orElse: () => current,
    );
  }

  Future<List<T>> _pushList<T>({
    required String table,
    required String familyId,
    required List<T> local,
    required Map<String, dynamic> Function(T item) toRemote,
    required SyncStatus Function(T item) statusOf,
    required T Function(T item, SyncStatus status) withStatus,
    required String Function(T item) familyIdOf,
  }) async {
    final pushed = <T>[];
    for (final item in local) {
      if (familyIdOf(item) != familyId || statusOf(item) == SyncStatus.synced) {
        pushed.add(item);
        continue;
      }
      try {
        final id = (toRemote(item)['id'] ?? '').toString();
        await _putJson('/api/$table/$id', toRemote(item));
        pushed.add(withStatus(item, SyncStatus.synced));
      } catch (_) {
        pushed.add(withStatus(item, SyncStatus.failed));
      }
    }
    return pushed;
  }

  Future<List<T>> _pullList<T>({
    required String table,
    required String familyId,
    required List<T> local,
    required T Function(Map<String, dynamic> json) fromRemote,
    required String Function(T item) idOf,
    required DateTime Function(T item) updatedAtOf,
    required SyncStatus Function(T item) statusOf,
  }) async {
    final rows = await _getList('/api/$table?familyId=$familyId');
    final remoteItems = rows.map(fromRemote).toList();
    final merged = [...local];

    for (final remote in remoteItems) {
      final index = merged.indexWhere((item) => idOf(item) == idOf(remote));
      if (index == -1) {
        merged.add(remote);
        continue;
      }

      final localItem = merged[index];
      final localIsNewer = updatedAtOf(localItem).isAfter(updatedAtOf(remote));
      final localIsPending = statusOf(localItem) != SyncStatus.synced;
      if (localIsPending && localIsNewer) {
        continue;
      }
      if (!localIsNewer || !localIsPending) {
        merged[index] = remote;
      }
    }

    return merged;
  }

  Future<void> _putJson(String path, Map<String, dynamic> body) async {
    final response = await _client.put(
      Uri.parse('$_baseUrl$path'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    _ensureSuccess(response);
  }

  Future<List<Map<String, dynamic>>> _getList(String path) async {
    final response = await _client.get(Uri.parse('$_baseUrl$path'));
    _ensureSuccess(response);
    final decoded = jsonDecode(response.body) as List<dynamic>;
    return decoded
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Map<String, dynamic> _decodeObject(String body) {
    return Map<String, dynamic>.from(jsonDecode(body) as Map);
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Server error ${response.statusCode}: ${response.body}');
    }
  }
}

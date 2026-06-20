import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/entities.dart';

class LocalStore {
  LocalStore._(this._prefs);

  static const _familyKey = 'family';
  static const _memberKey = 'currentMember';
  static const _membersKey = 'members';
  static const _shoppingItemsKey = 'shoppingItems';
  static const _mealsKey = 'meals';
  static const _recipesKey = 'recipes';
  static const _recipeIngredientsKey = 'recipeIngredients';
  static const _lastSyncKey = 'lastSyncAt';
  static const _serverUrlKey = 'serverUrl';

  final SharedPreferences _prefs;

  static Future<LocalStore> create() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalStore._(prefs);
  }

  Future<AppData> loadAll() async {
    return AppData(
      family: _readObject(_familyKey, Family.fromJson),
      currentMember: _readObject(_memberKey, Member.fromJson),
      members: _readList(_membersKey, Member.fromJson),
      shoppingItems: _readList(_shoppingItemsKey, ShoppingItem.fromJson),
      meals: _readList(_mealsKey, Meal.fromJson),
      recipes: _readList(_recipesKey, Recipe.fromJson),
      recipeIngredients: _readList(
        _recipeIngredientsKey,
        RecipeIngredient.fromJson,
      ),
    );
  }

  Future<void> saveAll(AppData data) async {
    await Future.wait([
      _writeObject(_familyKey, data.family?.toJson()),
      _writeObject(_memberKey, data.currentMember?.toJson()),
      _writeList(_membersKey, data.members.map((item) => item.toJson())),
      _writeList(
        _shoppingItemsKey,
        data.shoppingItems.map((item) => item.toJson()),
      ),
      _writeList(_mealsKey, data.meals.map((item) => item.toJson())),
      _writeList(_recipesKey, data.recipes.map((item) => item.toJson())),
      _writeList(
        _recipeIngredientsKey,
        data.recipeIngredients.map((item) => item.toJson()),
      ),
    ]);
  }

  DateTime? loadLastSyncAt() {
    final value = _prefs.getString(_lastSyncKey);
    if (value == null) {
      return null;
    }
    return DateTime.tryParse(value)?.toLocal();
  }

  String? loadServerUrl() {
    return nullableString(_prefs.getString(_serverUrlKey));
  }

  Future<void> saveServerUrl(String? value) {
    final cleanValue = nullableString(value);
    if (cleanValue == null) {
      return _prefs.remove(_serverUrlKey);
    }
    return _prefs.setString(_serverUrlKey, cleanValue);
  }

  Future<void> saveLastSyncAt(DateTime value) {
    return _prefs.setString(_lastSyncKey, value.toUtc().toIso8601String());
  }

  Future<void> clear() async {
    await Future.wait([
      _prefs.remove(_familyKey),
      _prefs.remove(_memberKey),
      _prefs.remove(_membersKey),
      _prefs.remove(_shoppingItemsKey),
      _prefs.remove(_mealsKey),
      _prefs.remove(_recipesKey),
      _prefs.remove(_recipeIngredientsKey),
      _prefs.remove(_lastSyncKey),
      _prefs.remove(_serverUrlKey),
    ]);
  }

  T? _readObject<T>(
    String key,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
  }

  List<T> _readList<T>(
    String key,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<void> _writeObject(String key, Map<String, dynamic>? value) {
    if (value == null) {
      return _prefs.remove(key);
    }
    return _prefs.setString(key, jsonEncode(value));
  }

  Future<void> _writeList(String key, Iterable<Map<String, dynamic>> values) {
    return _prefs.setString(key, jsonEncode(values.toList()));
  }
}

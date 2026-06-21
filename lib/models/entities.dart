import 'dart:convert';

enum SyncStatus { synced, pending, failed }

SyncStatus syncStatusFromJson(Object? value) {
  return SyncStatus.values.firstWhere(
    (status) => status.name == value,
    orElse: () => SyncStatus.pending,
  );
}

DateTime dateFromJson(Object? value) {
  if (value is DateTime) {
    return value.toUtc();
  }
  if (value is String) {
    return DateTime.tryParse(value)?.toUtc() ?? DateTime.now().toUtc();
  }
  return DateTime.now().toUtc();
}

double doubleFromJson(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value.replaceAll(',', '.')) ?? 0;
  }
  return 0;
}

int intFromJson(Object? value) {
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? 1;
  }
  return 1;
}

bool boolFromJson(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    return value == 'true' || value == '1';
  }
  return false;
}

List<String> stringListFromJson(Object? value) {
  if (value is List) {
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  if (value is String) {
    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return [];
}

String? nullableString(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) {
    return null;
  }
  return text;
}

String normalizeName(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

String formatQuantity(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

class AppData {
  const AppData({
    required this.family,
    required this.currentMember,
    required this.members,
    required this.shoppingItems,
    required this.meals,
    required this.recipes,
    required this.recipeIngredients,
    required this.mealPlans,
    required this.calendarEvents,
    required this.nutritionGoals,
    required this.nutritionEntries,
    required this.trainingEntries,
    required this.favoriteProducts,
    required this.receipts,
  });

  factory AppData.empty() {
    return const AppData(
      family: null,
      currentMember: null,
      members: [],
      shoppingItems: [],
      meals: [],
      recipes: [],
      recipeIngredients: [],
      mealPlans: [],
      calendarEvents: [],
      nutritionGoals: [],
      nutritionEntries: [],
      trainingEntries: [],
      favoriteProducts: [],
      receipts: [],
    );
  }

  final Family? family;
  final Member? currentMember;
  final List<Member> members;
  final List<ShoppingItem> shoppingItems;
  final List<Meal> meals;
  final List<Recipe> recipes;
  final List<RecipeIngredient> recipeIngredients;
  final List<MealPlan> mealPlans;
  final List<CalendarEvent> calendarEvents;
  final List<NutritionGoal> nutritionGoals;
  final List<NutritionEntry> nutritionEntries;
  final List<TrainingEntry> trainingEntries;
  final List<FavoriteProduct> favoriteProducts;
  final List<Receipt> receipts;

  List<Member> get activeMembers =>
      members.where((member) => !member.isDeleted).toList();

  List<ShoppingItem> get activeShoppingItems =>
      shoppingItems.where((item) => !item.isDeleted).toList();

  List<Meal> get activeMeals => meals.where((meal) => !meal.isDeleted).toList();

  List<Recipe> get activeRecipes =>
      recipes.where((recipe) => !recipe.isDeleted).toList();

  List<RecipeIngredient> get activeRecipeIngredients =>
      recipeIngredients.where((ingredient) => !ingredient.isDeleted).toList();

  List<MealPlan> get activeMealPlans =>
      mealPlans.where((plan) => !plan.isDeleted).toList();

  List<CalendarEvent> get activeCalendarEvents =>
      calendarEvents.where((event) => !event.isDeleted).toList();

  List<NutritionGoal> get activeNutritionGoals =>
      nutritionGoals.where((goal) => !goal.isDeleted).toList();

  List<NutritionEntry> get activeNutritionEntries =>
      nutritionEntries.where((entry) => !entry.isDeleted).toList();

  List<TrainingEntry> get activeTrainingEntries =>
      trainingEntries.where((entry) => !entry.isDeleted).toList();

  List<FavoriteProduct> get activeFavoriteProducts =>
      favoriteProducts.where((product) => !product.isDeleted).toList();

  List<Receipt> get activeReceipts =>
      receipts.where((receipt) => !receipt.isDeleted).toList();

  int get pendingCount {
    var count = 0;
    if (family != null && family!.syncStatus != SyncStatus.synced) {
      count++;
    }
    count += members
        .where((item) => item.syncStatus != SyncStatus.synced)
        .length;
    count += shoppingItems
        .where((item) => item.syncStatus != SyncStatus.synced)
        .length;
    count += meals.where((item) => item.syncStatus != SyncStatus.synced).length;
    count += recipes
        .where((item) => item.syncStatus != SyncStatus.synced)
        .length;
    count += recipeIngredients
        .where((item) => item.syncStatus != SyncStatus.synced)
        .length;
    count += mealPlans
        .where((item) => item.syncStatus != SyncStatus.synced)
        .length;
    count += calendarEvents
        .where((item) => item.syncStatus != SyncStatus.synced)
        .length;
    count += nutritionGoals
        .where((item) => item.syncStatus != SyncStatus.synced)
        .length;
    count += nutritionEntries
        .where((item) => item.syncStatus != SyncStatus.synced)
        .length;
    count += trainingEntries
        .where((item) => item.syncStatus != SyncStatus.synced)
        .length;
    count += favoriteProducts
        .where((item) => item.syncStatus != SyncStatus.synced)
        .length;
    count += receipts
        .where((item) => item.syncStatus != SyncStatus.synced)
        .length;
    return count;
  }

  AppData copyWith({
    Family? family,
    Member? currentMember,
    List<Member>? members,
    List<ShoppingItem>? shoppingItems,
    List<Meal>? meals,
    List<Recipe>? recipes,
    List<RecipeIngredient>? recipeIngredients,
    List<MealPlan>? mealPlans,
    List<CalendarEvent>? calendarEvents,
    List<NutritionGoal>? nutritionGoals,
    List<NutritionEntry>? nutritionEntries,
    List<TrainingEntry>? trainingEntries,
    List<FavoriteProduct>? favoriteProducts,
    List<Receipt>? receipts,
    bool clearFamily = false,
    bool clearMember = false,
  }) {
    return AppData(
      family: clearFamily ? null : family ?? this.family,
      currentMember: clearMember ? null : currentMember ?? this.currentMember,
      members: members ?? this.members,
      shoppingItems: shoppingItems ?? this.shoppingItems,
      meals: meals ?? this.meals,
      recipes: recipes ?? this.recipes,
      recipeIngredients: recipeIngredients ?? this.recipeIngredients,
      mealPlans: mealPlans ?? this.mealPlans,
      calendarEvents: calendarEvents ?? this.calendarEvents,
      nutritionGoals: nutritionGoals ?? this.nutritionGoals,
      nutritionEntries: nutritionEntries ?? this.nutritionEntries,
      trainingEntries: trainingEntries ?? this.trainingEntries,
      favoriteProducts: favoriteProducts ?? this.favoriteProducts,
      receipts: receipts ?? this.receipts,
    );
  }
}

class Family {
  const Family({
    required this.id,
    required this.familyId,
    required this.name,
    required this.code,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.isDeleted,
    required this.syncStatus,
    required this.createOnSync,
  });

  factory Family.fromJson(Map<String, dynamic> json) {
    return Family(
      id: json['id'].toString(),
      familyId: (json['familyId'] ?? json['family_id'] ?? json['id'])
          .toString(),
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      createdAt: dateFromJson(json['createdAt'] ?? json['created_at']),
      updatedAt: dateFromJson(json['updatedAt'] ?? json['updated_at']),
      createdBy:
          json['createdBy']?.toString() ?? json['created_by']?.toString() ?? '',
      isDeleted: boolFromJson(json['isDeleted'] ?? json['is_deleted']),
      syncStatus: syncStatusFromJson(json['syncStatus']),
      createOnSync: boolFromJson(json['createOnSync'] ?? true),
    );
  }

  factory Family.fromRemote(Map<String, dynamic> json) {
    final id = json['id'].toString();
    return Family(
      id: id,
      familyId: (json['family_id'] ?? id).toString(),
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      createdAt: dateFromJson(json['created_at']),
      updatedAt: dateFromJson(json['updated_at']),
      createdBy: json['created_by']?.toString() ?? '',
      isDeleted: boolFromJson(json['is_deleted'] ?? json['deleted']),
      syncStatus: SyncStatus.synced,
      createOnSync: true,
    );
  }

  final String id;
  final String familyId;
  final String name;
  final String code;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final bool isDeleted;
  final SyncStatus syncStatus;

  /// False means the user joined by code and sync should first find that family.
  final bool createOnSync;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'familyId': familyId,
      'name': name,
      'code': code,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'createdBy': createdBy,
      'isDeleted': isDeleted,
      'syncStatus': syncStatus.name,
      'createOnSync': createOnSync,
    };
  }

  Map<String, dynamic> toRemote() {
    return {
      'id': id,
      'family_id': familyId,
      'name': name,
      'code': code,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'created_by': createdBy,
      'is_deleted': isDeleted,
    };
  }

  Family copyWith({
    String? id,
    String? familyId,
    String? name,
    String? code,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    bool? isDeleted,
    SyncStatus? syncStatus,
    bool? createOnSync,
  }) {
    return Family(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      name: name ?? this.name,
      code: code ?? this.code,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      isDeleted: isDeleted ?? this.isDeleted,
      syncStatus: syncStatus ?? this.syncStatus,
      createOnSync: createOnSync ?? this.createOnSync,
    );
  }
}

class Member {
  const Member({
    required this.id,
    required this.familyId,
    required this.name,
    required this.email,
    required this.phone,
    required this.avatar,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.isDeleted,
    required this.syncStatus,
  });

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      id: json['id'].toString(),
      familyId: (json['familyId'] ?? json['family_id']).toString(),
      name: json['name']?.toString() ?? '',
      email: nullableString(json['email']),
      phone: nullableString(json['phone']),
      avatar: nullableString(json['avatar'] ?? json['avatar_url']),
      createdAt: dateFromJson(json['createdAt'] ?? json['created_at']),
      updatedAt: dateFromJson(json['updatedAt'] ?? json['updated_at']),
      createdBy:
          json['createdBy']?.toString() ?? json['created_by']?.toString() ?? '',
      isDeleted: boolFromJson(json['isDeleted'] ?? json['is_deleted']),
      syncStatus: syncStatusFromJson(json['syncStatus']),
    );
  }

  factory Member.fromRemote(Map<String, dynamic> json) {
    return Member(
      id: json['id'].toString(),
      familyId: json['family_id'].toString(),
      name: json['name']?.toString() ?? '',
      email: nullableString(json['email']),
      phone: nullableString(json['phone']),
      avatar: nullableString(json['avatar_url']),
      createdAt: dateFromJson(json['created_at']),
      updatedAt: dateFromJson(json['updated_at']),
      createdBy: json['created_by']?.toString() ?? '',
      isDeleted: boolFromJson(json['is_deleted'] ?? json['deleted']),
      syncStatus: SyncStatus.synced,
    );
  }

  final String id;
  final String familyId;
  final String name;
  final String? email;
  final String? phone;
  final String? avatar;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final bool isDeleted;
  final SyncStatus syncStatus;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'familyId': familyId,
      'name': name,
      'email': email,
      'phone': phone,
      'avatar': avatar,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'createdBy': createdBy,
      'isDeleted': isDeleted,
      'syncStatus': syncStatus.name,
    };
  }

  Map<String, dynamic> toRemote() {
    return {
      'id': id,
      'family_id': familyId,
      'name': name,
      'email': email,
      'phone': phone,
      'avatar_url': avatar,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'created_by': createdBy,
      'is_deleted': isDeleted,
    };
  }

  Member copyWith({
    String? id,
    String? familyId,
    String? name,
    String? email,
    String? phone,
    String? avatar,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    bool? isDeleted,
    SyncStatus? syncStatus,
  }) {
    return Member(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatar: avatar ?? this.avatar,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      isDeleted: isDeleted ?? this.isDeleted,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

class ShoppingItem {
  const ShoppingItem({
    required this.id,
    required this.familyId,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.authorName,
    required this.isPurchased,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.isDeleted,
    required this.syncStatus,
  });

  factory ShoppingItem.fromJson(Map<String, dynamic> json) {
    return ShoppingItem(
      id: json['id'].toString(),
      familyId: (json['familyId'] ?? json['family_id']).toString(),
      name: json['name']?.toString() ?? '',
      quantity: doubleFromJson(json['quantity']),
      unit: json['unit']?.toString() ?? '',
      authorName:
          json['authorName']?.toString() ??
          json['author_name']?.toString() ??
          '',
      isPurchased: boolFromJson(json['isPurchased'] ?? json['is_purchased']),
      createdAt: dateFromJson(json['createdAt'] ?? json['created_at']),
      updatedAt: dateFromJson(json['updatedAt'] ?? json['updated_at']),
      createdBy:
          json['createdBy']?.toString() ?? json['created_by']?.toString() ?? '',
      isDeleted: boolFromJson(json['isDeleted'] ?? json['is_deleted']),
      syncStatus: syncStatusFromJson(json['syncStatus']),
    );
  }

  factory ShoppingItem.fromRemote(Map<String, dynamic> json) {
    return ShoppingItem(
      id: json['id'].toString(),
      familyId: json['family_id'].toString(),
      name: json['name']?.toString() ?? '',
      quantity: doubleFromJson(json['quantity']),
      unit: json['unit']?.toString() ?? '',
      authorName: json['author_name']?.toString() ?? '',
      isPurchased: boolFromJson(json['is_purchased']),
      createdAt: dateFromJson(json['created_at']),
      updatedAt: dateFromJson(json['updated_at']),
      createdBy: json['created_by']?.toString() ?? '',
      isDeleted: boolFromJson(json['is_deleted'] ?? json['deleted']),
      syncStatus: SyncStatus.synced,
    );
  }

  final String id;
  final String familyId;
  final String name;
  final double quantity;
  final String unit;
  final String authorName;
  final bool isPurchased;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final bool isDeleted;
  final SyncStatus syncStatus;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'familyId': familyId,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'authorName': authorName,
      'isPurchased': isPurchased,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'createdBy': createdBy,
      'isDeleted': isDeleted,
      'syncStatus': syncStatus.name,
    };
  }

  Map<String, dynamic> toRemote() {
    return {
      'id': id,
      'family_id': familyId,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'author_name': authorName,
      'is_purchased': isPurchased,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'created_by': createdBy,
      'is_deleted': isDeleted,
    };
  }

  ShoppingItem copyWith({
    String? id,
    String? familyId,
    String? name,
    double? quantity,
    String? unit,
    String? authorName,
    bool? isPurchased,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    bool? isDeleted,
    SyncStatus? syncStatus,
  }) {
    return ShoppingItem(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      authorName: authorName ?? this.authorName,
      isPurchased: isPurchased ?? this.isPurchased,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      isDeleted: isDeleted ?? this.isDeleted,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

class Meal {
  const Meal({
    required this.id,
    required this.familyId,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.isDeleted,
    required this.syncStatus,
  });

  factory Meal.fromJson(Map<String, dynamic> json) {
    return Meal(
      id: json['id'].toString(),
      familyId: (json['familyId'] ?? json['family_id']).toString(),
      name: json['name']?.toString() ?? '',
      createdAt: dateFromJson(json['createdAt'] ?? json['created_at']),
      updatedAt: dateFromJson(json['updatedAt'] ?? json['updated_at']),
      createdBy:
          json['createdBy']?.toString() ?? json['created_by']?.toString() ?? '',
      isDeleted: boolFromJson(json['isDeleted'] ?? json['is_deleted']),
      syncStatus: syncStatusFromJson(json['syncStatus']),
    );
  }

  factory Meal.fromRemote(Map<String, dynamic> json) {
    return Meal(
      id: json['id'].toString(),
      familyId: json['family_id'].toString(),
      name: json['name']?.toString() ?? '',
      createdAt: dateFromJson(json['created_at']),
      updatedAt: dateFromJson(json['updated_at']),
      createdBy: json['created_by']?.toString() ?? '',
      isDeleted: boolFromJson(json['is_deleted'] ?? json['deleted']),
      syncStatus: SyncStatus.synced,
    );
  }

  final String id;
  final String familyId;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final bool isDeleted;
  final SyncStatus syncStatus;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'familyId': familyId,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'createdBy': createdBy,
      'isDeleted': isDeleted,
      'syncStatus': syncStatus.name,
    };
  }

  Map<String, dynamic> toRemote() {
    return {
      'id': id,
      'family_id': familyId,
      'name': name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'created_by': createdBy,
      'is_deleted': isDeleted,
    };
  }

  Meal copyWith({
    String? id,
    String? familyId,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    bool? isDeleted,
    SyncStatus? syncStatus,
  }) {
    return Meal(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      isDeleted: isDeleted ?? this.isDeleted,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

class Recipe {
  const Recipe({
    required this.id,
    required this.familyId,
    required this.mealId,
    required this.parentRecipeId,
    required this.name,
    required this.category,
    required this.instructions,
    required this.baseServings,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.isDeleted,
    required this.syncStatus,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'].toString(),
      familyId: (json['familyId'] ?? json['family_id']).toString(),
      mealId: (json['mealId'] ?? json['meal_id']).toString(),
      parentRecipeId: nullableString(
        json['parentRecipeId'] ?? json['parent_recipe_id'],
      ),
      name: json['name']?.toString() ?? '',
      category:
          json['category']?.toString() ??
          json['recipe_category']?.toString() ??
          'Tomek',
      instructions: json['instructions']?.toString() ?? '',
      baseServings: intFromJson(json['baseServings'] ?? json['base_servings']),
      createdAt: dateFromJson(json['createdAt'] ?? json['created_at']),
      updatedAt: dateFromJson(json['updatedAt'] ?? json['updated_at']),
      createdBy:
          json['createdBy']?.toString() ?? json['created_by']?.toString() ?? '',
      isDeleted: boolFromJson(json['isDeleted'] ?? json['is_deleted']),
      syncStatus: syncStatusFromJson(json['syncStatus']),
    );
  }

  factory Recipe.fromRemote(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'].toString(),
      familyId: json['family_id'].toString(),
      mealId: json['meal_id'].toString(),
      parentRecipeId: nullableString(json['parent_recipe_id']),
      name: json['name']?.toString() ?? '',
      category: json['recipe_category']?.toString() ?? 'Tomek',
      instructions: json['instructions']?.toString() ?? '',
      baseServings: intFromJson(json['base_servings']),
      createdAt: dateFromJson(json['created_at']),
      updatedAt: dateFromJson(json['updated_at']),
      createdBy: json['created_by']?.toString() ?? '',
      isDeleted: boolFromJson(json['is_deleted'] ?? json['deleted']),
      syncStatus: SyncStatus.synced,
    );
  }

  final String id;
  final String familyId;
  final String mealId;
  final String? parentRecipeId;
  final String name;
  final String category;
  final String instructions;
  final int baseServings;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final bool isDeleted;
  final SyncStatus syncStatus;

  bool get isSubRecipe => parentRecipeId != null;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'familyId': familyId,
      'mealId': mealId,
      'parentRecipeId': parentRecipeId,
      'name': name,
      'category': category,
      'instructions': instructions,
      'baseServings': baseServings,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'createdBy': createdBy,
      'isDeleted': isDeleted,
      'syncStatus': syncStatus.name,
    };
  }

  Map<String, dynamic> toRemote() {
    return {
      'id': id,
      'family_id': familyId,
      'meal_id': mealId,
      'parent_recipe_id': parentRecipeId,
      'name': name,
      'recipe_category': category,
      'instructions': instructions,
      'base_servings': baseServings,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'created_by': createdBy,
      'is_deleted': isDeleted,
    };
  }

  Recipe copyWith({
    String? id,
    String? familyId,
    String? mealId,
    String? parentRecipeId,
    String? name,
    String? category,
    String? instructions,
    int? baseServings,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    bool? isDeleted,
    SyncStatus? syncStatus,
  }) {
    return Recipe(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      mealId: mealId ?? this.mealId,
      parentRecipeId: parentRecipeId ?? this.parentRecipeId,
      name: name ?? this.name,
      category: category ?? this.category,
      instructions: instructions ?? this.instructions,
      baseServings: baseServings ?? this.baseServings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      isDeleted: isDeleted ?? this.isDeleted,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

class RecipeIngredient {
  const RecipeIngredient({
    required this.id,
    required this.familyId,
    required this.recipeId,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.isDeleted,
    required this.syncStatus,
  });

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) {
    return RecipeIngredient(
      id: json['id'].toString(),
      familyId: (json['familyId'] ?? json['family_id']).toString(),
      recipeId: (json['recipeId'] ?? json['recipe_id']).toString(),
      name: json['name']?.toString() ?? '',
      quantity: doubleFromJson(json['quantity']),
      unit: json['unit']?.toString() ?? '',
      createdAt: dateFromJson(json['createdAt'] ?? json['created_at']),
      updatedAt: dateFromJson(json['updatedAt'] ?? json['updated_at']),
      createdBy:
          json['createdBy']?.toString() ?? json['created_by']?.toString() ?? '',
      isDeleted: boolFromJson(json['isDeleted'] ?? json['is_deleted']),
      syncStatus: syncStatusFromJson(json['syncStatus']),
    );
  }

  factory RecipeIngredient.fromRemote(Map<String, dynamic> json) {
    return RecipeIngredient(
      id: json['id'].toString(),
      familyId: json['family_id'].toString(),
      recipeId: json['recipe_id'].toString(),
      name: json['name']?.toString() ?? '',
      quantity: doubleFromJson(json['quantity']),
      unit: json['unit']?.toString() ?? '',
      createdAt: dateFromJson(json['created_at']),
      updatedAt: dateFromJson(json['updated_at']),
      createdBy: json['created_by']?.toString() ?? '',
      isDeleted: boolFromJson(json['is_deleted'] ?? json['deleted']),
      syncStatus: SyncStatus.synced,
    );
  }

  final String id;
  final String familyId;
  final String recipeId;
  final String name;
  final double quantity;
  final String unit;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final bool isDeleted;
  final SyncStatus syncStatus;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'familyId': familyId,
      'recipeId': recipeId,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'createdBy': createdBy,
      'isDeleted': isDeleted,
      'syncStatus': syncStatus.name,
    };
  }

  Map<String, dynamic> toRemote() {
    return {
      'id': id,
      'family_id': familyId,
      'recipe_id': recipeId,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'created_by': createdBy,
      'is_deleted': isDeleted,
    };
  }

  RecipeIngredient copyWith({
    String? id,
    String? familyId,
    String? recipeId,
    String? name,
    double? quantity,
    String? unit,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    bool? isDeleted,
    SyncStatus? syncStatus,
  }) {
    return RecipeIngredient(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      recipeId: recipeId ?? this.recipeId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      isDeleted: isDeleted ?? this.isDeleted,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

class MealPlan {
  const MealPlan({
    required this.id,
    required this.familyId,
    required this.date,
    required this.mealId,
    required this.recipeIds,
    required this.servings,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.isDeleted,
    required this.syncStatus,
  });

  factory MealPlan.fromJson(Map<String, dynamic> json) {
    return MealPlan(
      id: json['id'].toString(),
      familyId: (json['familyId'] ?? json['family_id']).toString(),
      date: dateFromJson(json['date']),
      mealId: (json['mealId'] ?? json['meal_id']).toString(),
      recipeIds: stringListFromJson(json['recipeIds'] ?? json['recipe_ids']),
      servings: intFromJson(json['servings']),
      createdAt: dateFromJson(json['createdAt'] ?? json['created_at']),
      updatedAt: dateFromJson(json['updatedAt'] ?? json['updated_at']),
      createdBy:
          json['createdBy']?.toString() ?? json['created_by']?.toString() ?? '',
      isDeleted: boolFromJson(json['isDeleted'] ?? json['is_deleted']),
      syncStatus: syncStatusFromJson(json['syncStatus']),
    );
  }

  factory MealPlan.fromRemote(Map<String, dynamic> json) {
    return MealPlan(
      id: json['id'].toString(),
      familyId: json['family_id'].toString(),
      date: dateFromJson(json['date']),
      mealId: json['meal_id'].toString(),
      recipeIds: stringListFromJson(json['recipe_ids']),
      servings: intFromJson(json['servings']),
      createdAt: dateFromJson(json['created_at']),
      updatedAt: dateFromJson(json['updated_at']),
      createdBy: json['created_by']?.toString() ?? '',
      isDeleted: boolFromJson(json['is_deleted'] ?? json['deleted']),
      syncStatus: SyncStatus.synced,
    );
  }

  final String id;
  final String familyId;
  final DateTime date;
  final String mealId;
  final List<String> recipeIds;
  final int servings;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final bool isDeleted;
  final SyncStatus syncStatus;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'familyId': familyId,
      'date': date.toIso8601String(),
      'mealId': mealId,
      'recipeIds': recipeIds,
      'servings': servings,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'createdBy': createdBy,
      'isDeleted': isDeleted,
      'syncStatus': syncStatus.name,
    };
  }

  Map<String, dynamic> toRemote() {
    return {
      'id': id,
      'family_id': familyId,
      'date': date.toIso8601String(),
      'meal_id': mealId,
      'recipe_ids': recipeIds.join(','),
      'servings': servings,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'created_by': createdBy,
      'is_deleted': isDeleted,
    };
  }

  MealPlan copyWith({
    String? id,
    String? familyId,
    DateTime? date,
    String? mealId,
    List<String>? recipeIds,
    int? servings,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    bool? isDeleted,
    SyncStatus? syncStatus,
  }) {
    return MealPlan(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      date: date ?? this.date,
      mealId: mealId ?? this.mealId,
      recipeIds: recipeIds ?? this.recipeIds,
      servings: servings ?? this.servings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      isDeleted: isDeleted ?? this.isDeleted,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.familyId,
    required this.date,
    required this.title,
    required this.notes,
    required this.memberId,
    required this.isFamilyWide,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.isDeleted,
    required this.syncStatus,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id'].toString(),
      familyId: (json['familyId'] ?? json['family_id']).toString(),
      date: dateFromJson(json['date'] ?? json['event_date']),
      title: json['title']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      memberId: nullableString(json['memberId'] ?? json['member_id']),
      isFamilyWide: boolFromJson(
        json['isFamilyWide'] ?? json['is_family_wide'],
      ),
      createdAt: dateFromJson(json['createdAt'] ?? json['created_at']),
      updatedAt: dateFromJson(json['updatedAt'] ?? json['updated_at']),
      createdBy:
          json['createdBy']?.toString() ?? json['created_by']?.toString() ?? '',
      isDeleted: boolFromJson(json['isDeleted'] ?? json['is_deleted']),
      syncStatus: syncStatusFromJson(json['syncStatus']),
    );
  }

  factory CalendarEvent.fromRemote(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id'].toString(),
      familyId: json['family_id'].toString(),
      date: dateFromJson(json['event_date']),
      title: json['title']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      memberId: nullableString(json['member_id']),
      isFamilyWide: boolFromJson(json['is_family_wide']),
      createdAt: dateFromJson(json['created_at']),
      updatedAt: dateFromJson(json['updated_at']),
      createdBy: json['created_by']?.toString() ?? '',
      isDeleted: boolFromJson(json['is_deleted'] ?? json['deleted']),
      syncStatus: SyncStatus.synced,
    );
  }

  final String id;
  final String familyId;
  final DateTime date;
  final String title;
  final String notes;
  final String? memberId;
  final bool isFamilyWide;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final bool isDeleted;
  final SyncStatus syncStatus;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'familyId': familyId,
      'date': date.toIso8601String(),
      'title': title,
      'notes': notes,
      'memberId': memberId,
      'isFamilyWide': isFamilyWide,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'createdBy': createdBy,
      'isDeleted': isDeleted,
      'syncStatus': syncStatus.name,
    };
  }

  Map<String, dynamic> toRemote() {
    return {
      'id': id,
      'family_id': familyId,
      'event_date': date.toIso8601String(),
      'title': title,
      'notes': notes,
      'member_id': memberId,
      'is_family_wide': isFamilyWide,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'created_by': createdBy,
      'is_deleted': isDeleted,
    };
  }

  CalendarEvent copyWith({
    String? id,
    String? familyId,
    DateTime? date,
    String? title,
    String? notes,
    String? memberId,
    bool clearMemberId = false,
    bool? isFamilyWide,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    bool? isDeleted,
    SyncStatus? syncStatus,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      date: date ?? this.date,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      memberId: clearMemberId ? null : memberId ?? this.memberId,
      isFamilyWide: isFamilyWide ?? this.isFamilyWide,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      isDeleted: isDeleted ?? this.isDeleted,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

class NutritionGoal {
  const NutritionGoal({
    required this.id,
    required this.familyId,
    required this.memberId,
    required this.dailyCalories,
    required this.dailyProtein,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.isDeleted,
    required this.syncStatus,
  });

  factory NutritionGoal.fromJson(Map<String, dynamic> json) {
    return NutritionGoal(
      id: json['id'].toString(),
      familyId: (json['familyId'] ?? json['family_id']).toString(),
      memberId: (json['memberId'] ?? json['member_id']).toString(),
      dailyCalories: intFromJson(
        json['dailyCalories'] ?? json['daily_calories'],
      ),
      dailyProtein: doubleFromJson(
        json['dailyProtein'] ?? json['daily_protein'],
      ),
      createdAt: dateFromJson(json['createdAt'] ?? json['created_at']),
      updatedAt: dateFromJson(json['updatedAt'] ?? json['updated_at']),
      createdBy:
          json['createdBy']?.toString() ?? json['created_by']?.toString() ?? '',
      isDeleted: boolFromJson(json['isDeleted'] ?? json['is_deleted']),
      syncStatus: syncStatusFromJson(json['syncStatus']),
    );
  }

  factory NutritionGoal.fromRemote(Map<String, dynamic> json) {
    return NutritionGoal(
      id: json['id'].toString(),
      familyId: json['family_id'].toString(),
      memberId: json['member_id'].toString(),
      dailyCalories: intFromJson(json['daily_calories']),
      dailyProtein: doubleFromJson(json['daily_protein']),
      createdAt: dateFromJson(json['created_at']),
      updatedAt: dateFromJson(json['updated_at']),
      createdBy: json['created_by']?.toString() ?? '',
      isDeleted: boolFromJson(json['is_deleted'] ?? json['deleted']),
      syncStatus: SyncStatus.synced,
    );
  }

  final String id;
  final String familyId;
  final String memberId;
  final int dailyCalories;
  final double dailyProtein;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final bool isDeleted;
  final SyncStatus syncStatus;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'familyId': familyId,
      'memberId': memberId,
      'dailyCalories': dailyCalories,
      'dailyProtein': dailyProtein,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'createdBy': createdBy,
      'isDeleted': isDeleted,
      'syncStatus': syncStatus.name,
    };
  }

  Map<String, dynamic> toRemote() {
    return {
      'id': id,
      'family_id': familyId,
      'member_id': memberId,
      'daily_calories': dailyCalories,
      'daily_protein': dailyProtein,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'created_by': createdBy,
      'is_deleted': isDeleted,
    };
  }

  NutritionGoal copyWith({
    String? id,
    String? familyId,
    String? memberId,
    int? dailyCalories,
    double? dailyProtein,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    bool? isDeleted,
    SyncStatus? syncStatus,
  }) {
    return NutritionGoal(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      memberId: memberId ?? this.memberId,
      dailyCalories: dailyCalories ?? this.dailyCalories,
      dailyProtein: dailyProtein ?? this.dailyProtein,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      isDeleted: isDeleted ?? this.isDeleted,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

class NutritionEntry {
  const NutritionEntry({
    required this.id,
    required this.familyId,
    required this.memberId,
    required this.date,
    required this.calories,
    required this.protein,
    required this.note,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.isDeleted,
    required this.syncStatus,
  });

  factory NutritionEntry.fromJson(Map<String, dynamic> json) {
    return NutritionEntry(
      id: json['id'].toString(),
      familyId: (json['familyId'] ?? json['family_id']).toString(),
      memberId: (json['memberId'] ?? json['member_id']).toString(),
      date: dateFromJson(json['date'] ?? json['entry_date']),
      calories: intFromJson(json['calories']),
      protein: doubleFromJson(json['protein']),
      note: json['note']?.toString() ?? '',
      createdAt: dateFromJson(json['createdAt'] ?? json['created_at']),
      updatedAt: dateFromJson(json['updatedAt'] ?? json['updated_at']),
      createdBy:
          json['createdBy']?.toString() ?? json['created_by']?.toString() ?? '',
      isDeleted: boolFromJson(json['isDeleted'] ?? json['is_deleted']),
      syncStatus: syncStatusFromJson(json['syncStatus']),
    );
  }

  factory NutritionEntry.fromRemote(Map<String, dynamic> json) {
    return NutritionEntry(
      id: json['id'].toString(),
      familyId: json['family_id'].toString(),
      memberId: json['member_id'].toString(),
      date: dateFromJson(json['entry_date']),
      calories: intFromJson(json['calories']),
      protein: doubleFromJson(json['protein']),
      note: json['note']?.toString() ?? '',
      createdAt: dateFromJson(json['created_at']),
      updatedAt: dateFromJson(json['updated_at']),
      createdBy: json['created_by']?.toString() ?? '',
      isDeleted: boolFromJson(json['is_deleted'] ?? json['deleted']),
      syncStatus: SyncStatus.synced,
    );
  }

  final String id;
  final String familyId;
  final String memberId;
  final DateTime date;
  final int calories;
  final double protein;
  final String note;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final bool isDeleted;
  final SyncStatus syncStatus;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'familyId': familyId,
      'memberId': memberId,
      'date': date.toIso8601String(),
      'calories': calories,
      'protein': protein,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'createdBy': createdBy,
      'isDeleted': isDeleted,
      'syncStatus': syncStatus.name,
    };
  }

  Map<String, dynamic> toRemote() {
    return {
      'id': id,
      'family_id': familyId,
      'member_id': memberId,
      'entry_date': date.toIso8601String(),
      'calories': calories,
      'protein': protein,
      'note': note,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'created_by': createdBy,
      'is_deleted': isDeleted,
    };
  }

  NutritionEntry copyWith({
    String? id,
    String? familyId,
    String? memberId,
    DateTime? date,
    int? calories,
    double? protein,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    bool? isDeleted,
    SyncStatus? syncStatus,
  }) {
    return NutritionEntry(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      memberId: memberId ?? this.memberId,
      date: date ?? this.date,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      isDeleted: isDeleted ?? this.isDeleted,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

class TrainingEntry {
  const TrainingEntry({
    required this.id,
    required this.familyId,
    required this.memberId,
    required this.date,
    required this.activity,
    required this.durationMinutes,
    required this.note,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.isDeleted,
    required this.syncStatus,
  });

  factory TrainingEntry.fromJson(Map<String, dynamic> json) {
    return TrainingEntry(
      id: json['id'].toString(),
      familyId: (json['familyId'] ?? json['family_id']).toString(),
      memberId: (json['memberId'] ?? json['member_id']).toString(),
      date: dateFromJson(json['date'] ?? json['training_date']),
      activity: json['activity']?.toString() ?? 'Trening',
      durationMinutes: intFromJson(
        json['durationMinutes'] ?? json['duration_minutes'],
      ),
      note: json['note']?.toString() ?? '',
      createdAt: dateFromJson(json['createdAt'] ?? json['created_at']),
      updatedAt: dateFromJson(json['updatedAt'] ?? json['updated_at']),
      createdBy:
          json['createdBy']?.toString() ?? json['created_by']?.toString() ?? '',
      isDeleted: boolFromJson(json['isDeleted'] ?? json['is_deleted']),
      syncStatus: syncStatusFromJson(json['syncStatus']),
    );
  }

  factory TrainingEntry.fromRemote(Map<String, dynamic> json) {
    return TrainingEntry(
      id: json['id'].toString(),
      familyId: json['family_id'].toString(),
      memberId: json['member_id'].toString(),
      date: dateFromJson(json['training_date']),
      activity: json['activity']?.toString() ?? 'Trening',
      durationMinutes: intFromJson(json['duration_minutes']),
      note: json['note']?.toString() ?? '',
      createdAt: dateFromJson(json['created_at']),
      updatedAt: dateFromJson(json['updated_at']),
      createdBy: json['created_by']?.toString() ?? '',
      isDeleted: boolFromJson(json['is_deleted'] ?? json['deleted']),
      syncStatus: SyncStatus.synced,
    );
  }

  final String id;
  final String familyId;
  final String memberId;
  final DateTime date;
  final String activity;
  final int durationMinutes;
  final String note;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final bool isDeleted;
  final SyncStatus syncStatus;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'familyId': familyId,
      'memberId': memberId,
      'date': date.toIso8601String(),
      'activity': activity,
      'durationMinutes': durationMinutes,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'createdBy': createdBy,
      'isDeleted': isDeleted,
      'syncStatus': syncStatus.name,
    };
  }

  Map<String, dynamic> toRemote() {
    return {
      'id': id,
      'family_id': familyId,
      'member_id': memberId,
      'training_date': date.toIso8601String(),
      'activity': activity,
      'duration_minutes': durationMinutes,
      'note': note,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'created_by': createdBy,
      'is_deleted': isDeleted,
    };
  }

  TrainingEntry copyWith({
    String? id,
    String? familyId,
    String? memberId,
    DateTime? date,
    String? activity,
    int? durationMinutes,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    bool? isDeleted,
    SyncStatus? syncStatus,
  }) {
    return TrainingEntry(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      memberId: memberId ?? this.memberId,
      date: date ?? this.date,
      activity: activity ?? this.activity,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      isDeleted: isDeleted ?? this.isDeleted,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

class FavoriteProduct {
  const FavoriteProduct({
    required this.id,
    required this.familyId,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.isDeleted,
    required this.syncStatus,
  });

  factory FavoriteProduct.fromJson(Map<String, dynamic> json) {
    return FavoriteProduct(
      id: (json['id'] ?? '').toString(),
      familyId: (json['familyId'] ?? json['family_id'] ?? '').toString(),
      name: json['name']?.toString() ?? '',
      quantity: doubleFromJson(json['quantity']),
      unit: json['unit']?.toString() ?? 'szt.',
      createdAt: dateFromJson(json['createdAt'] ?? json['created_at']),
      updatedAt: dateFromJson(json['updatedAt'] ?? json['updated_at']),
      createdBy:
          json['createdBy']?.toString() ?? json['created_by']?.toString() ?? '',
      isDeleted: boolFromJson(json['isDeleted'] ?? json['is_deleted']),
      syncStatus: syncStatusFromJson(json['syncStatus']),
    );
  }

  factory FavoriteProduct.fromRemote(Map<String, dynamic> json) {
    return FavoriteProduct(
      id: json['id'].toString(),
      familyId: json['family_id'].toString(),
      name: json['name']?.toString() ?? '',
      quantity: doubleFromJson(json['quantity']),
      unit: json['unit']?.toString() ?? 'szt.',
      createdAt: dateFromJson(json['created_at']),
      updatedAt: dateFromJson(json['updated_at']),
      createdBy: json['created_by']?.toString() ?? '',
      isDeleted: boolFromJson(json['is_deleted'] ?? json['deleted']),
      syncStatus: SyncStatus.synced,
    );
  }

  final String id;
  final String familyId;
  final String name;
  final double quantity;
  final String unit;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final bool isDeleted;
  final SyncStatus syncStatus;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'familyId': familyId,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'createdBy': createdBy,
      'isDeleted': isDeleted,
      'syncStatus': syncStatus.name,
    };
  }

  Map<String, dynamic> toRemote() {
    return {
      'id': id,
      'family_id': familyId,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'created_by': createdBy,
      'is_deleted': isDeleted,
    };
  }

  FavoriteProduct copyWith({
    String? id,
    String? familyId,
    String? name,
    double? quantity,
    String? unit,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    bool? isDeleted,
    SyncStatus? syncStatus,
  }) {
    return FavoriteProduct(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      isDeleted: isDeleted ?? this.isDeleted,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

class Receipt {
  const Receipt({
    required this.id,
    required this.familyId,
    required this.storeName,
    required this.purchasedAt,
    required this.total,
    required this.rawText,
    required this.imageData,
    required this.imageMimeType,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.isDeleted,
    required this.syncStatus,
  });

  factory Receipt.fromJson(Map<String, dynamic> json) {
    return Receipt(
      id: json['id'].toString(),
      familyId: (json['familyId'] ?? json['family_id']).toString(),
      storeName:
          json['storeName']?.toString() ?? json['store_name']?.toString() ?? '',
      purchasedAt: dateFromJson(json['purchasedAt'] ?? json['purchased_at']),
      total: doubleFromJson(json['total']),
      rawText:
          json['rawText']?.toString() ?? json['raw_text']?.toString() ?? '',
      imageData: nullableString(json['imageData'] ?? json['image_data']),
      imageMimeType: nullableString(
        json['imageMimeType'] ?? json['image_mime_type'],
      ),
      items: receiptItemsFromJson(
        json['items'] ?? json['itemsJson'] ?? json['items_json'],
      ),
      createdAt: dateFromJson(json['createdAt'] ?? json['created_at']),
      updatedAt: dateFromJson(json['updatedAt'] ?? json['updated_at']),
      createdBy:
          json['createdBy']?.toString() ?? json['created_by']?.toString() ?? '',
      isDeleted: boolFromJson(json['isDeleted'] ?? json['is_deleted']),
      syncStatus: syncStatusFromJson(json['syncStatus']),
    );
  }

  factory Receipt.fromRemote(Map<String, dynamic> json) {
    return Receipt(
      id: json['id'].toString(),
      familyId: json['family_id'].toString(),
      storeName: json['store_name']?.toString() ?? '',
      purchasedAt: dateFromJson(json['purchased_at']),
      total: doubleFromJson(json['total']),
      rawText: json['raw_text']?.toString() ?? '',
      imageData: nullableString(json['image_data']),
      imageMimeType: nullableString(json['image_mime_type']),
      items: receiptItemsFromJson(json['items_json']),
      createdAt: dateFromJson(json['created_at']),
      updatedAt: dateFromJson(json['updated_at']),
      createdBy: json['created_by']?.toString() ?? '',
      isDeleted: boolFromJson(json['is_deleted'] ?? json['deleted']),
      syncStatus: SyncStatus.synced,
    );
  }

  final String id;
  final String familyId;
  final String storeName;
  final DateTime purchasedAt;
  final double total;
  final String rawText;
  final String? imageData;
  final String? imageMimeType;
  final List<ReceiptItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final bool isDeleted;
  final SyncStatus syncStatus;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'familyId': familyId,
      'storeName': storeName,
      'purchasedAt': purchasedAt.toIso8601String(),
      'total': total,
      'rawText': rawText,
      'imageData': imageData,
      'imageMimeType': imageMimeType,
      'items': items.map((item) => item.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'createdBy': createdBy,
      'isDeleted': isDeleted,
      'syncStatus': syncStatus.name,
    };
  }

  Map<String, dynamic> toRemote() {
    return {
      'id': id,
      'family_id': familyId,
      'store_name': storeName,
      'purchased_at': purchasedAt.toIso8601String(),
      'total': total,
      'raw_text': rawText,
      'image_data': imageData,
      'image_mime_type': imageMimeType,
      'items_json': jsonEncode(items.map((item) => item.toJson()).toList()),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'created_by': createdBy,
      'is_deleted': isDeleted,
    };
  }

  Receipt copyWith({
    String? id,
    String? familyId,
    String? storeName,
    DateTime? purchasedAt,
    double? total,
    String? rawText,
    String? imageData,
    String? imageMimeType,
    List<ReceiptItem>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    bool? isDeleted,
    SyncStatus? syncStatus,
  }) {
    return Receipt(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      storeName: storeName ?? this.storeName,
      purchasedAt: purchasedAt ?? this.purchasedAt,
      total: total ?? this.total,
      rawText: rawText ?? this.rawText,
      imageData: imageData ?? this.imageData,
      imageMimeType: imageMimeType ?? this.imageMimeType,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      isDeleted: isDeleted ?? this.isDeleted,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

List<ReceiptItem> receiptItemsFromJson(Object? value) {
  Object? decoded = value;
  if (decoded is String && decoded.trim().isNotEmpty) {
    try {
      decoded = jsonDecode(decoded);
    } catch (_) {
      decoded = const [];
    }
  }
  if (decoded is! List) {
    return const [];
  }
  return decoded
      .whereType<Map>()
      .map((item) => ReceiptItem.fromJson(Map<String, dynamic>.from(item)))
      .toList();
}

class ReceiptItem {
  const ReceiptItem({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.price,
  });

  factory ReceiptItem.fromJson(Map<String, dynamic> json) {
    return ReceiptItem(
      name: json['name']?.toString() ?? '',
      quantity: doubleFromJson(json['quantity']),
      unit: json['unit']?.toString() ?? 'szt.',
      price: doubleFromJson(json['price']),
    );
  }

  final String name;
  final double quantity;
  final String unit;
  final double price;

  Map<String, dynamic> toJson() {
    return {'name': name, 'quantity': quantity, 'unit': unit, 'price': price};
  }
}

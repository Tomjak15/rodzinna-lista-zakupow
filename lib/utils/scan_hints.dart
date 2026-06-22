import '../data/product_catalog.dart';
import '../models/entities.dart';

List<String> buildProductScanHints(AppData data, {int limit = 260}) {
  final names = <String>{};

  for (final item in productCatalog) {
    _addHint(names, item.name);
  }
  for (final item in data.activeFavoriteProducts) {
    _addHint(names, item.name);
  }
  for (final item in data.activeShoppingItems) {
    _addHint(names, item.name);
  }
  for (final receipt in data.activeReceipts) {
    for (final item in receipt.items) {
      _addHint(names, item.name);
    }
  }

  return _sortedLimitedHints(names, limit);
}

List<String> buildIngredientScanHints(AppData data, {int limit = 280}) {
  final names = <String>{};

  for (final item in buildProductScanHints(data, limit: limit)) {
    _addHint(names, item);
  }
  for (final ingredient in data.activeRecipeIngredients) {
    _addHint(names, ingredient.name);
  }

  return _sortedLimitedHints(names, limit);
}

void _addHint(Set<String> names, String value) {
  final cleaned = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (cleaned.length < 2 || cleaned.length > 48) {
    return;
  }
  names.add(cleaned);
}

List<String> _sortedLimitedHints(Set<String> names, int limit) {
  final sorted = names.toList()
    ..sort((a, b) {
      final lengthCompare = a.length.compareTo(b.length);
      return lengthCompare == 0 ? a.compareTo(b) : lengthCompare;
    });
  return sorted.take(limit).toList(growable: false);
}

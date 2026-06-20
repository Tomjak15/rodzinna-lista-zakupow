import '../models/entities.dart';
import '../models/ingredient_draft.dart';

const defaultIngredientUnit = 'szt.';

List<IngredientDraft> parseIngredientLines(String value) {
  final parsed = value
      .split(RegExp(r'[\r\n]+'))
      .map(_parseIngredientLine)
      .nonNulls
      .toList();
  return mergeIngredientDrafts(parsed);
}

List<IngredientDraft> mergeIngredientDrafts(Iterable<IngredientDraft> items) {
  final grouped = <String, IngredientDraft>{};
  for (final item in items) {
    final name = _cleanName(item.name);
    final unit = normalizeIngredientUnit(item.unit);
    if (name.isEmpty || item.quantity <= 0) {
      continue;
    }

    final key = '${normalizeName(name)}|${normalizeName(unit)}';
    final existing = grouped[key];
    grouped[key] = IngredientDraft(
      name: existing?.name ?? name,
      quantity: (existing?.quantity ?? 0) + item.quantity,
      unit: unit,
    );
  }
  return grouped.values.toList(growable: false);
}

String normalizeIngredientUnit(String value) {
  final cleaned = _cleanUnitText(value);
  if (cleaned.isEmpty) {
    return defaultIngredientUnit;
  }
  return _unitAliases[_unitKey(cleaned)] ?? cleaned;
}

String ingredientDraftsToText(Iterable<IngredientDraft> ingredients) {
  return ingredients
      .map(
        (ingredient) =>
            '${ingredient.name}; ${formatQuantity(ingredient.quantity)}; ${ingredient.unit}',
      )
      .join('\n');
}

String recipeIngredientsToText(Iterable<RecipeIngredient> ingredients) {
  return ingredientDraftsToText(
    ingredients.map(
      (ingredient) => IngredientDraft(
        name: ingredient.name,
        quantity: ingredient.quantity,
        unit: ingredient.unit,
      ),
    ),
  );
}

IngredientDraft? _parseIngredientLine(String rawLine) {
  final line = _cleanLine(rawLine);
  if (line.isEmpty) {
    return null;
  }

  final semicolonDraft = _parseSemicolonLine(line);
  if (semicolonDraft != null) {
    return semicolonDraft;
  }

  final tokens = line
      .split(RegExp(r'\s+'))
      .map(_cleanToken)
      .where((token) => token.isNotEmpty && token.toLowerCase() != 'x')
      .toList();
  if (tokens.isEmpty) {
    return null;
  }

  final quantityIndex = tokens.indexWhere(
    (token) => _parseQuantity(token) != null,
  );
  if (quantityIndex == -1) {
    return _draft(
      name: tokens.join(' '),
      quantity: 1,
      unit: defaultIngredientUnit,
    );
  }

  final quantity = _parseQuantity(tokens[quantityIndex]) ?? 0;
  if (quantityIndex == 0) {
    return _parseQuantityFirst(tokens, quantity);
  }
  return _parseNameFirst(tokens, quantityIndex, quantity);
}

IngredientDraft? _parseSemicolonLine(String line) {
  if (!line.contains(';')) {
    return null;
  }
  final parts = line
      .split(';')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.length < 2) {
    return null;
  }

  if (parts.length >= 3) {
    return _draft(
      name: parts.first,
      quantity: _parseQuantity(parts[1]) ?? 0,
      unit: parts.sublist(2).join(' '),
    );
  }

  final detailTokens = parts[1]
      .split(RegExp(r'\s+'))
      .map(_cleanToken)
      .where((token) => token.isNotEmpty)
      .toList();
  final quantityIndex = detailTokens.indexWhere(
    (token) => _parseQuantity(token) != null,
  );
  if (quantityIndex == -1) {
    return _draft(name: parts.first, quantity: 1, unit: detailTokens.join(' '));
  }

  final unitTokens = [
    ...detailTokens.take(quantityIndex),
    ...detailTokens.skip(quantityIndex + 1),
  ];
  return _draft(
    name: parts.first,
    quantity: _parseQuantity(detailTokens[quantityIndex]) ?? 0,
    unit: unitTokens.join(' '),
  );
}

IngredientDraft? _parseQuantityFirst(List<String> tokens, double quantity) {
  if (tokens.length == 1) {
    return null;
  }

  final afterQuantity = tokens.sublist(1);
  if (afterQuantity.isNotEmpty && _isKnownUnit(afterQuantity.first)) {
    return _draft(
      name: afterQuantity.skip(1).join(' '),
      quantity: quantity,
      unit: afterQuantity.first,
    );
  }

  if (afterQuantity.length >= 2 && _isKnownUnit(afterQuantity.last)) {
    return _draft(
      name: afterQuantity.take(afterQuantity.length - 1).join(' '),
      quantity: quantity,
      unit: afterQuantity.last,
    );
  }

  return _draft(
    name: afterQuantity.join(' '),
    quantity: quantity,
    unit: defaultIngredientUnit,
  );
}

IngredientDraft? _parseNameFirst(
  List<String> tokens,
  int quantityIndex,
  double quantity,
) {
  final beforeQuantity = tokens.take(quantityIndex).toList();
  final afterQuantity = tokens.skip(quantityIndex + 1).toList();
  if (beforeQuantity.isEmpty) {
    return null;
  }

  if (afterQuantity.isEmpty) {
    return _draft(
      name: beforeQuantity.join(' '),
      quantity: quantity,
      unit: defaultIngredientUnit,
    );
  }

  final unit = afterQuantity.first;
  final nameParts = [
    ...beforeQuantity,
    if (afterQuantity.length > 1) ...afterQuantity.skip(1),
  ];
  return _draft(name: nameParts.join(' '), quantity: quantity, unit: unit);
}

IngredientDraft? _draft({
  required String name,
  required double quantity,
  required String unit,
}) {
  final cleanedName = _cleanName(name);
  if (cleanedName.isEmpty || quantity <= 0) {
    return null;
  }
  return IngredientDraft(
    name: cleanedName,
    quantity: quantity,
    unit: normalizeIngredientUnit(unit),
  );
}

double? _parseQuantity(String rawValue) {
  var value = _cleanToken(rawValue).toLowerCase();
  if (value.startsWith('x')) {
    value = value.substring(1);
  }
  if (value.endsWith('x')) {
    value = value.substring(0, value.length - 1);
  }
  value = value.replaceAll(',', '.');
  final fractionParts = value.split('/');
  if (fractionParts.length == 2) {
    final numerator = double.tryParse(fractionParts[0]);
    final denominator = double.tryParse(fractionParts[1]);
    if (numerator != null && denominator != null && denominator != 0) {
      return numerator / denominator;
    }
  }
  return double.tryParse(value);
}

bool _isKnownUnit(String value) {
  return _unitAliases.containsKey(_unitKey(value));
}

String _cleanLine(String value) {
  return value
      .replaceAll(RegExp(r'^[\s\-*•]+'), '')
      .replaceAll(RegExp(r'\s+[xX]\s+'), ' ')
      .trim();
}

String _cleanName(String value) {
  return value
      .split(RegExp(r'\s+'))
      .map(_cleanToken)
      .where((token) => token.isNotEmpty)
      .join(' ')
      .trim();
}

String _cleanUnitText(String value) {
  return value
      .split(RegExp(r'\s+'))
      .map(_cleanToken)
      .where((token) => token.isNotEmpty)
      .join(' ')
      .trim();
}

String _cleanToken(String value) {
  return value
      .trim()
      .replaceAll(RegExp(r'^[,.;:()\[\]{}+\-]+'), '')
      .replaceAll(RegExp(r'[,.;:()\[\]{}+\-]+$'), '');
}

String _unitKey(String value) {
  return _cleanUnitText(value)
      .toLowerCase()
      .replaceAll('.', '')
      .replaceAll('ą', 'a')
      .replaceAll('ć', 'c')
      .replaceAll('ę', 'e')
      .replaceAll('ł', 'l')
      .replaceAll('ń', 'n')
      .replaceAll('ó', 'o')
      .replaceAll('ś', 's')
      .replaceAll('ż', 'z')
      .replaceAll('ź', 'z');
}

const _unitAliases = {
  'szt': defaultIngredientUnit,
  'sztuka': defaultIngredientUnit,
  'sztuki': defaultIngredientUnit,
  'sztuk': defaultIngredientUnit,
  'g': 'g',
  'gram': 'g',
  'gramy': 'g',
  'gramow': 'g',
  'gr': 'g',
  'kg': 'kg',
  'kilogram': 'kg',
  'kilogramy': 'kg',
  'kilogramow': 'kg',
  'ml': 'ml',
  'mililitr': 'ml',
  'mililitry': 'ml',
  'mililitrow': 'ml',
  'l': 'l',
  'litr': 'l',
  'litry': 'l',
  'litrow': 'l',
  'lyzka': 'łyżka',
  'lyzki': 'łyżka',
  'lyzek': 'łyżka',
  'lyzeczka': 'łyżeczka',
  'lyzeczki': 'łyżeczka',
  'lyzeczek': 'łyżeczka',
  'szklanka': 'szklanka',
  'szklanki': 'szklanka',
  'szklanek': 'szklanka',
  'opak': 'opak.',
  'op': 'opak.',
  'opakowanie': 'opak.',
  'opakowania': 'opak.',
  'puszka': 'puszka',
  'puszki': 'puszka',
  'puszek': 'puszka',
  'plaster': 'plaster',
  'plastry': 'plaster',
  'plastrow': 'plaster',
  'zabek': 'ząbek',
  'zabki': 'ząbek',
  'peczek': 'pęczek',
  'peczki': 'pęczek',
  'garsc': 'garść',
  'garsci': 'garść',
  'kostka': 'kostka',
  'kostki': 'kostka',
  'szczypta': 'szczypta',
  'szczypty': 'szczypta',
  'saszetka': 'saszetka',
  'saszetki': 'saszetka',
  'kubek': 'kubek',
  'kubki': 'kubek',
};

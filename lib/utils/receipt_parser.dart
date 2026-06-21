import '../models/entities.dart';
import 'ingredient_parser.dart';

class ParsedReceipt {
  const ParsedReceipt({
    required this.items,
    required this.total,
    required this.storeName,
  });

  final List<ReceiptItem> items;
  final double total;
  final String? storeName;
}

ParsedReceipt parseReceiptText(String rawText) {
  final lines = rawText
      .split(RegExp(r'\r?\n'))
      .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
      .where((line) => line.isNotEmpty)
      .toList();

  final items = <ReceiptItem>[];
  double? detectedTotal;

  for (var index = 0; index < lines.length; index++) {
    final line = lines[index];
    final lowerLine = _normalizeForSearch(line);
    final price = _lastPrice(line);

    if (_isTotalLine(lowerLine)) {
      detectedTotal =
          price?.value ?? _nearbyPrice(lines, index)?.value ?? detectedTotal;
      continue;
    }
    if (_shouldSkipLine(lowerLine) || price == null) {
      continue;
    }

    final item = _itemFromLine(
      line,
      price,
      previousLine: index > 0 ? lines[index - 1] : null,
    );
    if (item != null) {
      items.add(item);
    }
  }

  if (items.isEmpty) {
    items.addAll(_itemsFromSplitNameAndPriceLines(lines));
  }

  final fallbackTotal = items.fold<double>(0, (sum, item) => sum + item.price);
  return ParsedReceipt(
    items: items,
    total: detectedTotal ?? fallbackTotal,
    storeName: _detectStoreName(lines),
  );
}

ReceiptItem? _itemFromLine(String line, _Price price, {String? previousLine}) {
  var beforePrice = line.substring(0, line.lastIndexOf(price.raw)).trim();
  if (_lineHasOnlyPrice(line) && previousLine != null) {
    beforePrice = previousLine;
  }

  final parsedQuantity = _quantityFromLine(beforePrice);
  var name = beforePrice
      .replaceAll(_quantityPattern, ' ')
      .replaceAll(RegExp(r'^\d+(?:[,.]\d+)?\s*x\s+', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'\b\d+\s*x\s*$', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'\b[A-Z]\b$'), ' ')
      .replaceAll(
        RegExp(r'\b(kg|g|l|ml|szt|op|opak)\b$', caseSensitive: false),
        ' ',
      )
      .replaceAll(RegExp(r'[*#:;]'), ' ')
      .replaceAll(RegExp(r'\b\d{5,}\b'), ' ')
      .replaceAll(RegExp(r'^[0-9]{2,}\s+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  if (!_isProductName(name)) {
    return null;
  }

  return ReceiptItem(
    name: _titleCaseProduct(name),
    quantity: parsedQuantity.quantity,
    unit: normalizeIngredientUnit(parsedQuantity.unit),
    price: price.value,
  );
}

List<ReceiptItem> _itemsFromSplitNameAndPriceLines(List<String> lines) {
  final items = <ReceiptItem>[];
  for (var index = 1; index < lines.length; index++) {
    final price = _lastPrice(lines[index]);
    if (price == null || !_lineHasOnlyPrice(lines[index])) {
      continue;
    }
    final previous = lines[index - 1];
    final lowerPrevious = _normalizeForSearch(previous);
    if (_shouldSkipLine(lowerPrevious) || _isTotalLine(lowerPrevious)) {
      continue;
    }
    final item = _itemFromLine('$previous ${price.raw}', price);
    if (item != null) {
      items.add(item);
    }
  }
  return items;
}

String? _detectStoreName(List<String> lines) {
  const knownStores = {
    'biedronka': 'Biedronka',
    'lidl': 'Lidl',
    'kaufland': 'Kaufland',
    'aldi': 'Aldi',
    'carrefour': 'Carrefour',
    'auchan': 'Auchan',
    'dino': 'Dino',
    'zabka': 'Żabka',
    'żabka': 'Żabka',
    'netto': 'Netto',
    'stokrotka': 'Stokrotka',
    'intermarche': 'Intermarche',
    'lewiatan': 'Lewiatan',
    'polomarket': 'Polomarket',
    'rossmann': 'Rossmann',
    'hebe': 'Hebe',
    'pepco': 'Pepco',
    'action': 'Action',
    'ikea': 'Ikea',
    'castorama': 'Castorama',
    'obi': 'OBI',
    'media expert': 'Media Expert',
  };

  for (final line in lines.take(14)) {
    final normalized = _normalizeForSearch(line);
    for (final entry in knownStores.entries) {
      if (normalized.contains(entry.key)) {
        return entry.value;
      }
    }
  }

  for (final line in lines.take(8)) {
    final candidate = line
        .replaceAll(RegExp(r'[^A-Za-zĄĆĘŁŃÓŚŹŻąćęłńóśźż0-9 &.-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final lower = _normalizeForSearch(candidate);
    if (candidate.length >= 3 &&
        candidate.length <= 36 &&
        RegExp(r'[A-Za-zĄĆĘŁŃÓŚŹŻąćęłńóśźż]').hasMatch(candidate) &&
        !_shouldSkipLine(lower) &&
        !lower.contains('sp z') &&
        !lower.contains('s a') &&
        !lower.contains('ul ') &&
        !RegExp(r'\d{4,}').hasMatch(candidate)) {
      return _titleCase(candidate);
    }
  }
  return null;
}

bool _isProductName(String value) {
  final name = value.trim();
  if (name.length < 2) {
    return false;
  }
  if (!RegExp(r'[A-Za-zĄĆĘŁŃÓŚŹŻąćęłńóśźż]').hasMatch(name)) {
    return false;
  }
  if (RegExp(r'^\d+$').hasMatch(name)) {
    return false;
  }
  if (RegExp(r'\b\d{8,}\b').hasMatch(name)) {
    return false;
  }
  return true;
}

bool _isTotalLine(String line) {
  return line.contains('suma') ||
      line.contains('razem') ||
      line.contains('lacznie') ||
      line.contains('łącznie') ||
      line.contains('do zaplaty') ||
      line.contains('do zapłaty') ||
      line.contains('naleznosc') ||
      line.contains('należność') ||
      line.contains('kwota') ||
      line == 'total';
}

bool _shouldSkipLine(String line) {
  const skipped = [
    'paragon',
    'fiskalny',
    'nip',
    'sprzedaz',
    'sprzedaż',
    'podatek',
    'vat',
    'kasa',
    'kasjer',
    'terminal',
    'platnosc',
    'płatność',
    'karta',
    'gotowka',
    'gotówka',
    'reszta',
    'data',
    'godz',
    'adres',
    'nr wydruku',
    'nr paragonu',
    'numer',
    'www',
    'bon',
    'rabat',
  ];
  return skipped.any((word) => line.contains(word));
}

_Price? _nearbyPrice(List<String> lines, int index) {
  for (final offset in [0, 1, -1, 2]) {
    final nextIndex = index + offset;
    if (nextIndex < 0 || nextIndex >= lines.length) {
      continue;
    }
    final price = _lastPrice(lines[nextIndex]);
    if (price != null) {
      return price;
    }
  }
  return null;
}

_Price? _lastPrice(String line) {
  final matches = RegExp(
    r'(?<!\d)(\d{1,5}[,.]\d{2})(?:\s*(?:zł|zl|pln|[A-Z]))?(?=\s|$)',
    caseSensitive: false,
  ).allMatches(line);
  final match = matches.isEmpty ? null : matches.last;
  if (match == null) {
    return null;
  }
  final raw = match.group(1)!;
  return _Price(
    raw: raw,
    value: double.tryParse(raw.replaceAll(',', '.')) ?? 0,
  );
}

bool _lineHasOnlyPrice(String line) {
  final price = _lastPrice(line);
  if (price == null) {
    return false;
  }
  final stripped = line
      .replaceAll(price.raw, '')
      .replaceAll(RegExp(r'\b(zł|zl|pln|[A-Z])\b', caseSensitive: false), '')
      .replaceAll(RegExp(r'[\s:;.-]+'), '');
  return stripped.isEmpty;
}

final _quantityPattern = RegExp(
  r'(\d+(?:[,.]\d+)?)\s*(kg|g|l|ml|szt|op|opak)\.?',
  caseSensitive: false,
);

_ParsedQuantity _quantityFromLine(String line) {
  final multiplierMatch = RegExp(
    r'\b(\d+(?:[,.]\d+)?)\s*x\b',
    caseSensitive: false,
  ).firstMatch(line);
  if (multiplierMatch != null) {
    return _ParsedQuantity(
      quantity: doubleFromJson(multiplierMatch.group(1)),
      unit: 'szt.',
    );
  }

  final quantityMatch = _quantityPattern.firstMatch(line);
  if (quantityMatch != null) {
    return _ParsedQuantity(
      quantity: doubleFromJson(quantityMatch.group(1)),
      unit: quantityMatch.group(2) ?? 'szt.',
    );
  }

  return const _ParsedQuantity(quantity: 1, unit: 'szt.');
}

String _normalizeForSearch(String value) {
  return value
      .toLowerCase()
      .replaceAll('ą', 'a')
      .replaceAll('ć', 'c')
      .replaceAll('ę', 'e')
      .replaceAll('ł', 'l')
      .replaceAll('ń', 'n')
      .replaceAll('ó', 'o')
      .replaceAll('ś', 's')
      .replaceAll('ź', 'z')
      .replaceAll('ż', 'z')
      .replaceAll(RegExp(r'[^a-z0-9,. ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _titleCase(String value) {
  return value
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) {
        if (part.length <= 2 && part == part.toUpperCase()) {
          return part;
        }
        return part[0].toUpperCase() + part.substring(1).toLowerCase();
      })
      .join(' ');
}

String _titleCaseProduct(String value) {
  if (value == value.toUpperCase()) {
    return _titleCase(value);
  }
  return value;
}

class _Price {
  const _Price({required this.raw, required this.value});

  final String raw;
  final double value;
}

class _ParsedQuantity {
  const _ParsedQuantity({required this.quantity, required this.unit});

  final double quantity;
  final String unit;
}

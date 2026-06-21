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
    if (item != null && !_containsSameItem(items, item)) {
      items.add(item);
    }
  }

  final fallbackTotal = items.fold<double>(0, (sum, item) => sum + item.price);
  return ParsedReceipt(
    items: items,
    total: detectedTotal ?? fallbackTotal,
    storeName: _detectStoreName(lines),
  );
}

ReceiptItem? _itemFromLine(String line, _Price price, {String? previousLine}) {
  var beforePrice = line.substring(0, price.start).trim();
  final previousCanBeName =
      previousLine != null &&
      !_shouldSkipLine(_normalizeForSearch(previousLine)) &&
      !_isTotalLine(_normalizeForSearch(previousLine)) &&
      _lastPrice(previousLine) == null &&
      _isProductName(previousLine);

  if (previousCanBeName &&
      (_lineHasOnlyPrice(line) || _lineLooksLikePriceContinuation(line))) {
    beforePrice = '$previousLine $beforePrice';
  }

  final parsedQuantity = _quantityFromLine(beforePrice);
  var name = beforePrice
      .replaceAll(_unitPricePattern, ' ')
      .replaceAll(_pricePattern, ' ')
      .replaceAll(_quantityPattern, ' ')
      .replaceAll(RegExp(r'\b\d+(?:[,.]\d+)?\s*x\b', caseSensitive: false), ' ')
      .replaceAll(
        RegExp(r'\bx\s*\d+(?:[,. ]\d{2})\b', caseSensitive: false),
        ' ',
      )
      .replaceAll(RegExp(r'\bx\b', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'\bVAT\s*[A-Z]\b', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'\b[A-Z]\b$'), ' ')
      .replaceAll(
        RegExp(r'\b(kg|g|l|ml|szt|szt\.|op|opak)\b$', caseSensitive: false),
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
        _letterPattern.hasMatch(candidate) &&
        !_shouldSkipLine(lower) &&
        !_isTotalLine(lower) &&
        !lower.contains('sp z') &&
        !lower.contains('s a') &&
        !lower.contains('ul ') &&
        !RegExp(r'\d{4,}').hasMatch(candidate)) {
      return _titleCase(candidate);
    }
  }
  return null;
}

bool _containsSameItem(List<ReceiptItem> items, ReceiptItem item) {
  return items.any(
    (existing) =>
        _normalizeForSearch(existing.name) == _normalizeForSearch(item.name) &&
        existing.price == item.price,
  );
}

bool _isProductName(String value) {
  final name = value.trim();
  if (name.length < 2) {
    return false;
  }
  if (!_letterPattern.hasMatch(name)) {
    return false;
  }
  if (RegExp(r'^\d+$').hasMatch(name)) {
    return false;
  }
  if (RegExp(r'\b\d{8,}\b').hasMatch(name)) {
    return false;
  }
  final lower = _normalizeForSearch(name);
  return !_shouldSkipLine(lower) && !_isTotalLine(lower);
}

bool _isTotalLine(String line) {
  return line.contains('suma') ||
      line.contains('razem') ||
      line.contains('lacznie') ||
      line.contains('do zaplaty') ||
      line.contains('naleznosc') ||
      line.contains('kwota') ||
      line.contains('total');
}

bool _shouldSkipLine(String line) {
  const skipped = [
    'paragon',
    'fiskalny',
    'nip',
    'sprzedaz',
    'podatek',
    'vat',
    'kasa',
    'kasjer',
    'terminal',
    'platnosc',
    'karta',
    'gotowka',
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
    'wydruk',
    'transakcja',
    'autoryzacja',
    'dziekujemy',
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
  final matches = _pricePattern.allMatches(line).toList();
  if (matches.isEmpty) {
    return null;
  }
  final match = matches.last;
  final whole = match.group(0)!;
  final amount = '${match.group(1)!}.${match.group(3)!}';
  return _Price(
    raw: whole,
    start: match.start,
    value: double.tryParse(amount) ?? 0,
  );
}

bool _lineHasOnlyPrice(String line) {
  final stripped = _stripPriceNoise(line);
  return stripped.isEmpty;
}

bool _lineLooksLikePriceContinuation(String line) {
  final stripped = _stripPriceNoise(line)
      .replaceAll(_quantityPattern, ' ')
      .replaceAll(RegExp(r'\b\d+(?:[,.]\d+)?\s*x\b', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'\bx\b', caseSensitive: false), ' ')
      .replaceAll(
        RegExp(r'\b(kg|g|l|ml|szt|op|opak)\b', caseSensitive: false),
        ' ',
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return stripped.isEmpty;
}

String _stripPriceNoise(String line) {
  return line
      .replaceAll(_pricePattern, ' ')
      .replaceAll(RegExp(r'\b(zł|zl|pln)\b', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'\b[A-Z]\b'), ' ')
      .replaceAll(RegExp(r'[\s:;.-]+'), ' ')
      .trim();
}

final _letterPattern = RegExp(r'[A-Za-zĄĆĘŁŃÓŚŹŻąćęłńóśźż]');

final _pricePattern = RegExp(
  r'(?<!\d)(\d{1,5})\s*([,.\-:]|\s+)\s*(\d{2})(?!\d)(?:\s*(?:zł|zl|pln|[A-Z]))?',
  caseSensitive: false,
);

final _unitPricePattern = RegExp(
  r'\b\d{1,5}(?:[,.]\d{2})\s*/\s*(kg|g|l|ml|szt)\b',
  caseSensitive: false,
);

final _quantityPattern = RegExp(
  r'(\d+(?:[,.]\d+)?)\s*(kg|g|l|ml|szt|szt\.|op|opak)\.?',
  caseSensitive: false,
);

_ParsedQuantity _quantityFromLine(String line) {
  final quantityMatch = _quantityPattern.firstMatch(line);
  if (quantityMatch != null) {
    return _ParsedQuantity(
      quantity: doubleFromJson(quantityMatch.group(1)),
      unit: quantityMatch.group(2) ?? 'szt.',
    );
  }

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
  const _Price({required this.raw, required this.start, required this.value});

  final String raw;
  final int start;
  final double value;
}

class _ParsedQuantity {
  const _ParsedQuantity({required this.quantity, required this.unit});

  final double quantity;
  final String unit;
}

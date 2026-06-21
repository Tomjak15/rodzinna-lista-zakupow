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

  for (final line in lines) {
    final lowerLine = line.toLowerCase();
    final price = _lastPrice(line);
    if (_isTotalLine(lowerLine)) {
      detectedTotal = price?.value ?? detectedTotal;
      continue;
    }
    if (price == null || _shouldSkipLine(lowerLine)) {
      continue;
    }

    final beforePrice = line.substring(0, line.lastIndexOf(price.raw)).trim();
    final parsedQuantity = _quantityFromLine(beforePrice);
    var name = beforePrice
        .replaceAll(_quantityPattern, ' ')
        .replaceAll(RegExp(r'\b\d+\s*x\s*$', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'[*#:;]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    name = name
        .replaceFirst(RegExp(r'^[0-9]{2,}\s+'), '')
        .replaceAll(RegExp(r'\b\d{5,}\b'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (!_isProductName(name)) {
      continue;
    }

    items.add(
      ReceiptItem(
        name: name,
        quantity: parsedQuantity.quantity,
        unit: normalizeIngredientUnit(parsedQuantity.unit),
        price: price.value,
      ),
    );
  }

  final fallbackTotal = items.fold<double>(0, (sum, item) => sum + item.price);
  return ParsedReceipt(
    items: items,
    total: detectedTotal ?? fallbackTotal,
    storeName: _detectStoreName(lines),
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
    'zabka': 'Zabka',
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

  for (final line in lines.take(12)) {
    final normalized = _normalizeStoreCandidate(line);
    for (final entry in knownStores.entries) {
      if (normalized.contains(entry.key)) {
        return entry.value;
      }
    }
  }

  for (final line in lines.take(8)) {
    final candidate = line
        .replaceAll(RegExp(r'[^A-Za-z0-9 &.-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final lower = candidate.toLowerCase();
    if (candidate.length >= 3 &&
        candidate.length <= 36 &&
        RegExp(r'[A-Za-z]').hasMatch(candidate) &&
        !_shouldSkipLine(lower) &&
        !lower.contains('sp. z') &&
        !lower.contains('s.a') &&
        !lower.contains('ul.') &&
        !RegExp(r'\d{4,}').hasMatch(candidate)) {
      return _titleCase(candidate);
    }
  }
  return null;
}

String _normalizeStoreCandidate(String value) {
  return value
      .toLowerCase()
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

bool _isProductName(String value) {
  final name = value.trim();
  if (name.length < 2) {
    return false;
  }
  if (!RegExp(r'[A-Za-z]').hasMatch(name)) {
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
      line.contains('do zaplaty') ||
      line.contains('do zapłaty') ||
      line.contains('naleznosc') ||
      line.contains('należność');
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
  ];
  return skipped.any((word) => line.contains(word));
}

_Price? _lastPrice(String line) {
  final matches = RegExp(
    r'(\d+[,.]\d{2})(?:\s*(?:zł|zl|pln|[A-Z]))?\s*$',
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

final _quantityPattern = RegExp(
  r'(\d+(?:[,.]\d+)?)\s*(kg|g|l|ml|szt|op|opak)\.?',
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

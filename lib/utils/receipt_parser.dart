import '../models/entities.dart';
import 'ingredient_parser.dart';

class ParsedReceipt {
  const ParsedReceipt({required this.items, required this.total});

  final List<ReceiptItem> items;
  final double total;
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

    name = name.replaceFirst(RegExp(r'^[0-9]{2,}\s+'), '').trim();
    if (name.length < 2 || RegExp(r'^\d+$').hasMatch(name)) {
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
  return ParsedReceipt(items: items, total: detectedTotal ?? fallbackTotal);
}

bool _isTotalLine(String line) {
  return line.contains('suma') ||
      line.contains('razem') ||
      line.contains('łącznie') ||
      line.contains('lacznie') ||
      line.contains('do zapłaty') ||
      line.contains('do zaplaty');
}

bool _shouldSkipLine(String line) {
  const skipped = [
    'paragon',
    'fiskalny',
    'nip',
    'sprzedaż',
    'sprzedaz',
    'podatek',
    'vat',
    'kasa',
    'kasjer',
    'terminal',
    'płatność',
    'platnosc',
    'karta',
    'gotówka',
    'gotowka',
    'reszta',
    'data',
    'godz',
    'adres',
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

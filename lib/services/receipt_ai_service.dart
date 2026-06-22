import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/entities.dart';
import '../utils/receipt_parser.dart';

class ReceiptAiService {
  ReceiptAiService(this._baseUrl, {http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  final String _baseUrl;
  final http.Client _client;
  final bool _ownsClient;

  Future<ParsedReceipt> scanReceipt({
    String? text,
    String? imageData,
    String? imageMimeType,
    List<String> hints = const [],
  }) async {
    final response = await _client
        .post(
          Uri.parse('$_baseUrl/api/ai/receipt-scan'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'text': text?.trim() ?? '',
            'imageData': imageData,
            'imageMimeType': imageMimeType,
            'hints': hints,
          }),
        )
        .timeout(const Duration(seconds: 60));

    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map && decoded['error'] != null
          ? decoded['error'].toString()
          : 'Nie udało się odczytać paragonu.';
      throw ReceiptAiException(message);
    }

    final data = decoded is Map<String, dynamic>
        ? decoded
        : Map<String, dynamic>.from(decoded as Map);
    final rawItems = data['items'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map(
                (item) => ReceiptItem(
                  name: (item['name'] ?? '').toString().trim(),
                  quantity: _toDouble(item['quantity'], fallback: 1),
                  unit: (item['unit'] ?? 'szt.').toString().trim(),
                  price: _toDouble(item['price']),
                ),
              )
              .where((item) => item.name.isNotEmpty && item.quantity > 0)
              .toList(growable: false)
        : <ReceiptItem>[];

    return ParsedReceipt(
      items: items,
      total: _toDouble(data['total']),
      storeName: (data['storeName'] ?? '').toString().trim(),
    );
  }

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }
}

class ReceiptAiException implements Exception {
  const ReceiptAiException(this.message);

  final String message;

  @override
  String toString() => message;
}

double _toDouble(Object? value, {double fallback = 0}) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse((value ?? '').toString().replaceAll(',', '.')) ??
      fallback;
}

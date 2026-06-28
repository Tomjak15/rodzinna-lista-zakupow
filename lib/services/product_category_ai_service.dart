import 'dart:convert';

import 'package:http/http.dart' as http;

import '../utils/product_category.dart';

class ProductCategoryAiService {
  ProductCategoryAiService(this._baseUrl, {http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  final String _baseUrl;
  final http.Client _client;
  final bool _ownsClient;

  Future<String?> classify({
    required String productName,
    String? familyId,
    List<String> hints = const [],
  }) async {
    final response = await _client
        .post(
          Uri.parse('$_baseUrl/api/ai/product-category'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'name': productName.trim(),
            'familyId': familyId?.trim() ?? '',
            'hints': hints,
          }),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final decoded = jsonDecode(response.body);
    final data = decoded is Map<String, dynamic>
        ? decoded
        : Map<String, dynamic>.from(decoded as Map);
    final category = (data['category'] ?? '').toString().trim();
    if (category == 'Inne' ||
        productCategories.any((item) => item.name == category)) {
      return category;
    }
    return null;
  }

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }
}

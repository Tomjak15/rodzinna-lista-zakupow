import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/recipe_scan_result.dart';

class RecipeAiService {
  RecipeAiService(this._baseUrl, {http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  final String _baseUrl;
  final http.Client _client;
  final bool _ownsClient;

  Future<RecipeScanDraft> scanRecipe({
    String? text,
    String? imageData,
    String? imageMimeType,
  }) async {
    final response = await _client
        .post(
          Uri.parse('$_baseUrl/api/ai/recipe-scan'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'text': text?.trim() ?? '',
            'imageData': imageData,
            'imageMimeType': imageMimeType,
          }),
        )
        .timeout(const Duration(seconds: 60));

    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map && decoded['error'] != null
          ? decoded['error'].toString()
          : 'Nie udało się zeskanować przepisu.';
      throw RecipeAiException(message);
    }

    final data = decoded is Map<String, dynamic>
        ? decoded
        : Map<String, dynamic>.from(decoded as Map);
    return RecipeScanDraft.fromJson(data);
  }

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }
}

class RecipeAiException implements Exception {
  const RecipeAiException(this.message);

  final String message;

  @override
  String toString() => message;
}

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

final class SimpleTranslationClient {
  SimpleTranslationClient({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  Future<String> translateToKorean(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Text is empty.');
    }

    final uri = Uri.https('api.mymemory.translated.net', '/get', {
      'q': trimmed,
      'langpair': 'en|ko',
    });
    final response = await _httpClient
        .get(uri)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Simple translation returned HTTP ${response.statusCode}',
        uri,
      );
    }

    final decoded = jsonDecode(
      utf8.decode(response.bodyBytes, allowMalformed: true),
    );
    if (decoded is! Map<String, Object?>) {
      throw const FormatException(
        'Simple translation response was not an object.',
      );
    }

    final responseData = decoded['responseData'];
    if (responseData is! Map<String, Object?>) {
      throw const FormatException(
        'Simple translation responseData is missing.',
      );
    }

    final translatedText = responseData['translatedText'];
    if (translatedText is! String || translatedText.trim().isEmpty) {
      throw const FormatException('Simple translation text is missing.');
    }

    return translatedText.trim();
  }

  void close() => _httpClient.close();
}

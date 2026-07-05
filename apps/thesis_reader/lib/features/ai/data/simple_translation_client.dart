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

    try {
      final translated = await _translateWithGoogle(trimmed);
      if (_isUsableTranslation(trimmed, translated)) {
        return translated;
      }
    } on Object {
      // Keep no-token translation available if the primary provider is down.
    }

    final translated = await _translateWithMyMemory(trimmed);
    if (!_isUsableTranslation(trimmed, translated)) {
      throw const FormatException(
        'Simple translation result matched the source text.',
      );
    }
    return translated;
  }

  Future<String> _translateWithGoogle(String text) async {
    final uri = Uri.https('translate.googleapis.com', '/translate_a/single', {
      'client': 'gtx',
      'sl': 'en',
      'tl': 'ko',
      'dt': 't',
      'q': text,
    });
    final response = await _httpClient
        .get(uri)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Google translation returned HTTP ${response.statusCode}',
        uri,
      );
    }

    final decoded = jsonDecode(
      utf8.decode(response.bodyBytes, allowMalformed: true),
    );
    if (decoded is! List<Object?> || decoded.isEmpty) {
      throw const FormatException(
        'Google translation response was not a list.',
      );
    }

    final translatedSegments = decoded.first;
    if (translatedSegments is! List<Object?>) {
      throw const FormatException('Google translation segments are missing.');
    }

    final buffer = StringBuffer();
    for (final segment in translatedSegments) {
      if (segment is List<Object?> &&
          segment.isNotEmpty &&
          segment.first is String) {
        buffer.write(segment.first as String);
      }
    }

    final translatedText = buffer.toString().trim();
    if (translatedText.isEmpty) {
      throw const FormatException('Google translation text is missing.');
    }

    return translatedText;
  }

  Future<String> _translateWithMyMemory(String text) async {
    final uri = Uri.https('api.mymemory.translated.net', '/get', {
      'q': text,
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

  bool _isUsableTranslation(String source, String translated) {
    if (translated.trim().isEmpty) {
      return false;
    }
    if (!_hasTranslatableEnglish(source)) {
      return true;
    }
    return _normalizeForComparison(source) !=
        _normalizeForComparison(translated);
  }

  bool _hasTranslatableEnglish(String source) {
    return RegExp(r'[A-Za-z]{4,}').hasMatch(source);
  }

  String _normalizeForComparison(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  void close() => _httpClient.close();
}

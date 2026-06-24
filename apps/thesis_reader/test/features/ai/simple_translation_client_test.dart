import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:thesis_reader/features/ai/data/simple_translation_client.dart';

void main() {
  test(
    'translates text with the no-token simple translation endpoint',
    () async {
      final client = SimpleTranslationClient(
        httpClient: MockClient((request) async {
          expect(request.url.host, 'api.mymemory.translated.net');
          expect(request.url.queryParameters['langpair'], 'en|ko');
          expect(request.url.queryParameters['q'], 'attention');
          return http.Response.bytes(
            utf8.encode('{"responseData":{"translatedText":"주의"}}'),
            200,
          );
        }),
      );

      addTearDown(client.close);

      final translated = await client.translateToKorean('attention');

      expect(translated, '주의');
    },
  );
}

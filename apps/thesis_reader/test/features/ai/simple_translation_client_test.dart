import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:thesis_reader/features/ai/data/simple_translation_client.dart';

void main() {
  test(
    'translates text with the Google simple translation endpoint first',
    () async {
      final client = SimpleTranslationClient(
        httpClient: MockClient((request) async {
          expect(request.url.host, 'translate.googleapis.com');
          expect(request.url.queryParameters['client'], 'gtx');
          expect(request.url.queryParameters['sl'], 'en');
          expect(request.url.queryParameters['tl'], 'ko');
          expect(request.url.queryParameters['dt'], 't');
          expect(request.url.queryParameters['q'], 'attention');
          return http.Response.bytes(
            utf8.encode('[[["주의","attention",null,null,2]],null,"en"]'),
            200,
          );
        }),
      );

      addTearDown(client.close);

      final translated = await client.translateToKorean('attention');

      expect(translated, '주의');
    },
  );

  test(
    'falls back when a simple translation provider returns the source text',
    () async {
      var requestCount = 0;
      final client = SimpleTranslationClient(
        httpClient: MockClient((request) async {
          requestCount += 1;
          if (requestCount == 1) {
            expect(request.url.host, 'translate.googleapis.com');
            return http.Response.bytes(
              utf8.encode(
                '[[["Circumscription","Circumscription",null,null,2]],null,"en"]',
              ),
              200,
            );
          }

          expect(request.url.host, 'api.mymemory.translated.net');
          expect(request.url.queryParameters['langpair'], 'en|ko');
          return http.Response.bytes(
            utf8.encode('{"responseData":{"translatedText":"외접"}}'),
            200,
          );
        }),
      );

      addTearDown(client.close);

      final translated = await client.translateToKorean('Circumscription');

      expect(translated, '외접');
      expect(requestCount, 2);
    },
  );
}

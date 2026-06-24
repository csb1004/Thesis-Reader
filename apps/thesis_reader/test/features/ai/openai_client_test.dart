import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:thesis_reader/features/ai/data/openai_client.dart';
import 'package:thesis_reader/features/ai/data/openai_key_store.dart';

void main() {
  test(
    'returns missingKey without issuing a request when key is absent',
    () async {
      var requestCount = 0;
      final client = OpenAiClient(
        keyStore: FakeKeyStore(null),
        baseUri: Uri.parse('https://api.openai.test'),
        httpClient: HandlerClient((request) {
          requestCount++;
          return jsonResponse({'output_text': 'unused'});
        }),
      );

      final result = await client.createText(
        OpenAiRequest.translateSelection(selectedText: 'hello'),
      );

      expect(result, isA<AiFailure<String>>());
      expect((result as AiFailure<String>).kind, AiFailureKind.missingKey);
      expect(requestCount, 0);
    },
  );

  test(
    'posts Responses API request with bearer key and parses outputText',
    () async {
      http.Request? capturedRequest;
      final client = OpenAiClient(
        keyStore: FakeKeyStore('sk-test'),
        baseUri: Uri.parse('https://api.openai.test'),
        httpClient: HandlerClient((request) async {
          capturedRequest = request as http.Request;
          return jsonResponse({'output_text': '맥락적 의미'});
        }),
      );

      final result = await client.createText(
        OpenAiRequest.wordMeaning(
          expression: 'salient',
          sourceSentence: 'The salient feature is robustness.',
          contextBefore: 'We compare models.',
          contextAfter: 'This matters in deployment.',
          sectionTitle: 'Experiments',
        ),
      );

      expect(result, isA<AiSuccess<String>>());
      expect((result as AiSuccess<String>).value, '맥락적 의미');
      expect(capturedRequest?.method, 'POST');
      expect(capturedRequest?.url.path, '/v1/responses');
      expect(capturedRequest?.headers['authorization'], 'Bearer sk-test');
      expect(capturedRequest?.headers['content-type'], 'application/json');

      final body = jsonDecode(capturedRequest!.body) as Map<String, Object?>;
      expect(body['model'], 'gpt-5.1-mini');
      expect(body['instructions'], contains('Korean'));
      expect(body['input'], contains('Target expression'));
      expect(body['input'], contains('salient'));
      expect(body['input'], contains('Experiments'));
    },
  );

  test(
    'concatenates nested output content text when outputText is absent',
    () async {
      final client = OpenAiClient(
        keyStore: FakeKeyStore('sk-test'),
        baseUri: Uri.parse('https://api.openai.test'),
        httpClient: HandlerClient((request) {
          return jsonResponse({
            'output': [
              {
                'type': 'message',
                'content': [
                  {'type': 'output_text', 'text': '첫 문장.'},
                  {'type': 'text', 'text': '둘째 문장.'},
                ],
              },
            ],
          });
        }),
      );

      final result = await client.createText(
        OpenAiRequest.translateSelection(selectedText: 'first second'),
      );

      expect(result, isA<AiSuccess<String>>());
      expect((result as AiSuccess<String>).value, '첫 문장.\n둘째 문장.');
    },
  );

  test('returns typed failures for api errors and invalid JSON', () async {
    final apiErrorClient = OpenAiClient(
      keyStore: FakeKeyStore('sk-test'),
      baseUri: Uri.parse('https://api.openai.test'),
      httpClient: HandlerClient((request) {
        return http.StreamedResponse(Stream.value(utf8.encode('nope')), 429);
      }),
    );

    final apiError = await apiErrorClient.createText(
      OpenAiRequest.translateSelection(selectedText: 'hello'),
    );

    expect(apiError, isA<AiFailure<String>>());
    expect((apiError as AiFailure<String>).kind, AiFailureKind.apiError);
    expect(apiError.statusCode, 429);
    expect(apiError.body, 'nope');

    final invalidJsonClient = OpenAiClient(
      keyStore: FakeKeyStore('sk-test'),
      baseUri: Uri.parse('https://api.openai.test'),
      httpClient: HandlerClient((request) {
        return http.StreamedResponse(
          Stream.value(utf8.encode('{bad json')),
          200,
        );
      }),
    );

    final invalid = await invalidJsonClient.createText(
      OpenAiRequest.translateSelection(selectedText: 'hello'),
    );

    expect(invalid, isA<AiFailure<String>>());
    expect((invalid as AiFailure<String>).kind, AiFailureKind.invalidResponse);
  });

  test('returns network failure when http client throws', () async {
    final client = OpenAiClient(
      keyStore: FakeKeyStore('sk-test'),
      baseUri: Uri.parse('https://api.openai.test'),
      httpClient: HandlerClient((request) {
        throw http.ClientException('socket closed');
      }),
    );

    final result = await client.createText(
      OpenAiRequest.translateSelection(selectedText: 'hello'),
    );

    expect(result, isA<AiFailure<String>>());
    expect((result as AiFailure<String>).kind, AiFailureKind.network);
  });
}

class FakeKeyStore implements OpenAiKeyReader {
  const FakeKeyStore(this.apiKey);

  final String? apiKey;

  @override
  Future<String?> readKey() async => apiKey;
}

class HandlerClient extends http.BaseClient {
  HandlerClient(this.handler);

  final FutureOr<http.StreamedResponse> Function(http.BaseRequest request)
  handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return handler(request);
  }
}

http.StreamedResponse jsonResponse(Map<String, Object?> payload) {
  return http.StreamedResponse(
    Stream.value(utf8.encode(jsonEncode(payload))),
    200,
    headers: {'content-type': 'application/json'},
  );
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:thesis_reader/features/ai/data/openai_client.dart';
import 'package:thesis_reader/features/ai/data/openai_key_store.dart';
import 'package:thesis_reader/features/ai/domain/translation_service.dart';

void main() {
  test('word meaning is marked for automatic vocabulary save', () async {
    final service = TranslationService(
      openAiClient: OpenAiClient(
        keyStore: const FakeKeyStore('sk-test'),
        httpClient: FakeTextClient('문맥상 두드러진'),
      ),
    );

    final result = await service.explainWord(
      expression: 'salient',
      sourceSentence: 'The salient feature is robustness.',
    );

    expect(result, isA<AiSuccess<TranslationAction>>());
    final action = (result as AiSuccess<TranslationAction>).value;
    expect(action.type, TranslationActionType.wordMeaning);
    expect(action.sourceText, 'salient');
    expect(action.koreanText, '문맥상 두드러진');
    expect(action.shouldAutoSave, isTrue);
    expect(action.canAddToVocabulary, isTrue);
  });

  test(
    'selection translation is not auto-saved but can be added later',
    () async {
      final service = TranslationService(
        openAiClient: OpenAiClient(
          keyStore: const FakeKeyStore('sk-test'),
          httpClient: FakeTextClient('강건성이 핵심 특징이다.'),
        ),
      );

      final result = await service.translateSelection(
        selectedText: 'Robustness is the key feature.',
      );

      expect(result, isA<AiSuccess<TranslationAction>>());
      final action = (result as AiSuccess<TranslationAction>).value;
      expect(action.type, TranslationActionType.selectionTranslation);
      expect(action.shouldAutoSave, isFalse);
      expect(action.canAddToVocabulary, isTrue);
    },
  );

  test('passes through typed OpenAI failures', () async {
    final service = TranslationService(
      openAiClient: OpenAiClient(
        keyStore: const FakeKeyStore(null),
        httpClient: FakeTextClient('unused'),
      ),
    );

    final result = await service.translateSelection(selectedText: 'hello');

    expect(result, isA<AiFailure<TranslationAction>>());
    expect(
      (result as AiFailure<TranslationAction>).kind,
      AiFailureKind.missingKey,
    );
  });
}

class FakeKeyStore implements OpenAiKeyReader {
  const FakeKeyStore(this.apiKey);

  final String? apiKey;

  @override
  Future<String?> readKey() async => apiKey;
}

class FakeTextClient extends http.BaseClient {
  FakeTextClient(this.text);

  final String text;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode({'output_text': text}))),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

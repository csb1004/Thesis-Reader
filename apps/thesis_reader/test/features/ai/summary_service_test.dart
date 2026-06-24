import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:thesis_reader/features/ai/data/openai_client.dart';
import 'package:thesis_reader/features/ai/data/openai_key_store.dart';
import 'package:thesis_reader/features/ai/domain/summary_service.dart';

void main() {
  test('summarizeSection returns section summary metadata', () async {
    final service = SummaryService(
      openAiClient: OpenAiClient(
        keyStore: const FakeKeyStore('sk-test'),
        httpClient: FakeTextClient('방법은 모델 비교를 수행한다.'),
      ),
    );

    final result = await service.summarizeSection(
      sectionTitle: 'Methods',
      paperText: 'We compare models.',
    );

    expect(result, isA<AiSuccess<SummaryResult>>());
    final summary = (result as AiSuccess<SummaryResult>).value;
    expect(summary.type, SummaryType.section);
    expect(summary.sectionTitle, 'Methods');
    expect(summary.summary, '방법은 모델 비교를 수행한다.');
  });

  test('summarizeRange returns range summary metadata', () async {
    final service = SummaryService(
      openAiClient: OpenAiClient(
        keyStore: const FakeKeyStore('sk-test'),
        httpClient: FakeTextClient('선택 범위는 강건성을 설명한다.'),
      ),
    );

    final result = await service.summarizeRange(
      sectionTitle: 'Results',
      paperText: 'This range discusses robustness.',
    );

    expect(result, isA<AiSuccess<SummaryResult>>());
    final summary = (result as AiSuccess<SummaryResult>).value;
    expect(summary.type, SummaryType.range);
    expect(summary.sectionTitle, 'Results');
    expect(summary.summary, '선택 범위는 강건성을 설명한다.');
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

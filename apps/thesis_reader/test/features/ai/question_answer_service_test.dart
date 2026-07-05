import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:thesis_reader/features/ai/data/openai_client.dart';
import 'package:thesis_reader/features/ai/data/openai_key_store.dart';
import 'package:thesis_reader/features/ai/domain/question_answer_service.dart';

void main() {
  test('answers paper questions using OpenAI text output', () async {
    final service = QuestionAnswerService(
      openAiClient: OpenAiClient(
        keyStore: const FakeKeyStore('sk-test'),
        httpClient: FakeTextClient('It introduces a focused reader workflow.'),
      ),
    );

    final result = await service.answerQuestion(
      question: 'What does it introduce?',
      paperText: 'This paper introduces a focused reader workflow.',
      paperTitle: 'Reader Paper',
    );

    expect(result, isA<AiSuccess<QuestionAnswer>>());
    final answer = (result as AiSuccess<QuestionAnswer>).value;
    expect(answer.question, 'What does it introduce?');
    expect(answer.answer, 'It introduces a focused reader workflow.');
  });

  test('passes through missing key failures', () async {
    final service = QuestionAnswerService(
      openAiClient: OpenAiClient(
        keyStore: const FakeKeyStore(null),
        httpClient: FakeTextClient('unused'),
      ),
    );

    final result = await service.answerQuestion(
      question: 'What is this?',
      paperText: 'Paper text',
    );

    expect(result, isA<AiFailure<QuestionAnswer>>());
    expect(
      (result as AiFailure<QuestionAnswer>).kind,
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

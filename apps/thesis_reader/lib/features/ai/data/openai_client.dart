import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:thesis_reader/features/ai/data/openai_key_store.dart';

const defaultOpenAiModel = 'gpt-5.4-mini';

enum AiFailureKind { missingKey, network, apiError, invalidResponse }

sealed class AiResult<T> {
  const AiResult();
}

final class AiSuccess<T> extends AiResult<T> {
  const AiSuccess(this.value);

  final T value;
}

final class AiFailure<T> extends AiResult<T> {
  const AiFailure({
    required this.kind,
    required this.message,
    this.statusCode,
    this.body,
  });

  final AiFailureKind kind;
  final String message;
  final int? statusCode;
  final String? body;
}

class OpenAiRequest {
  const OpenAiRequest({
    required this.input,
    this.instructions,
    this.model = defaultOpenAiModel,
  });

  final String model;
  final String? instructions;
  final String input;

  factory OpenAiRequest.wordMeaning({
    required String expression,
    required String sourceSentence,
    String? contextBefore,
    String? contextAfter,
    String? sectionTitle,
  }) {
    return OpenAiRequest(
      instructions: [
        'You explain English academic writing to a Korean thesis reader.',
        'Return only the contextual Korean meaning of the target expression.',
        'Be concise, but include nuance when the source sentence changes the meaning.',
      ].join(' '),
      input: _labeledInput({
        'Task':
            'Explain the target English word or short expression in Korean.',
        'Target expression': expression,
        'Section title': sectionTitle,
        'Previous context': contextBefore,
        'Source sentence': sourceSentence,
        'Next context': contextAfter,
      }),
    );
  }

  factory OpenAiRequest.translateSelection({required String selectedText}) {
    return OpenAiRequest(
      instructions: [
        'Translate English academic prose into natural Korean.',
        'Preserve technical meaning and citation markers.',
        'Return only the Korean translation.',
      ].join(' '),
      input: _labeledInput({
        'Task': 'Translate the selected text into Korean.',
        'Selected text': selectedText,
      }),
    );
  }

  factory OpenAiRequest.summarizeRange({
    required String paperText,
    String? sectionTitle,
  }) {
    return OpenAiRequest(
      instructions: [
        'Summarize academic paper text for a Korean reader.',
        'Return a concise Korean summary with the key claim, method, and finding when present.',
      ].join(' '),
      input: _labeledInput({
        'Task': 'Summarize this selected paper range in Korean.',
        'Section title': sectionTitle,
        'Paper text': paperText,
      }),
    );
  }

  factory OpenAiRequest.summarizeSection({
    required String sectionTitle,
    required String paperText,
  }) {
    return OpenAiRequest(
      instructions: [
        'Summarize one academic paper section for a Korean reader.',
        'Return a Korean section summary focused on purpose, evidence, and conclusion.',
      ].join(' '),
      input: _labeledInput({
        'Task': 'Summarize this paper section in Korean.',
        'Section title': sectionTitle,
        'Paper text': paperText,
      }),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'model': model,
      if (instructions != null && instructions!.trim().isNotEmpty)
        'instructions': instructions,
      'input': input,
    };
  }
}

class OpenAiClient {
  OpenAiClient({
    required OpenAiKeyReader keyStore,
    http.Client? httpClient,
    Uri? baseUri,
  }) : _keyStore = keyStore,
       _httpClient = httpClient ?? http.Client(),
       _baseUri = baseUri ?? Uri.parse('https://api.openai.com');

  final OpenAiKeyReader _keyStore;
  final http.Client _httpClient;
  final Uri _baseUri;

  Future<AiResult<String>> createText(OpenAiRequest request) async {
    final apiKey = (await _keyStore.readKey())?.trim();
    if (apiKey == null || apiKey.isEmpty) {
      return const AiFailure(
        kind: AiFailureKind.missingKey,
        message: 'OpenAI API key is missing.',
      );
    }

    http.Response response;
    try {
      response = await _httpClient
          .post(
            _baseUri.resolve('/v1/responses'),
            headers: {
              'authorization': 'Bearer $apiKey',
              'content-type': 'application/json',
            },
            body: jsonEncode(request.toJson()),
          )
          .timeout(const Duration(seconds: 45));
    } on TimeoutException {
      return const AiFailure(
        kind: AiFailureKind.network,
        message: 'OpenAI request timed out.',
      );
    } on http.ClientException catch (error) {
      return AiFailure(
        kind: AiFailureKind.network,
        message: 'OpenAI network request failed: ${error.message}',
      );
    } on Object catch (error) {
      return AiFailure(
        kind: AiFailureKind.network,
        message: 'OpenAI network request failed: $error',
      );
    }

    final responseBody = utf8.decode(response.bodyBytes, allowMalformed: true);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return AiFailure(
        kind: AiFailureKind.apiError,
        message: 'OpenAI returned HTTP ${response.statusCode}.',
        statusCode: response.statusCode,
        body: responseBody,
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(responseBody);
    } on FormatException {
      return AiFailure(
        kind: AiFailureKind.invalidResponse,
        message: 'OpenAI returned malformed JSON.',
        body: responseBody,
      );
    }

    if (decoded is! Map<String, Object?>) {
      return AiFailure(
        kind: AiFailureKind.invalidResponse,
        message: 'OpenAI response was not a JSON object.',
        body: responseBody,
      );
    }

    final text = _parseResponseText(decoded);
    if (text == null) {
      return AiFailure(
        kind: AiFailureKind.invalidResponse,
        message: 'OpenAI response did not contain text output.',
        body: responseBody,
      );
    }

    return AiSuccess(text);
  }

  void close() => _httpClient.close();

  String? _parseResponseText(Map<String, Object?> payload) {
    final outputText = payload['output_text'];
    if (outputText is String && outputText.trim().isNotEmpty) {
      return outputText.trim();
    }

    final fragments = <String>[];
    final output = payload['output'];
    if (output is List<Object?>) {
      for (final item in output) {
        if (item is! Map<String, Object?>) {
          continue;
        }

        _appendTextFragment(item, fragments);
        final content = item['content'];
        if (content is List<Object?>) {
          for (final contentItem in content) {
            if (contentItem is Map<String, Object?>) {
              _appendTextFragment(contentItem, fragments);
            }
          }
        }
      }
    }

    final text = fragments
        .map((fragment) => fragment.trim())
        .where((fragment) => fragment.isNotEmpty)
        .join('\n')
        .trim();
    return text.isEmpty ? null : text;
  }

  void _appendTextFragment(Map<String, Object?> item, List<String> fragments) {
    final type = item['type'];
    final text = item['text'];
    if (text is String &&
        text.isNotEmpty &&
        (type == null || type == 'output_text' || type == 'text')) {
      fragments.add(text);
    }
  }
}

String _labeledInput(Map<String, String?> fields) {
  return fields.entries
      .where((entry) => entry.value != null && entry.value!.trim().isNotEmpty)
      .map((entry) => '${entry.key}:\n${entry.value!.trim()}')
      .join('\n\n');
}

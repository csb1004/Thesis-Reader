import 'package:thesis_reader/features/ai/data/openai_client.dart';

enum SummaryType { range, section }

class SummaryResult {
  const SummaryResult({
    required this.type,
    required this.summary,
    this.sectionTitle,
  });

  final SummaryType type;
  final String summary;
  final String? sectionTitle;
}

class SummaryService {
  const SummaryService({required OpenAiClient openAiClient})
    : _openAiClient = openAiClient;

  final OpenAiClient _openAiClient;

  Future<AiResult<SummaryResult>> summarizeRange({
    required String paperText,
    String? sectionTitle,
  }) async {
    final result = await _openAiClient.createText(
      OpenAiRequest.summarizeRange(
        paperText: paperText,
        sectionTitle: sectionTitle,
      ),
    );

    return _toSummaryResult(
      result,
      type: SummaryType.range,
      sectionTitle: sectionTitle,
    );
  }

  Future<AiResult<SummaryResult>> summarizeSection({
    required String sectionTitle,
    required String paperText,
  }) async {
    final result = await _openAiClient.createText(
      OpenAiRequest.summarizeSection(
        sectionTitle: sectionTitle,
        paperText: paperText,
      ),
    );

    return _toSummaryResult(
      result,
      type: SummaryType.section,
      sectionTitle: sectionTitle,
    );
  }

  AiResult<SummaryResult> _toSummaryResult(
    AiResult<String> result, {
    required SummaryType type,
    required String? sectionTitle,
  }) {
    return switch (result) {
      AiSuccess(value: final summary) => AiSuccess(
        SummaryResult(type: type, summary: summary, sectionTitle: sectionTitle),
      ),
      AiFailure(
        kind: final kind,
        message: final message,
        statusCode: final statusCode,
        body: final body,
      ) =>
        AiFailure(
          kind: kind,
          message: message,
          statusCode: statusCode,
          body: body,
        ),
    };
  }
}

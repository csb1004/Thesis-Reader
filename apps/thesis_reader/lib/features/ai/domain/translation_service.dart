import 'package:thesis_reader/features/ai/data/openai_client.dart';

enum TranslationActionType { wordMeaning, selectionTranslation }

class TranslationAction {
  const TranslationAction({
    required this.type,
    required this.sourceText,
    required this.koreanText,
    required this.shouldAutoSave,
    required this.canAddToVocabulary,
  });

  final TranslationActionType type;
  final String sourceText;
  final String koreanText;
  final bool shouldAutoSave;
  final bool canAddToVocabulary;
}

class TranslationService {
  const TranslationService({required OpenAiClient openAiClient})
    : _openAiClient = openAiClient;

  final OpenAiClient _openAiClient;

  Future<AiResult<TranslationAction>> explainWord({
    required String expression,
    required String sourceSentence,
    String? contextBefore,
    String? contextAfter,
    String? sectionTitle,
  }) async {
    final result = await _openAiClient.createText(
      OpenAiRequest.wordMeaning(
        expression: expression,
        sourceSentence: sourceSentence,
        contextBefore: contextBefore,
        contextAfter: contextAfter,
        sectionTitle: sectionTitle,
      ),
    );

    return switch (result) {
      AiSuccess(value: final koreanText) => AiSuccess(
        TranslationAction(
          type: TranslationActionType.wordMeaning,
          sourceText: expression,
          koreanText: koreanText,
          shouldAutoSave: true,
          canAddToVocabulary: true,
        ),
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

  Future<AiResult<TranslationAction>> translateSelection({
    required String selectedText,
  }) async {
    final result = await _openAiClient.createText(
      OpenAiRequest.translateSelection(selectedText: selectedText),
    );

    return switch (result) {
      AiSuccess(value: final koreanText) => AiSuccess(
        TranslationAction(
          type: TranslationActionType.selectionTranslation,
          sourceText: selectedText,
          koreanText: koreanText,
          shouldAutoSave: false,
          canAddToVocabulary: true,
        ),
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

import 'package:thesis_reader/features/ai/data/openai_client.dart';

class QuestionAnswer {
  const QuestionAnswer({required this.question, required this.answer});

  final String question;
  final String answer;
}

class QuestionAnswerService {
  const QuestionAnswerService({required OpenAiClient openAiClient})
    : _openAiClient = openAiClient;

  final OpenAiClient _openAiClient;

  Future<AiResult<QuestionAnswer>> answerQuestion({
    required String question,
    required String paperText,
    String? paperTitle,
  }) async {
    final result = await _openAiClient.createText(
      OpenAiRequest.answerPaperQuestion(
        question: question,
        paperText: paperText,
        paperTitle: paperTitle,
      ),
    );

    return switch (result) {
      AiSuccess(value: final answer) => AiSuccess(
        QuestionAnswer(question: question, answer: answer),
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

String normalizeVocabularyExpression(String expression) {
  final withoutTrailingPunctuation = expression.trim().replaceFirst(
    RegExp(r'[\.,;:]+$'),
    '',
  );

  return withoutTrailingPunctuation.trim().toLowerCase().replaceAll(
    RegExp(r'\s+'),
    ' ',
  );
}

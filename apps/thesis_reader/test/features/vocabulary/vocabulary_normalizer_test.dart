import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_reader/features/vocabulary/domain/vocabulary_normalizer.dart';

void main() {
  group('normalizeVocabularyExpression', () {
    test('trims and lowercases a single expression', () {
      expect(normalizeVocabularyExpression('  Transformer  '), 'transformer');
    });

    test('collapses whitespace in a multi-word phrase', () {
      expect(
        normalizeVocabularyExpression('  In \n\t Context  '),
        'in context',
      );
    });

    test('removes trailing sentence punctuation after trimming', () {
      expect(normalizeVocabularyExpression('Attention, '), 'attention');
      expect(normalizeVocabularyExpression('alignment;'), 'alignment');
      expect(normalizeVocabularyExpression('in context:'), 'in context');
      expect(normalizeVocabularyExpression('embedding.'), 'embedding');
    });

    test('keeps non-trailing punctuation inside a phrase', () {
      expect(
        normalizeVocabularyExpression('self-attention, mechanism'),
        'self-attention, mechanism',
      );
    });
  });
}

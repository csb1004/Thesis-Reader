import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_reader/features/reader/domain/readable_math_text.dart';

void main() {
  test('parses braced Greek subscripts as visual subscript tokens', () {
    final tokens = parseReadableMathText('p_{θ}(x₀):=p_{θ}(x₀:t)');

    expect(tokens.map((token) => (token.text, token.isSubscript)).toList(), [
      ('p', false),
      ('θ', true),
      ('(x₀):=p', false),
      ('θ', true),
      ('(x₀:t)', false),
    ]);
  });

  test('parses legacy Greek subscript parentheses from cached packages', () {
    final tokens = parseReadableMathText('p₍θ₎(x₀)');

    expect(tokens.map((token) => (token.text, token.isSubscript)).toList(), [
      ('p', false),
      ('θ', true),
      ('(x₀)', false),
    ]);
  });

  test(
    'builds display text with source offsets that skip marker internals',
    () {
      final layoutText = buildReadableMathLayoutText('p_{θ}(x₀)');

      expect(layoutText.text, 'pθ(x₀)');
      expect(layoutText.sourceOffsetAt(1), 1);
      expect(layoutText.sourceOffsetAt(2), 5);
    },
  );
}

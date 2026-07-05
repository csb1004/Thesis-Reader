import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_reader/features/reader/domain/reader_action_text.dart';

void main() {
  test('reader action preview keeps snackbar text compact', () {
    expect(readerActionPreview('short phrase'), 'short phrase');
    expect(
      readerActionPreview('first line\nsecond line with more detail'),
      'first line second line with more detail',
    );
    expect(
      readerActionPreview(
        'This selected thesis sentence is intentionally long and continues.',
      ),
      'This selected thesis sentence is intentionally...',
    );
  });
}

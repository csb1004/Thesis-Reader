import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_reader/features/library/data/document_package_loader.dart';

void main() {
  for (final modern in [true, false]) {
    test('preserves structured text and links (modern: $modern)', () async {
      final directory = await Directory.systemTemp.createTemp('text_integrity');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/package.json');
      const text = '\u{1D6FC} first\nsecond Figure 1, another';
      final start = text.indexOf('Figure');
      final offsetAdjustment = modern ? 0 : 1;
      await file.writeAsString(
        jsonEncode({
          'packageVersion': 1,
          'documentId': 'd',
          'metadata': {
            'title': 'Test',
            'sourceFilename': 'test.pdf',
            'originalPdfSha256': 'hash',
            'converterVersion': 'mvp-2',
          },
          'conversionMode': 'latex-source',
          'sourceInfo': modern
              ? {'offsetEncoding': 'utf-16', 'textNormalized': true}
              : {},
          'sections': [],
          'assets': [],
          'blocks': [
            {
              'id': 'b',
              'sectionId': 's',
              'kind': 'paragraph',
              'text': text,
              'source': {'preserveStructure': true},
              'textSpans': [
                {
                  'start': start - offsetAdjustment,
                  'end': start + 8 - offsetAdjustment,
                  'italic': true,
                },
              ],
              'referenceSpans': [
                {
                  'start': start - offsetAdjustment,
                  'end': start + 8 - offsetAdjustment,
                  'kind': 'figure',
                  'targetAssetId': 'fig-1',
                  'label': 'Figure 1',
                },
              ],
            },
          ],
        }),
      );
      final loaded = await DocumentPackageLoader.load(
        documentId: 'd',
        appDirectory: directory,
        storedPackagePath: file.path,
      );
      final block = loaded!.package.blocks.single;
      expect(block.text, text);
      final reference = block.referenceSpans.single;
      final style = block.textSpans.single;
      expect(block.text!.substring(reference.start, reference.end), 'Figure 1');
      expect(block.text!.substring(style.start, style.end), 'Figure 1');
    });
  }
}

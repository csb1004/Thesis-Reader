import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:thesis_reader/features/library/data/document_package_loader.dart';

void main() {
  test('loads a converted package from the stored package path', () async {
    final temp = await Directory.systemTemp.createTemp('package_loader_test');
    final packageFile = File(
      p.join(temp.path, 'packages', 'doc-1', 'job-1', 'package.json'),
    );
    await packageFile.parent.create(recursive: true);
    await packageFile.writeAsString(
      jsonEncode({
        'packageVersion': 1,
        'documentId': 'doc-1',
        'metadata': {
          'title': 'Converted title',
          'sourceFilename': 'paper.pdf',
          'originalPdfSha256': 'abc123',
          'converterVersion': 'mvp-1',
        },
        'sections': [
          {
            'id': 'sec-1',
            'title': 'Document',
            'blockIds': ['block-1'],
          },
        ],
        'blocks': [
          {
            'id': 'block-1',
            'sectionId': 'sec-1',
            'kind': 'paragraph',
            'text': 'Converted text',
          },
        ],
        'assets': [],
      }),
    );

    final loaded = await DocumentPackageLoader.load(
      documentId: 'doc-1',
      appDirectory: temp,
      storedPackagePath: packageFile.path,
    );

    expect(loaded?.package.metadata.title, 'Converted title');
    expect(loaded?.package.blocks.single.text, 'Converted text');
  });

  test(
    'falls back to legacy package directory when packagePath is absent',
    () async {
      final temp = await Directory.systemTemp.createTemp('package_loader_test');
      final packageFile = File(
        p.join(temp.path, 'packages', 'doc-1', 'package.json'),
      );
      await packageFile.parent.create(recursive: true);
      await packageFile.writeAsString(
        jsonEncode({
          'packageVersion': 1,
          'documentId': 'doc-1',
          'metadata': {
            'title': 'Legacy title',
            'sourceFilename': 'paper.pdf',
            'originalPdfSha256': 'abc123',
            'converterVersion': 'mvp-1',
          },
          'sections': [],
          'blocks': [],
          'assets': [],
        }),
      );

      final loaded = await DocumentPackageLoader.load(
        documentId: 'doc-1',
        appDirectory: temp,
        storedPackagePath: null,
      );

      expect(loaded?.package.metadata.title, 'Legacy title');
      expect(loaded?.packageFile.path, packageFile.path);
    },
  );

  test('normalizes cached hyphenated line breaks in paragraph text', () async {
    final temp = await Directory.systemTemp.createTemp('package_loader_test');
    final packageFile = File(
      p.join(temp.path, 'packages', 'doc-1', 'package.json'),
    );
    await packageFile.parent.create(recursive: true);
    await packageFile.writeAsString(
      jsonEncode({
        'packageVersion': 1,
        'documentId': 'doc-1',
        'metadata': {
          'title': 'Cached title',
          'sourceFilename': 'paper.pdf',
          'originalPdfSha256': 'abc123',
          'converterVersion': 'mvp-1',
        },
        'sections': [
          {
            'id': 'sec-1',
            'title': 'Document',
            'blockIds': ['block-1'],
          },
        ],
        'blocks': [
          {
            'id': 'block-1',
            'sectionId': 'sec-1',
            'kind': 'paragraph',
            'text': 'sequence modeling and transduc-\ntion models',
          },
        ],
        'assets': [],
      }),
    );

    final loaded = await DocumentPackageLoader.load(
      documentId: 'doc-1',
      appDirectory: temp,
      storedPackagePath: null,
    );

    expect(
      loaded?.package.blocks.single.text,
      'sequence modeling and transduction models',
    );
  });

  test('normalizes cached wrapped words and label line breaks', () async {
    final temp = await Directory.systemTemp.createTemp('package_loader_test');
    final packageFile = File(
      p.join(temp.path, 'packages', 'doc-1', 'package.json'),
    );
    await packageFile.parent.create(recursive: true);
    await packageFile.writeAsString(
      jsonEncode({
        'packageVersion': 1,
        'documentId': 'doc-1',
        'metadata': {
          'title': 'Cached title',
          'sourceFilename': 'paper.pdf',
          'originalPdfSha256': 'abc123',
          'converterVersion': 'mvp-1',
        },
        'sections': [
          {
            'id': 'sec-1',
            'title': 'Document',
            'blockIds': ['block-1'],
          },
        ],
        'blocks': [
          {
            'id': 'block-1',
            'sectionId': 'sec-1',
            'kind': 'paragraph',
            'text': 'transduc- tion models\nDecoder:\nThe stack is repeated.',
          },
        ],
        'assets': [],
      }),
    );

    final loaded = await DocumentPackageLoader.load(
      documentId: 'doc-1',
      appDirectory: temp,
      storedPackagePath: null,
    );

    expect(
      loaded?.package.blocks.single.text,
      'transduction models Decoder: The stack is repeated.',
    );
  });

  test(
    'normalizes cached attention equation text without changing structure',
    () async {
      final temp = await Directory.systemTemp.createTemp('package_loader_test');
      final packageFile = File(
        p.join(temp.path, 'packages', 'doc-1', 'package.json'),
      );
      await packageFile.parent.create(recursive: true);
      await packageFile.writeAsString(
        jsonEncode({
          'packageVersion': 1,
          'documentId': 'doc-1',
          'metadata': {
            'title': 'Cached title',
            'sourceFilename': 'paper.pdf',
            'originalPdfSha256': 'abc123',
            'converterVersion': 'mvp-1',
          },
          'sections': [
            {
              'id': 'sec-1',
              'title': 'Document',
              'blockIds': ['block-1'],
            },
          ],
          'blocks': [
            {
              'id': 'block-1',
              'sectionId': 'sec-1',
              'kind': 'paragraph',
              'text': 'Attention(Q, K, V ) = softmax(QKT\n√dk\n)V\n(1)',
            },
          ],
          'assets': [],
        }),
      );

      final loaded = await DocumentPackageLoader.load(
        documentId: 'doc-1',
        appDirectory: temp,
        storedPackagePath: null,
      );

      expect(
        loaded?.package.blocks.single.text,
        'Attention(Q, K, V) = softmax(QK^T / √d_k) V (1)',
      );
    },
  );
}

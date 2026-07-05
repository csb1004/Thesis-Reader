import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:document_contract/document_contract.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:thesis_reader/features/ai/data/simple_translation_client.dart';
import 'package:thesis_reader/features/reader/domain/reader_settings.dart';
import 'package:thesis_reader/features/reader/presentation/reader_screen.dart';
import 'package:thesis_reader/shared/platform/volume_key_channel.dart';

void main() {
  testWidgets('renders text blocks as selectable text with theme colors', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderScreen(
          documentId: 'doc-1',
          package: _packageWithBlocks(['Selectable thesis text']),
          initialSettings: const ReaderSettings(themeId: 'dark'),
        ),
      ),
    );

    final selectable = tester.widget<SelectableText>(
      find.byType(SelectableText),
    );
    final theme = ReaderThemeCatalog.resolve('dark');

    expect(selectable.data, 'Selectable thesis text');
    expect(selectable.style?.color, theme.textColor);
    expect(
      tester
          .widget<ColoredBox>(find.byKey(const Key('reader-theme-background')))
          .color,
      theme.backgroundColor,
    );
  });

  testWidgets('reader body text uses only in-app font scaling', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: MaterialApp(
          home: ReaderScreen(
            documentId: 'doc-1',
            package: _packageWithBlocks(['Selectable thesis text']),
          ),
        ),
      ),
    );

    final selectable = tester.widget<SelectableText>(
      find.byType(SelectableText),
    );

    expect(selectable.textScaler, TextScaler.noScaling);
  });

  testWidgets('uses the library document title in the app bar', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderScreen(
          documentId: 'doc-1',
          displayTitle: 'Attention Is All You Need',
          package: _packageWithBlocks(['Selectable thesis text']),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('reader-menu-toggle-zone')));
    await tester.pumpAndSettle();

    expect(find.text('Attention Is All You Need'), findsOneWidget);
    expect(find.text('Reader Test'), findsNothing);
  });

  testWidgets('reader chrome is hidden until the center is tapped', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderScreen(
          documentId: 'doc-1',
          displayTitle: 'Attention Is All You Need',
          package: _packageWithBlocks(['Selectable thesis text']),
        ),
      ),
    );

    expect(find.text('Attention Is All You Need'), findsNothing);
    expect(find.byKey(const Key('reader-page-slider')), findsNothing);

    await tester.tap(find.byKey(const Key('reader-menu-toggle-zone')));
    await tester.pumpAndSettle();

    expect(find.text('Attention Is All You Need'), findsOneWidget);
    expect(find.byKey(const Key('reader-page-slider')), findsOneWidget);

    await tester.tap(find.byKey(const Key('reader-menu-toggle-zone')));
    await tester.pumpAndSettle();

    expect(find.text('Attention Is All You Need'), findsNothing);
    expect(find.byKey(const Key('reader-page-slider')), findsNothing);
  });

  testWidgets('long pressing reader text does not reveal reader chrome', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderScreen(
          documentId: 'doc-1',
          displayTitle: 'Current and Future Research',
          package: _packageWithBlocks(['Answer set programming']),
        ),
      ),
    );

    await tester.longPress(find.text('Answer set programming'));
    await tester.pumpAndSettle();

    expect(find.text('Current and Future Research'), findsNothing);
    expect(find.byKey(const Key('reader-page-slider')), findsNothing);
    expect(_hasColoredModalBarrier(tester), isFalse);
  });

  testWidgets('showing reader chrome does not shift the reading surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderScreen(
          documentId: 'doc-1',
          displayTitle: 'Attention Is All You Need',
          package: _packageWithBlocks(['Selectable thesis text']),
        ),
      ),
    );

    final before = tester.getRect(
      find.byKey(const Key('reader-theme-background')),
    );

    await tester.tap(find.byKey(const Key('reader-menu-toggle-zone')));
    await tester.pumpAndSettle();

    final after = tester.getRect(
      find.byKey(const Key('reader-theme-background')),
    );

    expect(after.top, before.top);
    expect(after.height, before.height);
  });

  testWidgets('page text starts below the hidden top chrome reserve', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderScreen(
          documentId: 'doc-1',
          package: _packageWithBlocks(['First visible reader line']),
        ),
      ),
    );

    final textTop = tester.getRect(find.text('First visible reader line')).top;

    expect(textTop, greaterThan(kToolbarHeight));
  });

  testWidgets('page reader does not hard clip text at the footer boundary', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderScreen(
          documentId: 'doc-1',
          package: _packageWithBlocks([
            'A dense thesis paragraph ${'keeps enough text near the bottom. ' * 80}',
          ]),
          initialSettings: const ReaderSettings(fontScale: 1.5),
        ),
      ),
    );

    final pageScrollView = tester.widget<SingleChildScrollView>(
      find.byKey(const Key('reader-page-content-scroll-view')),
    );

    expect(pageScrollView.clipBehavior, Clip.none);
  });

  testWidgets('bottom slider changes the current page when chrome is visible', (
    tester,
  ) async {
    final progressChanges = <ReaderProgress>[];

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 320,
          height: 240,
          child: ReaderScreen(
            documentId: 'doc-1',
            package: _packageWithBlocks(
              List.generate(
                5,
                (index) =>
                    'Paragraph $index ${'fills the reader page. ' * 400}',
              ),
            ),
            onProgressChanged: progressChanges.add,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('reader-menu-toggle-zone')));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('reader-page-slider')),
      const Offset(200, 0),
    );
    await tester.pumpAndSettle();

    expect(progressChanges.last.pageIndex, greaterThan(0));
    expect(find.textContaining(RegExp(r'\d+ / \d+')), findsOneWidget);
  });

  testWidgets('reports scroll progress after scroll end', (tester) async {
    final progressChanges = <ReaderProgress>[];

    await tester.pumpWidget(
      MaterialApp(
        home: ReaderScreen(
          documentId: 'doc-1',
          package: _packageWithBlocks(
            List.generate(
              30,
              (index) =>
                  'Paragraph $index has enough text to require a scrollable '
                  'reader surface for progress reporting. ${'More text. ' * 80}',
            ),
          ),
          initialSettings: const ReaderSettings(
            readingMode: ReadingMode.scroll,
          ),
          onProgressChanged: progressChanges.add,
        ),
      ),
    );

    await tester.dragFrom(
      tester.getTopLeft(find.byType(CustomScrollView)) + const Offset(8, 8),
      const Offset(0, -500),
      touchSlopY: 0,
    );
    await tester.pumpAndSettle();

    expect(progressChanges, hasLength(1));
    expect(progressChanges.single.scrollOffset, greaterThan(0));
    expect(progressChanges.single.scrollProgress, greaterThan(0));
    expect(progressChanges.single.scrollProgress, lessThanOrEqualTo(1));
  });

  testWidgets('volume keys move between pages in page mode', (tester) async {
    final volumeKeys = StreamController<VolumeKeyEvent>.broadcast();
    final progressChanges = <ReaderProgress>[];
    addTearDown(volumeKeys.close);

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 320,
          height: 240,
          child: ReaderScreen(
            documentId: 'doc-1',
            package: _packageWithBlocks(
              List.generate(
                8,
                (index) =>
                    'Paragraph $index ${'fills the reader page. ' * 400}',
              ),
            ),
            volumeKeyEvents: volumeKeys.stream,
            onProgressChanged: progressChanges.add,
          ),
        ),
      ),
    );

    expect(progressChanges, isEmpty);

    volumeKeys.add(VolumeKeyEvent.next);
    await tester.pumpAndSettle();

    expect(progressChanges.last.pageIndex, 1);
    expect(progressChanges.last.pageCount, greaterThan(8));

    volumeKeys.add(VolumeKeyEvent.previous);
    await tester.pumpAndSettle();

    expect(progressChanges.last.pageIndex, 0);

    final progressCountAtFirstPage = progressChanges.length;

    volumeKeys.add(VolumeKeyEvent.previous);
    await tester.pumpAndSettle();

    expect(progressChanges, hasLength(progressCountAtFirstPage));
  });

  testWidgets('volume keys are ignored in scroll mode', (tester) async {
    final volumeKeys = StreamController<VolumeKeyEvent>.broadcast();
    addTearDown(volumeKeys.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ReaderScreen(
          documentId: 'doc-1',
          package: _packageWithBlocks(
            List.generate(
              8,
              (index) =>
                  'Paragraph $index has enough text to remain scrollable.',
            ),
          ),
          initialSettings: const ReaderSettings(
            readingMode: ReadingMode.scroll,
          ),
          volumeKeyEvents: volumeKeys.stream,
        ),
      ),
    );

    volumeKeys.add(VolumeKeyEvent.next);
    await tester.pumpAndSettle();

    expect(find.byType(CustomScrollView), findsOneWidget);
    expect(find.byType(PageView), findsNothing);
  });

  testWidgets('native volume navigation follows page-mode lifecycle', (
    tester,
  ) async {
    const methodChannel = MethodChannel(VolumeKeyChannel.channelName);
    final calls = <MethodCall>[];
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, null),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
          calls.add(call);
          return null;
        });

    await tester.pumpWidget(
      MaterialApp(
        home: ReaderScreen(
          documentId: 'doc-1',
          package: _packageWithBlocks(['Page mode text']),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('reader-menu-toggle-zone')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    await tester.tap(find.text('스크롤'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('페이지'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    expect(calls, [
      isMethodCall('setVolumeKeyNavigationEnabled', arguments: true),
      isMethodCall('setVolumeKeyNavigationEnabled', arguments: false),
      isMethodCall('setVolumeKeyNavigationEnabled', arguments: true),
      isMethodCall('setVolumeKeyNavigationEnabled', arguments: false),
    ]);
  });

  testWidgets('renders valid asset references as clickable styled spans', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderScreen(documentId: 'doc-1', package: _package()),
      ),
    );

    final selectable = tester.widget<SelectableText>(
      find.byType(SelectableText),
    );
    final rootSpan = selectable.textSpan!;
    final referenceSpan = rootSpan.children!.whereType<TextSpan>().singleWhere(
      (span) => span.text == 'Figure 1',
    );

    expect(referenceSpan.recognizer, isNotNull);
    expect(referenceSpan.style?.decoration, TextDecoration.underline);
    expect(referenceSpan.style?.color, isNotNull);
  });

  testWidgets('opens citation references as italic tappable spans', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderScreen(
          documentId: 'doc-1',
          package: _packageWithCitation(),
        ),
      ),
    );

    final citationSpan = _textSpanWithText(tester, '[36]');

    expect(citationSpan.recognizer, isNotNull);
    expect(citationSpan.style?.fontStyle, FontStyle.italic);
    expect(
      citationSpan.style?.fontFeatures,
      contains(const FontFeature('ital')),
    );

    (citationSpan.recognizer! as TapGestureRecognizer).onTap!();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('reader-reference-bottom-sheet')),
      findsOneWidget,
    );
    expect(find.text('[36]'), findsWidgets);
    expect(
      find.textContaining('Label smoothing improves Transformer quality.'),
      findsWidgets,
    );
  });

  testWidgets('opens internal section references as bottom sheets', (
    tester,
  ) async {
    const sectionReferenceText =
        'See Section Reasoning About Action And Planning for details.';
    final package = _packageWithCustomBlocks(const [
      DocumentBlock.paragraph(
        id: 'b1',
        sectionId: 's1',
        text: sectionReferenceText,
        referenceSpans: [
          ReferenceSpan(
            start: 12,
            end: 47,
            targetAssetId: '',
            kind: ReferenceKind.reference,
            label: 'Section: Reasoning About Action And Planning',
          ),
        ],
      ),
      DocumentBlock(
        id: 'heading-1',
        sectionId: 's1',
        kind: BlockKind.heading,
        text: 'Reasoning About Action And Planning',
      ),
      DocumentBlock.paragraph(
        id: 'b2',
        sectionId: 's1',
        text: 'This section explains action and planning.',
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: ReaderScreen(documentId: 'doc-1', package: package),
      ),
    );

    final referenceSpan = _textSpanWithText(
      tester,
      'Reasoning About Action And Planning',
    );

    expect(referenceSpan.recognizer, isNotNull);
    expect(referenceSpan.style?.decoration, TextDecoration.underline);

    (referenceSpan.recognizer! as TapGestureRecognizer).onTap!();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('reader-inline-reference-bottom-sheet')),
      findsOneWidget,
    );
    final sheet = find.byKey(const Key('reader-inline-reference-bottom-sheet'));
    expect(
      find.text('Section: Reasoning About Action And Planning'),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: sheet,
        matching: find.text('This section explains action and planning.'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('reader selection uses thesis actions instead of platform menu', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderScreen(
          documentId: 'doc-1',
          package: _packageWithBlocks(['Transformer context sentence']),
        ),
      ),
    );

    final selectable = tester.widget<SelectableText>(
      find.byType(SelectableText),
    );

    expect(selectable.contextMenuBuilder, isNotNull);
  });

  testWidgets('reader selection boxes stay tight to selected glyphs', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderScreen(
          documentId: 'doc-1',
          package: _packageWithBlocks(['Right edge word']),
        ),
      ),
    );

    var selectable = tester.widget<SelectableText>(find.byType(SelectableText));
    expect(selectable.selectionWidthStyle, ui.BoxWidthStyle.tight);

    await tester.pumpWidget(
      MaterialApp(
        home: ReaderScreen(documentId: 'doc-1', package: _package()),
      ),
    );

    selectable = tester.widget<SelectableText>(find.byType(SelectableText));
    expect(selectable.selectionWidthStyle, ui.BoxWidthStyle.tight);
  });

  testWidgets('selection action clears handles before running translation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderScreen(
          documentId: 'doc-1',
          package: _packageWithBlocks(['Transformer context sentence']),
        ),
      ),
    );

    final editableState = tester.state<EditableTextState>(
      find.byType(EditableText).first,
    );
    editableState.userUpdateTextEditingValue(
      editableState.textEditingValue.copyWith(
        selection: const TextSelection(baseOffset: 0, extentOffset: 11),
      ),
      SelectionChangedCause.longPress,
    );

    final menu = _selectionToolbarForEditableText(tester, editableState);
    menu.buttonItems!.first.onPressed!();
    await tester.pump();

    expect(editableState.textEditingValue.selection.isCollapsed, isTrue);
  });

  testWidgets('long selection translation opens a constrained result sheet', (
    tester,
  ) async {
    const selectedText =
        'Answer set programming in its most basic form can be seen as a '
        'fragment of default logic with semantics directly traceable to '
        'default extensions and related nonmonotonic reasoning systems.';
    final client = SimpleTranslationClient(
      httpClient: MockClient((request) async {
        return http.Response.bytes(
          utf8.encode(
            '{"responseData":{"translatedText":"translated result"}}',
          ),
          200,
        );
      }),
    );
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ReaderScreen(
          documentId: 'doc-1',
          package: _packageWithBlocks([selectedText]),
          simpleTranslationClient: client,
        ),
      ),
    );

    final editableState = tester.state<EditableTextState>(
      find.byType(EditableText).first,
    );
    editableState.userUpdateTextEditingValue(
      editableState.textEditingValue.copyWith(
        selection: TextSelection(
          baseOffset: 0,
          extentOffset: selectedText.length,
        ),
      ),
      SelectionChangedCause.longPress,
    );

    final menu = _selectionToolbarForEditableText(tester, editableState);
    menu.buttonItems!.first.onPressed!();
    await tester.pumpAndSettle();

    final sheet = find.byKey(const Key('reader-translation-result-sheet'));
    expect(sheet, findsOneWidget);
    expect(
      find.descendant(of: sheet, matching: find.byType(SingleChildScrollView)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text(selectedText)),
      findsNothing,
    );
    expect(find.text('translated result'), findsOneWidget);
  });

  testWidgets('single-word translation result does not dim reader surface', (
    tester,
  ) async {
    final client = SimpleTranslationClient(
      httpClient: MockClient((request) async {
        return http.Response.bytes(
          utf8.encode('{"responseData":{"translatedText":"translated word"}}'),
          200,
        );
      }),
    );
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ReaderScreen(
          documentId: 'doc-1',
          package: _packageWithBlocks(['salient context sentence']),
          simpleTranslationClient: client,
        ),
      ),
    );

    final editableState = tester.state<EditableTextState>(
      find.byType(EditableText).first,
    );
    editableState.userUpdateTextEditingValue(
      editableState.textEditingValue.copyWith(
        selection: const TextSelection(baseOffset: 0, extentOffset: 7),
      ),
      SelectionChangedCause.longPress,
    );

    final menu = _selectionToolbarForEditableText(tester, editableState);
    menu.buttonItems!.first.onPressed!();
    await tester.pumpAndSettle();

    final sheet = find.byKey(const Key('reader-translation-result-sheet'));
    expect(sheet, findsOneWidget);
    expect(tester.getSize(sheet).height, lessThanOrEqualTo(260));
    expect(find.text('translated word'), findsOneWidget);
    expect(_hasColoredModalBarrier(tester), isFalse);
  });

  testWidgets('opens referenced asset in a bottom sheet', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderScreen(documentId: 'doc-1', package: _package()),
      ),
    );

    _referenceTapRecognizer(tester).onTap!();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('reader-asset-bottom-sheet')), findsOneWidget);
    expect(find.text('Figure 1'), findsWidgets);
    expect(find.text('Architecture diagram'), findsOneWidget);
    expect(find.text('assets/figures/figure-1.png'), findsOneWidget);
  });

  testWidgets('renders equation asset blocks inline', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderScreen(
          documentId: 'doc-1',
          package: _packageWithEquationAsset('/tmp/equation.png'),
        ),
      ),
    );

    expect(
      find.byKey(const Key('reader-inline-asset-equation-1')),
      findsOneWidget,
    );
  });

  testWidgets('fits equation assets into the inline reader width', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderScreen(
          documentId: 'doc-1',
          package: _packageWithEquationAsset('/tmp/equation.png'),
        ),
      ),
    );

    expect(
      find.byKey(const Key('reader-inline-equation-fit-equation-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('reader-inline-equation-scroll-equation-1')),
      findsNothing,
    );
  });

  testWidgets('prefers equation assets over client-side latex rendering', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderScreen(
          documentId: 'doc-1',
          package: _packageWithEquationAsset(
            '/tmp/equation.png',
            latex: r'\unsupportedPaperMacro{x}',
          ),
        ),
      ),
    );

    expect(
      find.byKey(const Key('reader-inline-asset-equation-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('reader-latex-equation-eq-block')),
      findsNothing,
    );
    expect(find.textContaining('Parser Error'), findsNothing);
  });

  testWidgets('renders latex equation blocks instead of fallback asset label', (
    tester,
  ) async {
    final package = _packageWithCustomBlocks([
      const DocumentBlock(
        id: 'eq-1',
        sectionId: 's1',
        kind: BlockKind.equation,
        latex: r'q(x_t \mid x_0) = \mathcal{N}(x_t; 0, I)',
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: ReaderScreen(documentId: 'doc-1', package: package),
      ),
    );

    expect(find.byKey(const Key('reader-latex-equation-eq-1')), findsOneWidget);
    expect(find.text('eq-1'), findsNothing);
  });

  testWidgets('hides raw parser errors for unsupported latex macros', (
    tester,
  ) async {
    final package = _packageWithCustomBlocks([
      const DocumentBlock(
        id: 'eq-unsupported',
        sectionId: 's1',
        kind: BlockKind.equation,
        latex: r'\unknownmacro{x}',
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: ReaderScreen(documentId: 'doc-1', package: package),
      ),
    );

    expect(
      find.byKey(const Key('reader-latex-equation-eq-unsupported')),
      findsOneWidget,
    );
    expect(find.textContaining('Parser Error'), findsNothing);
    expect(find.textContaining('수식을 표시할 수 없습니다'), findsOneWidget);
  });

  testWidgets('renders normalized DDPM source equations', (tester) async {
    final package = _packageWithCustomBlocks([
      const DocumentBlock(
        id: 'eq-ddpm',
        sectionId: 's1',
        kind: BlockKind.equation,
        latex:
            r'p_\theta(\mathbf{x}_{0:T}) := p(\mathbf{x}_T)\prod_{t=1}^T p_\theta(\mathbf{x}_{t-1}|\mathbf{x}_t), \boldsymbol{\mu}_\theta(\mathbf{x}_t,t)',
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: ReaderScreen(documentId: 'doc-1', package: package),
      ),
    );

    expect(
      find.byKey(const Key('reader-latex-equation-eq-ddpm')),
      findsOneWidget,
    );
    expect(find.textContaining('Parser Error'), findsNothing);
    expect(find.textContaining('수식을 표시할 수 없습니다'), findsNothing);
  });

  testWidgets('renders table asset blocks inline', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderScreen(
          documentId: 'doc-1',
          package: _packageWithTableAsset('/tmp/table.png'),
        ),
      ),
    );

    expect(
      find.byKey(const Key('reader-inline-asset-table-1')),
      findsOneWidget,
    );
  });

  testWidgets('opens referenced asset in fullscreen mode', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderScreen(
          documentId: 'doc-1',
          package: _package(),
          initialSettings: const ReaderSettings(
            assetOpenMode: AssetOpenMode.fullScreen,
          ),
        ),
      ),
    );

    _referenceTapRecognizer(tester).onTap!();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('reader-asset-fullscreen')), findsOneWidget);
    expect(find.text('Figure 1'), findsWidgets);
    expect(find.text('그림'), findsOneWidget);
  });

  testWidgets('ignores invalid and missing-target reference spans', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderScreen(
          documentId: 'doc-1',
          package: _package(
            referenceSpans: const [
              ReferenceSpan(
                start: 34,
                end: 42,
                targetAssetId: 'missing',
                kind: ReferenceKind.figure,
              ),
              ReferenceSpan(
                start: 90,
                end: 100,
                targetAssetId: 'figure-1',
                kind: ReferenceKind.figure,
              ),
            ],
          ),
        ),
      ),
    );

    final selectable = tester.widget<SelectableText>(
      find.byType(SelectableText),
    );

    expect(selectable.data, _referenceText);
    expect(selectable.textSpan, isNull);
  });

  testWidgets(
    'missing-target overlaps do not suppress later valid references',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ReaderScreen(
            documentId: 'doc-1',
            package: _package(
              referenceSpans: const [
                ReferenceSpan(
                  start: 19,
                  end: 31,
                  targetAssetId: 'missing',
                  kind: ReferenceKind.figure,
                ),
                ReferenceSpan(
                  start: 21,
                  end: 29,
                  targetAssetId: 'figure-1',
                  kind: ReferenceKind.figure,
                ),
              ],
            ),
          ),
        ),
      );

      final selectable = tester.widget<SelectableText>(
        find.byType(SelectableText),
      );
      final referenceSpan = selectable.textSpan!.children!
          .whereType<TextSpan>()
          .singleWhere((span) => span.text == 'Figure 1');

      expect(referenceSpan.recognizer, isNotNull);
    },
  );

  testWidgets('heading-like blocks render larger and bold inline', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderScreen(
          documentId: 'doc-1',
          package: _packageWithBlocks(['1', 'Introduction', 'Body paragraph']),
        ),
      ),
    );

    final heading = tester.widget<SelectableText>(
      find.byWidgetPredicate(
        (widget) => widget is SelectableText && widget.data == 'Introduction',
      ),
    );
    final body = tester.widget<SelectableText>(
      find.byWidgetPredicate(
        (widget) => widget is SelectableText && widget.data == 'Body paragraph',
      ),
    );

    expect(heading.style?.fontSize, greaterThan((body.style?.fontSize)!));
    expect(heading.style?.fontWeight, FontWeight.w700);
  });

  testWidgets('renders structured TeX line breaks and inline style spans', (
    tester,
  ) async {
    final package = _packageWithCustomBlocks([
      const DocumentBlock.paragraph(
        id: 'b1',
        sectionId: 's1',
        text: 'First line\nSecond line with bold and marked.',
        textSpans: [
          TextStyleSpan(start: 28, end: 32, bold: true),
          TextStyleSpan(start: 37, end: 43, highlight: true),
        ],
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: ReaderScreen(documentId: 'doc-1', package: package),
      ),
    );

    final selectable = tester.widget<SelectableText>(
      find.byType(SelectableText),
    );
    expect(selectable.textSpan, isNotNull);

    final boldSpan = _textSpanWithText(tester, 'bold');
    final highlightedSpan = _textSpanWithText(tester, 'marked');

    expect(boldSpan.style?.fontWeight, FontWeight.w700);
    expect(highlightedSpan.style?.backgroundColor, isNotNull);
    expect(_flattenSelectableText(selectable), contains('\n'));
  });

  testWidgets('renders TeX horizontal rules as reader dividers', (
    tester,
  ) async {
    final package = _packageWithCustomBlocks([
      const DocumentBlock(
        id: 'hr-1',
        sectionId: 's1',
        kind: BlockKind.paragraph,
        source: {'role': 'horizontalRule'},
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: ReaderScreen(documentId: 'doc-1', package: package),
      ),
    );

    expect(
      find.byKey(const Key('reader-horizontal-rule-hr-1')),
      findsOneWidget,
    );
  });
}

DocumentPackage _packageWithCustomBlocks(List<DocumentBlock> blocks) {
  return DocumentPackage(
    packageVersion: 1,
    documentId: 'doc-1',
    metadata: const DocumentMetadata(
      title: 'Reader Test',
      sourceFilename: 'reader.pdf',
      originalPdfSha256: 'abc123',
    ),
    sections: [
      DocumentSection(
        id: 's1',
        title: 'Body',
        blockIds: blocks.map((block) => block.id).toList(),
      ),
    ],
    blocks: blocks,
    assets: const [],
  );
}

DocumentPackage _packageWithBlocks(List<String> texts) {
  final blockIds = [
    for (var index = 0; index < texts.length; index++) 'b$index',
  ];

  return DocumentPackage(
    packageVersion: 1,
    documentId: 'doc-1',
    metadata: const DocumentMetadata(
      title: 'Reader Test',
      sourceFilename: 'reader.pdf',
      originalPdfSha256: 'abc123',
    ),
    sections: [DocumentSection(id: 's1', title: 'Body', blockIds: blockIds)],
    blocks: [
      for (var index = 0; index < texts.length; index++)
        DocumentBlock.paragraph(
          id: blockIds[index],
          sectionId: 's1',
          text: texts[index],
        ),
    ],
    assets: const [],
  );
}

DocumentPackage _packageWithEquationAsset(
  String equationPath, {
  String? latex,
}) {
  return DocumentPackage(
    packageVersion: 1,
    documentId: 'doc-1',
    metadata: const DocumentMetadata(
      title: 'Reader Test',
      sourceFilename: 'reader.pdf',
      originalPdfSha256: 'abc123',
    ),
    sections: const [
      DocumentSection(id: 's1', title: 'Body', blockIds: ['eq-block']),
    ],
    blocks: [
      DocumentBlock(
        id: 'eq-block',
        sectionId: 's1',
        kind: BlockKind.equation,
        assetId: 'equation-1',
        latex: latex,
      ),
    ],
    assets: [
      DocumentAsset(
        id: 'equation-1',
        kind: AssetKind.equation,
        label: 'Equation 1',
        relativePath: equationPath,
      ),
    ],
  );
}

DocumentPackage _packageWithTableAsset(String tablePath) {
  return DocumentPackage(
    packageVersion: 1,
    documentId: 'doc-1',
    metadata: const DocumentMetadata(
      title: 'Reader Test',
      sourceFilename: 'reader.pdf',
      originalPdfSha256: 'abc123',
    ),
    sections: const [
      DocumentSection(id: 's1', title: 'Body', blockIds: ['table-block']),
    ],
    blocks: const [
      DocumentBlock(
        id: 'table-block',
        sectionId: 's1',
        kind: BlockKind.table,
        assetId: 'table-1',
      ),
    ],
    assets: [
      DocumentAsset(
        id: 'table-1',
        kind: AssetKind.table,
        label: 'Table 1',
        relativePath: tablePath,
      ),
    ],
  );
}

DocumentPackage _packageWithCitation() {
  const text = 'Label smoothing improves BLEU [36].';
  return DocumentPackage(
    packageVersion: 1,
    documentId: 'doc-1',
    metadata: const DocumentMetadata(
      title: 'Reader Test',
      sourceFilename: 'reader.pdf',
      originalPdfSha256: 'abc123',
    ),
    sections: const [
      DocumentSection(id: 's1', title: 'Body', blockIds: ['b1', 'ref-36']),
    ],
    blocks: const [
      DocumentBlock.paragraph(
        id: 'b1',
        sectionId: 's1',
        text: text,
        referenceSpans: [
          ReferenceSpan(
            start: 30,
            end: 34,
            targetAssetId: '',
            kind: ReferenceKind.citation,
          ),
        ],
      ),
      DocumentBlock(
        id: 'ref-36',
        sectionId: 's1',
        kind: BlockKind.reference,
        text:
            '[36] Ashish Vaswani et al. Label smoothing improves Transformer quality.',
      ),
    ],
    assets: const [],
  );
}

const _referenceText = 'This paragraph cites Figure 1 in context.';

TapGestureRecognizer _referenceTapRecognizer(WidgetTester tester) {
  return tester
          .widget<SelectableText>(find.byType(SelectableText))
          .textSpan!
          .children!
          .whereType<TextSpan>()
          .singleWhere((span) => span.text == 'Figure 1')
          .recognizer!
      as TapGestureRecognizer;
}

TextSpan _textSpanWithText(WidgetTester tester, String text) {
  for (final selectable in tester.widgetList<SelectableText>(
    find.byType(SelectableText),
  )) {
    final span = selectable.textSpan;
    if (span == null) {
      continue;
    }
    for (final child in span.children ?? const <InlineSpan>[]) {
      if (child is TextSpan && child.text == text) {
        return child;
      }
    }
  }
  throw StateError('No TextSpan found for $text');
}

AdaptiveTextSelectionToolbar _selectionToolbarForEditableText(
  WidgetTester tester,
  EditableTextState editableState,
) {
  final selectable = tester.widget<SelectableText>(
    find.byType(SelectableText).first,
  );
  return selectable.contextMenuBuilder!(editableState.context, editableState)
      as AdaptiveTextSelectionToolbar;
}

String _flattenSelectableText(SelectableText selectable) {
  final data = selectable.data;
  if (data != null) {
    return data;
  }
  final buffer = StringBuffer();
  void visit(InlineSpan span) {
    if (span is TextSpan) {
      buffer.write(span.text ?? '');
      for (final child in span.children ?? const <InlineSpan>[]) {
        visit(child);
      }
    }
  }

  visit(selectable.textSpan!);
  return buffer.toString();
}

bool _hasColoredModalBarrier(WidgetTester tester) {
  for (final barrier in tester.widgetList(find.byType(ModalBarrier))) {
    if (barrier is ModalBarrier &&
        barrier.color != null &&
        barrier.color!.a != 0) {
      return true;
    }
  }
  for (final barrier in tester.widgetList(find.byType(AnimatedModalBarrier))) {
    if (barrier is AnimatedModalBarrier &&
        barrier.color.value != null &&
        barrier.color.value!.a != 0) {
      return true;
    }
  }
  return false;
}

DocumentPackage _package({List<ReferenceSpan>? referenceSpans}) {
  return DocumentPackage(
    packageVersion: 1,
    documentId: 'doc-1',
    metadata: const DocumentMetadata(
      title: 'Reader Test',
      sourceFilename: 'reader.pdf',
      originalPdfSha256: 'abc123',
    ),
    sections: const [
      DocumentSection(id: 's1', title: 'Body', blockIds: ['b1']),
    ],
    blocks: [
      DocumentBlock.paragraph(
        id: 'b1',
        sectionId: 's1',
        text: _referenceText,
        referenceSpans:
            referenceSpans ??
            const [
              ReferenceSpan(
                start: 21,
                end: 29,
                targetAssetId: 'figure-1',
                kind: ReferenceKind.figure,
              ),
            ],
      ),
    ],
    assets: const [
      DocumentAsset(
        id: 'figure-1',
        kind: AssetKind.figure,
        label: 'Figure 1',
        relativePath: 'assets/figures/figure-1.png',
        caption: 'Architecture diagram',
      ),
    ],
  );
}

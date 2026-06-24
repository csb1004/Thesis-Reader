import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_reader/features/reader/domain/reader_settings.dart';
import 'package:thesis_reader/features/reader/presentation/viewer_settings_sheet.dart';

void main() {
  testWidgets('shows reader setting controls', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ViewerSettingsSheet())),
    );

    expect(find.byKey(const Key('reader-theme-paper')), findsOneWidget);
    expect(find.byKey(const Key('reader-theme-dark')), findsOneWidget);
    expect(find.byKey(const Key('reader-font-system')), findsOneWidget);
    expect(find.byKey(const Key('reader-font-serif')), findsOneWidget);
    expect(find.byType(Slider), findsNWidgets(3));
    expect(find.byType(SegmentedButton<ReadingMode>), findsOneWidget);
    expect(find.byType(SegmentedButton<AssetOpenMode>), findsOneWidget);
  });

  testWidgets('emits updated theme and font family settings', (tester) async {
    final changes = <ReaderSettings>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ViewerSettingsSheet(
            settings: const ReaderSettings(),
            onChanged: changes.add,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('reader-theme-dark')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('reader-font-serif')));
    await tester.pump();

    expect(changes.map((settings) => settings.themeId), contains('dark'));
    expect(changes.map((settings) => settings.fontFamily), contains('serif'));
  });
}

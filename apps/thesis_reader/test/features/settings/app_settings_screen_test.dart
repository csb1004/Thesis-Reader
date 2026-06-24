import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_reader/features/settings/presentation/app_settings_screen.dart';

void main() {
  testWidgets('settings saves and clears the OpenAI key', (tester) async {
    String? savedKey;
    var cleared = false;

    await tester.pumpWidget(
      MaterialApp(
        home: AppSettingsScreen(
          onSaveOpenAiApiKey: (apiKey) async => savedKey = apiKey,
          onClearOpenAiApiKey: () async => cleared = true,
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '  sk-test  ');
    await tester.tap(find.text('저장'));
    await tester.pump();

    expect(savedKey, 'sk-test');

    await tester.tap(find.text('삭제'));
    await tester.pump();

    expect(cleared, isTrue);
  });

  testWidgets('settings changes the default translation mode', (tester) async {
    TranslationModePreference? selectedMode;

    await tester.pumpWidget(
      MaterialApp(
        home: AppSettingsScreen(
          onTranslationModeChanged: (mode) => selectedMode = mode,
        ),
      ),
    );

    await tester.tap(find.text('OpenAI').last);
    await tester.pumpAndSettle();

    expect(selectedMode, TranslationModePreference.openAi);
  });
}

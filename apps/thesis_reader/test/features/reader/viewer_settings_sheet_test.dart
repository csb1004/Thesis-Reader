import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_reader/features/reader/presentation/viewer_settings_sheet.dart';

void main() {
  testWidgets('shows viewer setting labels', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ViewerSettingsSheet())),
    );

    expect(find.text('뷰어 설정'), findsOneWidget);
    expect(find.text('열람 방식'), findsOneWidget);
    expect(find.text('글자 크기'), findsOneWidget);
    expect(find.text('줄 간격'), findsOneWidget);
    expect(find.text('여백'), findsOneWidget);
    expect(find.text('그림 열기'), findsOneWidget);
  });
}

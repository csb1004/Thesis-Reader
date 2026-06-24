# Reader Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Polish reader pagination, manual PDF reconversion, Korean language labels, and the white reader theme.

**Architecture:** Keep changes inside the existing Flutter app layers. Reader layout changes stay in the reader domain/presentation files, manual conversion is wired through the library screen callbacks and existing Railway converter client, and Korean labels are plain strings in current widgets.

**Tech Stack:** Flutter, Dart, Drift, pdfx, existing Railway converter HTTP client.

---

### Task 1: Reader Page Fill and White Theme

**Files:**
- Modify: `apps/thesis_reader/lib/features/reader/domain/reader_settings.dart`
- Modify: `apps/thesis_reader/lib/features/reader/presentation/reader_screen.dart`
- Modify: `apps/thesis_reader/lib/features/reader/presentation/viewer_settings_sheet.dart`
- Test: `apps/thesis_reader/test/features/reader/viewer_settings_sheet_test.dart`
- Test: `apps/thesis_reader/test/features/reader/reader_layout_engine_test.dart`

- [ ] Add `ReaderThemeData(id: 'white', label: '흰색', backgroundColor: Color(0xFFFFFFFF), textColor: Color(0xFF171717))`.
- [ ] Change viewer settings labels to Korean: 보기 설정, 테마, 글꼴, 보기 방식, 글자 크기, 줄 간격, 여백, 그림 열기, 페이지, 스크롤, 아래 창, 전체 화면.
- [ ] In `_PageModeReader`, replace the full-page padding/Column layout with a footer-aware layout:

```dart
const footerHeight = 28.0;
final outerPadding = 24 * settings.marginScale;
return Padding(
  padding: EdgeInsets.all(outerPadding),
  child: Column(
    children: [
      Expanded(child: ...blocks...),
      SizedBox(
        height: footerHeight,
        child: Align(...pageNumber...),
      ),
    ],
  ),
);
```

- [ ] Add or adjust tests to assert the white theme swatch exists and settings labels are Korean.
- [ ] Run `flutter test test/features/reader/viewer_settings_sheet_test.dart test/features/reader/reader_layout_engine_test.dart`.

### Task 2: Korean Reader Text

**Files:**
- Modify: `apps/thesis_reader/lib/features/reader/presentation/reader_screen.dart`
- Test: `apps/thesis_reader/test/features/reader/reader_screen_test.dart`

- [ ] Replace mojibake and English labels in reader screen:

```dart
title: Text(package?.metadata.title ?? '리더')
tooltip: '현재 페이지 요약'
tooltip: '단어장'
tooltip: '보기 설정'
label: '단순 번역'
label: 'OpenAI 번역'
label: '단어장에 추가'
```

- [ ] Replace snackbars and dialogs with Korean messages for missing token, translation, summary, vocabulary save, asset preview, and empty fallback.
- [ ] Run `flutter test test/features/reader/reader_screen_test.dart`.

### Task 3: Manual Reconversion

**Files:**
- Modify: `apps/thesis_reader/lib/features/library/presentation/library_screen.dart`
- Modify: `apps/thesis_reader/lib/app.dart`
- Test: `apps/thesis_reader/test/features/library/library_screen_test.dart`

- [ ] Add `onReconvertDocument` callback to `LibraryScreen`.
- [ ] Add document popup menu item `PDF 다시 변환` with `Icons.sync`.
- [ ] In `_LibraryHomeState`, add `_reconvertDocument(String documentId)` that finds the stored original PDF path, sets status to `변환 중`, calls `_convertWithRailway`, and reloads documents.
- [ ] Make `_convertWithRailway` reusable for imports and manual conversion. On success, update status to `변환 완료`; on failure, update status to `변환 실패 - 원본 보기`.
- [ ] Run `flutter test test/features/library/library_screen_test.dart`.

### Task 4: Library Korean Labels and Verification

**Files:**
- Modify: `apps/thesis_reader/lib/app.dart`
- Modify: `apps/thesis_reader/lib/features/library/presentation/library_screen.dart`
- Test: existing Flutter tests

- [ ] Replace broken Korean strings in app/library dialogs and snackbars with normal Korean.
- [ ] Run `flutter analyze`.
- [ ] Run `flutter test`.
- [ ] Run `services/converter/.venv/Scripts/python.exe -m pytest`.
- [ ] Run `flutter build apk --release`.
- [ ] Commit, push to `main`, create `v0.1.9-mvp` release with the release APK.

## Self-Review

- Spec coverage: page fill, manual conversion, white theme, and Korean labels are covered.
- Placeholder scan: no TODO/TBD placeholders.
- Type consistency: callback names and files match existing Flutter structure.

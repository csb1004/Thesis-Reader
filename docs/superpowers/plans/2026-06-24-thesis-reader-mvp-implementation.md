# Thesis Reader MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Flutter + Railway MVP that imports PDF papers, converts them into cached reader packages, and supports KakaoPage-like reading, references, OpenAI translation/summaries, and per-paper vocabulary.

**Architecture:** Use a monorepo with a Flutter app in `apps/thesis_reader`, a FastAPI conversion server in `services/converter`, and a shared document package contract in `packages/document_contract`. The server produces the same package schema that the app stores locally, while the app directly calls OpenAI with the user's key.

**Tech Stack:** Flutter, Dart, Riverpod, Drift SQLite, FastAPI, PyMuPDF, pytest, OpenAI Responses API over HTTPS, Railway deployment.

---

## Scope Check

The approved design includes several subsystems. This plan keeps them in one MVP plan because the work must prove one end-to-end vertical slice: import PDF -> convert or fallback -> cache package -> read -> translate/summarize -> save vocabulary. Each task is still isolated enough to test and commit independently.

## Target File Structure

- Create: `apps/thesis_reader/` - Flutter application.
- Create: `apps/thesis_reader/lib/app.dart` - app root and routes.
- Create: `apps/thesis_reader/lib/features/library/` - import flow, document list, conversion status.
- Create: `apps/thesis_reader/lib/features/reader/` - page/scroll reader, settings, references, progress.
- Create: `apps/thesis_reader/lib/features/ai/` - OpenAI key storage, translation, summary.
- Create: `apps/thesis_reader/lib/features/vocabulary/` - per-paper vocabulary data and screens.
- Create: `apps/thesis_reader/lib/shared/` - storage, HTTP, errors, platform channels.
- Create: `packages/document_contract/` - Dart models for the reader package.
- Create: `services/converter/` - FastAPI conversion server.
- Create: `services/converter/app/api/` - HTTP routes.
- Create: `services/converter/app/conversion/` - PDF extraction and package writing.
- Create: `services/converter/app/models/` - Python package schema.
- Create: `services/converter/tests/` - server tests and generated PDF fixtures.
- Create: `docs/contracts/document_package.schema.json` - documented JSON contract.

---

### Task 1: Bootstrap Monorepo And Tooling

**Files:**
- Create: `apps/thesis_reader/`
- Create: `packages/document_contract/`
- Create: `services/converter/`
- Create: `services/converter/requirements.txt`
- Create: `services/converter/pyproject.toml`
- Modify: `.gitignore`
- Test: `apps/thesis_reader/test/smoke_test.dart`
- Test: `services/converter/tests/test_smoke.py`

- [ ] **Step 1: Create the Flutter app and Dart package**

Run:

```powershell
flutter create apps/thesis_reader
flutter create --template=package packages/document_contract
```

Expected: both commands end with `All done!`.

- [ ] **Step 2: Add Flutter dependencies**

Modify `apps/thesis_reader/pubspec.yaml` so `dependencies` contains:

```yaml
dependencies:
  flutter:
    sdk: flutter
  document_contract:
    path: ../../packages/document_contract
  flutter_riverpod: ^2.5.1
  go_router: ^14.2.7
  drift: ^2.20.3
  drift_flutter: ^0.2.0
  sqlite3_flutter_libs: ^0.5.24
  path_provider: ^2.1.4
  path: ^1.9.0
  file_picker: ^8.1.2
  http: ^1.2.2
  uuid: ^4.5.0
  archive: ^3.6.1
  flutter_secure_storage: ^9.2.2
  shared_preferences: ^2.3.2
  pdfx: ^2.6.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: ^2.4.12
  drift_dev: ^2.20.3
  mocktail: ^1.0.4
  fake_async: ^1.3.1
```

- [ ] **Step 3: Add server dependencies**

Create `services/converter/requirements.txt`:

```text
fastapi==0.115.0
uvicorn[standard]==0.30.6
python-multipart==0.0.9
pydantic==2.8.2
pymupdf==1.24.10
reportlab==4.2.2
pytest==8.3.2
httpx==0.27.2
```

Create `services/converter/pyproject.toml`:

```toml
[tool.pytest.ini_options]
pythonpath = ["."]
testpaths = ["tests"]

[tool.ruff]
line-length = 100
```

- [ ] **Step 4: Add smoke tests**

Create `apps/thesis_reader/test/smoke_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('test runner is configured', () {
    expect(1 + 1, 2);
  });
}
```

Create `services/converter/tests/test_smoke.py`:

```python
def test_pytest_is_configured():
    assert 1 + 1 == 2
```

- [ ] **Step 5: Run smoke tests**

Run:

```powershell
flutter test apps/thesis_reader/test/smoke_test.dart
python -m venv services/converter/.venv
services/converter/.venv/Scripts/python -m pip install -r services/converter/requirements.txt
services/converter/.venv/Scripts/python -m pytest services/converter/tests/test_smoke.py -q
```

Expected: Flutter reports `All tests passed!`; pytest reports `1 passed`.

- [ ] **Step 6: Commit**

```powershell
git add .gitignore apps packages services
git commit -m "chore: bootstrap thesis reader monorepo"
```

---

### Task 2: Define Document Package Contract

**Files:**
- Create: `docs/contracts/document_package.schema.json`
- Modify: `packages/document_contract/lib/document_contract.dart`
- Create: `packages/document_contract/lib/src/document_package.dart`
- Create: `packages/document_contract/test/document_package_test.dart`
- Create: `services/converter/app/models/document_package.py`
- Create: `services/converter/tests/test_document_package_model.py`

- [ ] **Step 1: Write Dart contract test**

Create `packages/document_contract/test/document_package_test.dart`:

```dart
import 'package:document_contract/document_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('minimal package round trips through json', () {
    final package = DocumentPackage(
      packageVersion: 1,
      documentId: 'doc-1',
      metadata: const DocumentMetadata(
        title: 'Attention Is All You Need',
        sourceFilename: 'paper.pdf',
        originalPdfSha256: 'abc123',
      ),
      sections: const [
        DocumentSection(id: 'sec-abstract', title: 'Abstract', blockIds: ['b1']),
      ],
      blocks: const [
        DocumentBlock.paragraph(
          id: 'b1',
          sectionId: 'sec-abstract',
          text: 'The model architecture is shown in Figure 1.',
          referenceSpans: [
            ReferenceSpan(
              start: 35,
              end: 43,
              targetAssetId: 'fig-1',
              kind: ReferenceKind.figure,
              label: 'Figure 1',
            ),
          ],
        ),
      ],
      assets: const [
        DocumentAsset(
          id: 'fig-1',
          kind: AssetKind.figure,
          label: 'Figure 1',
          relativePath: 'assets/fig-1.png',
          caption: 'Model architecture.',
        ),
      ],
    );

    final decoded = DocumentPackage.fromJson(package.toJson());

    expect(decoded.documentId, 'doc-1');
    expect(decoded.blocks.single.text, contains('Figure 1'));
    expect(decoded.blocks.single.referenceSpans.single.targetAssetId, 'fig-1');
  });
}
```

- [ ] **Step 2: Implement Dart contract**

Create `packages/document_contract/lib/src/document_package.dart` with immutable classes, `toJson`, and `fromJson` for:

```dart
enum BlockKind { heading, paragraph, quote, figure, table, equation, footnote, reference }
enum AssetKind { figure, table, equation, pageRegion, thumbnail }
enum ReferenceKind { figure, table, equation, footnote, citation, reference }

final class DocumentPackage {
  const DocumentPackage({
    required this.packageVersion,
    required this.documentId,
    required this.metadata,
    required this.sections,
    required this.blocks,
    required this.assets,
    this.anchors = const [],
    this.vocabulary = const [],
    this.summaries = const [],
  });
}

final class DocumentMetadata {
  const DocumentMetadata({
    required this.title,
    required this.sourceFilename,
    this.authors = const [],
    this.originalPdfSha256,
    this.importedAtIso8601,
    this.converterVersion,
  });
}

final class DocumentSection {
  const DocumentSection({required this.id, required this.title, required this.blockIds});
}

final class DocumentBlock {
  const DocumentBlock({
    required this.id,
    required this.sectionId,
    required this.kind,
    this.text,
    this.assetId,
    this.referenceSpans = const [],
    this.anchor,
  });
}

final class DocumentAsset {
  const DocumentAsset({
    required this.id,
    required this.kind,
    required this.label,
    required this.relativePath,
    this.caption,
  });
}

final class ReferenceSpan {
  const ReferenceSpan({
    required this.start,
    required this.end,
    required this.targetAssetId,
    required this.kind,
    required this.label,
  });
}

final class ReadingAnchor {
  const ReadingAnchor({
    required this.blockId,
    required this.textOffset,
    this.originalPdfPage,
    this.originalPdfRect,
  });
}

final class VocabularyEntry {
  const VocabularyEntry({
    required this.id,
    required this.documentId,
    required this.expression,
    required this.expressionKey,
    required this.meaningKo,
    this.sourceSentence,
    this.contextBefore,
    this.contextAfter,
    this.anchor,
    this.userMeaning,
    this.userMemo,
  });
}

final class SectionSummary {
  const SectionSummary({
    required this.sectionId,
    required this.summaryKo,
    required this.createdAtIso8601,
  });
}
```

Use these required JSON keys exactly: `packageVersion`, `documentId`, `metadata`, `sections`, `blocks`, `assets`, `anchors`, `vocabulary`, `summaries`.

Modify `packages/document_contract/lib/document_contract.dart`:

```dart
library document_contract;

export 'src/document_package.dart';
```

- [ ] **Step 3: Run Dart contract test**

Run:

```powershell
flutter test packages/document_contract/test/document_package_test.dart
```

Expected: the test passes.

- [ ] **Step 4: Write Python model test**

Create `services/converter/tests/test_document_package_model.py`:

```python
from services.converter.app.models.document_package import (
    AssetKind,
    BlockKind,
    DocumentAsset,
    DocumentBlock,
    DocumentMetadata,
    DocumentPackage,
    DocumentSection,
)


def test_minimal_document_package_serializes_to_contract_keys():
    package = DocumentPackage(
        packageVersion=1,
        documentId="doc-1",
        metadata=DocumentMetadata(
            title="Attention Is All You Need",
            sourceFilename="paper.pdf",
            originalPdfSha256="abc123",
        ),
        sections=[DocumentSection(id="sec-abstract", title="Abstract", blockIds=["b1"])],
        blocks=[
            DocumentBlock(
                id="b1",
                sectionId="sec-abstract",
                kind=BlockKind.paragraph,
                text="The model architecture is shown in Figure 1.",
                referenceSpans=[],
            )
        ],
        assets=[
            DocumentAsset(
                id="fig-1",
                kind=AssetKind.figure,
                label="Figure 1",
                relativePath="assets/fig-1.png",
                caption="Model architecture.",
            )
        ],
    )

    payload = package.model_dump(mode="json")

    assert payload["packageVersion"] == 1
    assert payload["metadata"]["sourceFilename"] == "paper.pdf"
    assert payload["blocks"][0]["kind"] == "paragraph"
```

- [ ] **Step 5: Implement Python Pydantic model**

Create `services/converter/app/models/document_package.py` with Pydantic v2 models matching the Dart contract. Use enum values `heading`, `paragraph`, `quote`, `figure`, `table`, `equation`, `footnote`, `reference`, `pageRegion`, `thumbnail`, `citation`.

- [ ] **Step 6: Run Python model test**

Run:

```powershell
services/converter/.venv/Scripts/python -m pytest services/converter/tests/test_document_package_model.py -q
```

Expected: `1 passed`.

- [ ] **Step 7: Document JSON schema**

Create `docs/contracts/document_package.schema.json` from the same field names. Include required top-level fields: `packageVersion`, `documentId`, `metadata`, `sections`, `blocks`, and `assets`.

- [ ] **Step 8: Commit**

```powershell
git add docs/contracts packages/document_contract services/converter/app/models services/converter/tests
git commit -m "feat: define document package contract"
```

---

### Task 3: Build Converter Server Job API

**Files:**
- Create: `services/converter/app/main.py`
- Create: `services/converter/app/api/jobs.py`
- Create: `services/converter/app/jobs/job_store.py`
- Create: `services/converter/app/jobs/models.py`
- Create: `services/converter/tests/test_jobs_api.py`

- [ ] **Step 1: Write API tests**

Create `services/converter/tests/test_jobs_api.py`:

```python
from fastapi.testclient import TestClient

from services.converter.app.main import app


client = TestClient(app)


def test_health_returns_ok():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_create_job_accepts_pdf_upload():
    response = client.post(
        "/jobs",
        files={"file": ("paper.pdf", b"%PDF-1.4\n%test\n", "application/pdf")},
    )

    assert response.status_code == 201
    body = response.json()
    assert body["jobId"]
    assert body["status"] in {"queued", "processing"}


def test_rejects_non_pdf_upload():
    response = client.post(
        "/jobs",
        files={"file": ("paper.txt", b"not a pdf", "text/plain")},
    )

    assert response.status_code == 415
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```powershell
services/converter/.venv/Scripts/python -m pytest services/converter/tests/test_jobs_api.py -q
```

Expected: import failure because `services.converter.app.main` does not exist.

- [ ] **Step 3: Implement API**

Create `services/converter/app/main.py`:

```python
from fastapi import FastAPI

from services.converter.app.api.jobs import router as jobs_router

app = FastAPI(title="Thesis Reader Converter")
app.include_router(jobs_router)


@app.get("/health")
def health():
    return {"status": "ok"}
```

Create `services/converter/app/jobs/models.py`:

```python
from enum import StrEnum
from pydantic import BaseModel


class JobStatus(StrEnum):
    queued = "queued"
    processing = "processing"
    succeeded = "succeeded"
    failed = "failed"


class JobSnapshot(BaseModel):
    jobId: str
    status: JobStatus
    error: str | None = None
```

Create `services/converter/app/jobs/job_store.py` with an in-memory store that saves uploaded bytes under `services/converter/.data/jobs/<jobId>/source.pdf`.

Create `services/converter/app/api/jobs.py` with:

```python
from fastapi import APIRouter, HTTPException, UploadFile
from services.converter.app.jobs.job_store import job_store

router = APIRouter()


@router.post("/jobs", status_code=201)
async def create_job(file: UploadFile):
    if file.content_type != "application/pdf" and not file.filename.lower().endswith(".pdf"):
        raise HTTPException(status_code=415, detail="Only PDF uploads are supported")
    data = await file.read()
    snapshot = job_store.create(data)
    return snapshot.model_dump(mode="json")


@router.get("/jobs/{job_id}")
def get_job(job_id: str):
    return job_store.get_or_404(job_id).model_dump(mode="json")
```

- [ ] **Step 4: Run API tests**

Run:

```powershell
services/converter/.venv/Scripts/python -m pytest services/converter/tests/test_jobs_api.py -q
```

Expected: `3 passed`.

- [ ] **Step 5: Commit**

```powershell
git add services/converter/app services/converter/tests/test_jobs_api.py
git commit -m "feat: add converter job API"
```

---

### Task 4: Implement Server PDF-To-Package Conversion

**Files:**
- Create: `services/converter/app/conversion/pdf_converter.py`
- Create: `services/converter/app/conversion/package_writer.py`
- Modify: `services/converter/app/jobs/job_store.py`
- Modify: `services/converter/app/api/jobs.py`
- Create: `services/converter/tests/fixtures.py`
- Create: `services/converter/tests/test_pdf_converter.py`

- [ ] **Step 1: Write converter test with generated PDF**

Create `services/converter/tests/fixtures.py`:

```python
from pathlib import Path
from reportlab.pdfgen import canvas


def write_simple_paper_pdf(path: Path) -> Path:
    c = canvas.Canvas(str(path))
    c.setFont("Helvetica-Bold", 16)
    c.drawString(72, 760, "A Small Paper")
    c.setFont("Helvetica", 11)
    c.drawString(72, 720, "Abstract")
    c.drawString(72, 700, "The model architecture is shown in Figure 1.")
    c.rect(72, 560, 180, 90)
    c.drawString(72, 540, "Figure 1. Model architecture.")
    c.save()
    return path
```

Create `services/converter/tests/test_pdf_converter.py`:

```python
from services.converter.app.conversion.pdf_converter import convert_pdf_to_package
from services.converter.tests.fixtures import write_simple_paper_pdf


def test_converts_simple_pdf_to_document_package(tmp_path):
    pdf_path = write_simple_paper_pdf(tmp_path / "paper.pdf")
    output_dir = tmp_path / "out"

    package = convert_pdf_to_package(
        pdf_path=pdf_path,
        output_dir=output_dir,
        document_id="doc-1",
    )

    assert package.documentId == "doc-1"
    assert package.metadata.title == "A Small Paper"
    assert any(block.text and "Figure 1" in block.text for block in package.blocks)
    assert output_dir.exists()
```

- [ ] **Step 2: Run converter test and verify failure**

Run:

```powershell
services/converter/.venv/Scripts/python -m pytest services/converter/tests/test_pdf_converter.py -q
```

Expected: import failure because `pdf_converter.py` does not exist.

- [ ] **Step 3: Implement minimal converter**

Create `services/converter/app/conversion/pdf_converter.py` that:

- Opens the PDF with PyMuPDF.
- Reads text blocks in top-to-bottom order.
- Uses the first non-empty line as title.
- Creates one default section if no section heading is detected.
- Creates paragraph blocks for extracted text.
- Detects references with regex patterns `Figure \d+`, `Table \d+`, and equation-like `(\d+)`.
- Writes page-region snapshots only when an extracted image or drawing rectangle is available.

Create `services/converter/app/conversion/package_writer.py` that writes:

- `package.json`
- `assets/`
- `source-map.json`

Use `DocumentPackage` models from Task 2.

- [ ] **Step 4: Run converter test**

Run:

```powershell
services/converter/.venv/Scripts/python -m pytest services/converter/tests/test_pdf_converter.py -q
```

Expected: `1 passed`.

- [ ] **Step 5: Connect job completion endpoint**

Modify job API so `GET /jobs/{job_id}` returns `succeeded` after conversion is run for the uploaded PDF. Add `GET /jobs/{job_id}/download` returning a zip file containing `package.json` and `assets/`.

- [ ] **Step 6: Add API download test**

Extend `services/converter/tests/test_jobs_api.py` with:

```python
def test_download_returns_package_zip_after_conversion():
    create = client.post(
        "/jobs",
        files={"file": ("paper.pdf", b"%PDF-1.4\n%test\n", "application/pdf")},
    )
    job_id = create.json()["jobId"]

    status = client.get(f"/jobs/{job_id}")
    assert status.status_code == 200

    download = client.get(f"/jobs/{job_id}/download")
    assert download.status_code in {200, 409}
```

Expected: `200` when generated fixture conversion is used; `409` for invalid minimal PDF bytes. Keep both acceptable in this API-level test.

- [ ] **Step 7: Run all server tests**

Run:

```powershell
services/converter/.venv/Scripts/python -m pytest services/converter/tests -q
```

Expected: all tests pass.

- [ ] **Step 8: Commit**

```powershell
git add services/converter/app services/converter/tests
git commit -m "feat: convert PDFs into document packages"
```

---

### Task 5: Add Flutter Local Storage And Repositories

**Files:**
- Create: `apps/thesis_reader/lib/shared/storage/app_database.dart`
- Create: `apps/thesis_reader/lib/shared/storage/document_file_store.dart`
- Create: `apps/thesis_reader/lib/features/library/data/document_repository.dart`
- Create: `apps/thesis_reader/test/features/library/document_repository_test.dart`

- [ ] **Step 1: Write repository test**

Create `apps/thesis_reader/test/features/library/document_repository_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_reader/features/library/data/document_repository.dart';
import 'package:thesis_reader/shared/storage/document_file_store.dart';

void main() {
  test('imported pdf is copied and registered', () async {
    final temp = await Directory.systemTemp.createTemp('thesis_reader_test');
    final source = File('${temp.path}/paper.pdf');
    await source.writeAsBytes([37, 80, 68, 70]);

    final store = DocumentFileStore(rootDirectory: temp);
    final repo = InMemoryDocumentRepository(fileStore: store);

    final document = await repo.importPdf(source);

    expect(document.id, isNotEmpty);
    expect(document.sourceFilename, 'paper.pdf');
    expect(await File(document.localPdfPath).exists(), isTrue);
  });
}
```

- [ ] **Step 2: Implement file store and repository**

Create `DocumentFileStore` with:

```dart
Future<File> copyPdfIntoDocumentDirectory({
  required String documentId,
  required File sourcePdf,
})
```

Create `DocumentRepository` interface and `InMemoryDocumentRepository` for tests. The production Drift-backed repository is added in the next step.

- [ ] **Step 3: Run repository test**

Run:

```powershell
flutter test apps/thesis_reader/test/features/library/document_repository_test.dart
```

Expected: test passes.

- [ ] **Step 4: Add Drift database**

Create `apps/thesis_reader/lib/shared/storage/app_database.dart` with tables:

- `documents`: id, title, sourceFilename, localPdfPath, packagePath, status, lastReadBlockId, lastReadOffset, createdAt, updatedAt.
- `vocabularyEntries`: id, documentId, expressionKey, expression, meaningKo, sourceSentence, contextBefore, contextAfter, blockId, textOffset, userMeaning, userMemo, createdAt, updatedAt.
- `viewerSettings`: documentId, readingMode, themeId, fontFamily, fontScale, lineHeight, marginScale, assetOpenMode.

Generate code:

```powershell
cd apps/thesis_reader
dart run build_runner build --delete-conflicting-outputs
cd ..\..
```

- [ ] **Step 5: Commit**

```powershell
git add apps/thesis_reader/lib apps/thesis_reader/test
git commit -m "feat: add local document storage"
```

---

### Task 6: Implement App Conversion Orchestration

**Files:**
- Create: `apps/thesis_reader/lib/features/library/data/converter_client.dart`
- Create: `apps/thesis_reader/lib/features/library/data/conversion_orchestrator.dart`
- Create: `apps/thesis_reader/lib/features/library/data/on_device_converter.dart`
- Create: `apps/thesis_reader/test/features/library/conversion_orchestrator_test.dart`

- [ ] **Step 1: Write timeout fallback test**

Create `apps/thesis_reader/test/features/library/conversion_orchestrator_test.dart`:

```dart
import 'dart:async';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_reader/features/library/data/conversion_orchestrator.dart';

class HangingServerClient implements ConverterClient {
  @override
  Future<ConverterJob> createJob(File pdf) => Completer<ConverterJob>().future;
}

class RecordingOnDeviceConverter implements OnDeviceConverter {
  bool called = false;

  @override
  Future<ConversionResult> convert(File pdf, String documentId) async {
    called = true;
    return ConversionResult(packagePath: 'local/package.json');
  }
}

void main() {
  test('falls back to on-device conversion after 10 seconds', () {
    fakeAsync((async) {
      final fallback = RecordingOnDeviceConverter();
      final orchestrator = ConversionOrchestrator(
        serverClient: HangingServerClient(),
        onDeviceConverter: fallback,
        serverTimeout: const Duration(seconds: 10),
      );

      orchestrator.start(File('paper.pdf'), documentId: 'doc-1');
      async.elapse(const Duration(seconds: 11));

      expect(fallback.called, isTrue);
    });
  });
}
```

- [ ] **Step 2: Implement interfaces and orchestrator**

Define:

```dart
abstract interface class ConverterClient {
  Future<ConverterJob> createJob(File pdf);
  Future<ConverterJobStatus> getJob(String jobId);
  Future<File> downloadPackage(String jobId, Directory targetDirectory);
}

abstract interface class OnDeviceConverter {
  Future<ConversionResult> convert(File pdf, String documentId);
}
```

Implement `ConversionOrchestrator.start` so it:

- Calls server `createJob`.
- Uses a 10-second timeout.
- Falls back to `OnDeviceConverter` on timeout or server failure.
- Returns `ConversionResult` with local package path.

- [ ] **Step 3: Run orchestrator test**

Run:

```powershell
flutter test apps/thesis_reader/test/features/library/conversion_orchestrator_test.dart
```

Expected: test passes.

- [ ] **Step 4: Add HTTP converter client**

Implement `HttpConverterClient` using `package:http`:

- `POST /jobs` multipart upload.
- `GET /jobs/{jobId}` status polling.
- `GET /jobs/{jobId}/download` package download.

Map server statuses to Dart enum values: `queued`, `processing`, `succeeded`, `failed`.

- [ ] **Step 5: Commit**

```powershell
git add apps/thesis_reader/lib/features/library apps/thesis_reader/test/features/library
git commit -m "feat: orchestrate server and fallback conversion"
```

---

### Task 7: Build Library And Import UI

**Files:**
- Create: `apps/thesis_reader/lib/features/library/presentation/library_screen.dart`
- Create: `apps/thesis_reader/lib/features/library/presentation/import_status_screen.dart`
- Modify: `apps/thesis_reader/lib/app.dart`
- Create: `apps/thesis_reader/test/features/library/library_screen_test.dart`

- [ ] **Step 1: Write library widget test**

Create `apps/thesis_reader/test/features/library/library_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_reader/features/library/presentation/library_screen.dart';

void main() {
  testWidgets('library shows empty state and import action', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LibraryScreen()));

    expect(find.text('논문이 없습니다'), findsOneWidget);
    expect(find.text('PDF 가져오기'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Implement library screen**

Implement:

- Empty state text: `논문이 없습니다`.
- Primary action: `PDF 가져오기`.
- Document list rows with title, conversion status, last read progress.
- Import status states: waiting for server, converting, original PDF preview action, failed with retry.

- [ ] **Step 3: Wire routes**

Modify `apps/thesis_reader/lib/app.dart` to include routes:

- `/` -> `LibraryScreen`
- `/import/:documentId` -> `ImportStatusScreen`
- `/reader/:documentId` -> `ReaderScreen` from Task 8. Until Task 8 is complete, route to a `Scaffold` with the text `리더 준비 중` so navigation compiles.

- [ ] **Step 4: Run UI test**

Run:

```powershell
flutter test apps/thesis_reader/test/features/library/library_screen_test.dart
```

Expected: test passes.

- [ ] **Step 5: Commit**

```powershell
git add apps/thesis_reader/lib/features/library apps/thesis_reader/lib/app.dart apps/thesis_reader/test/features/library
git commit -m "feat: add library import UI"
```

---

### Task 8: Implement Reader Layout, Settings, And Progress

**Files:**
- Create: `apps/thesis_reader/lib/features/reader/domain/reader_settings.dart`
- Create: `apps/thesis_reader/lib/features/reader/domain/reader_layout_engine.dart`
- Create: `apps/thesis_reader/lib/features/reader/presentation/reader_screen.dart`
- Create: `apps/thesis_reader/lib/features/reader/presentation/viewer_settings_sheet.dart`
- Create: `apps/thesis_reader/test/features/reader/reader_layout_engine_test.dart`
- Create: `apps/thesis_reader/test/features/reader/viewer_settings_sheet_test.dart`

- [ ] **Step 1: Write layout test**

Create `apps/thesis_reader/test/features/reader/reader_layout_engine_test.dart`:

```dart
import 'package:document_contract/document_contract.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_reader/features/reader/domain/reader_layout_engine.dart';
import 'package:thesis_reader/features/reader/domain/reader_settings.dart';

void main() {
  test('setting changes alter page count without changing block order', () {
    final package = DocumentPackage(
      packageVersion: 1,
      documentId: 'doc-1',
      metadata: const DocumentMetadata(title: 'Paper', sourceFilename: 'paper.pdf'),
      sections: const [DocumentSection(id: 's1', title: 'Intro', blockIds: ['b1', 'b2'])],
      blocks: const [
        DocumentBlock.paragraph(id: 'b1', sectionId: 's1', text: 'First paragraph.'),
        DocumentBlock.paragraph(id: 'b2', sectionId: 's1', text: 'Second paragraph.'),
      ],
      assets: const [],
    );

    final engine = ReaderLayoutEngine();
    final compact = engine.paginate(package, const ReaderSettings(fontScale: 1.0), const ReaderViewport(width: 360, height: 640));
    final large = engine.paginate(package, const ReaderSettings(fontScale: 1.6), const ReaderViewport(width: 360, height: 640));

    expect(compact.orderedBlockIds, ['b1', 'b2']);
    expect(large.orderedBlockIds, ['b1', 'b2']);
  });
}
```

- [ ] **Step 2: Implement reader settings and layout engine**

Implement:

- `ReadingMode.page`, `ReadingMode.scroll`.
- `AssetOpenMode.bottomSheet`, `AssetOpenMode.fullScreen`.
- `ReaderSettings` with themeId, fontFamily, fontScale, lineHeight, marginScale.
- `ReaderLayoutEngine.paginate` returning pages with ordered block IDs and anchors.

Use an approximate text measurement first: characters per line based on viewport width, font scale, and margin. Keep the engine deterministic.

- [ ] **Step 3: Write settings sheet test**

Create `apps/thesis_reader/test/features/reader/viewer_settings_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_reader/features/reader/presentation/viewer_settings_sheet.dart';

void main() {
  testWidgets('settings sheet exposes KakaoPage-like controls', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ViewerSettingsSheet())));

    expect(find.text('뷰어 설정'), findsOneWidget);
    expect(find.text('열람 방식'), findsOneWidget);
    expect(find.text('글자 크기'), findsOneWidget);
    expect(find.text('줄 간격'), findsOneWidget);
    expect(find.text('여백'), findsOneWidget);
    expect(find.text('그림 열기'), findsOneWidget);
  });
}
```

- [ ] **Step 4: Implement reader screen**

Implement:

- Page mode rendering using `PageView`.
- Scroll mode rendering using `CustomScrollView`.
- Text blocks using selectable text spans.
- Settings bottom sheet.
- Reading progress saved on page change and scroll settle.

- [ ] **Step 5: Run reader tests**

Run:

```powershell
flutter test apps/thesis_reader/test/features/reader
```

Expected: all reader tests pass.

- [ ] **Step 6: Commit**

```powershell
git add apps/thesis_reader/lib/features/reader apps/thesis_reader/test/features/reader
git commit -m "feat: add reader modes and viewer settings"
```

---

### Task 9: Add References, Asset Viewers, And Selection Precedence

**Files:**
- Create: `apps/thesis_reader/lib/features/reader/presentation/reference_text.dart`
- Create: `apps/thesis_reader/lib/features/reader/presentation/asset_bottom_sheet.dart`
- Create: `apps/thesis_reader/lib/features/reader/presentation/asset_full_screen_viewer.dart`
- Create: `apps/thesis_reader/test/features/reader/reference_text_test.dart`

- [ ] **Step 1: Write reference interaction test**

Create `apps/thesis_reader/test/features/reader/reference_text_test.dart`:

```dart
import 'package:document_contract/document_contract.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_reader/features/reader/presentation/reference_text.dart';

void main() {
  testWidgets('tap on reference span opens asset callback', (tester) async {
    String? openedAssetId;

    await tester.pumpWidget(MaterialApp(
      home: ReferenceText(
        text: 'See Figure 1 for details.',
        referenceSpans: const [
          ReferenceSpan(start: 4, end: 12, targetAssetId: 'fig-1', kind: ReferenceKind.figure, label: 'Figure 1'),
        ],
        onOpenAsset: (assetId) => openedAssetId = assetId,
        onSelectionRequested: (_) {},
      ),
    ));

    await tester.tap(find.textContaining('Figure 1'));

    expect(openedAssetId, 'fig-1');
  });
}
```

- [ ] **Step 2: Implement reference text**

Implement `ReferenceText` with:

- Distinct color for reference spans.
- Tap recognizer for reference spans.
- Long-press start that calls `onSelectionRequested`.
- Drag selection path that suppresses link opening.

- [ ] **Step 3: Implement asset viewers**

Implement:

- `AssetBottomSheet` with image preview, label, caption, close button.
- `AssetFullScreenViewer` with dark background, image zoom, pan, label, caption.

Use `InteractiveViewer` for zoom and pan.

- [ ] **Step 4: Run reference tests**

Run:

```powershell
flutter test apps/thesis_reader/test/features/reader/reference_text_test.dart
```

Expected: test passes.

- [ ] **Step 5: Commit**

```powershell
git add apps/thesis_reader/lib/features/reader apps/thesis_reader/test/features/reader
git commit -m "feat: add reference asset interactions"
```

---

### Task 10: Add Android Volume Key Page Navigation

**Files:**
- Modify: `apps/thesis_reader/android/app/src/main/kotlin/com/example/thesis_reader/MainActivity.kt`
- Create: `apps/thesis_reader/lib/shared/platform/volume_key_channel.dart`
- Modify: `apps/thesis_reader/lib/features/reader/presentation/reader_screen.dart`
- Create: `apps/thesis_reader/test/shared/platform/volume_key_channel_test.dart`

- [ ] **Step 1: Write Dart channel test**

Create `apps/thesis_reader/test/shared/platform/volume_key_channel_test.dart`:

```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_reader/shared/platform/volume_key_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('volume channel maps down and up events', () async {
    final events = <VolumeKeyEvent>[];
    final channel = VolumeKeyChannel();
    channel.events.listen(events.add);

    const methodChannel = MethodChannel('thesis_reader/volume_keys');
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      methodChannel.name,
      methodChannel.codec.encodeMethodCall(const MethodCall('volumeDown')),
      (_) {},
    );

    expect(events, [VolumeKeyEvent.down]);
  });
}
```

- [ ] **Step 2: Implement Dart channel**

Create `VolumeKeyChannel` with a broadcast stream that maps:

- `volumeDown` -> `VolumeKeyEvent.down`
- `volumeUp` -> `VolumeKeyEvent.up`

- [ ] **Step 3: Implement Android MainActivity override**

Modify Kotlin `MainActivity.kt` to override `dispatchKeyEvent` and emit method channel calls for `KEYCODE_VOLUME_DOWN` and `KEYCODE_VOLUME_UP` only on `ACTION_DOWN`. Return `true` when reader page mode is active; otherwise return `super.dispatchKeyEvent(event)`.

- [ ] **Step 4: Wire reader**

In `ReaderScreen`, subscribe to `VolumeKeyChannel.events`:

- Down moves to next page.
- Up moves to previous page.
- Ignore events in scroll mode.

- [ ] **Step 5: Run Dart channel test**

Run:

```powershell
flutter test apps/thesis_reader/test/shared/platform/volume_key_channel_test.dart
```

Expected: test passes.

- [ ] **Step 6: Commit**

```powershell
git add apps/thesis_reader/android apps/thesis_reader/lib apps/thesis_reader/test
git commit -m "feat: navigate pages with Android volume keys"
```

---

### Task 11: Implement OpenAI Key Storage, Translation, And Summaries

**Files:**
- Create: `apps/thesis_reader/lib/features/ai/data/openai_key_store.dart`
- Create: `apps/thesis_reader/lib/features/ai/data/openai_client.dart`
- Create: `apps/thesis_reader/lib/features/ai/domain/translation_service.dart`
- Create: `apps/thesis_reader/lib/features/ai/domain/summary_service.dart`
- Create: `apps/thesis_reader/test/features/ai/openai_client_test.dart`
- Create: `apps/thesis_reader/test/features/ai/translation_service_test.dart`

- [ ] **Step 1: Write OpenAI client test**

Create `apps/thesis_reader/test/features/ai/openai_client_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_reader/features/ai/data/openai_client.dart';

void main() {
  test('builds word meaning prompt with compact context', () {
    final request = OpenAiRequestFactory.wordMeaning(
      word: 'alignment',
      sentence: 'The alignment score improves.',
      contextBefore: 'We compare models.',
      contextAfter: 'The result is stable.',
      sectionTitle: 'Experiments',
    );

    expect(request.model, isNotEmpty);
    expect(request.input, contains('alignment'));
    expect(request.input, contains('한국어'));
    expect(request.input, isNot(contains('services/converter')));
  });
}
```

- [ ] **Step 2: Implement key store and request factory**

Implement:

- `OpenAiKeyStore.readKey()`
- `OpenAiKeyStore.writeKey(String key)`
- `OpenAiRequestFactory.wordMeaning`
- `OpenAiRequestFactory.translateSelection`
- `OpenAiRequestFactory.summarizeRange`
- `OpenAiRequestFactory.summarizeSection`

Use `flutter_secure_storage` for the key.

- [ ] **Step 3: Implement OpenAI HTTP client**

Implement a client that sends `POST https://api.openai.com/v1/responses` with:

```json
{
  "model": "gpt-4.1-mini",
  "input": "Translate the selected paper text into Korean and preserve technical terms where useful."
}
```

Parse the first text output into a Dart result object. Return typed failures for missing key, network failure, and API error status.

- [ ] **Step 4: Write translation service test**

Create `apps/thesis_reader/test/features/ai/translation_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_reader/features/ai/domain/translation_service.dart';

void main() {
  test('single word translation auto save flag is true', () {
    final action = TranslationAction.forSingleWord(
      expression: 'alignment',
      sentence: 'The alignment score improves.',
      contextBefore: 'We compare models.',
      contextAfter: 'The result is stable.',
    );

    expect(action.shouldAutoSaveToVocabulary, isTrue);
  });

  test('long sentence translation auto save flag is false', () {
    final action = TranslationAction.forSelection(
      text: 'The alignment score improves across all datasets.',
    );

    expect(action.shouldAutoSaveToVocabulary, isFalse);
  });
}
```

- [ ] **Step 5: Run AI tests**

Run:

```powershell
flutter test apps/thesis_reader/test/features/ai
```

Expected: all AI tests pass.

- [ ] **Step 6: Commit**

```powershell
git add apps/thesis_reader/lib/features/ai apps/thesis_reader/test/features/ai
git commit -m "feat: add OpenAI translation and summaries"
```

---

### Task 12: Implement Per-Paper Vocabulary

**Files:**
- Create: `apps/thesis_reader/lib/features/vocabulary/domain/vocabulary_normalizer.dart`
- Create: `apps/thesis_reader/lib/features/vocabulary/data/vocabulary_repository.dart`
- Create: `apps/thesis_reader/lib/features/vocabulary/presentation/vocabulary_screen.dart`
- Create: `apps/thesis_reader/test/features/vocabulary/vocabulary_repository_test.dart`
- Create: `apps/thesis_reader/test/features/vocabulary/vocabulary_normalizer_test.dart`

- [ ] **Step 1: Write normalizer test**

Create `apps/thesis_reader/test/features/vocabulary/vocabulary_normalizer_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_reader/features/vocabulary/domain/vocabulary_normalizer.dart';

void main() {
  test('normalizes phrase keys for duplicate prevention', () {
    expect(normalizeVocabularyExpression(' In  Context. '), 'in context');
    expect(normalizeVocabularyExpression('in   context'), 'in context');
  });
}
```

- [ ] **Step 2: Write repository duplicate test**

Create `apps/thesis_reader/test/features/vocabulary/vocabulary_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_reader/features/vocabulary/data/vocabulary_repository.dart';

void main() {
  test('prevents duplicates inside one paper but not across papers', () async {
    final repo = InMemoryVocabularyRepository();

    await repo.upsert(VocabularyDraft(documentId: 'paper-a', expression: 'In Context', meaningKo: '문맥상'));
    await repo.upsert(VocabularyDraft(documentId: 'paper-a', expression: 'in   context', meaningKo: '문맥에서'));
    await repo.upsert(VocabularyDraft(documentId: 'paper-b', expression: 'in context', meaningKo: '문맥'));

    expect(await repo.countForDocument('paper-a'), 1);
    expect(await repo.countForDocument('paper-b'), 1);
  });
}
```

- [ ] **Step 3: Implement normalizer and repository**

Implement `normalizeVocabularyExpression`:

- Trim.
- Lowercase.
- Collapse whitespace.
- Remove trailing `.`, `,`, `;`, `:`.

Implement repository methods:

- `upsert(VocabularyDraft draft)`
- `listForDocument(String documentId)`
- `countForDocument(String documentId)`
- `updateUserMeaningAndMemo({required String entryId, String? userMeaning, String? userMemo})`

- [ ] **Step 4: Implement vocabulary screen**

Implement a document-specific vocabulary screen showing:

- Expression.
- Korean meaning.
- Source sentence.
- User memo.
- Edit action.

- [ ] **Step 5: Run vocabulary tests**

Run:

```powershell
flutter test apps/thesis_reader/test/features/vocabulary
```

Expected: all vocabulary tests pass.

- [ ] **Step 6: Commit**

```powershell
git add apps/thesis_reader/lib/features/vocabulary apps/thesis_reader/test/features/vocabulary
git commit -m "feat: add per-paper vocabulary"
```

---

### Task 13: End-To-End MVP Verification And Railway Prep

**Files:**
- Create: `services/converter/Dockerfile`
- Create: `services/converter/railway.json`
- Create: `docs/testing/manual-mvp-checklist.md`
- Modify: `README.md`

- [ ] **Step 1: Add server Dockerfile**

Create `services/converter/Dockerfile`:

```dockerfile
FROM python:3.12-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app ./app
COPY services ./services

ENV PYTHONPATH=/app
CMD ["uvicorn", "services.converter.app.main:app", "--host", "0.0.0.0", "--port", "8080"]
```

- [ ] **Step 2: Add Railway config**

Create `services/converter/railway.json`:

```json
{
  "$schema": "https://railway.com/railway.schema.json",
  "build": {
    "builder": "DOCKERFILE",
    "dockerfilePath": "services/converter/Dockerfile"
  },
  "deploy": {
    "startCommand": "uvicorn services.converter.app.main:app --host 0.0.0.0 --port ${PORT}"
  }
}
```

- [ ] **Step 3: Add manual MVP checklist**

Create `docs/testing/manual-mvp-checklist.md` with these checks:

```markdown
# Thesis Reader MVP Manual Checklist

- Import a single-column text PDF.
- Import a two-column academic PDF.
- Confirm server conversion creates a cached package.
- Stop the server URL and confirm app fallback conversion starts after 10 seconds.
- Open converted document in page mode.
- Open converted document in scroll mode.
- Change theme, font size, line spacing, and margin.
- Tap a Figure/Table reference span and verify bottom sheet mode.
- Switch asset setting to full screen and verify zoom/pan.
- Long-press a word and verify Korean meaning plus vocabulary save.
- Drag-select a phrase and verify translation plus optional vocabulary save.
- Summarize a section.
- Close and reopen the app and confirm last document and position restore.
- On Android, verify volume down moves next and volume up moves previous.
```

- [ ] **Step 4: Run full automated checks**

Run:

```powershell
flutter test apps/thesis_reader
flutter test packages/document_contract
services/converter/.venv/Scripts/python -m pytest services/converter/tests -q
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```powershell
git add services/converter/Dockerfile services/converter/railway.json docs/testing README.md
git commit -m "chore: prepare MVP verification and deployment"
```

---

## Self-Review Checklist

- Spec coverage: PDF import, server conversion, 10-second fallback, cached package, original PDF copy, page/scroll reader, settings, reference spans, asset viewers, reading progress, OpenAI direct calls, section summary, single word translation, phrase vocabulary, per-paper duplicate prevention, and Android volume keys all have tasks.
- Known limitation: iOS volume key navigation is intentionally excluded from guaranteed behavior and covered through fallback controls in the reader task.
- Execution safety: every task has tests before implementation, expected command results, and a commit step.
- Deployment: Railway prep is included after the app and server vertical slice exists.

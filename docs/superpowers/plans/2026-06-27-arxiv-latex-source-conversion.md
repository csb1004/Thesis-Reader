# arXiv LaTeX Source Conversion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make PDF upload automatically try arXiv source-first conversion, preserving LaTeX equations and tables when source is available, with the existing PDF converter as fallback.

**Architecture:** Add a server-side conversion orchestrator before the existing PDF converter. It detects an arXiv ID from the uploaded PDF, downloads and unpacks arXiv source, extracts a reader package from LaTeX, and falls back to `convert_pdf_to_package` when any source step fails. Extend the package contract so the Flutter app can parse conversion metadata and render equation blocks from LaTeX with an asset fallback.

**Tech Stack:** Python 3.12, FastAPI, PyMuPDF, Pydantic, pytest, Flutter/Dart, document_contract, flutter_test.

---

## File Structure

- Create `services/converter/app/conversion/arxiv_source.py`
  - Detect arXiv IDs from filenames and PDF text.
  - Fetch `https://arxiv.org/e-print/{id}` through an injectable fetcher.
  - Unpack `.tex`, `.gz`, `.tar`, `.tar.gz`, and `.tgz` source bundles.
  - Select a main `.tex` file.

- Create `services/converter/app/conversion/latex_converter.py`
  - Normalize LaTeX source by expanding simple includes.
  - Extract title, sections, paragraphs, display equations, figures, tables, and references.
  - Build a `DocumentPackage` with `conversionMode="latex-source"`.

- Create `services/converter/app/conversion/document_converter.py`
  - Public entry point `convert_document_to_package`.
  - Calls arXiv source conversion first.
  - Calls `convert_pdf_to_package` on failure and records fallback metadata.

- Modify `services/converter/app/jobs/job_store.py`
  - Replace direct `convert_pdf_to_package` call with `convert_document_to_package`.

- Modify `services/converter/app/models/document_package.py`
  - Add package-level conversion metadata.
  - Add optional `latex` and `source` fields to blocks.

- Modify `packages/document_contract/lib/src/document_package.dart`
  - Mirror the Python contract fields in Dart.
  - Keep parsing old packages with missing metadata.

- Modify `apps/thesis_reader/lib/features/library/data/document_package_loader.dart`
  - Preserve new package metadata and block fields while normalizing text.

- Modify `apps/thesis_reader/lib/features/reader/presentation/reader_screen.dart`
  - Render equation blocks from `block.latex` when present.
  - Keep existing image asset fallback.

- Modify tests under:
  - `services/converter/tests/test_arxiv_source.py`
  - `services/converter/tests/test_latex_converter.py`
  - `services/converter/tests/test_document_converter.py`
  - `services/converter/tests/test_document_package_model.py`
  - `packages/document_contract/test/document_package_test.dart`
  - `apps/thesis_reader/test/features/library/document_package_loader_test.dart`
  - `apps/thesis_reader/test/features/reader/reader_screen_test.dart`

---

### Task 1: Extend the Document Package Contract

**Files:**
- Modify: `services/converter/app/models/document_package.py`
- Modify: `services/converter/tests/test_document_package_model.py`
- Modify: `packages/document_contract/lib/src/document_package.dart`
- Modify: `packages/document_contract/test/document_package_test.dart`

- [ ] **Step 1: Write Python contract tests**

Add this test to `services/converter/tests/test_document_package_model.py`:

```python
def test_document_package_serializes_conversion_metadata_and_latex_block():
    package = DocumentPackage(
        packageVersion=1,
        documentId="doc-1",
        metadata=DocumentMetadata(
            title="Denoising Diffusion Probabilistic Models",
            sourceFilename="2006.11239.pdf",
            originalPdfSha256="abc123",
            converterVersion="mvp-2",
        ),
        conversionMode="latex-source",
        fallbackReason=None,
        sourceInfo={"arxivId": "2006.11239", "mainTex": "main.tex"},
        sections=[DocumentSection(id="sec-1", title="Document", blockIds=["eq-1"])],
        blocks=[
            DocumentBlock(
                id="eq-1",
                sectionId="sec-1",
                kind=BlockKind.equation,
                latex=r"q(x_t \mid x_0) = \mathcal{N}(x_t; \sqrt{\bar\alpha_t}x_0, (1-\bar\alpha_t)I)",
                source={"mode": "latex", "environment": "equation"},
            )
        ],
        assets=[],
    )

    payload = package.model_dump(mode="json")

    assert payload["conversionMode"] == "latex-source"
    assert payload["fallbackReason"] is None
    assert payload["sourceInfo"]["arxivId"] == "2006.11239"
    assert payload["blocks"][0]["latex"].startswith("q(x_t")
    assert payload["blocks"][0]["source"]["environment"] == "equation"
```

- [ ] **Step 2: Run Python contract test and verify it fails**

Run:

```powershell
.\services\converter\.venv\Scripts\python.exe -m pytest services\converter\tests\test_document_package_model.py -q
```

Expected: FAIL because `DocumentPackage` rejects `conversionMode`, `fallbackReason`, `sourceInfo`, and `DocumentBlock` rejects `latex` and `source`.

- [ ] **Step 3: Implement Python contract fields**

In `services/converter/app/models/document_package.py`, extend these models:

```python
class DocumentBlock(ContractModel):
    id: str
    sectionId: str
    kind: BlockKind
    text: str | None = None
    assetId: str | None = None
    latex: str | None = None
    source: dict[str, str | int | float | bool | None] | None = None
    referenceSpans: list[ReferenceSpan] = Field(default_factory=list)
    anchor: ReadingAnchor | None = None


class DocumentPackage(ContractModel):
    packageVersion: int
    documentId: str
    metadata: DocumentMetadata
    sections: list[DocumentSection]
    blocks: list[DocumentBlock]
    assets: list[DocumentAsset]
    conversionMode: str | None = None
    fallbackReason: str | None = None
    sourceInfo: dict[str, str | int | float | bool | None] | None = None
    anchors: list[ReadingAnchor] = Field(default_factory=list)
    vocabulary: list[VocabularyEntry] = Field(default_factory=list)
    summaries: list[SectionSummary] = Field(default_factory=list)
```

- [ ] **Step 4: Write Dart contract tests**

Add this test to `packages/document_contract/test/document_package_test.dart`:

```dart
test('package parses conversion metadata and latex equation blocks', () {
  final package = DocumentPackage.fromJson({
    'packageVersion': 1,
    'documentId': 'doc-1',
    'metadata': {
      'title': 'DDPM',
      'sourceFilename': '2006.11239.pdf',
      'originalPdfSha256': 'abc123',
    },
    'conversionMode': 'latex-source',
    'fallbackReason': null,
    'sourceInfo': {'arxivId': '2006.11239', 'mainTex': 'main.tex'},
    'sections': [
      {
        'id': 'sec-1',
        'title': 'Document',
        'blockIds': ['eq-1'],
      },
    ],
    'blocks': [
      {
        'id': 'eq-1',
        'sectionId': 'sec-1',
        'kind': 'equation',
        'latex': r'q(x_t \mid x_0) = \mathcal{N}(x_t; 0, I)',
        'source': {'mode': 'latex', 'environment': 'equation'},
      },
    ],
    'assets': [],
  });

  expect(package.conversionMode, 'latex-source');
  expect(package.sourceInfo?['arxivId'], '2006.11239');
  expect(package.blocks.single.latex, contains(r'\mathcal'));
  expect(package.blocks.single.source?['environment'], 'equation');
});
```

- [ ] **Step 5: Implement Dart contract fields**

In `packages/document_contract/lib/src/document_package.dart`, add fields:

```dart
final String? conversionMode;
final String? fallbackReason;
final Map<String, Object?>? sourceInfo;
```

to `DocumentPackage`, and:

```dart
final String? latex;
final Map<String, Object?>? source;
```

to `DocumentBlock`. Parse them from JSON and include them in `toJson()`. Constructors must keep defaults nullable so old packages continue to parse.

- [ ] **Step 6: Run contract tests**

Run:

```powershell
.\services\converter\.venv\Scripts\python.exe -m pytest services\converter\tests\test_document_package_model.py -q
Push-Location packages\document_contract; flutter test test\document_package_test.dart; Pop-Location
```

Expected: all tests pass.

- [ ] **Step 7: Commit**

```powershell
git add services\converter\app\models\document_package.py services\converter\tests\test_document_package_model.py packages\document_contract\lib\src\document_package.dart packages\document_contract\test\document_package_test.dart
git commit -m "Extend document package for source conversion"
```

---

### Task 2: Add arXiv Source Detection, Fetching, and Unpacking

**Files:**
- Create: `services/converter/app/conversion/arxiv_source.py`
- Create: `services/converter/tests/test_arxiv_source.py`

- [ ] **Step 1: Write source resolver tests**

Create `services/converter/tests/test_arxiv_source.py`:

```python
import gzip
import tarfile
from io import BytesIO

from services.converter.app.conversion.arxiv_source import (
    ArxivSourceBundle,
    detect_arxiv_id,
    select_main_tex,
    unpack_arxiv_source,
)


def test_detects_arxiv_id_from_filename():
    assert detect_arxiv_id(filename="2006.11239.pdf", pdf_text="") == "2006.11239"
    assert detect_arxiv_id(filename="arxiv-1706.03762v7.pdf", pdf_text="") == "1706.03762v7"


def test_detects_arxiv_id_from_pdf_text():
    assert detect_arxiv_id(filename="renamed.pdf", pdf_text="arXiv:2006.11239v2 [cs.LG]") == "2006.11239v2"


def test_unpacks_single_gzipped_tex_file(tmp_path):
    payload = gzip.compress(b"\\documentclass{article}\\begin{document}Hi\\end{document}")

    bundle = unpack_arxiv_source(payload, tmp_path)

    assert bundle.root == tmp_path
    assert [path.name for path in bundle.tex_files] == ["source.tex"]
    assert bundle.tex_files[0].read_text(encoding="utf-8").startswith("\\documentclass")


def test_unpacks_tar_gz_source_bundle(tmp_path):
    archive_bytes = BytesIO()
    with tarfile.open(fileobj=archive_bytes, mode="w:gz") as archive:
        data = b"\\documentclass{article}\\begin{document}Main\\end{document}"
        info = tarfile.TarInfo("paper/main.tex")
        info.size = len(data)
        archive.addfile(info, BytesIO(data))

    bundle = unpack_arxiv_source(archive_bytes.getvalue(), tmp_path)

    assert [path.name for path in bundle.tex_files] == ["main.tex"]


def test_selects_main_tex_by_documentclass(tmp_path):
    supplement = tmp_path / "supplement.tex"
    supplement.write_text("Supplement only", encoding="utf-8")
    main = tmp_path / "main.tex"
    main.write_text("\\documentclass{article}\\begin{document}Main\\end{document}", encoding="utf-8")

    bundle = ArxivSourceBundle(root=tmp_path, tex_files=[supplement, main])

    assert select_main_tex(bundle) == main
```

- [ ] **Step 2: Run resolver tests and verify they fail**

Run:

```powershell
.\services\converter\.venv\Scripts\python.exe -m pytest services\converter\tests\test_arxiv_source.py -q
```

Expected: FAIL because `arxiv_source.py` does not exist.

- [ ] **Step 3: Implement `arxiv_source.py`**

Create `services/converter/app/conversion/arxiv_source.py` with these public APIs:

```python
import gzip
import re
import tarfile
from dataclasses import dataclass
from io import BytesIO
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import urlopen

ARXIV_ID_PATTERN = re.compile(
    r"(?:arxiv:|arxiv-)?(?P<id>(?:\d{4}\.\d{4,5}|[a-z-]+(?:\.[A-Z]{2})?/\d{7})(?:v\d+)?)",
    re.IGNORECASE,
)


@dataclass(frozen=True)
class ArxivSourceBundle:
    root: Path
    tex_files: list[Path]


class ArxivSourceError(RuntimeError):
    pass


def detect_arxiv_id(filename: str, pdf_text: str) -> str | None:
    for candidate in (filename, pdf_text):
        match = ARXIV_ID_PATTERN.search(candidate or "")
        if match:
            return match.group("id")
    return None


def fetch_arxiv_source(arxiv_id: str, fetcher=urlopen) -> bytes:
    url = f"https://arxiv.org/e-print/{arxiv_id}"
    try:
        with fetcher(url, timeout=20) as response:
            return response.read()
    except (HTTPError, URLError, TimeoutError, OSError) as exc:
        raise ArxivSourceError(f"Could not fetch arXiv source for {arxiv_id}: {exc}") from exc


def unpack_arxiv_source(payload: bytes, output_dir: Path) -> ArxivSourceBundle:
    output_dir.mkdir(parents=True, exist_ok=True)
    try:
        with tarfile.open(fileobj=BytesIO(payload), mode="r:*") as archive:
            archive.extractall(output_dir)
    except tarfile.TarError:
        try:
            text = gzip.decompress(payload)
        except OSError:
            text = payload
        (output_dir / "source.tex").write_bytes(text)

    tex_files = sorted(output_dir.rglob("*.tex"))
    if not tex_files:
        raise ArxivSourceError("arXiv source did not contain any .tex files")
    return ArxivSourceBundle(root=output_dir, tex_files=tex_files)


def select_main_tex(bundle: ArxivSourceBundle) -> Path:
    def score(path: Path) -> tuple[int, int]:
        text = path.read_text(encoding="utf-8", errors="ignore")
        return (
            int("\\documentclass" in text) * 4 + int("\\begin{document}" in text) * 2,
            len(text),
        )

    return max(bundle.tex_files, key=score)
```

- [ ] **Step 4: Run resolver tests**

Run:

```powershell
.\services\converter\.venv\Scripts\python.exe -m pytest services\converter\tests\test_arxiv_source.py -q
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```powershell
git add services\converter\app\conversion\arxiv_source.py services\converter\tests\test_arxiv_source.py
git commit -m "Add arXiv source resolver"
```

---

### Task 3: Add Minimal LaTeX Source Converter

**Files:**
- Create: `services/converter/app/conversion/latex_converter.py`
- Create: `services/converter/tests/test_latex_converter.py`

- [ ] **Step 1: Write LaTeX converter tests**

Create `services/converter/tests/test_latex_converter.py`:

```python
from pathlib import Path

from services.converter.app.conversion.latex_converter import convert_latex_source_to_package
from services.converter.app.models.document_package import BlockKind


def test_converts_latex_sections_paragraphs_equations_and_references(tmp_path):
    main_tex = tmp_path / "main.tex"
    main_tex.write_text(
        r"""
\documentclass{article}
\title{Denoising Diffusion Probabilistic Models}
\begin{document}
\maketitle
\begin{abstract}
Diffusion models are latent variable models \cite{sohl2015deep}.
\end{abstract}
\section{Background}
The forward process is fixed.
\begin{equation}
q(x_t \mid x_0) = \mathcal{N}(x_t; \sqrt{\bar\alpha_t}x_0, (1-\bar\alpha_t)I)
\end{equation}
\begin{thebibliography}{9}
\bibitem{sohl2015deep} Sohl-Dickstein et al. Deep Unsupervised Learning using Nonequilibrium Thermodynamics.
\end{thebibliography}
\end{document}
""",
        encoding="utf-8",
    )

    package = convert_latex_source_to_package(
        main_tex=main_tex,
        output_dir=tmp_path / "out",
        document_id="doc-1",
        source_filename="2006.11239.pdf",
        original_pdf_sha256="abc123",
        source_info={"arxivId": "2006.11239", "mainTex": "main.tex"},
    )

    assert package.metadata.title == "Denoising Diffusion Probabilistic Models"
    assert package.conversionMode == "latex-source"
    assert any(block.kind == BlockKind.heading and block.text == "Background" for block in package.blocks)
    assert any(block.kind == BlockKind.paragraph and "forward process" in (block.text or "") for block in package.blocks)
    equations = [block for block in package.blocks if block.kind == BlockKind.equation]
    assert len(equations) == 1
    assert r"\mathcal{N}" in equations[0].latex
    assert any(block.kind == BlockKind.reference and "Sohl-Dickstein" in (block.text or "") for block in package.blocks)
    assert (tmp_path / "out" / "package.json").exists()
```

- [ ] **Step 2: Run LaTeX converter test and verify it fails**

Run:

```powershell
.\services\converter\.venv\Scripts\python.exe -m pytest services\converter\tests\test_latex_converter.py -q
```

Expected: FAIL because `latex_converter.py` does not exist.

- [ ] **Step 3: Implement `latex_converter.py`**

Create `services/converter/app/conversion/latex_converter.py` with:

```python
import hashlib
import re
from datetime import UTC, datetime
from pathlib import Path

from services.converter.app.conversion.package_writer import write_document_package
from services.converter.app.models.document_package import (
    BlockKind,
    DocumentBlock,
    DocumentMetadata,
    DocumentPackage,
    DocumentSection,
    ReadingAnchor,
)

DISPLAY_ENVIRONMENTS = ("equation", "align", "align*", "gather", "gather*", "multline", "multline*")


def convert_latex_source_to_package(
    main_tex: Path,
    output_dir: Path,
    document_id: str,
    source_filename: str,
    original_pdf_sha256: str,
    source_info: dict[str, str],
) -> DocumentPackage:
    raw = main_tex.read_text(encoding="utf-8", errors="ignore")
    body = _document_body(_expand_simple_includes(raw, main_tex.parent))
    title = _clean_text(_first_match(raw, r"\\title\{(?P<value>.*?)\}") or main_tex.stem)
    blocks = _extract_blocks(body)
    if not blocks:
        raise ValueError("LaTeX source produced no reader blocks")

    section_id = "sec-1"
    anchored = [
        block.model_copy(
            update={
                "sectionId": section_id,
                "anchor": ReadingAnchor(blockId=block.id, textOffset=0),
            }
        )
        for block in blocks
    ]
    package = DocumentPackage(
        packageVersion=1,
        documentId=document_id,
        metadata=DocumentMetadata(
            title=title,
            sourceFilename=source_filename,
            originalPdfSha256=original_pdf_sha256,
            importedAtIso8601=datetime.now(UTC).isoformat(),
            converterVersion="mvp-2",
        ),
        conversionMode="latex-source",
        fallbackReason=None,
        sourceInfo=source_info,
        sections=[DocumentSection(id=section_id, title="Document", blockIds=[block.id for block in anchored])],
        blocks=anchored,
        assets=[],
        anchors=[block.anchor for block in anchored if block.anchor is not None],
    )
    write_document_package(package, output_dir)
    return package


def _extract_blocks(body: str) -> list[DocumentBlock]:
    tokens = _tokenize_body(body)
    blocks: list[DocumentBlock] = []
    for token in tokens:
        block_id = f"block-{len(blocks) + 1}"
        if token["kind"] == "heading":
            blocks.append(DocumentBlock(id=block_id, sectionId="", kind=BlockKind.heading, text=token["text"]))
        elif token["kind"] == "equation":
            blocks.append(
                DocumentBlock(
                    id=block_id,
                    sectionId="",
                    kind=BlockKind.equation,
                    latex=token["latex"],
                    source={"mode": "latex", "environment": token["environment"]},
                )
            )
        elif token["kind"] == "reference":
            blocks.append(DocumentBlock(id=block_id, sectionId="", kind=BlockKind.reference, text=token["text"]))
        else:
            blocks.append(DocumentBlock(id=block_id, sectionId="", kind=BlockKind.paragraph, text=token["text"]))
    return blocks
```

Add the helper functions in the same file:

```python
def _first_match(text: str, pattern: str) -> str | None:
    match = re.search(pattern, text, flags=re.DOTALL)
    return match.group("value") if match else None


def _document_body(text: str) -> str:
    match = re.search(
        r"\\begin\{document\}(?P<body>.*?)\\end\{document\}",
        text,
        flags=re.DOTALL,
    )
    if not match:
        raise ValueError("LaTeX source has no document body")
    return match.group("body")


def _expand_simple_includes(text: str, root: Path) -> str:
    pattern = re.compile(r"\\(?:input|include)\{(?P<path>[^}]+)\}")

    def replace(match: re.Match[str]) -> str:
        include_path = root / match.group("path")
        if include_path.suffix != ".tex":
            include_path = include_path.with_suffix(".tex")
        root_path = root.resolve()
        resolved = include_path.resolve()
        if not include_path.exists() or not resolved.is_relative_to(root_path):
            return ""
        return include_path.read_text(encoding="utf-8", errors="ignore")

    return pattern.sub(replace, text)


def _tokenize_body(body: str) -> list[dict[str, str]]:
    protected: list[dict[str, str]] = []

    def protect(kind: str, content: str, environment: str = "") -> str:
        key = f"@@BLOCK_{len(protected)}@@"
        protected.append({"kind": kind, "text": content, "environment": environment})
        return f"\n\n{key}\n\n"

    for environment in DISPLAY_ENVIRONMENTS:
        pattern = re.compile(
            rf"\\begin\{{{re.escape(environment)}\}}(?P<value>.*?)"
            rf"\\end\{{{re.escape(environment)}\}}",
            flags=re.DOTALL,
        )
        body = pattern.sub(
            lambda match: protect("equation", match.group("value").strip(), environment),
            body,
        )

    body = re.sub(
        r"\\\[(?P<value>.*?)\\\]",
        lambda match: protect("equation", match.group("value").strip(), "displaymath"),
        body,
        flags=re.DOTALL,
    )
    body = re.sub(
        r"\\section\*?\{(?P<value>.*?)\}",
        lambda match: protect("heading", _clean_text(match.group("value"))),
        body,
        flags=re.DOTALL,
    )
    body = re.sub(
        r"\\subsection\*?\{(?P<value>.*?)\}",
        lambda match: protect("heading", _clean_text(match.group("value"))),
        body,
        flags=re.DOTALL,
    )

    references = re.findall(
        r"\\bibitem(?:\[[^\]]+\])?\{[^}]+\}(?P<value>.*?)(?=\\bibitem|\\end\{thebibliography\})",
        body,
        flags=re.DOTALL,
    )
    body = re.sub(
        r"\\begin\{thebibliography\}.*?\\end\{thebibliography\}",
        "",
        body,
        flags=re.DOTALL,
    )

    tokens: list[dict[str, str]] = []
    for chunk in re.split(r"\n\s*\n", body):
        chunk = chunk.strip()
        if not chunk:
            continue
        block_match = re.fullmatch(r"@@BLOCK_(?P<index>\d+)@@", chunk)
        if block_match:
            item = protected[int(block_match.group("index"))]
            if item["kind"] == "equation":
                tokens.append(
                    {
                        "kind": "equation",
                        "latex": item["text"],
                        "environment": item["environment"],
                    }
                )
            elif item["kind"] == "heading":
                tokens.append({"kind": "heading", "text": item["text"]})
            continue
        cleaned = _clean_text(chunk)
        if cleaned:
            tokens.append({"kind": "paragraph", "text": cleaned})

    for index, reference in enumerate(references, start=1):
        cleaned = _clean_text(reference)
        if cleaned:
            tokens.append({"kind": "reference", "text": f"[{index}] {cleaned}"})

    return tokens


def _clean_text(text: str) -> str:
    cleaned = text.replace("~", " ")
    cleaned = re.sub(r"\\(?:maketitle|begin\{abstract\}|end\{abstract\})", " ", cleaned)
    cleaned = re.sub(r"\\cite\{([^}]+)\}", r"[\1]", cleaned)
    cleaned = re.sub(r"\\[a-zA-Z]+\*?(?:\[[^\]]+\])?\{([^{}]*)\}", r"\1", cleaned)
    cleaned = cleaned.replace("{", "").replace("}", "")
    return re.sub(r"\s+", " ", cleaned).strip()
```

- [ ] **Step 4: Run LaTeX converter tests**

Run:

```powershell
.\services\converter\.venv\Scripts\python.exe -m pytest services\converter\tests\test_latex_converter.py -q
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```powershell
git add services\converter\app\conversion\latex_converter.py services\converter\tests\test_latex_converter.py
git commit -m "Convert arXiv LaTeX source into reader packages"
```

---

### Task 4: Add Source-First Conversion Orchestrator with PDF Fallback

**Files:**
- Create: `services/converter/app/conversion/document_converter.py`
- Modify: `services/converter/app/jobs/job_store.py`
- Create: `services/converter/tests/test_document_converter.py`

- [ ] **Step 1: Write orchestrator tests**

Create `services/converter/tests/test_document_converter.py`:

```python
from pathlib import Path

from services.converter.app.conversion.document_converter import convert_document_to_package


def test_uses_latex_source_when_arxiv_id_is_detected(tmp_path, monkeypatch):
    pdf_path = tmp_path / "2006.11239.pdf"
    pdf_path.write_bytes(b"%PDF-1.4 fake fixture")

    def fake_source_converter(**kwargs):
        class Package:
            conversionMode = "latex-source"
            fallbackReason = None
        return Package()

    monkeypatch.setattr(
        "services.converter.app.conversion.document_converter._convert_from_arxiv_source",
        fake_source_converter,
    )

    package = convert_document_to_package(pdf_path, tmp_path / "out", "doc-1")

    assert package.conversionMode == "latex-source"


def test_falls_back_to_pdf_when_source_conversion_fails(tmp_path, monkeypatch):
    pdf_path = tmp_path / "2006.11239.pdf"
    pdf_path.write_bytes(b"%PDF-1.4 fake fixture")

    def failing_source_converter(**kwargs):
        raise RuntimeError("source unavailable")

    def fake_pdf_converter(pdf_path, output_dir, document_id):
        from services.converter.app.models.document_package import (
            DocumentMetadata,
            DocumentPackage,
        )

        return DocumentPackage(
            packageVersion=1,
            documentId=document_id,
            metadata=DocumentMetadata(
                title="Fallback",
                sourceFilename=pdf_path.name,
                originalPdfSha256="abc123",
            ),
            sections=[],
            blocks=[],
            assets=[],
        )

    monkeypatch.setattr(
        "services.converter.app.conversion.document_converter._convert_from_arxiv_source",
        failing_source_converter,
    )
    monkeypatch.setattr(
        "services.converter.app.conversion.document_converter.convert_pdf_to_package",
        fake_pdf_converter,
    )

    package = convert_document_to_package(pdf_path, tmp_path / "out", "doc-1")

    assert package.conversionMode == "pdf-fallback"
    assert "source unavailable" in package.fallbackReason
```

- [ ] **Step 2: Run orchestrator tests and verify they fail**

Run:

```powershell
.\services\converter\.venv\Scripts\python.exe -m pytest services\converter\tests\test_document_converter.py -q
```

Expected: FAIL because `document_converter.py` does not exist.

- [ ] **Step 3: Implement `document_converter.py`**

Create `services/converter/app/conversion/document_converter.py`:

```python
import hashlib
import shutil
from pathlib import Path

import fitz

from services.converter.app.conversion.arxiv_source import (
    detect_arxiv_id,
    fetch_arxiv_source,
    select_main_tex,
    unpack_arxiv_source,
)
from services.converter.app.conversion.latex_converter import convert_latex_source_to_package
from services.converter.app.conversion.package_writer import write_document_package
from services.converter.app.conversion.pdf_converter import convert_pdf_to_package
from services.converter.app.models.document_package import DocumentPackage


def convert_document_to_package(pdf_path: Path, output_dir: Path, document_id: str) -> DocumentPackage:
    pdf_text = _first_pages_text(pdf_path, page_limit=2)
    arxiv_id = detect_arxiv_id(filename=pdf_path.name, pdf_text=pdf_text)
    if arxiv_id:
        try:
            return _convert_from_arxiv_source(
                arxiv_id=arxiv_id,
                pdf_path=pdf_path,
                output_dir=output_dir,
                document_id=document_id,
            )
        except Exception as exc:
            package = convert_pdf_to_package(pdf_path, output_dir, document_id)
            package.conversionMode = "pdf-fallback"
            package.fallbackReason = str(exc)
            package.sourceInfo = {"arxivId": arxiv_id}
            write_document_package(package, output_dir)
            return package

    package = convert_pdf_to_package(pdf_path, output_dir, document_id)
    package.conversionMode = "pdf-layout"
    package.fallbackReason = "No arXiv ID detected"
    write_document_package(package, output_dir)
    return package


def _convert_from_arxiv_source(
    arxiv_id: str,
    pdf_path: Path,
    output_dir: Path,
    document_id: str,
) -> DocumentPackage:
    source_dir = output_dir.parent / "arxiv-source"
    shutil.rmtree(source_dir, ignore_errors=True)
    payload = fetch_arxiv_source(arxiv_id)
    bundle = unpack_arxiv_source(payload, source_dir)
    main_tex = select_main_tex(bundle)
    return convert_latex_source_to_package(
        main_tex=main_tex,
        output_dir=output_dir,
        document_id=document_id,
        source_filename=pdf_path.name,
        original_pdf_sha256=hashlib.sha256(pdf_path.read_bytes()).hexdigest(),
        source_info={"arxivId": arxiv_id, "mainTex": main_tex.relative_to(bundle.root).as_posix()},
    )


def _first_pages_text(pdf_path: Path, page_limit: int) -> str:
    try:
        with fitz.open(pdf_path) as document:
            page_count = min(page_limit, document.page_count)
            return "\n".join(
                document.load_page(index).get_text() for index in range(page_count)
            )
    except Exception:
        return ""
```

- [ ] **Step 4: Wire `JobStore` to orchestrator**

In `services/converter/app/jobs/job_store.py`, replace:

```python
from services.converter.app.conversion.pdf_converter import convert_pdf_to_package
```

with:

```python
from services.converter.app.conversion.document_converter import convert_document_to_package
```

and replace the call inside `convert()` with:

```python
convert_document_to_package(
    pdf_path=self.source_path(job_id),
    output_dir=self.package_dir(job_id),
    document_id=job_id,
)
```

- [ ] **Step 5: Run orchestrator and API tests**

Run:

```powershell
.\services\converter\.venv\Scripts\python.exe -m pytest services\converter\tests\test_document_converter.py services\converter\tests\test_jobs_api.py -q
```

Expected: all tests pass.

- [ ] **Step 6: Commit**

```powershell
git add services\converter\app\conversion\document_converter.py services\converter\app\jobs\job_store.py services\converter\tests\test_document_converter.py
git commit -m "Use arXiv source before PDF fallback"
```

---

### Task 5: Preserve New Fields in Flutter Package Loading

**Files:**
- Modify: `apps/thesis_reader/lib/features/library/data/document_package_loader.dart`
- Modify: `apps/thesis_reader/test/features/library/document_package_loader_test.dart`

- [ ] **Step 1: Write loader test**

Add this test to `apps/thesis_reader/test/features/library/document_package_loader_test.dart`:

```dart
test('preserves conversion metadata and latex block fields', () async {
  final temp = await Directory.systemTemp.createTemp('package_loader_test');
  final packageFile = File(p.join(temp.path, 'packages', 'doc-1', 'package.json'));
  await packageFile.parent.create(recursive: true);
  await packageFile.writeAsString(jsonEncode({
    'packageVersion': 1,
    'documentId': 'doc-1',
    'conversionMode': 'latex-source',
    'sourceInfo': {'arxivId': '2006.11239'},
    'metadata': {
      'title': 'DDPM',
      'sourceFilename': '2006.11239.pdf',
      'originalPdfSha256': 'abc123',
    },
    'sections': [
      {
        'id': 'sec-1',
        'title': 'Document',
        'blockIds': ['eq-1'],
      },
    ],
    'blocks': [
      {
        'id': 'eq-1',
        'sectionId': 'sec-1',
        'kind': 'equation',
        'latex': r'q(x_t \mid x_0) = \mathcal{N}(x_t; 0, I)',
      },
    ],
    'assets': [],
  }));

  final loaded = await DocumentPackageLoader.load(
    documentId: 'doc-1',
    appDirectory: temp,
    storedPackagePath: null,
  );

  expect(loaded?.package.conversionMode, 'latex-source');
  expect(loaded?.package.sourceInfo?['arxivId'], '2006.11239');
  expect(loaded?.package.blocks.single.latex, contains(r'\mathcal'));
});
```

- [ ] **Step 2: Run loader test and verify it fails**

Run:

```powershell
Push-Location apps\thesis_reader; flutter test test\features\library\document_package_loader_test.dart; Pop-Location
```

Expected: FAIL until loader copies new fields when rebuilding `DocumentPackage` and `DocumentBlock`.

- [ ] **Step 3: Preserve fields in loader**

In `DocumentPackageLoader._withPackageAssetPaths` and `_normalizePackageText`, pass through:

```dart
conversionMode: package.conversionMode,
fallbackReason: package.fallbackReason,
sourceInfo: package.sourceInfo,
```

When rebuilding `DocumentBlock`, pass through:

```dart
latex: block.latex,
source: block.source,
```

- [ ] **Step 4: Run loader test**

Run:

```powershell
Push-Location apps\thesis_reader; flutter test test\features\library\document_package_loader_test.dart; Pop-Location
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```powershell
git add apps\thesis_reader\lib\features\library\data\document_package_loader.dart apps\thesis_reader\test\features\library\document_package_loader_test.dart
git commit -m "Preserve source conversion fields in package loader"
```

---

### Task 6: Render LaTeX Equations in Reader with Asset Fallback

**Files:**
- Modify: `apps/thesis_reader/pubspec.yaml`
- Modify: `apps/thesis_reader/lib/features/reader/presentation/reader_screen.dart`
- Modify: `apps/thesis_reader/test/features/reader/reader_screen_test.dart`

- [ ] **Step 1: Add math renderer dependency**

Run:

```powershell
Push-Location apps\thesis_reader; flutter pub add flutter_math_fork; Pop-Location
```

Expected: `apps/thesis_reader/pubspec.yaml` and `apps/thesis_reader/pubspec.lock` update.

- [ ] **Step 2: Write reader test**

Add this test to `apps/thesis_reader/test/features/reader/reader_screen_test.dart`:

```dart
testWidgets('renders latex equation blocks instead of fallback asset label', (tester) async {
  final package = _packageWithCustomBlocks([
    const DocumentBlock(
      id: 'eq-1',
      sectionId: 'sec-1',
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
```

If the test helper `_packageWithCustomBlocks` does not exist, add it near the existing test helpers:

```dart
DocumentPackage _packageWithCustomBlocks(List<DocumentBlock> blocks) {
  return DocumentPackage(
    packageVersion: 1,
    documentId: 'doc-1',
    metadata: const DocumentMetadata(
      title: 'Reader Test',
      sourceFilename: 'paper.pdf',
      originalPdfSha256: 'abc123',
    ),
    sections: [
      DocumentSection(
        id: 'sec-1',
        title: 'Document',
        blockIds: blocks.map((block) => block.id).toList(),
      ),
    ],
    blocks: blocks,
    assets: const [],
  );
}
```

- [ ] **Step 3: Run reader test and verify it fails**

Run:

```powershell
Push-Location apps\thesis_reader; flutter test test\features\reader\reader_screen_test.dart; Pop-Location
```

Expected: FAIL until equation blocks render from `block.latex`.

- [ ] **Step 4: Implement LaTeX equation widget**

In `reader_screen.dart`, import:

```dart
import 'package:flutter_math_fork/flutter_math.dart';
```

Inside `_ReaderBlock.build`, before the text block branch, add:

```dart
if (block.kind == BlockKind.equation && block.latex case final latex?) {
  return Padding(
    key: Key('reader-latex-equation-${block.id}'),
    padding: EdgeInsets.only(bottom: addBottomSpacing ? 16 : 0),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Math.tex(
        latex,
        textStyle: textStyle.copyWith(fontSize: (textStyle.fontSize ?? 16) * 1.05),
      ),
    ),
  );
}
```

Keep the existing asset branch unchanged so source conversion can still provide `assetId` fallback.

- [ ] **Step 5: Run reader test**

Run:

```powershell
Push-Location apps\thesis_reader; flutter test test\features\reader\reader_screen_test.dart; Pop-Location
```

Expected: all tests pass.

- [ ] **Step 6: Commit**

```powershell
git add apps\thesis_reader\pubspec.yaml apps\thesis_reader\pubspec.lock apps\thesis_reader\lib\features\reader\presentation\reader_screen.dart apps\thesis_reader\test\features\reader\reader_screen_test.dart
git commit -m "Render source LaTeX equations in reader"
```

---

### Task 7: Add End-to-End Fixtures and Smoke Checks

**Files:**
- Modify: `services/converter/tests/test_latex_converter.py`
- Modify: `services/converter/tests/test_document_converter.py`

- [ ] **Step 1: Add DDPM-style equation fixture test**

Add this test to `services/converter/tests/test_latex_converter.py`:

```python
def test_preserves_ddpm_multiline_loss_equation_as_latex(tmp_path):
    main_tex = tmp_path / "main.tex"
    main_tex.write_text(
        r"""
\documentclass{article}
\title{Denoising Diffusion Probabilistic Models}
\begin{document}
\section{Background}
Equation (5) uses KL divergence:
\begin{align}
L &= D_{KL}(q(x_T \mid x_0) \| p(x_T)) \\
&+ \sum_{t>1} D_{KL}(q(x_{t-1} \mid x_t, x_0) \| p_\theta(x_{t-1} \mid x_t)) \\
&- \log p_\theta(x_0 \mid x_1)
\end{align}
\end{document}
""",
        encoding="utf-8",
    )

    package = convert_latex_source_to_package(
        main_tex=main_tex,
        output_dir=tmp_path / "out",
        document_id="doc-1",
        source_filename="2006.11239.pdf",
        original_pdf_sha256="abc123",
        source_info={"arxivId": "2006.11239", "mainTex": "main.tex"},
    )

    equations = [block for block in package.blocks if block.kind == BlockKind.equation]
    assert len(equations) == 1
    assert r"D_{KL}" in equations[0].latex
    assert r"\sum_{t>1}" in equations[0].latex
    body_text = " ".join(block.text or "" for block in package.blocks)
    assert "LT" not in body_text
    assert "L0" not in body_text
    assert "l{z}" not in body_text
```

- [ ] **Step 2: Add fallback metadata fixture test**

Add this test to `services/converter/tests/test_document_converter.py`:

```python
def test_pdf_layout_mode_when_no_arxiv_id_is_detected(tmp_path, monkeypatch):
    pdf_path = tmp_path / "renamed.pdf"
    pdf_path.write_bytes(b"%PDF-1.4 fake fixture")

    def fake_pdf_converter(pdf_path, output_dir, document_id):
        from services.converter.app.models.document_package import (
            DocumentMetadata,
            DocumentPackage,
        )

        return DocumentPackage(
            packageVersion=1,
            documentId=document_id,
            metadata=DocumentMetadata(
                title="Fallback",
                sourceFilename=pdf_path.name,
                originalPdfSha256="abc123",
            ),
            sections=[],
            blocks=[],
            assets=[],
        )

    monkeypatch.setattr(
        "services.converter.app.conversion.document_converter._first_pages_text",
        lambda pdf_path, page_limit: "A paper without source identifier",
    )
    monkeypatch.setattr(
        "services.converter.app.conversion.document_converter.convert_pdf_to_package",
        fake_pdf_converter,
    )

    package = convert_document_to_package(pdf_path, tmp_path / "out", "doc-1")

    assert package.conversionMode == "pdf-layout"
    assert package.fallbackReason == "No arXiv ID detected"
```

- [ ] **Step 3: Run server regression tests**

Run:

```powershell
.\services\converter\.venv\Scripts\python.exe -m pytest services\converter\tests -q
```

Expected: all converter tests pass.

- [ ] **Step 4: Run Flutter regression tests**

Run:

```powershell
Push-Location packages\document_contract; flutter test test; Pop-Location
Push-Location apps\thesis_reader; flutter test test\features\library\document_package_loader_test.dart test\features\reader\reader_screen_test.dart; Pop-Location
```

Expected: all selected Flutter tests pass.

- [ ] **Step 5: Commit**

```powershell
git add services\converter\tests\test_latex_converter.py services\converter\tests\test_document_converter.py
git commit -m "Cover source conversion quality fixtures"
```

---

### Task 8: Final Verification and Push

**Files:**
- No direct file edits unless verification finds a defect.

- [ ] **Step 1: Run full server tests**

Run:

```powershell
.\services\converter\.venv\Scripts\python.exe -m pytest services\converter\tests -q
```

Expected: all tests pass.

- [ ] **Step 2: Run focused Flutter tests**

Run:

```powershell
Push-Location packages\document_contract; flutter test test; Pop-Location
Push-Location apps\thesis_reader; flutter test test\features\library\document_package_loader_test.dart test\features\reader\reader_screen_test.dart; Pop-Location
```

Expected: all tests pass.

- [ ] **Step 3: Inspect generated package from local LaTeX fixture**

Run a short local script:

```powershell
@'
from pathlib import Path
from services.converter.app.conversion.latex_converter import convert_latex_source_to_package
from services.converter.app.models.document_package import BlockKind

root = Path("services/converter/.tmp-latex-smoke")
root.mkdir(parents=True, exist_ok=True)
tex = root / "main.tex"
tex.write_text(r"""
\documentclass{article}
\title{Denoising Diffusion Probabilistic Models}
\begin{document}
\section{Background}
Equation (5) uses KL divergence:
\begin{align}
L &= D_{KL}(q(x_T \mid x_0) \| p(x_T)) \\
&+ \sum_{t>1} D_{KL}(q(x_{t-1} \mid x_t, x_0) \| p_\theta(x_{t-1} \mid x_t))
\end{align}
\end{document}
""", encoding="utf-8")
package = convert_latex_source_to_package(
    main_tex=tex,
    output_dir=root / "out",
    document_id="smoke",
    source_filename="2006.11239.pdf",
    original_pdf_sha256="abc123",
    source_info={"arxivId": "2006.11239", "mainTex": "main.tex"},
)
equations = [block for block in package.blocks if block.kind == BlockKind.equation]
print(package.conversionMode)
print(equations[0].latex)
'@ | .\services\converter\.venv\Scripts\python.exe -
```

Expected output contains:

```text
latex-source
D_{KL}
```

- [ ] **Step 4: Check git status**

Run:

```powershell
git status --short --branch
```

Expected: clean working tree on `thesis-reader-mvp`.

- [ ] **Step 5: Push to main**

Run:

```powershell
git push origin HEAD:main
```

Expected: push succeeds.

---

## Self-Review Notes

- Spec coverage: PDF upload remains the entry point; automatic arXiv ID detection is in Task 2; source-first conversion is in Tasks 3 and 4; fallback is in Task 4; package metadata is in Task 1; app rendering is in Task 6; DDPM and Attention-style quality risks are covered by Task 7.
- Placeholder scan: every task gives file paths, function names, commands, and expected outputs.
- Type consistency: Python fields `conversionMode`, `fallbackReason`, `sourceInfo`, `latex`, and `source` match Dart fields and loader preservation steps.

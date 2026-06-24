import hashlib
import re
from datetime import UTC, datetime
from pathlib import Path

import fitz

from services.converter.app.conversion.package_writer import write_document_package
from services.converter.app.models.document_package import (
    AssetKind,
    BlockKind,
    DocumentAsset,
    DocumentBlock,
    DocumentMetadata,
    DocumentPackage,
    DocumentSection,
    ReadingAnchor,
    ReferenceKind,
    ReferenceSpan,
)

REFERENCE_PATTERNS = (
    (re.compile(r"\bFigure\s+\d+\b"), ReferenceKind.figure, AssetKind.figure, "fig"),
    (re.compile(r"\bTable\s+\d+\b"), ReferenceKind.table, AssetKind.table, "table"),
    (re.compile(r"\(\d+\)"), ReferenceKind.equation, AssetKind.equation, "eq"),
)


def convert_pdf_to_package(pdf_path: Path, output_dir: Path, document_id: str) -> DocumentPackage:
    lines = _extract_lines(pdf_path)
    title = next((line["text"] for line in lines if line["text"]), pdf_path.stem)
    body_lines = [line for line in lines if line["text"] and line["text"] != title]

    section_id = "sec-1"
    blocks: list[DocumentBlock] = []
    anchors: list[ReadingAnchor] = []
    assets_by_label: dict[str, DocumentAsset] = {}

    for index, line in enumerate(body_lines, start=1):
        block_id = f"block-{index}"
        anchor = ReadingAnchor(
            blockId=block_id,
            textOffset=0,
            originalPdfPage=line["page"],
            originalPdfRect=line["rect"],
        )
        anchors.append(anchor)
        blocks.append(
            DocumentBlock(
                id=block_id,
                sectionId=section_id,
                kind=BlockKind.paragraph,
                text=line["text"],
                referenceSpans=_reference_spans(line["text"], assets_by_label),
                anchor=anchor,
            )
        )

    package = DocumentPackage(
        packageVersion=1,
        documentId=document_id,
        metadata=DocumentMetadata(
            title=title,
            sourceFilename=pdf_path.name,
            originalPdfSha256=hashlib.sha256(pdf_path.read_bytes()).hexdigest(),
            importedAtIso8601=datetime.now(UTC).isoformat(),
            converterVersion="mvp-1",
        ),
        sections=[
            DocumentSection(
                id=section_id,
                title="Document",
                blockIds=[block.id for block in blocks],
            )
        ],
        blocks=blocks,
        assets=list(assets_by_label.values()),
        anchors=anchors,
    )
    write_document_package(package, output_dir)
    return package


def _extract_lines(pdf_path: Path) -> list[dict]:
    extracted: list[dict] = []
    with fitz.open(pdf_path) as document:
        for page_index, page in enumerate(document, start=1):
            raw_blocks = page.get_text("blocks")
            text_blocks = [block for block in raw_blocks if len(block) >= 5 and block[4].strip()]
            for block in sorted(text_blocks, key=lambda item: (item[1], item[0])):
                rect = [float(block[0]), float(block[1]), float(block[2]), float(block[3])]
                for text in _split_lines(block[4]):
                    extracted.append({"text": text, "page": page_index, "rect": rect})
    return extracted


def _split_lines(text: str) -> list[str]:
    return [line.strip() for line in text.splitlines() if line.strip()]


def _reference_spans(text: str, assets_by_label: dict[str, DocumentAsset]) -> list[ReferenceSpan]:
    spans: list[ReferenceSpan] = []
    for pattern, reference_kind, asset_kind, prefix in REFERENCE_PATTERNS:
        for match in pattern.finditer(text):
            label = match.group(0)
            asset = assets_by_label.setdefault(
                label,
                DocumentAsset(
                    id=f"{prefix}-{_reference_number(label)}",
                    kind=asset_kind,
                    label=label,
                    relativePath=f"assets/{prefix}-{_reference_number(label)}.txt",
                ),
            )
            spans.append(
                ReferenceSpan(
                    start=match.start(),
                    end=match.end(),
                    targetAssetId=asset.id,
                    kind=reference_kind,
                    label=label,
                )
            )
    return sorted(spans, key=lambda span: span.start)


def _reference_number(label: str) -> str:
    match = re.search(r"\d+", label)
    return match.group(0) if match else "unknown"

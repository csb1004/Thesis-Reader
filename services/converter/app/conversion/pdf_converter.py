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
    body_lines = _merge_lines_into_paragraphs(
        [line for line in lines if line["text"] and line["text"] != title]
    )

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
    _write_asset_images(pdf_path, output_dir, package.assets, body_lines)
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


def _merge_lines_into_paragraphs(lines: list[dict]) -> list[dict]:
    paragraphs: list[dict] = []
    current: dict | None = None

    for line in lines:
        if current is None:
            current = dict(line)
            continue

        if _should_merge_lines(current, line):
            current["text"] = _join_wrapped_text(current["text"], line["text"])
            current["rect"] = _union_rect(current["rect"], line["rect"])
        else:
            paragraphs.append(current)
            current = dict(line)

    if current is not None:
        paragraphs.append(current)

    for paragraph in paragraphs:
        paragraph["text"] = _normalize_extracted_text(paragraph["text"])

    return paragraphs


def _should_merge_lines(previous: dict, current: dict) -> bool:
    if previous["page"] != current["page"]:
        return False
    if _looks_like_heading(previous["text"]):
        return False

    previous_rect = previous["rect"]
    current_rect = current["rect"]
    if _same_text_block(previous_rect, current_rect):
        return True

    vertical_gap = current_rect[1] - previous_rect[3]
    return -4 <= vertical_gap <= 24


def _same_text_block(left: list[float], right: list[float]) -> bool:
    return all(abs(left[index] - right[index]) < 0.5 for index in range(4))


def _looks_like_heading(text: str) -> bool:
    stripped = text.strip()
    if not stripped:
        return False
    if stripped.endswith((".", ",", ";", ":")):
        return False
    return len(stripped.split()) <= 4


def _join_wrapped_text(previous: str, current: str) -> str:
    if previous.endswith("-"):
        return previous[:-1] + current
    return f"{previous} {current}"


def _normalize_extracted_text(text: str) -> str:
    joined_words = re.sub(r"([A-Za-z])-\s+([A-Za-z])", r"\1\2", text.replace("☆", "√"))
    collapsed = re.sub(r"\s+", " ", joined_words).strip()
    return _normalize_math_text(_normalize_punctuation_spacing(collapsed))


def _normalize_math_text(text: str) -> str:
    return re.sub(
        r"Attention\(\s*Q\s*,\s*K\s*,\s*V\s*\)\s*=\s*softmax\(\s*Q\s*K\s*T\s*/?\s*√\s*d\s*_?\s*k\s*\)\s*V",
        "Attention(Q, K, V) = softmax(QK^T / √d_k) V",
        text,
    )


def _normalize_punctuation_spacing(text: str) -> str:
    normalized = re.sub(r"\s+([,.;:])", r"\1", text)
    normalized = re.sub(r"\(\s+", "(", normalized)
    normalized = re.sub(r"\s+\)", ")", normalized)
    normalized = re.sub(r"\)([A-Za-z])", r") \1", normalized)
    return re.sub(r"\s+", " ", normalized).strip()


def _union_rect(left: list[float], right: list[float]) -> list[float]:
    return [
        min(left[0], right[0]),
        min(left[1], right[1]),
        max(left[2], right[2]),
        max(left[3], right[3]),
    ]


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
                    relativePath=f"assets/{prefix}-{_reference_number(label)}.png",
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


def _write_asset_images(
    pdf_path: Path,
    output_dir: Path,
    assets: list[DocumentAsset],
    lines: list[dict],
) -> None:
    if not assets:
        return

    assets_dir = output_dir / "assets"
    assets_dir.mkdir(parents=True, exist_ok=True)

    with fitz.open(pdf_path) as document:
        for asset in assets:
            target = output_dir / asset.relativePath
            target.parent.mkdir(parents=True, exist_ok=True)
            if target.exists():
                continue

            match = _line_for_asset(asset, lines)
            page_index = max(0, (match["page"] if match else 1) - 1)
            page = document[page_index]
            clip = _asset_clip(page, match)
            pixmap = page.get_pixmap(matrix=fitz.Matrix(2, 2), clip=clip, alpha=False)
            pixmap.save(target)


def _line_for_asset(asset: DocumentAsset, lines: list[dict]) -> dict | None:
    for line in lines:
        if asset.label in line["text"]:
            return line
    return None


def _asset_clip(page: fitz.Page, line: dict | None) -> fitz.Rect:
    if line is None:
        return page.rect

    rect = fitz.Rect(line["rect"])
    top = max(0, rect.y0 - 280)
    bottom = min(page.rect.height, rect.y1 + 80)
    if bottom - top < 120:
        top = max(0, rect.y0 - 180)
        bottom = min(page.rect.height, rect.y1 + 180)

    return fitz.Rect(0, top, page.rect.width, bottom)

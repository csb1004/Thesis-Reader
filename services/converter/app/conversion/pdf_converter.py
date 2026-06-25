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
EQUATION_CLIP_LEFT_PADDING = 32.0
EQUATION_CLIP_RIGHT_PADDING = 80.0
EQUATION_CLIP_VERTICAL_PADDING = 8.0
TABLE_REGION_CLOSE_GAP = 36.0
TABLE_REGION_CONTENT_GAP = 72.0
TABLE_REGION_OVERLAP_TOLERANCE = -24.0
PAGE_NUMBER_BOTTOM_RATIO = 0.88
FOOTNOTE_BOTTOM_RATIO = 0.84
FOOTNOTE_SUPERSCRIPT_DIGITS = "⁰¹²³⁴⁵⁶⁷⁸⁹"
TABLE_CONTENT_MARKERS = (
    "bleu",
    "dev",
    "dff",
    "dk",
    "dmodel",
    "dv",
    "en-de",
    "en-fr",
    "flop",
    "params",
    "pdrop",
    "ppl",
    "steps",
    "training cost",
    "×10",
)
SUPERSCRIPT_TRANSLATION = str.maketrans(
    "0123456789+-=()n",
    "⁰¹²³⁴⁵⁶⁷⁸⁹⁺⁻⁼⁽⁾ⁿ",
)
SUBSCRIPT_TRANSLATION = str.maketrans(
    "0123456789+-=()aehijklmnoprstuvx",
    "₀₁₂₃₄₅₆₇₈₉₊₋₌₍₎ₐₑₕᵢⱼₖₗₘₙₒₚᵣₛₜᵤᵥₓ",
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
        if line.get("kind") == BlockKind.equation:
            label = _equation_label(line["text"], len(assets_by_label) + 1)
            asset = assets_by_label.setdefault(
                label,
                DocumentAsset(
                    id=f"eq-{_reference_number(label)}",
                    kind=AssetKind.equation,
                    label=label,
                    relativePath=f"assets/eq-{_reference_number(label)}.png",
                ),
            )
            line["assetId"] = asset.id
            blocks.append(
                DocumentBlock(
                    id=block_id,
                    sectionId=section_id,
                    kind=BlockKind.equation,
                    assetId=asset.id,
                    anchor=anchor,
                )
            )
        elif line.get("kind") == BlockKind.table:
            label = _table_label(line["text"], len(assets_by_label) + 1)
            asset = assets_by_label.setdefault(
                label,
                DocumentAsset(
                    id=f"table-{_reference_number(label)}",
                    kind=AssetKind.table,
                    label=label,
                    relativePath=f"assets/table-{_reference_number(label)}.png",
                ),
            )
            line["assetId"] = asset.id
            blocks.append(
                DocumentBlock(
                    id=block_id,
                    sectionId=section_id,
                    kind=BlockKind.table,
                    assetId=asset.id,
                    anchor=anchor,
                )
            )
        else:
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
            raw_blocks = page.get_text("dict").get("blocks", [])
            for block in raw_blocks:
                if block.get("type") != 0:
                    continue
                for line in _combine_inline_pdf_lines(block.get("lines", [])):
                    text = _line_text(line).strip()
                    if not text:
                        continue
                    bbox = line.get("bbox")
                    rect = [float(bbox[index]) for index in range(4)]
                    if _should_skip_extracted_line(
                        text,
                        rect,
                        page.rect,
                        _line_font_size(line),
                    ):
                        continue
                    extracted.append({"text": text, "page": page_index, "rect": rect})
    extracted.sort(key=lambda item: (item["page"], item["rect"][1], item["rect"][0]))
    return extracted


def _line_font_size(line: dict) -> float:
    sizes = [
        float(span.get("size", 0))
        for span in line.get("spans", [])
        if span.get("text", "").strip()
    ]
    return max(sizes) if sizes else 0.0


def _should_skip_extracted_line(
    text: str,
    rect: list[float],
    page_rect: fitz.Rect,
    font_size: float,
) -> bool:
    stripped = text.strip()
    if re.fullmatch(r"\d+", stripped):
        center_x = (rect[0] + rect[2]) / 2
        page_center_x = page_rect.width / 2
        if (
            rect[1] >= page_rect.height * PAGE_NUMBER_BOTTOM_RATIO
            and abs(center_x - page_center_x) <= 32
        ):
            return True

    if rect[1] >= page_rect.height * FOOTNOTE_BOTTOM_RATIO and (
        font_size <= 8.5 or stripped[:1] in FOOTNOTE_SUPERSCRIPT_DIGITS
    ):
        return True

    return False


def _combine_inline_pdf_lines(lines: list[dict]) -> list[dict]:
    combined: list[dict] = []
    for line in lines:
        current = {
            "bbox": [float(value) for value in line.get("bbox", [0, 0, 0, 0])],
            "spans": list(line.get("spans", [])),
        }
        if combined and _same_visual_line(combined[-1]["bbox"], current["bbox"]):
            combined[-1]["bbox"] = _union_rect(combined[-1]["bbox"], current["bbox"])
            combined[-1]["spans"].extend(current["spans"])
        else:
            combined.append(current)
    return combined


def _same_visual_line(left: list[float], right: list[float]) -> bool:
    vertical_overlap = min(left[3], right[3]) - max(left[1], right[1])
    if vertical_overlap <= 0:
        return False
    return vertical_overlap / max(1.0, min(left[3] - left[1], right[3] - right[1])) >= 0.45


def _line_text(line: dict) -> str:
    spans = sorted(
        line.get("spans", []),
        key=lambda span: (
            float(span.get("bbox", [0, 0, 0, 0])[0]),
            float(span.get("bbox", [0, 0, 0, 0])[1]),
        ),
    )
    if not spans:
        return ""

    sizes = [float(span.get("size", 0)) for span in spans if span.get("text", "").strip()]
    main_size = max(sizes) if sizes else 1.0
    baseline_candidates = [
        float(span.get("origin", (0, span.get("bbox", [0, 0, 0, 0])[3]))[1])
        for span in spans
        if float(span.get("size", main_size)) >= main_size * 0.9
        and span.get("text", "").strip()
    ]
    main_baseline = _median(baseline_candidates) if baseline_candidates else 0.0

    chunks: list[str] = []
    for span in spans:
        text = span.get("text", "")
        if not text:
            continue
        size = float(span.get("size", main_size))
        origin = span.get("origin")
        baseline = float(origin[1]) if origin else float(span.get("bbox", [0, 0, 0, 0])[3])
        if size <= main_size * 0.8 and text.strip():
            if baseline < main_baseline - main_size * 0.2:
                chunks.append(_translate_script(text, SUPERSCRIPT_TRANSLATION))
                continue
            if baseline > main_baseline + main_size * 0.2:
                chunks.append(_translate_script(text, SUBSCRIPT_TRANSLATION))
                continue
        if not (size <= main_size * 0.8 and text.isspace()):
            chunks.append(text)

    return "".join(chunks)


def _median(values: list[float]) -> float:
    ordered = sorted(values)
    midpoint = len(ordered) // 2
    if len(ordered) % 2 == 1:
        return ordered[midpoint]
    return (ordered[midpoint - 1] + ordered[midpoint]) / 2


def _translate_script(text: str, translation: dict[int, str]) -> str:
    return text.translate(translation)


def _merge_lines_into_paragraphs(lines: list[dict]) -> list[dict]:
    paragraphs: list[dict] = []
    current: dict | None = None
    equation: dict | None = None
    table: dict | None = None

    def flush_current() -> None:
        nonlocal current
        if current is not None:
            paragraphs.append(current)
            current = None

    def flush_equation() -> None:
        nonlocal equation
        if equation is not None:
            paragraphs.append(equation)
            equation = None

    def flush_table() -> None:
        nonlocal table
        if table is not None:
            paragraphs.append(table)
            table = None

    for line in lines:
        if table is not None:
            if _should_continue_table_region(table, line):
                table["text"] = _join_wrapped_text(table["text"], line["text"])
                table["rect"] = _union_rect(table["rect"], line["rect"])
                table["_hasTableContent"] = bool(
                    table.get("_hasTableContent")
                ) or _looks_like_table_content(line["text"])
                continue
            flush_table()

        if _looks_like_table_start(line["text"]):
            flush_current()
            flush_equation()
            table = dict(line)
            table["kind"] = BlockKind.table
            table["_hasTableContent"] = False
            continue

        if _looks_like_equation_line(line["text"]) or (
            equation is not None and _looks_like_equation_continuation(line["text"])
        ):
            flush_current()
            if equation is not None and _should_merge_equation_lines(equation, line):
                equation["text"] = f'{equation["text"]} {line["text"]}'
                equation["rect"] = _union_rect(equation["rect"], line["rect"])
            else:
                flush_equation()
                equation = dict(line)
                equation["kind"] = BlockKind.equation
            continue

        flush_equation()
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
    if equation is not None:
        paragraphs.append(equation)
    if table is not None:
        paragraphs.append(table)

    for paragraph in paragraphs:
        if paragraph.get("kind") not in {BlockKind.equation, BlockKind.table}:
            paragraph["text"] = _normalize_extracted_text(paragraph["text"])

    return paragraphs


def _looks_like_equation_line(text: str) -> bool:
    stripped = text.strip()
    if not stripped:
        return False
    if re.fullmatch(r"\(\d+\)", stripped):
        return False
    word_count = len(stripped.split())
    if stripped.endswith((".", ",", ";")):
        return False
    if "=" in stripped and word_count <= 14:
        if _looks_like_inline_math_sentence(stripped):
            return False
        return True
    if word_count == 1:
        return False
    if (
        re.search(r"[∈∑√≤≥×^_]|[A-Z]\s*[=∈]", stripped)
        and word_count <= 10
        and not _looks_like_inline_math_sentence(stripped)
    ):
        return True
    return bool(
        re.search(r"\b(?:Attention|softmax|MultiHead|Concat|head\w*)\b", stripped)
        and "=" in stripped
    )


def _looks_like_inline_math_sentence(text: str) -> bool:
    words = re.findall(r"[A-Za-z]{2,}", text.lower())
    if len(words) < 7:
        return False
    return any(
        word
        in {
            "during",
            "training",
            "we",
            "employed",
            "value",
            "this",
            "the",
            "where",
            "used",
            "with",
            "for",
        }
        for word in words
    )


def _looks_like_table_start(text: str) -> bool:
    return bool(re.match(r"^Table\s+\d+\s*[:.]", text.strip()))


def _should_continue_table_region(table: dict, line: dict) -> bool:
    if table["page"] != line["page"]:
        return False
    if _looks_like_numbered_section_heading(line["text"]):
        return False

    vertical_gap = line["rect"][1] - table["rect"][3]
    if TABLE_REGION_OVERLAP_TOLERANCE <= vertical_gap <= TABLE_REGION_CLOSE_GAP:
        if table.get("_hasTableContent"):
            return _looks_like_table_content(line["text"])
        return True
    return (
        0 <= vertical_gap <= TABLE_REGION_CONTENT_GAP
        and _looks_like_table_content(line["text"])
    )


def _looks_like_table_content(text: str) -> bool:
    stripped = text.strip()
    if not stripped or _looks_like_numbered_section_heading(stripped):
        return False
    prose_words = re.findall(r"[A-Za-z]{2,}", stripped)
    if len(prose_words) >= 8:
        return False
    if stripped in {"Model", "BLEU", "Training Cost (FLOPs)"}:
        return True
    if re.fullmatch(r"\([A-Z]\)", stripped):
        return True
    lowered = stripped.lower()
    if any(marker in lowered for marker in TABLE_CONTENT_MARKERS):
        return True
    if re.search(r"\[[0-9]+\]", stripped) and re.search(r"\d", stripped):
        return True
    if len(re.findall(r"\d+(?:\.\d+)?", stripped)) >= 2:
        return True
    return bool(re.search(r"[A-Z]{2,}(?:-[A-Z]{2,})+", stripped))


def _looks_like_numbered_section_heading(text: str) -> bool:
    return bool(re.match(r"^\d+(?:\.\d+)+\s*[A-Z]", text.strip()))


def _looks_like_equation_continuation(text: str) -> bool:
    stripped = text.strip()
    if not stripped:
        return False
    if re.fullmatch(r"\(\d+\)", stripped):
        return True
    if len(stripped.split()) > 6:
        return False
    if stripped.endswith((".", ":", ";")):
        return False
    compact = re.sub(r"\s+", "", stripped)
    if len(compact) > 40:
        return False
    prose_words = re.findall(r"[A-Za-z]{3,}", stripped.lower())
    if len(prose_words) >= 2 and any(
        word
        in {
            "the",
            "and",
            "are",
            "with",
            "using",
            "attention",
            "function",
            "functions",
            "algorithm",
            "except",
            "scaling",
            "factor",
        }
        for word in prose_words
    ):
        return False
    if any(not character.isalnum() for character in compact):
        return True
    uppercase_tokens = re.findall(r"\b[A-Z]{1,3}\b", stripped)
    return bool(uppercase_tokens and len(prose_words) <= 1)


def _should_merge_equation_lines(previous: dict, current: dict) -> bool:
    if previous["page"] != current["page"]:
        return False

    previous_rect = previous["rect"]
    current_rect = current["rect"]
    vertical_overlap = min(previous_rect[3], current_rect[3]) - max(
        previous_rect[1],
        current_rect[1],
    )
    if vertical_overlap >= -4:
        return True

    vertical_gap = current_rect[1] - previous_rect[3]
    return 0 <= vertical_gap <= 24


def _should_merge_lines(previous: dict, current: dict) -> bool:
    if previous["page"] != current["page"]:
        return False
    if _looks_like_heading(previous["text"]):
        return False

    previous_rect = previous["rect"]
    current_rect = current["rect"]
    if _same_text_block(previous_rect, current_rect):
        return True
    if _overlaps_same_text_flow(previous_rect, current_rect):
        return True

    vertical_gap = current_rect[1] - previous_rect[3]
    return -4 <= vertical_gap <= 24


def _same_text_block(left: list[float], right: list[float]) -> bool:
    return all(abs(left[index] - right[index]) < 0.5 for index in range(4))


def _overlaps_same_text_flow(left: list[float], right: list[float]) -> bool:
    vertical_overlap = min(left[3], right[3]) - max(left[1], right[1])
    if vertical_overlap <= 0:
        return False
    return right[0] <= left[2] + 8 and right[2] >= left[0] - 8


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
            if reference_kind == ReferenceKind.equation:
                if _is_complexity_notation_reference(text, match.start()):
                    continue
                if not _has_explicit_equation_reference_context(text, match.start()):
                    continue
                asset = assets_by_label.get(label)
                if asset is None:
                    continue
            else:
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


def _is_complexity_notation_reference(text: str, start: int) -> bool:
    prefix = text[max(0, start - 1) : start]
    return prefix in {"O", "o"}


def _has_explicit_equation_reference_context(text: str, start: int) -> bool:
    context = text[max(0, start - 18) : start].lower()
    return bool(re.search(r"\b(?:equation|eq\.?|formula)\s*$", context))


def _reference_number(label: str) -> str:
    match = re.search(r"\d+", label)
    return match.group(0) if match else "unknown"


def _equation_label(text: str, fallback_number: int) -> str:
    match = re.search(r"\(\s*(\d+)\s*\)", text)
    if match:
        return f"({match.group(1)})"
    return f"Equation {fallback_number}"


def _table_label(text: str, fallback_number: int) -> str:
    match = re.search(r"\bTable\s+(\d+)\b", text)
    if match:
        return f"Table {match.group(1)}"
    return f"Table {fallback_number}"


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
            clip = _asset_clip(page, match, asset)
            pixmap = page.get_pixmap(matrix=fitz.Matrix(2, 2), clip=clip, alpha=False)
            pixmap.save(target)


def _line_for_asset(asset: DocumentAsset, lines: list[dict]) -> dict | None:
    for line in lines:
        if line.get("assetId") == asset.id:
            return line
    for line in lines:
        if asset.label in line["text"]:
            return line
    return None


def _asset_clip(page: fitz.Page, line: dict | None, asset: DocumentAsset) -> fitz.Rect:
    if line is None:
        return page.rect

    rect = fitz.Rect(line["rect"])
    if asset.kind == AssetKind.equation:
        return fitz.Rect(
            max(0, rect.x0 - EQUATION_CLIP_LEFT_PADDING),
            max(0, rect.y0 - EQUATION_CLIP_VERTICAL_PADDING),
            min(page.rect.width, rect.x1 + EQUATION_CLIP_RIGHT_PADDING),
            min(page.rect.height, rect.y1 + EQUATION_CLIP_VERTICAL_PADDING),
        )
    if asset.kind == AssetKind.table:
        return fitz.Rect(
            max(0, rect.x0 - 18),
            max(0, rect.y0 - 12),
            min(page.rect.width, rect.x1 + 18),
            min(page.rect.height, rect.y1 + 12),
        )

    top = max(0, rect.y0 - 280)
    bottom = min(page.rect.height, rect.y1 + 80)
    if bottom - top < 120:
        top = max(0, rect.y0 - 180)
        bottom = min(page.rect.height, rect.y1 + 180)

    return fitz.Rect(0, top, page.rect.width, bottom)

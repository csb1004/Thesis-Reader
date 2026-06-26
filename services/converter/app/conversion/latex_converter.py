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

DISPLAY_ENVIRONMENTS = (
    "equation",
    "equation*",
    "align",
    "align*",
    "gather",
    "gather*",
    "multline",
    "multline*",
)


def convert_latex_source_to_package(
    main_tex: Path,
    output_dir: Path,
    document_id: str,
    source_filename: str,
    original_pdf_sha256: str,
    source_info: dict[str, str],
) -> DocumentPackage:
    raw = main_tex.read_text(encoding="utf-8", errors="ignore")
    expanded = _expand_simple_includes(raw, main_tex.parent)
    body = _document_body(expanded)
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
            },
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
        sections=[
            DocumentSection(
                id=section_id,
                title="Document",
                blockIds=[block.id for block in anchored],
            )
        ],
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
        match token["kind"]:
            case "heading":
                blocks.append(
                    DocumentBlock(
                        id=block_id,
                        sectionId="",
                        kind=BlockKind.heading,
                        text=token["text"],
                    )
                )
            case "equation":
                blocks.append(
                    DocumentBlock(
                        id=block_id,
                        sectionId="",
                        kind=BlockKind.equation,
                        latex=token["latex"],
                        source={"mode": "latex", "environment": token["environment"]},
                    )
                )
            case "table":
                blocks.append(
                    DocumentBlock(
                        id=block_id,
                        sectionId="",
                        kind=BlockKind.table,
                        text=token.get("text"),
                        latex=token.get("latex"),
                        source={"mode": "latex", "environment": "table"},
                    )
                )
            case "figure":
                blocks.append(
                    DocumentBlock(
                        id=block_id,
                        sectionId="",
                        kind=BlockKind.figure,
                        text=token.get("text"),
                        latex=token.get("latex"),
                        source={"mode": "latex", "environment": "figure"},
                    )
                )
            case "reference":
                blocks.append(
                    DocumentBlock(
                        id=block_id,
                        sectionId="",
                        kind=BlockKind.reference,
                        text=token["text"],
                    )
                )
            case _:
                blocks.append(
                    DocumentBlock(
                        id=block_id,
                        sectionId="",
                        kind=BlockKind.paragraph,
                        text=token["text"],
                    )
                )
    return blocks


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
    body = _strip_comments(body)
    protected: list[dict[str, str]] = []

    def protect(kind: str, content: str, environment: str = "", text: str = "") -> str:
        key = f"@@BLOCK_{len(protected)}@@"
        protected.append(
            {
                "kind": kind,
                "latex": content,
                "environment": environment,
                "text": text,
            }
        )
        return f"\n\n{key}\n\n"

    for environment in DISPLAY_ENVIRONMENTS:
        pattern = re.compile(
            rf"\\begin\{{{re.escape(environment)}\}}(?P<value>.*?)"
            rf"\\end\{{{re.escape(environment)}\}}",
            flags=re.DOTALL,
        )
        body = pattern.sub(
            lambda match: protect(
                "equation",
                match.group("value").strip(),
                environment,
            ),
            body,
        )

    for environment in ("table", "table*", "tabular", "tabular*"):
        pattern = re.compile(
            rf"\\begin\{{{re.escape(environment)}\}}(?P<value>.*?)"
            rf"\\end\{{{re.escape(environment)}\}}",
            flags=re.DOTALL,
        )
        body = pattern.sub(
            lambda match: protect(
                "table",
                match.group(0).strip(),
                environment,
                _clean_text(match.group("value")),
            ),
            body,
        )

    for environment in ("figure", "figure*"):
        pattern = re.compile(
            rf"\\begin\{{{re.escape(environment)}\}}(?P<value>.*?)"
            rf"\\end\{{{re.escape(environment)}\}}",
            flags=re.DOTALL,
        )
        body = pattern.sub(
            lambda match: protect(
                "figure",
                match.group(0).strip(),
                environment,
                _figure_text(match.group("value")),
            ),
            body,
        )

    body = re.sub(
        r"\\\[(?P<value>.*?)\\\]",
        lambda match: protect("equation", match.group("value").strip(), "displaymath"),
        body,
        flags=re.DOTALL,
    )
    body = re.sub(
        r"\$\$(?P<value>.*?)\$\$",
        lambda match: protect("equation", match.group("value").strip(), "displaymath"),
        body,
        flags=re.DOTALL,
    )
    body = re.sub(
        r"\\section\*?\{(?P<value>.*?)\}",
        lambda match: protect("heading", "", text=_clean_text(match.group("value"))),
        body,
        flags=re.DOTALL,
    )
    body = re.sub(
        r"\\subsection\*?\{(?P<value>.*?)\}",
        lambda match: protect("heading", "", text=_clean_text(match.group("value"))),
        body,
        flags=re.DOTALL,
    )

    references = re.findall(
        r"\\bibitem(?:\[[^\]]+\])?\{[^}]+\}(?P<value>.*?)(?=\\bibitem|\\end\{thebibliography\})",
        body,
        flags=re.DOTALL,
    )
    body = re.sub(
        r"\\begin\{thebibliography\}(?:\{[^}]*\})?.*?\\end\{thebibliography\}",
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
            match item["kind"]:
                case "equation":
                    tokens.append(
                        {
                            "kind": "equation",
                            "latex": item["latex"],
                            "environment": item["environment"],
                        }
                    )
                case "heading":
                    tokens.append({"kind": "heading", "text": item["text"]})
                case "table":
                    tokens.append(
                        {
                            "kind": "table",
                            "latex": item["latex"],
                            "text": item["text"] or "Table",
                        }
                    )
                case "figure":
                    tokens.append(
                        {
                            "kind": "figure",
                            "latex": item["latex"],
                            "text": item["text"] or "Figure",
                        }
                    )
            continue
        cleaned = _clean_text(chunk)
        if cleaned:
            tokens.append({"kind": "paragraph", "text": cleaned})

    for index, reference in enumerate(references, start=1):
        cleaned = _clean_text(reference)
        if cleaned:
            tokens.append({"kind": "reference", "text": f"[{index}] {cleaned}"})

    return tokens


def _strip_comments(text: str) -> str:
    return re.sub(r"(?<!\\)%.*", "", text)


def _figure_text(text: str) -> str:
    caption = _first_match(text, r"\\caption\{(?P<value>.*?)\}")
    if caption:
        return _clean_text(caption)
    return _clean_text(text)


def _clean_text(text: str) -> str:
    cleaned = text.replace("~", " ")
    cleaned = re.sub(r"\\(?:maketitle|begin\{abstract\}|end\{abstract\})", " ", cleaned)
    cleaned = re.sub(r"\\cite\{([^}]+)\}", r"[\1]", cleaned)
    cleaned = re.sub(r"\\[a-zA-Z]+\*?(?:\[[^\]]+\])?\{([^{}]*)\}", r"\1", cleaned)
    cleaned = re.sub(r"\\[a-zA-Z]+\*?", " ", cleaned)
    cleaned = cleaned.replace("{", "").replace("}", "")
    return re.sub(r"\s+", " ", cleaned).strip()

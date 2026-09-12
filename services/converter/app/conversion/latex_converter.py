import re
from collections.abc import Callable
from datetime import UTC, datetime
from pathlib import Path

from services.converter.app.conversion.equation_renderer import (
    render_latex_equation_asset,
)
from services.converter.app.conversion.math_text import latex_to_readable_math_text
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
    TextStyleSpan,
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
LINE_BREAK_MARKER = "@@LATEX_LINE_BREAK@@"
LEGACY_COMPILED_SECTION_NUMBERS = {
    "areas.asp": "2.2",
    "section areas.asp": "2.2",
}


def convert_latex_source_to_package(
    main_tex: Path,
    output_dir: Path,
    document_id: str,
    source_filename: str,
    original_pdf_sha256: str,
    source_info: dict[str, str],
    original_pdf_path: Path | None = None,
) -> DocumentPackage:
    raw = main_tex.read_text(encoding="utf-8", errors="ignore")
    expanded = _expand_simple_includes(raw, main_tex.parent)
    body = _expand_user_macros(_document_body(expanded), expanded.split(r"\begin{document}", 1)[0])
    title = _clean_text(_first_match(raw, r"\\title\{(?P<value>.*?)\}") or main_tex.stem)
    section_reference_numbers = _section_reference_numbers(body)
    blocks = _extract_blocks(body, section_reference_numbers)
    if not blocks:
        raise ValueError("LaTeX source produced no reader blocks")
    if original_pdf_path is not None:
        _validate_source_identity(title, blocks, original_pdf_path)
        if any(block.kind in {BlockKind.figure, BlockKind.table} for block in blocks):
            raise ValueError("Source contains visuals requiring original PDF extraction")
    blocks, assets = _attach_equation_assets(blocks, output_dir)
    if original_pdf_path is not None and any(
        (block.source or {}).get("renderMode") == "fallback-png" for block in blocks
    ):
        raise ValueError("Equation rendering failed; use original PDF visuals")

    anchored, sections = _assign_blocks_to_sections(blocks)
    package = DocumentPackage(
        packageVersion=1,
        documentId=document_id,
        metadata=DocumentMetadata(
            title=title,
            sourceFilename=source_filename,
            originalPdfSha256=original_pdf_sha256,
            importedAtIso8601=datetime.now(UTC).isoformat(),
            converterVersion="mvp-3",
        ),
        conversionMode="latex-source",
        fallbackReason=None,
        sourceInfo=source_info,
        sections=sections,
        blocks=anchored,
        assets=assets,
        anchors=[block.anchor for block in anchored if block.anchor is not None],
    )
    write_document_package(package, output_dir)
    return package


def _validate_source_identity(title: str, blocks: list[DocumentBlock], pdf_path: Path) -> None:
    import fitz

    words = lambda text: re.findall(r"[a-z]{3,}", text.lower())
    with fitz.open(pdf_path) as document:
        pdf_words = words(" ".join(page.get_text() for page in document))
    title_words = words(title)
    vocabulary = set(pdf_words)
    if not title_words or sum(word in vocabulary for word in title_words) / len(title_words) < .9:
        raise ValueError("TeX title does not match uploaded PDF")
    source_words = words(" ".join(block.text or "" for block in blocks if block.kind == BlockKind.paragraph))
    if len(source_words) < 20:
        raise ValueError("Insufficient source text to verify PDF identity")
    pdf_pairs = set(zip(pdf_words, pdf_words[1:]))
    source_pairs = list(zip(source_words, source_words[1:]))
    if sum(pair in pdf_pairs for pair in source_pairs) / len(source_pairs) < .65:
        raise ValueError("TeX content does not match uploaded PDF")


def _expand_user_macros(body: str, preamble: str) -> str:
    preamble = _strip_comments(preamble)
    declarations = re.compile(r"\\(?:newcommand|renewcommand|providecommand)\*?\s*(?:\{\\(?P<braced>[A-Za-z]+)\}|\\(?P<bare>[A-Za-z]+))\s*(?:\[(?P<count>\d)\])?\s*")
    macros = {}
    for match in declarations.finditer(preamble):
        parsed = _read_balanced_latex_group(preamble, match.end())
        if parsed is None:
            continue
        value, _ = parsed
        macros[match.group("braced") or match.group("bare")] = (int(match.group("count") or 0), value)
    for _ in range(20):
        previous = body
        for name, (count, value) in macros.items():
            def substitute(args: list[str], template: str = value) -> str:
                return re.sub(r"#([1-9])", lambda m: args[int(m.group(1))-1] if int(m.group(1)) <= len(args) else m.group(0), template)
            body = _replace_latex_macro_args(body, name, count, substitute)
        if body == previous:
            return body
        if len(body) > 5_000_000:
            raise ValueError("TeX macro expansion exceeds size limit")
    raise ValueError("Recursive TeX macro expansion")


def _attach_equation_assets(
    blocks: list[DocumentBlock],
    output_dir: Path,
) -> tuple[list[DocumentBlock], list[DocumentAsset]]:
    assets: list[DocumentAsset] = []
    updated_blocks: list[DocumentBlock] = []

    for block in blocks:
        if block.kind != BlockKind.equation or not block.latex:
            updated_blocks.append(block)
            continue

        equation_number = len(assets) + 1
        asset = DocumentAsset(
            id=f"eq-{equation_number}",
            kind=AssetKind.equation,
            label=f"Equation {equation_number}",
            relativePath=f"assets/eq-{equation_number}.png",
        )
        render_mode = render_latex_equation_asset(
            block.latex,
            output_dir / asset.relativePath,
            environment=(block.source or {}).get("environment"),
        )
        source = {
            **(block.source or {}),
            "mode": "latex-asset",
            "assetId": asset.id,
            "renderMode": render_mode,
        }
        assets.append(asset)
        updated_blocks.append(
            block.model_copy(update={"assetId": asset.id, "source": source})
        )

    return updated_blocks, assets


def _assign_blocks_to_sections(
    blocks: list[DocumentBlock],
) -> tuple[list[DocumentBlock], list[DocumentSection]]:
    sections: list[DocumentSection] = []
    anchored: list[DocumentBlock] = []
    current_id: str | None = None
    current_title = "Document"
    current_block_ids: list[str] = []

    def finish_section() -> None:
        if current_id is None:
            return
        sections.append(
            DocumentSection(
                id=current_id,
                title=current_title,
                blockIds=list(current_block_ids),
            )
        )

    def start_section(title: str) -> str:
        nonlocal current_id, current_title, current_block_ids
        finish_section()
        current_id = f"sec-{len(sections) + 1}"
        current_title = title.strip() or "Document"
        current_block_ids = []
        return current_id

    for block in blocks:
        if block.kind == BlockKind.heading and block.text:
            section_id = start_section(block.text)
        elif current_id is None:
            section_id = start_section("Document")
        else:
            section_id = current_id

        current_block_ids.append(block.id)
        anchored.append(
            block.model_copy(
                update={
                    "sectionId": section_id,
                    "anchor": ReadingAnchor(blockId=block.id, textOffset=0),
                },
            )
        )

    finish_section()
    return anchored, sections


def _section_reference_numbers(body: str) -> dict[str, str]:
    pattern = re.compile(
        r"\\(?P<command>subsubsection|subsection|section)(?P<star>\*)?"
        r"\{(?P<title>.*?)\}"
        r"(?P<label_tail>\s*\\label\{(?P<label>[^}]+)\})?",
        flags=re.DOTALL,
    )
    section = 0
    subsection = 0
    subsubsection = 0
    numbers: dict[str, str] = {}

    for match in pattern.finditer(body):
        command = match.group("command")
        if match.group("star"):
            continue

        if command == "section":
            section += 1
            subsection = 0
            subsubsection = 0
            number = str(section)
        elif command == "subsection":
            if section == 0:
                section = 1
            subsection += 1
            subsubsection = 0
            number = f"{section}.{subsection}"
        else:
            if section == 0:
                section = 1
            if subsection == 0:
                subsection = 1
            subsubsection += 1
            number = f"{section}.{subsection}.{subsubsection}"

        label = match.group("label")
        if label:
            numbers[label.strip()] = number

    return numbers


def _extract_blocks(
    body: str,
    section_reference_numbers: dict[str, str],
) -> list[DocumentBlock]:
    tokens = _tokenize_body(body, section_reference_numbers)
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
                        textSpans=token.get("textSpans", []),
                        referenceSpans=token.get("referenceSpans", []),
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
            case "horizontalRule":
                blocks.append(
                    DocumentBlock(
                        id=block_id,
                        sectionId="",
                        kind=BlockKind.paragraph,
                        source={
                            "mode": "latex",
                            "role": "horizontalRule",
                            "preserveStructure": True,
                        },
                    )
                )
            case _:
                blocks.append(
                    DocumentBlock(
                        id=block_id,
                        sectionId="",
                        kind=BlockKind.paragraph,
                        text=token["text"],
                        source=token.get("source"),
                        textSpans=token.get("textSpans", []),
                        referenceSpans=token.get("referenceSpans", []),
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
    pattern = re.compile(r"\\(?:input|include)\s*(?:\{(?P<braced>[^}]+)\}|(?P<bare>[^\s{}]+))")
    root = root.resolve()

    def expand(content: str, directory: Path, stack: tuple[Path, ...]) -> str:
        if len(stack) > 32:
            raise ValueError("TeX include nesting exceeds 32 levels")

        def replace(match: re.Match[str]) -> str:
            name = Path(match.group("braced") or match.group("bare"))
            if not name.suffix:
                name = name.with_suffix(".tex")
            # TeX resolves from the main directory; accept local nested paths too.
            candidates = [(root / name).resolve(), (directory / name).resolve()]
            path = next((p for p in candidates if p.is_relative_to(root) and p.is_file()), None)
            if path is None:
                raise ValueError(f"Missing or unsafe TeX include: {name}")
            if path in stack:
                raise ValueError(f"Cyclic TeX include: {name}")
            return expand(path.read_text(encoding="utf-8"), path.parent, (*stack, path))

        return pattern.sub(replace, _strip_comments(content))

    return expand(text, root, ())


def _tokenize_body(
    body: str,
    section_reference_numbers: dict[str, str],
) -> list[dict[str, str]]:
    body = _strip_comments(body)
    protected: list[dict[str, str]] = []

    def protect(kind: str, content: str, environment: str = "", text: str = "") -> str:
        key = f"@@BLOCK_{len(protected)}@@"
        protected.append(
            {
                "kind": kind,
                "latex": _normalize_display_latex(content) if kind == "equation" else content,
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
        r"\\begin\{abstract\}(?P<value>.*?)\\end\{abstract\}",
        lambda match: (
            f"{protect('heading', '', text='Abstract')}\n\n"
            f"{match.group('value').strip()}"
        ),
        body,
        flags=re.DOTALL,
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
        r"\\(?:subsubsection|subsection|section)\*?\{(?P<value>.*?)\}",
        lambda match: protect("heading", "", text=_clean_text(match.group("value"))),
        body,
        flags=re.DOTALL,
    )

    body = re.sub(
        r"\\(?:hrule|rule\{[^{}]*\}\{[^{}]*\})",
        lambda _match: protect("horizontalRule", ""),
        body,
    )

    references = _extract_bibitems(body)
    citation_numbers = {
        reference["key"]: str(index)
        for index, reference in enumerate(references, start=1)
        if reference["key"]
    }
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
                case "horizontalRule":
                    tokens.append({"kind": "horizontalRule"})
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
        cleaned, text_spans, reference_spans = _clean_text_metadata(
            chunk,
            citation_numbers,
            section_reference_numbers,
        )
        if cleaned:
            token: dict[str, str | bool | list[TextStyleSpan] | list[ReferenceSpan] | dict[str, bool | str]] = {
                "kind": "paragraph",
                "text": cleaned,
            }
            if "\n" in cleaned:
                token["source"] = {
                    "mode": "latex",
                    "preserveStructure": True,
                }
            if text_spans:
                token["textSpans"] = text_spans
            if reference_spans:
                token["referenceSpans"] = reference_spans
            tokens.append(token)

    for index, reference in enumerate(references, start=1):
        cleaned = _clean_text(
            reference["value"],
            citation_numbers,
            section_reference_numbers,
        )
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


def _extract_bibitems(text: str) -> list[dict[str, str]]:
    pattern = re.compile(
        r"\\bibitem(?:\[[^\]]+\])?\{(?P<key>[^}]+)\}"
        r"(?P<value>.*?)(?=\\bibitem|\\end\{thebibliography\})",
        flags=re.DOTALL,
    )
    return [
        {
            "key": match.group("key").strip(),
            "value": match.group("value").strip(),
        }
        for match in pattern.finditer(text)
    ]


def _clean_text(
    text: str,
    citation_numbers: dict[str, str] | None = None,
    section_reference_numbers: dict[str, str] | None = None,
) -> str:
    cleaned, _, _ = _clean_text_metadata(
        text,
        citation_numbers,
        section_reference_numbers,
    )
    return cleaned


def _clean_text_metadata(
    text: str,
    citation_numbers: dict[str, str] | None = None,
    section_reference_numbers: dict[str, str] | None = None,
) -> tuple[str, list[TextStyleSpan], list[ReferenceSpan]]:
    style_markers: list[dict[str, bool]] = []
    citation_markers: list[str] = []
    reference_markers: list[str] = []
    cleaned = text.replace("~", " ")
    cleaned = re.sub(r"\\(?:maketitle|begin\{abstract\}|end\{abstract\})", " ", cleaned)
    cleaned = _mark_text_style_commands(cleaned, style_markers)
    cleaned = _replace_citations(cleaned, citation_numbers or {}, citation_markers)
    cleaned = _replace_references(
        cleaned,
        reference_markers,
        section_reference_numbers or {},
    )
    cleaned = _replace_inline_math(cleaned)
    cleaned = re.sub(r"\\\\(?:\[[^\]]+\])?", f" {LINE_BREAK_MARKER} ", cleaned)
    cleaned = re.sub(
        r"\\(?:newline|linebreak|par)\b(?:\[[^\]]+\])?",
        f" {LINE_BREAK_MARKER} ",
        cleaned,
    )
    cleaned = re.sub(r"\\label\{[^}]+\}", " ", cleaned)
    cleaned = re.sub(r"\\[a-zA-Z]+\*?(?:\[[^\]]+\])?\{([^{}]*)\}", r"\1", cleaned)
    cleaned = re.sub(r"\\[a-zA-Z]+\*?", " ", cleaned)
    cleaned = cleaned.replace("{", "").replace("}", "")
    cleaned = _normalize_text_whitespace(cleaned)
    return _extract_marked_text_spans(
        cleaned,
        style_markers,
        citation_markers,
        reference_markers,
    )


def _mark_text_style_commands(text: str, markers: list[dict[str, bool]]) -> str:
    command_styles = {
        "textbf": {"bold": True, "italic": False, "highlight": False},
        "textit": {"bold": False, "italic": True, "highlight": False},
        "emph": {"bold": False, "italic": True, "highlight": False},
        "hl": {"bold": False, "italic": False, "highlight": True},
    }

    changed = True
    while changed:
        changed = False
        for command, style in command_styles.items():
            pattern = re.compile(rf"\\{command}\{{(?P<value>[^{{}}]*)\}}")

            def replace(match: re.Match[str], style: dict[str, bool] = style) -> str:
                nonlocal changed
                changed = True
                marker_id = len(markers)
                markers.append(style)
                return (
                    f"@@STYLE_{marker_id}_START@@"
                    f"{match.group('value')}"
                    f"@@STYLE_{marker_id}_END@@"
                )

            text = pattern.sub(replace, text)

        colorbox_pattern = re.compile(
            r"\\colorbox\{[^{}]*\}\{(?P<value>[^{}]*)\}"
        )

        def replace_colorbox(match: re.Match[str]) -> str:
            nonlocal changed
            changed = True
            marker_id = len(markers)
            markers.append({"bold": False, "italic": False, "highlight": True})
            return (
                f"@@STYLE_{marker_id}_START@@"
                f"{match.group('value')}"
                f"@@STYLE_{marker_id}_END@@"
            )

        text = colorbox_pattern.sub(replace_colorbox, text)

    return text


def _replace_citations(
    text: str,
    citation_numbers: dict[str, str],
    markers: list[str],
) -> str:
    citation_commands = (
        "cite",
        "citep",
        "citet",
        "citealp",
        "citealt",
        "citeauthor",
        "citeyear",
        "citeyearpar",
    )
    pattern = re.compile(
        rf"\\(?:{'|'.join(citation_commands)})(?:\[[^\]]*\]){{0,2}}\{{(?P<keys>[^}}]+)\}}"
    )

    def replace(match: re.Match[str]) -> str:
        keys = [key.strip() for key in match.group("keys").split(",") if key.strip()]
        labels = [citation_numbers.get(key, key) for key in keys]
        label = f"[{', '.join(labels)}]" if labels else ""
        if not label:
            return ""
        marker_id = len(markers)
        markers.append(label)
        return f"@@CITE_{marker_id}_START@@{label}@@CITE_{marker_id}_END@@"

    return pattern.sub(replace, text)


def _normalize_text_whitespace(text: str) -> str:
    text = re.sub(r"\s+", " ", text)
    text = text.replace(f" {LINE_BREAK_MARKER} ", "\n")
    text = text.replace(LINE_BREAK_MARKER, "\n")
    text = re.sub(r" *\n *", "\n", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def _extract_marked_text_spans(
    text: str,
    style_markers: list[dict[str, bool]],
    citation_markers: list[str],
    reference_markers: list[str],
) -> tuple[str, list[TextStyleSpan], list[ReferenceSpan]]:
    token_pattern = re.compile(
        r"@@(?P<kind>STYLE|CITE|REF)_(?P<index>\d+)_(?P<edge>START|END)@@"
    )
    output: list[str] = []
    style_starts: dict[int, int] = {}
    citation_starts: dict[int, int] = {}
    reference_starts: dict[int, int] = {}
    text_spans: list[TextStyleSpan] = []
    reference_spans: list[ReferenceSpan] = []
    cursor = 0
    output_length = 0

    for match in token_pattern.finditer(text):
        literal = text[cursor : match.start()]
        output.append(literal)
        output_length += len(literal)

        index = int(match.group("index"))
        edge = match.group("edge")
        if match.group("kind") == "STYLE":
            if edge == "START":
                style_starts[index] = output_length
            else:
                start = style_starts.pop(index, output_length)
                if output_length > start:
                    flags = style_markers[index]
                    text_spans.append(
                        TextStyleSpan(
                            start=start,
                            end=output_length,
                            bold=flags["bold"],
                            italic=flags["italic"],
                            highlight=flags["highlight"],
                        )
                    )
        elif match.group("kind") == "CITE" and edge == "START":
            citation_starts[index] = output_length
        elif match.group("kind") == "CITE":
            start = citation_starts.pop(index, output_length)
            if output_length > start:
                reference_spans.append(
                    ReferenceSpan(
                        start=start,
                        end=output_length,
                        targetAssetId="",
                        kind=ReferenceKind.citation,
                        label=citation_markers[index],
                    )
                )
        elif edge == "START":
            reference_starts[index] = output_length
        else:
            start = reference_starts.pop(index, output_length)
            if output_length > start:
                reference_spans.append(
                    ReferenceSpan(
                        start=start,
                        end=output_length,
                        targetAssetId="",
                        kind=ReferenceKind.reference,
                        label=reference_markers[index],
                    )
                )
        cursor = match.end()

    literal = text[cursor:]
    output.append(literal)
    output_text = "".join(output)
    return output_text, text_spans, reference_spans


def _replace_references(
    text: str,
    markers: list[str],
    section_reference_numbers: dict[str, str],
) -> str:
    pattern = re.compile(
        r"\\(?P<command>eqref|labelcref|cref|Cref|autoref|Autoref|ref|Ref|vref|Vref|pageref|nameref)\*?(?:\[[^\]]*\])?\{(?P<labels>[^}]+)\}"
    )

    def replace(match: re.Match[str]) -> str:
        command = match.group("command")
        labels: list[str] = []
        preceding_text = text[: match.start()]
        for label in match.group("labels").split(","):
            label = label.strip()
            if not label:
                continue
            display, marker_label = _human_readable_reference_label(
                command,
                label,
                preceding_text,
                section_reference_numbers,
            )
            if marker_label is None:
                labels.append(display)
                continue
            marker_id = len(markers)
            markers.append(marker_label)
            labels.append(f"@@REF_{marker_id}_START@@{display}@@REF_{marker_id}_END@@")
        return ", ".join(labels)

    return pattern.sub(replace, text)


def _human_readable_reference_label(
    command: str,
    label: str,
    preceding_text: str,
    section_reference_numbers: dict[str, str],
) -> tuple[str, str | None]:
    prefix_name, cleaned_body = _reference_type_and_body(command, label)
    if label in section_reference_numbers:
        prefix_name = "Section"
    if prefix_name == "Section":
        cleaned_body = (
            section_reference_numbers.get(label)
            or LEGACY_COMPILED_SECTION_NUMBERS.get(label.lower())
            or cleaned_body
        )
        include_prefix = not _preceded_by_reference_word(
            preceding_text,
            prefix_name,
        )
        display = f"{prefix_name} {cleaned_body}" if include_prefix else cleaned_body
        return display, None

    include_prefix = prefix_name is not None and not _preceded_by_reference_word(
        preceding_text,
        prefix_name,
    )
    display = f"{prefix_name} {cleaned_body}" if include_prefix else cleaned_body
    marker_label = f"{prefix_name}: {cleaned_body}" if prefix_name else cleaned_body
    return display, marker_label


def _reference_type_and_body(command: str, label: str) -> tuple[str | None, str]:
    prefix, body = _reference_label_prefix_and_body(label)
    cleaned_body = _humanize_reference_body(body or prefix)
    prefix_name = _reference_type_for_prefix(prefix)
    if command.lower() == "eqref":
        prefix_name = "Equation"
    if command.lower() == "pageref":
        prefix_name = "Page"
    return prefix_name, cleaned_body


def _reference_label_prefix_and_body(label: str) -> tuple[str, str]:
    prefix, separator, body = label.partition(":")
    if separator:
        return prefix, body

    prefix, separator, body = label.partition(".")
    if separator and body and _reference_type_for_prefix(prefix) is not None:
        return prefix, body

    return label, ""


def _reference_type_for_prefix(prefix: str) -> str | None:
    normalized = _humanize_reference_body(prefix).lower()
    first_word = normalized.split(" ", 1)[0] if normalized else ""
    return {
        "alg": "Algorithm",
        "algorithm": "Algorithm",
        "eq": "Equation",
        "equation": "Equation",
        "fig": "Figure",
        "figure": "Figure",
        "sec": "Section",
        "section": "Section",
        "sections": "Section",
        "tab": "Table",
        "table": "Table",
    }.get(first_word)


def _humanize_reference_body(value: str) -> str:
    value = value.replace("_", " ").replace("-", " ").strip()
    value = re.sub(r"(?<=[a-z0-9])(?=[A-Z])", " ", value)
    value = re.sub(r"(?<=[A-Z])(?=[A-Z][a-z]{2,})", " ", value)
    return re.sub(r"\s+", " ", value).strip()


def _preceded_by_reference_word(text: str, prefix_name: str) -> bool:
    aliases = {
        "Algorithm": r"(algorithm|alg\.?)",
        "Equation": r"(equation|eq\.?)",
        "Figure": r"(figure|fig\.?)",
        "Page": r"(page|p\.?)",
        "Section": r"(section|sections|sec\.?)",
        "Table": r"(table|tab\.?)",
    }.get(prefix_name)
    if aliases is None:
        return False
    tail = re.sub(r"[\s~]+", " ", text[-80:]).rstrip()
    return re.search(rf"(?i){aliases}$", tail) is not None


def _replace_inline_math(text: str) -> str:
    text = re.sub(
        r"\\\((?P<value>.*?)\\\)",
        lambda match: _inline_math_text(match.group("value")),
        text,
        flags=re.DOTALL,
    )
    return re.sub(
        r"(?<!\\)\$(?!\$)(?P<value>.*?)(?<!\\)\$",
        lambda match: _inline_math_text(match.group("value")),
        text,
        flags=re.DOTALL,
    )


def _inline_math_text(text: str) -> str:
    return latex_to_readable_math_text(text)


def _normalize_display_latex(text: str) -> str:
    normalized = text.strip()
    normalized = re.sub(r"\\(?:label|tag)\{[^}]*\}", " ", normalized)
    normalized = re.sub(r"\\(?:notag|nonumber)\b", " ", normalized)
    normalized = re.sub(
        r"\\(?:big|Big|bigg|Bigg|bigl|bigr|Bigl|Bigr|biggl|biggr|Biggl|Biggr)",
        "",
        normalized,
    )
    normalized = normalized.replace(r"\eqqcolon", ":=")
    normalized = normalized.replace(r"\coloneqq", ":=")
    normalized = normalized.replace(r"\defeq", ":=")
    normalized = normalized.replace(r"\grad", r"\nabla")
    normalized = normalized.replace(r"\pdata", r"p_{\mathrm{data}}")
    normalized = re.sub(r"\\E(?![a-zA-Z])", r"\\mathbb{E}", normalized)
    normalized = re.sub(r"\\Var(?![a-zA-Z])", r"\\mathrm{Var}", normalized)
    normalized = re.sub(r"\\Cov(?![a-zA-Z])", r"\\mathrm{Cov}", normalized)
    normalized = _replace_latex_macro_args(
        normalized,
        "Ea",
        1,
        lambda args: rf"\mathbb{{E}}\left[{args[0]}\right]",
    )
    normalized = _replace_latex_macro_args(
        normalized,
        "Eb",
        2,
        lambda args: rf"\mathbb{{E}}_{{{args[0]}}}\left[{args[1]}\right]",
    )
    normalized = _replace_latex_macro_args(
        normalized,
        "Vara",
        1,
        lambda args: rf"\mathrm{{Var}}\left[{args[0]}\right]",
    )
    normalized = _replace_latex_macro_args(
        normalized,
        "Varb",
        2,
        lambda args: rf"\mathrm{{Var}}_{{{args[0]}}}\left[{args[1]}\right]",
    )
    normalized = _replace_latex_macro_args(
        normalized,
        "kl",
        2,
        lambda args: rf"D_{{\mathrm{{KL}}}}\left({args[0]} \| {args[1]}\right)",
    )
    normalized = _replace_latex_bold_macros(normalized)
    normalized = _wrap_accented_latex_macros(normalized)
    return re.sub(r"\s+", " ", normalized).strip()


def _replace_latex_macro_args(
    text: str,
    macro: str,
    arg_count: int,
    render: Callable[[list[str]], str],
) -> str:
    needle = "\\" + macro
    result: list[str] = []
    offset = 0
    while True:
        index = text.find(needle, offset)
        if index < 0:
            result.append(text[offset:])
            return "".join(result)
        next_index = index + len(needle)
        if next_index < len(text) and text[next_index].isalpha():
            result.append(text[offset : next_index])
            offset = next_index
            continue
        args: list[str] = []
        cursor = next_index
        for _ in range(arg_count):
            while cursor < len(text) and text[cursor].isspace():
                cursor += 1
            parsed = _read_balanced_latex_group(text, cursor)
            if parsed is None:
                break
            value, cursor = parsed
            args.append(value)
        if len(args) != arg_count:
            result.append(text[offset : next_index])
            offset = next_index
            continue
        result.append(text[offset:index])
        result.append(render(args))
        offset = cursor


def _read_balanced_latex_group(text: str, start: int) -> tuple[str, int] | None:
    if start >= len(text) or text[start] != "{":
        return None
    depth = 0
    for index in range(start, len(text)):
        char = text[index]
        if char == "{" and (index == 0 or text[index - 1] != "\\"):
            depth += 1
        elif char == "}" and (index == 0 or text[index - 1] != "\\"):
            depth -= 1
            if depth == 0:
                return text[start + 1 : index], index + 1
    return None


def _replace_latex_bold_macros(text: str) -> str:
    replacements = {
        "bzero": r"\mathbf{0}",
        "bone": r"\mathbf{1}",
        "btheta": r"\boldsymbol{\theta}",
        "bphi": r"\boldsymbol{\phi}",
        "bepsilon": r"\boldsymbol{\epsilon}",
        "bmu": r"\boldsymbol{\mu}",
        "bnu": r"\boldsymbol{\nu}",
        "bSigma": r"\boldsymbol{\Sigma}",
        "bxh": r"\hat{\mathbf{x}}",
    }
    for source, target in sorted(replacements.items(), key=lambda item: -len(item[0])):
        text = re.sub(
            rf"\\{source}(?![a-zA-Z])",
            lambda _match, replacement=target: replacement,
            text,
        )
    text = re.sub(
        r"\\b([A-Z])(?![a-zA-Z])",
        lambda match: rf"\mathbf{{{match.group(1)}}}",
        text,
    )
    text = re.sub(
        r"\\b([a-z])(?![a-zA-Z])",
        lambda match: rf"\mathbf{{{match.group(1)}}}",
        text,
    )
    return text


def _wrap_accented_latex_macros(text: str) -> str:
    accent_commands = (
        "bar",
        "hat",
        "tilde",
        "vec",
        "dot",
        "ddot",
        "widehat",
        "widetilde",
    )
    styled_commands = ("boldsymbol", "mathbf", "mathrm", "mathcal", "mathbb")
    for accent in accent_commands:
        for styled in styled_commands:
            text = re.sub(
                rf"\\{accent}\\{styled}\{{([^{{}}]+)\}}",
                rf"\\{accent}{{\\{styled}{{\1}}}}",
                text,
            )
    return text

import re
from collections.abc import Callable
from datetime import UTC, datetime
from pathlib import Path

from services.converter.app.conversion.equation_renderer import (
    render_latex_equation_asset,
)
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
    blocks, assets = _attach_equation_assets(blocks, output_dir)

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
        assets=assets,
        anchors=[block.anchor for block in anchored if block.anchor is not None],
    )
    write_document_package(package, output_dir)
    return package


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
    cleaned = _replace_citations(cleaned)
    cleaned = _replace_references(cleaned)
    cleaned = _replace_inline_math(cleaned)
    cleaned = re.sub(r"\\label\{[^}]+\}", " ", cleaned)
    cleaned = re.sub(r"\\[a-zA-Z]+\*?(?:\[[^\]]+\])?\{([^{}]*)\}", r"\1", cleaned)
    cleaned = re.sub(r"\\[a-zA-Z]+\*?", " ", cleaned)
    cleaned = cleaned.replace("{", "").replace("}", "")
    return re.sub(r"\s+", " ", cleaned).strip()


def _replace_citations(text: str) -> str:
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
        return f"[{', '.join(keys)}]" if keys else ""

    return pattern.sub(replace, text)


def _replace_references(text: str) -> str:
    pattern = re.compile(
        r"\\(?P<command>eqref|labelcref|cref|Cref|autoref|ref)(?:\[[^\]]*\])?\{(?P<labels>[^}]+)\}"
    )

    def replace(match: re.Match[str]) -> str:
        command = match.group("command")
        labels = [
            _human_readable_reference_label(command, label.strip())
            for label in match.group("labels").split(",")
            if label.strip()
        ]
        return ", ".join(labels)

    return pattern.sub(replace, text)


def _human_readable_reference_label(command: str, label: str) -> str:
    prefix, _, body = label.partition(":")
    cleaned_body = (body or prefix).replace("_", " ").replace("-", " ").strip()
    prefix_name = {
        "alg": "Algorithm",
        "algorithm": "Algorithm",
        "eq": "Equation",
        "equation": "Equation",
        "fig": "Figure",
        "figure": "Figure",
        "sec": "Section",
        "section": "Section",
        "tab": "Table",
        "table": "Table",
    }.get(prefix.lower())
    if command == "eqref":
        prefix_name = "Equation"
    return f"{prefix_name} {cleaned_body}" if prefix_name else cleaned_body


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
    cleaned = text.strip()
    cleaned = cleaned.replace(r"\,", " ")
    cleaned = cleaned.replace(r"\;", " ")
    cleaned = cleaned.replace(r"\!", "")
    cleaned = re.sub(r"\\(?:left|right|big|Big|bigl|bigr|Bigl|Bigr)", "", cleaned)

    for _ in range(4):
        cleaned = re.sub(r"\\frac\{([^{}]+)\}\{([^{}]+)\}", r"(\1)/(\2)", cleaned)
        cleaned = re.sub(r"\\sqrt\{([^{}]+)\}", r"sqrt(\1)", cleaned)
        cleaned = re.sub(
            r"\\(?:mathrm|mathbf|mathcal|mathbb|text|operatorname)\{([^{}]+)\}",
            r"\1",
            cleaned,
        )
        cleaned = re.sub(r"\\bar\{\\?([a-zA-Z]+)\}", r"\1_bar", cleaned)
        cleaned = re.sub(r"\\bar\s*\\([a-zA-Z]+)", r"\1_bar", cleaned)
        cleaned = re.sub(
            r"_\{([^{}]+)\}",
            lambda match: f"_{_script_text(match.group(1))}",
            cleaned,
        )
        cleaned = re.sub(
            r"\^\{([^{}]+)\}",
            lambda match: f"^{_script_text(match.group(1))}",
            cleaned,
        )

    replacements = {
        r"\bSigma": "Sigma",
        r"\btheta": "theta",
        r"\balpha": "alpha",
        r"\bbeta": "beta",
        r"\bepsilon": "epsilon",
        r"\bmu": "mu",
        r"\bzero": "0",
        r"\bI": "I",
        r"\bx": "x",
        r"\alpha": "alpha",
        r"\beta": "beta",
        r"\theta": "theta",
        r"\epsilon": "epsilon",
        r"\varepsilon": "epsilon",
        r"\mu": "mu",
        r"\sigma": "sigma",
        r"\Sigma": "Sigma",
        r"\mathcal": "",
        r"\mathbb": "",
        r"\defeq": ":=",
        r"\prod": "prod",
        r"\sum": "sum",
        r"\log": "log",
        r"\mid": "|",
        r"\vert": "|",
        r"\lVert": "||",
        r"\rVert": "||",
        r"\times": "x",
        r"\cdot": "*",
        r"\sim": "~",
        r"\leq": "<=",
        r"\geq": ">=",
        r"\neq": "!=",
        r"\dotsc": "...",
        r"\dots": "...",
    }
    for source, target in sorted(replacements.items(), key=lambda item: -len(item[0])):
        cleaned = cleaned.replace(source, target)

    cleaned = re.sub(
        r"\\([a-zA-Z]+)\*?",
        lambda match: match.group(1)[1:] if match.group(1).startswith("b") else match.group(1),
        cleaned,
    )
    cleaned = cleaned.replace(r"\{", "{").replace(r"\}", "}")
    cleaned = cleaned.replace("{", "").replace("}", "")
    cleaned = re.sub(r"\s+", " ", cleaned).strip()
    cleaned = re.sub(r"\s*([_=+\-/:<>|])\s*", r"\1", cleaned)
    cleaned = re.sub(r"\s*([(),;])\s*", r"\1", cleaned)
    return cleaned


def _script_text(text: str) -> str:
    compact = text.strip()
    if len(compact) > 1 and re.search(r"[=+\-/*, ]", compact):
        return f"({compact})"
    return compact


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

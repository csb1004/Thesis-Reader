# arXiv LaTeX Source Conversion Design

## Goal

Improve equation, table, and structured-paper readability by using arXiv LaTeX source as the primary conversion input when it is available, while keeping the current PDF-based image-preserving converter as the automatic fallback.

The current PDF converter is useful for arbitrary PDFs, but PDF text extraction does not preserve the source semantics for equations, superscripts, tables, or reading order. That is why DDPM equations can become fragments such as `LT`, `L0`, `l{z}`, or body text mixed with cropped equation images. For arXiv papers, the LaTeX source is the best available representation and should be used before trying to infer structure from a rendered PDF.

## Requirements

- Imported PDFs still work as the user-facing entry point.
- If an arXiv ID can be detected, the server attempts a source-first conversion.
- Source-first conversion preserves section structure, paragraphs, display equations, inline math, references, figures, and tables more accurately than PDF text extraction.
- If source retrieval, unpacking, parsing, or rendering fails, conversion automatically falls back to the existing PDF converter.
- The document package records which conversion mode was used and why fallback happened, if applicable.
- The app exposes this as the default high-quality mode, without requiring a paid external API.

## Non-Goals

- Perfect conversion for every non-arXiv PDF.
- Full TeX package compatibility in the first implementation.
- Replacing the existing PDF fallback pipeline.
- Making every rendered equation fully selectable in the first implementation.

## Source Resolution

The converter should accept the same PDF upload request it accepts today. Before PDF-only conversion starts, it attempts to resolve an arXiv ID from:

- The uploaded filename, such as `2501.12345.pdf` or `arxiv-2501.12345v2.pdf`.
- The first page text, looking for arXiv-style identifiers.
- PDF metadata, when available.

Later, the app can add a manual `arXiv ID` field for renamed PDFs, but the first version can remain automatic.

When an ID is found, the converter downloads the source bundle from arXiv and stores source diagnostics in the conversion result. Network access is server-side only. Tests should use local fixtures rather than live arXiv requests.

## Source Unpack and Main File Detection

The source resolver must handle common arXiv source shapes:

- A single `.tex` file.
- `.tar`, `.tar.gz`, `.tgz`, or gzipped source files.
- Nested folders with figures, `.bib`, and multiple `.tex` files.

Main file detection should prefer files with `\documentclass`, then files that include `\begin{document}`, then the largest plausible root file. The chosen root and any unresolved includes should be recorded in diagnostics.

## LaTeX Normalization

The converter should build a normalized source document before extraction:

- Expand simple `\input{...}` and `\include{...}` references.
- Collect common macro definitions from `\newcommand`, `\renewcommand`, and `\def`.
- Preserve unsupported macros in the LaTeX payload instead of guessing a lossy text representation.
- Strip preamble content that should not become reader body text.

The important rule is to avoid degrading math into plain text when the source math is available.

## Structured Extraction

The source-first extractor should produce the same broad package shape as the current reader package, with minimal schema extensions.

Extracted blocks:

- `heading`: `\section`, `\subsection`, and similar commands.
- `paragraph`: prose with inline spans.
- `equation`: display math from `equation`, `align`, `gather`, `multline`, `\[...\]`, and `$$...$$`.
- `figure`: source figure references when available, with PDF crop fallback when needed.
- `table`: LaTeX table blocks rendered as structured table assets or preserved image assets.
- `reference`: bibliography entries, separated one entry per block.

Inline references such as `[11, 55]` remain styled as reference spans. Tapping them should continue to show the matching bibliography entry when available.

## Math Rendering Strategy

The package should preserve the original LaTeX for math blocks:

- Add optional `latex` to equation blocks.
- Add optional inline math spans for paragraph content.
- Keep `assetId` as a fallback render target.

Rendering order:

1. Prefer source LaTeX rendering.
2. If the app renderer cannot handle a specific formula, use a server-rendered SVG or PNG for that formula.
3. If source conversion fails entirely, use the existing PDF image-preserving converter.

This avoids making TeX Live a hard dependency on Railway in the first pass. A Flutter-compatible renderer or MathJax/KaTeX-based rendering should be evaluated first because it is lighter than a full TeX installation. If those renderers fail on real DDPM formulas, server-rendered SVG becomes the next fallback because it scales better than clipped bitmap crops.

## Figure and Table Handling

Figures and tables should not be emitted twice. When a source figure or table block is emitted, overlapping PDF-derived text or image fragments for the same region should be suppressed.

Tables need special handling because plain PDF text extraction loses columns. Source-first conversion should:

- Preserve `tabular` and `table` environments as table blocks.
- Prefer source-level table rendering over flattened text.
- Fall back to a rendered table image when structured table extraction is too complex.

This is especially important for papers such as Attention Is All You Need, where tables become unreadable when columns are flattened.

## Package Schema Extensions

Extend existing document package blocks conservatively:

```json
{
  "kind": "equation",
  "text": "optional accessible fallback",
  "latex": "\\\\mathcal{L}_{t-1} = ...",
  "assetId": "optional-rendered-fallback",
  "source": {
    "mode": "latex",
    "environment": "align",
    "label": "eq:loss"
  }
}
```

At the package level, add:

```json
{
  "conversionMode": "latex-source",
  "fallbackReason": null,
  "sourceInfo": {
    "arxivId": "2006.11239",
    "mainTex": "main.tex"
  }
}
```

Allowed conversion modes:

- `latex-source`
- `pdf-layout`
- `pdf-fallback`

## App UX

The default conversion option should be renamed or described as high quality in Korean UI copy:

- High-quality conversion: arXiv source first, PDF fallback.
- PDF conversion: current PDF image-preserving path.

Document detail or conversion status should show the active mode in Korean. If fallback happened, the app should show a short Korean reason meaning: `Could not find arXiv source, so PDF conversion was used`.

Manual reconversion should reuse the selected conversion mode so users can retry after entering an arXiv ID later.

## Testing

Server tests:

- Detect arXiv IDs from filenames, metadata-like strings, and first-page text fixtures.
- Unpack `.tex`, `.tar.gz`, and nested source fixtures.
- Choose the correct main `.tex` file.
- Extract headings, paragraphs, display equations, inline math, figures, tables, and references from a small fixture.
- Verify source conversion failure falls back to the existing PDF converter.
- Verify duplicate figure/equation/table blocks are not emitted when source blocks are used.

App tests:

- Render equation blocks from `latex` or fallback `assetId`.
- Keep page layout stable when equation assets are wider than text.
- Show conversion mode and fallback reason.
- Preserve existing reader navigation, settings, vocabulary, translation, summary, and reference popup behavior.

Manual smoke tests:

- Attention Is All You Need: equations, tables, figures, and references should be readable.
- Denoising Diffusion Probabilistic Models: multi-line equations should not degrade into text fragments such as `LT`, `L0`, or `l{z}`.

## Risks

- arXiv source packages vary widely and can include unsupported TeX macros.
- Client-side math renderers may not support every formula or macro.
- Server-rendered SVG fallback adds implementation complexity, but is preferable to clipped bitmap crops when formula fidelity matters.
- Some PDFs will not expose an arXiv ID. Those documents will still use the current PDF fallback unless the app later adds manual ID entry.

## Recommended First Slice

1. Add source-resolution diagnostics and `conversionMode` metadata.
2. Implement arXiv source download, unpacking, and main `.tex` detection behind the existing conversion endpoint.
3. Add a minimal LaTeX extractor for headings, paragraphs, display equations, references, figures, and tables.
4. Extend the package schema to carry `latex` equation payloads.
5. Add app rendering for equation blocks with a fallback to image assets.
6. Keep the current PDF converter as automatic fallback.
7. Reconvert and inspect DDPM and Attention Is All You Need before shipping.

## Approval Gate

This design should be reviewed before implementation. Once approved, the next step is a concrete implementation plan with file-level tasks and verification commands.

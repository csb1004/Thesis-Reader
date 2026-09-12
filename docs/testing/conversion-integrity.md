# Conversion Integrity

Converter `mvp-3` and Android `1.0.10+11` address the cross-document conversion audit.

## Data Contract

- Newly written packages declare `sourceInfo.offsetEncoding = "utf-16"` and `sourceInfo.textNormalized = true`.
- Text is finalized before reference/style offsets are exported. Flutter preserves that text, including explicit TeX line breaks.
- Cached `mvp-1`/`mvp-2` Python offsets are converted from code points to UTF-16 on load. Text with spans is not rewritten independently of those spans.
- Rewriting a package must not convert UTF-16 offsets a second time.
- References are accepted only when the visible text agrees with their label. PDF visual links require an extracted target, with ambiguous duplicate labels left unlinked.

## Conversion Checks

- arXiv identifiers must come from a complete filename or a standalone arXiv classification stamp, not an incidental citation. Conflicting identifiers are rejected.
- Downloaded TeX must match the uploaded PDF title vocabulary and body word pairs. Unverifiable sources fall back to the uploaded PDF.
- Nested includes are expanded recursively, with missing files and cycles reported instead of silently dropping content.
- Basic user-defined TeX commands are expanded before math conversion. A failed equation render is not published as a pseudo-equation PNG in the upload workflow.
- TeX figures/tables that cannot be faithfully exported trigger PDF extraction. The fallback reason is retained in the package.
- Two-column prose is ordered by column, with spanning lines separating reading bands. Regions from different columns are not merged.
- Figure crops use actual image/vector geometry associated with a caption. A sentence mentioning a figure does not become a crop target.
- Each equation/visual region has its own asset ID, even when equation numbering restarts.

## Automated Checks

```powershell
services/converter/.venv/Scripts/python -m pytest services/converter/tests -q
```

```powershell
cd apps/thesis_reader
flutter analyze
flutter test
flutter build apk --release
```

Regression cases cover two-column ordering, nested includes/cycles, arXiv misidentification, UTF-16 offsets, repeated serialization, custom math commands, source identity, failed rendering, figure crop dimensions, repeated equation numbers, and text/link preservation through package loading.

## Deployment And Reimport

Deploy the converter and install the new APK together. Previously converted packages keep their old extracted content and images: reimport the original PDF to regenerate them. APK installation alone cannot reconstruct text already lost during server conversion.

Check real papers on Android in both page and scroll modes. Complex multi-column layouts, scans, unusual TeX packages, and unsupported source structures may still require original-PDF fallback; automated synthetic fixtures do not establish universal layout fidelity.

## TU Delft Survey Regression

PDF converter `mvp-4` and Android `1.0.11+12` additionally preserve font-detected chapters/subsections, indented paragraphs, multiline headings, and dotted visual numbers. Printed contents pages do not create duplicate outline entries. Running headers are filtered. Dedicated mathematical text blocks around numbered equations are cropped together, excluding footer page numbers; inline sums remain with their paragraph. Numeric interval links are disabled when no numbered bibliography exists. Pagination and rendering share heading styles.

The user-supplied 122-page survey is deliberately not redistributed in this repository. To run its complete-document regression after downloading it locally:

```powershell
$env:THESIS_SURVEY_PDF = 'C:/path/to/2200000086.pdf'
services/converter/.venv/Scripts/python -m pytest services/converter/tests -q
```

The test checks 37 outline groups (including front matter), the subsection destination on physical page 16, the three paragraphs and single equation on physical page 10, and absence of spurious numeric links there. Equation `(2.1)` was also visually compared with its original page. These checks do not replace physical Android testing or exhaustive visual review of every page.

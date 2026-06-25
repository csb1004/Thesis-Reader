from types import SimpleNamespace

import fitz

from services.converter.app.conversion import pdf_converter
from services.converter.app.conversion.pdf_converter import convert_pdf_to_package
from services.converter.app.models.document_package import AssetKind, BlockKind, ReferenceKind
from services.converter.app.models.document_package import DocumentAsset
from services.converter.tests.fixtures import (
    write_bleu_table_with_caption_gap_pdf,
    write_complexity_table_pdf,
    write_numbered_table_region_pdf,
    write_attention_equation_pdf,
    write_attention_equation_with_following_prose_pdf,
    write_hyphenated_line_pdf,
    write_simple_paper_pdf,
    write_unlabeled_equation_pdf,
    write_wrapped_paragraph_pdf,
)


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
    assert package.assets
    for asset in package.assets:
        assert asset.relativePath.endswith(".png")
        assert (output_dir / asset.relativePath).is_file()


def test_merges_wrapped_pdf_lines_into_paragraphs(tmp_path):
    pdf_path = write_wrapped_paragraph_pdf(tmp_path / "wrapped.pdf")
    output_dir = tmp_path / "out"
    package = convert_pdf_to_package(
        pdf_path=pdf_path,
        output_dir=output_dir,
        document_id="doc-1",
    )

    texts = [block.text for block in package.blocks if block.text]

    assert (
        "The dominant sequence transduction models are based on complex recurrent "
        "or convolutional neural networks that include an encoder and a decoder."
    ) in texts
    assert "A new paragraph starts after a visual gap." in texts
    assert "The dominant sequence transduction models" not in texts


def test_joins_hyphenated_line_breaks_inside_words(tmp_path):
    pdf_path = write_hyphenated_line_pdf(tmp_path / "hyphenated.pdf")
    output_dir = tmp_path / "out"
    package = convert_pdf_to_package(
        pdf_path=pdf_path,
        output_dir=output_dir,
        document_id="doc-1",
    )

    text = " ".join(block.text or "" for block in package.blocks)

    assert "transduction models" in text
    assert "transduc-" not in text


def test_exports_attention_equation_as_image_asset(tmp_path):
    pdf_path = write_attention_equation_pdf(tmp_path / "equation.pdf")
    output_dir = tmp_path / "out"
    package = convert_pdf_to_package(
        pdf_path=pdf_path,
        output_dir=output_dir,
        document_id="doc-1",
    )

    text = " ".join(block.text or "" for block in package.blocks)
    equation_blocks = [
        block for block in package.blocks if block.kind == BlockKind.equation
    ]
    equation_assets = [
        asset for asset in package.assets if asset.kind == AssetKind.equation
    ]

    assert equation_blocks
    assert len(equation_blocks) == 1
    assert equation_assets
    assert equation_blocks[0].assetId == equation_assets[0].id
    assert (output_dir / equation_assets[0].relativePath).is_file()
    assert "Attention(Q, K, V)" not in text
    assert "QKT" not in text


def test_keeps_following_prose_out_of_attention_equation_asset(tmp_path):
    pdf_path = write_attention_equation_with_following_prose_pdf(
        tmp_path / "equation-with-prose.pdf"
    )
    output_dir = tmp_path / "out"
    package = convert_pdf_to_package(
        pdf_path=pdf_path,
        output_dir=output_dir,
        document_id="doc-1",
    )

    text = " ".join(block.text or "" for block in package.blocks)
    equation_blocks = [
        block for block in package.blocks if block.kind == BlockKind.equation
    ]
    equation_assets = [
        asset for asset in package.assets if asset.kind == AssetKind.equation
    ]

    assert len(equation_blocks) == 1
    assert len(equation_assets) == 1
    assert "Attention(Q, K, V)" not in text
    assert "QKT" not in text
    assert "√dk" not in text
    assert "The two most commonly used attention functions" in text
    assert "dot-product (multiplicative) attention" in text


def test_keeps_inline_math_fragments_inside_paragraphs():
    lines = [
        {
            "text": "To counteract this effect, we scale the dot products by",
            "page": 1,
            "rect": [72.0, 100.0, 504.0, 120.0],
        },
        {
            "text": "√dk .",
            "page": 1,
            "rect": [440.0, 112.0, 460.0, 132.0],
        },
    ]

    paragraphs = pdf_converter._merge_lines_into_paragraphs(lines)

    assert all(
        paragraph.get("kind") != BlockKind.equation for paragraph in paragraphs
    )
    assert paragraphs[0]["text"] == (
        "To counteract this effect, we scale the dot products by √dk."
    )


def test_keeps_inline_equations_inside_prose_sentences():
    lines = [
        {
            "text": "During training, we employed label smoothing of value ϵls = 0.1 [36]. This",
            "page": 1,
            "rect": [72.0, 100.0, 504.0, 120.0],
        },
        {
            "text": "hurts perplexity, but improves accuracy and BLEU score.",
            "page": 1,
            "rect": [72.0, 116.0, 504.0, 136.0],
        },
    ]

    paragraphs = pdf_converter._merge_lines_into_paragraphs(lines)

    assert all(
        paragraph.get("kind") != BlockKind.equation for paragraph in paragraphs
    )
    assert paragraphs[0]["text"] == (
        "During training, we employed label smoothing of value ϵls = 0.1 [36]. "
        "This hurts perplexity, but improves accuracy and BLEU score."
    )


def test_keeps_tiny_table_math_fragments_out_of_equation_blocks():
    lines = [
        {
            "text": "Training Cost (FLOPs)",
            "page": 1,
            "rect": [72.0, 100.0, 200.0, 120.0],
        },
        {
            "text": "×106",
            "page": 1,
            "rect": [210.0, 100.0, 240.0, 120.0],
        },
    ]

    paragraphs = pdf_converter._merge_lines_into_paragraphs(lines)

    assert all(
        paragraph.get("kind") != BlockKind.equation for paragraph in paragraphs
    )


def test_restores_inline_superscripts_and_subscripts_from_pdf_spans(tmp_path):
    pdf_path = write_complexity_table_pdf(tmp_path / "complexity.pdf")
    output_dir = tmp_path / "out"
    package = convert_pdf_to_package(
        pdf_path=pdf_path,
        output_dir=output_dir,
        document_id="doc-1",
    )

    text = " ".join(block.text or "" for block in package.blocks)

    assert "O(n² · d)" in text
    assert "O(n · d²)" in text
    assert "dₖ" in text
    assert "n2" not in text
    assert "d2" not in text


def test_does_not_link_complexity_notation_as_equation_reference(tmp_path):
    pdf_path = write_complexity_table_pdf(tmp_path / "complexity.pdf")
    output_dir = tmp_path / "out"
    package = convert_pdf_to_package(
        pdf_path=pdf_path,
        output_dir=output_dir,
        document_id="doc-1",
    )

    complexity_blocks = [
        block
        for block in package.blocks
        if block.text and "Self-Attention" in block.text
    ]

    assert complexity_blocks
    assert all(
        span.kind != ReferenceKind.equation
        for block in complexity_blocks
        for span in block.referenceSpans
    )


def test_links_equations_only_with_explicit_equation_context():
    asset = DocumentAsset(
        id="eq-1",
        kind=AssetKind.equation,
        label="(1)",
        relativePath="assets/eq-1.png",
    )

    spans = pdf_converter._reference_spans(
        "Equation (1) defines attention. Complexity is O(1). A citation 19(1) is not math.",
        {"(1)": asset},
    )

    assert len(spans) == 1
    assert spans[0].kind == ReferenceKind.equation
    assert spans[0].label == "(1)"


def test_preserves_numbered_table_regions_as_table_assets(tmp_path):
    pdf_path = write_numbered_table_region_pdf(tmp_path / "table.pdf")
    output_dir = tmp_path / "out"
    package = convert_pdf_to_package(
        pdf_path=pdf_path,
        output_dir=output_dir,
        document_id="doc-1",
    )

    table_blocks = [block for block in package.blocks if block.kind == BlockKind.table]
    table_assets = [asset for asset in package.assets if asset.kind == AssetKind.table]
    text = " ".join(block.text or "" for block in package.blocks)

    assert len(table_blocks) == 1
    assert len(table_assets) == 1
    assert table_blocks[0].assetId == table_assets[0].id
    assert (output_dir / table_assets[0].relativePath).is_file()
    assert "Self-Attention" not in text
    assert "O(1)" not in text
    assert "Positional Encoding" in text


def test_preserves_table_rows_after_caption_gap_as_table_asset(tmp_path):
    pdf_path = write_bleu_table_with_caption_gap_pdf(tmp_path / "bleu-table.pdf")
    output_dir = tmp_path / "out"
    package = convert_pdf_to_package(
        pdf_path=pdf_path,
        output_dir=output_dir,
        document_id="doc-1",
    )

    table_blocks = [block for block in package.blocks if block.kind == BlockKind.table]
    table_assets = [asset for asset in package.assets if asset.kind == AssetKind.table]
    text = " ".join(block.text or "" for block in package.blocks)

    assert len(table_blocks) == 1
    assert len(table_assets) == 1
    assert table_blocks[0].assetId == table_assets[0].id
    assert (output_dir / table_assets[0].relativePath).is_file()
    assert "ByteNet" not in text
    assert "EN-DE" not in text
    assert "Deep-Att" not in text
    assert "Transformer (big) outperforms previous ensembles." in text


def test_table_region_keeps_overlapping_header_rows_without_swallowing_prose():
    paragraphs = pdf_converter._merge_lines_into_paragraphs(
        [
            {
                "text": "Table 2: The Transformer achieves better BLEU scores than previous state-of-the-art models on the",
                "page": 8,
                "rect": [107.7, 69.5, 504.0, 81.6],
            },
            {
                "text": "English-to-German and English-to-French newstest2014 tests at a fraction of the training cost.",
                "page": 8,
                "rect": [108.0, 80.5, 483.5, 92.5],
            },
            {
                "text": "BLEUTraining Cost (FLOPs)",
                "page": 8,
                "rect": [311.0, 96.3, 475.3, 108.3],
            },
            {
                "text": "Model",
                "page": 8,
                "rect": [136.7, 104.6, 162.7, 116.6],
            },
            {
                "text": "EN-DEEN-FREN-DEEN-FR",
                "page": 8,
                "rect": [288.7, 112.2, 468.8, 124.2],
            },
            {
                "text": "ByteNet [18]23.75",
                "page": 8,
                "rect": [136.7, 123.5, 314.9, 135.5],
            },
            {
                "text": "Deep-Att + PosUnk [39]39.21.0 · 10²⁰",
                "page": 8,
                "rect": [136.7, 134.9, 473.1, 153.6],
            },
            {
                "text": "GNMT + RL [38]24.639.922.3 · 10¹⁹1.4 · 10²⁰",
                "page": 8,
                "rect": [136.7, 146.3, 473.1, 165.0],
            },
            {
                "text": "ConvS2S [9]25.1640.469.6 · 10¹⁸1.5 · 10²⁰",
                "page": 8,
                "rect": [136.7, 157.6, 473.1, 176.4],
            },
            {
                "text": "MoE [32]26.0340.562.0 · 10¹⁹1.2 · 10²⁰",
                "page": 8,
                "rect": [136.7, 169.0, 473.1, 187.8],
            },
            {
                "text": "Deep-Att + PosUnk Ensemble [39]40.48.0 · 10²⁰",
                "page": 8,
                "rect": [136.7, 181.7, 473.1, 200.4],
            },
            {
                "text": "GNMT + RL Ensemble [38]26.3041.161.8 · 10²⁰1.1 · 10²¹",
                "page": 8,
                "rect": [136.7, 193.0, 473.1, 211.8],
            },
            {
                "text": "ConvS2S Ensemble [9]26.3641.297.7 · 10¹⁹1.2 · 10²¹",
                "page": 8,
                "rect": [136.7, 204.1, 473.1, 223.2],
            },
            {
                "text": "Transformer (base model)27.338.13.3 · 10¹⁸",
                "page": 8,
                "rect": [136.7, 217.6, 450.7, 236.1],
            },
            {
                "text": "Transformer (big)28.441.82.3 · 10¹⁹",
                "page": 8,
                "rect": [136.7, 228.6, 448.0, 247.7],
            },
            {
                "text": "Residual DropoutWe apply dropout [33] to the output of each sub-layer.",
                "page": 8,
                "rect": [108.0, 271.3, 504.0, 284.3],
            },
        ]
    )

    table_regions = [
        paragraph for paragraph in paragraphs if paragraph.get("kind") == BlockKind.table
    ]
    plain_text = " ".join(
        paragraph["text"]
        for paragraph in paragraphs
        if paragraph.get("kind") != BlockKind.table
    )

    assert len(table_regions) == 1
    assert "ByteNet" in table_regions[0]["text"]
    assert "EN-DEEN-FR" in table_regions[0]["text"]
    assert "Residual Dropout" not in table_regions[0]["text"]
    assert "ByteNet" not in plain_text
    assert "EN-DEEN-FR" not in plain_text
    assert "Residual DropoutWe apply dropout" in plain_text


def test_unlabeled_equation_asset_uses_equation_clip_not_full_page(tmp_path):
    pdf_path = write_unlabeled_equation_pdf(tmp_path / "equation.pdf")
    output_dir = tmp_path / "out"
    package = convert_pdf_to_package(
        pdf_path=pdf_path,
        output_dir=output_dir,
        document_id="doc-1",
    )

    equation_asset = next(
        asset for asset in package.assets if asset.kind == AssetKind.equation
    )
    width, height = _png_dimensions(output_dir / equation_asset.relativePath)

    assert width < 900
    assert height < 220


def test_equation_clip_keeps_horizontal_padding_without_broad_vertical_crop():
    page = SimpleNamespace(rect=fitz.Rect(0, 0, 600, 800))
    line = {"rect": [72, 100, 320, 130]}
    asset = DocumentAsset(
        id="eq-1",
        kind=AssetKind.equation,
        label="Equation 1",
        relativePath="assets/eq-1.png",
    )

    clip = pdf_converter._asset_clip(page, line, asset)

    assert clip.x0 <= 40
    assert clip.x1 >= 368
    assert clip.y0 <= 92
    assert clip.y1 >= 138


def _png_dimensions(path):
    data = path.read_bytes()
    return int.from_bytes(data[16:20], "big"), int.from_bytes(data[20:24], "big")

from types import SimpleNamespace

import fitz

from services.converter.app.conversion import pdf_converter
from services.converter.app.conversion.pdf_converter import convert_pdf_to_package
from services.converter.app.models.document_package import AssetKind, BlockKind, ReferenceKind
from services.converter.app.models.document_package import DocumentAsset
from services.converter.tests.fixtures import (
    write_bleu_table_with_caption_gap_pdf,
    write_bottom_footer_noise_pdf,
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


def test_combines_pdf_spans_only_when_their_line_centers_match():
    lines = [
        _pdf_line([108.0, 534.7, 504.0, 555.0], "posterior q(x1:T |x0), called the forward process, is fixed to a chain that"),
        _pdf_line([108.0, 545.6, 454.6, 559.1], "gradually adds Gaussian noise according to a variance schedule beta1, ..., betaT:"),
    ]

    combined = pdf_converter._combine_inline_pdf_lines(lines)

    assert len(combined) == 2
    assert pdf_converter._line_text(combined[0]).startswith("posterior q")
    assert pdf_converter._line_text(combined[1]).startswith("gradually adds")


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


def test_table_region_keeps_compressed_architecture_rows_out_of_text():
    paragraphs = pdf_converter._merge_lines_into_paragraphs(
        [
            {
                "text": "Table 3: Variations on the Transformer architecture. Unlisted values are identical to those of the base",
                "page": 9,
                "rect": [107.7, 69.5, 504.0, 81.6],
            },
            {
                "text": "model. All metrics are on the English-to-German translation development set, newstest2013. Listed",
                "page": 9,
                "rect": [108.0, 80.5, 504.0, 92.5],
            },
            {
                "text": "perplexities are per-wordpiece, according to our byte-pair encoding, and should not be compared to",
                "page": 9,
                "rect": [108.0, 91.4, 504.0, 103.4],
            },
            {
                "text": "per-word perplexities.",
                "page": 9,
                "rect": [108.0, 102.3, 195.5, 114.3],
            },
            {
                "text": "trainPPLBLEUparams",
                "page": 9,
                "rect": [371.1, 129.8, 502.8, 141.8],
            },
            {
                "text": "NdmodeldffhdkdvPdropϵls",
                "page": 9,
                "rect": [146.1, 137.0, 356.0, 147.9],
            },
            {
                "text": "steps(dev)(dev)×10⁶",
                "page": 9,
                "rect": [370.3, 141.2, 499.0, 160.0],
            },
            {
                "text": "base65122048864640.10.1100K4.9225.865",
                "page": 9,
                "rect": [116.5, 153.9, 493.4, 165.9],
            },
            {
                "text": "15125125.2924.9",
                "page": 9,
                "rect": [236.6, 166.5, 457.7, 178.5],
            },
            {
                "text": "41281285.0025.5",
                "page": 9,
                "rect": [236.6, 177.4, 457.7, 189.4],
            },
            {
                "text": "(A)",
                "page": 9,
                "rect": [118.4, 182.9, 132.2, 194.9],
            },
            {
                "text": "1632324.9125.8",
                "page": 9,
                "rect": [234.1, 188.3, 457.7, 200.3],
            },
            {
                "text": "3216165.0125.4",
                "page": 9,
                "rect": [234.1, 199.2, 457.7, 211.2],
            },
            {
                "text": "(B)165.1625.158",
                "page": 9,
                "rect": [118.7, 211.9, 493.4, 229.3],
            },
            {
                "text": "325.0125.460",
                "page": 9,
                "rect": [258.5, 222.8, 493.4, 234.8],
            },
            {
                "text": "26.1123.736",
                "page": 9,
                "rect": [148.2, 235.4, 493.4, 247.4],
            },
            {
                "text": "45.1925.350",
                "page": 9,
                "rect": [148.2, 246.3, 493.4, 258.3],
            },
            {
                "text": "84.8825.580",
                "page": 9,
                "rect": [148.2, 257.2, 493.4, 269.2],
            },
            {
                "text": "(C)",
                "page": 9,
                "rect": [118.7, 268.1, 132.0, 280.1],
            },
            {
                "text": "25632325.7524.528",
                "page": 9,
                "rect": [171.3, 268.1, 493.4, 280.1],
            },
            {
                "text": "10241281284.6626.0168",
                "page": 9,
                "rect": [168.8, 279.0, 495.8, 291.0],
            },
            {
                "text": "10245.1225.453",
                "page": 9,
                "rect": [202.2, 289.9, 493.4, 302.0],
            },
            {
                "text": "40964.7526.290",
                "page": 9,
                "rect": [202.2, 300.9, 493.4, 312.9],
            },
            {
                "text": "0.05.7724.6",
                "page": 9,
                "rect": [315.1, 313.5, 457.7, 325.5],
            },
            {
                "text": "0.24.9525.5",
                "page": 9,
                "rect": [315.1, 324.4, 457.7, 336.4],
            },
            {
                "text": "(D)",
                "page": 9,
                "rect": [118.4, 329.9, 132.2, 341.9],
            },
            {
                "text": "0.04.6725.3",
                "page": 9,
                "rect": [344.8, 335.3, 457.7, 347.3],
            },
            {
                "text": "0.25.4725.7",
                "page": 9,
                "rect": [344.8, 346.2, 457.7, 358.2],
            },
            {
                "text": "(E)positional embedding instead of sinusoids4.9225.7",
                "page": 9,
                "rect": [119.0, 358.9, 457.7, 370.9],
            },
            {
                "text": "big610244096160.3300K4.3326.4213",
                "page": 9,
                "rect": [119.0, 371.1, 495.8, 384.1],
            },
            {
                "text": "development set, newstest2013. We used beam search as described in the previous section, but no",
                "page": 9,
                "rect": [108.0, 412.1, 504.0, 424.1],
            },
            {
                "text": "checkpoint averaging. We present these results in Table 3.",
                "page": 9,
                "rect": [108.0, 423.0, 339.1, 435.0],
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
    assert "NdmodeldffhdkdvPdropϵls" in table_regions[0]["text"]
    assert "base65122048864640" in table_regions[0]["text"]
    assert "(A)" in table_regions[0]["text"]
    assert "25632325.7524.528" in table_regions[0]["text"]
    assert "0.05.7724.6" in table_regions[0]["text"]
    assert "big610244096160.3300K4.3326.4213" in table_regions[0]["text"]
    assert "beam search" not in table_regions[0]["text"]
    assert "NdmodeldffhdkdvPdropϵls" not in plain_text
    assert "base65122048864640" not in plain_text
    assert "0.05.7724.6" not in plain_text
    assert "big610244096160.3300K4.3326.4213" not in plain_text
    assert "beam search" in plain_text


def test_extract_lines_omits_bottom_footnotes_and_page_numbers(tmp_path):
    pdf_path = write_bottom_footer_noise_pdf(tmp_path / "footer-noise.pdf")

    lines = pdf_converter._extract_lines(pdf_path)
    text = " ".join(line["text"] for line in lines)

    assert "we varied our base model in different ways." in text
    assert "TFLOPS" not in text
    assert " 8 " not in f" {text} "


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
    assert clip.y0 >= 98
    assert clip.y1 <= 132


def test_equation_clip_uses_tight_default_vertical_padding():
    page = SimpleNamespace(rect=fitz.Rect(0, 0, 600, 800))
    line = {"rect": [72, 100, 320, 130]}
    asset = DocumentAsset(
        id="eq-1",
        kind=AssetKind.equation,
        label="Equation 1",
        relativePath="assets/eq-1.png",
    )

    clip = pdf_converter._asset_clip(page, line, asset)

    assert clip.y0 >= 98
    assert clip.y1 <= 132


def test_equation_clip_respects_adjacent_text_bounds():
    page = SimpleNamespace(rect=fitz.Rect(0, 0, 600, 800))
    line = {
        "rect": [124, 491.5, 504, 529.2],
        "_clipTop": 491.6,
        "_clipBottom": 521.8,
    }
    asset = DocumentAsset(
        id="eq-1",
        kind=AssetKind.equation,
        label="(1)",
        relativePath="assets/eq-1.png",
    )

    clip = pdf_converter._asset_clip(page, line, asset)

    assert clip.y0 >= 491.6
    assert clip.y1 <= 521.8


def test_equation_clip_bounds_trim_overlapping_prose_rects_from_top():
    lines = [
        {
            "text": "using the notation alpha_t and alpha_bar_t, we have",
            "page": 2,
            "rect": [107.7, 646.5, 504.0, 730.4],
        },
        {
            "text": "q(xt|x0) = N(xt; sqrt(alpha_bar_t)x0, (1 - alpha_bar_t)I)(4)",
            "page": 2,
            "rect": [229.8, 701.4, 504.0, 726.3],
            "kind": BlockKind.equation,
        },
    ]

    pdf_converter._annotate_asset_clip_bounds(lines)

    assert lines[1]["_clipTop"] == 705.4


def test_asset_image_source_prefers_block_anchor_over_earlier_reference():
    asset = DocumentAsset(
        id="table-3",
        kind=AssetKind.table,
        label="Table 3",
        relativePath="assets/table-3.png",
    )
    reference_line = {
        "text": "The configuration of this model is listed in the bottom line of Table 3.",
        "page": 8,
        "rect": [108, 449, 504, 461],
    }
    table_line = {
        "text": "Table 3: Variations on the Transformer architecture.",
        "page": 9,
        "rect": [108, 69, 504, 384],
        "assetId": "table-3",
    }

    match = pdf_converter._line_for_asset(asset, [reference_line, table_line])

    assert match == table_line


def test_attention_visualization_region_becomes_figure_asset():
    paragraphs = pdf_converter._merge_lines_into_paragraphs(
        [
            {
                "text": "Input-Input Layer5Attention Visualizations",
                "page": 13,
                "rect": [108.0, 62.5, 250.5, 86.0],
            },
            {
                "text": "governments",
                "page": 13,
                "rect": [237.1, 115.5, 245.8, 160.5],
            },
            {
                "text": "<pad>",
                "page": 13,
                "rect": [482.1, 138.4, 490.8, 160.5],
            },
            {
                "text": "voting",
                "page": 13,
                "rect": [365.4, 139.7, 374.1, 160.5],
            },
            {
                "text": "of",
                "page": 13,
                "rect": [213.8, 154.0, 222.4, 160.5],
            },
            {
                "text": "Figure 3: An example of the attention mechanism following long-distance dependencies in the",
                "page": 13,
                "rect": [108.0, 310.7, 504.0, 322.7],
            },
            {
                "text": "encoder self-attention in layer 5 of 6. Many of the attention heads attend to a distant dependency of",
                "page": 13,
                "rect": [108.0, 321.6, 504.0, 333.7],
            },
            {
                "text": "the verb making, completing the phrase making...more difficult.",
                "page": 13,
                "rect": [108.0, 332.6, 504.0, 344.6],
            },
            {
                "text": "Acknowledgements",
                "page": 13,
                "rect": [108.0, 388.0, 220.0, 402.0],
            },
        ]
    )

    figure_regions = [
        paragraph for paragraph in paragraphs if paragraph.get("kind") == BlockKind.figure
    ]
    plain_text = " ".join(
        paragraph["text"]
        for paragraph in paragraphs
        if paragraph.get("kind") != BlockKind.figure
    )

    assert len(figure_regions) == 1
    assert "Figure 3" in figure_regions[0]["text"]
    assert "<pad>" in figure_regions[0]["text"]
    assert "voting" in figure_regions[0]["text"]
    assert "<pad>" not in plain_text
    assert "voting" not in plain_text
    assert "Acknowledgements" in plain_text


def test_diffusion_graphical_model_region_becomes_figure_asset():
    paragraphs = pdf_converter._merge_lines_into_paragraphs(
        [
            {
                "text": "that have produced images comparable to those of GANs [11, 55].",
                "page": 2,
                "rect": [72.0, 170.0, 504.0, 190.0],
            },
            {
                "text": "Figure 1: Generated samples on CelebA-HQ 256 x 256 (left) and unconditional CIFAR10 (right)",
                "page": 2,
                "rect": [72.0, 220.0, 504.0, 244.0],
            },
            {
                "text": "34th Conference on Neural Information Processing Systems (NeurIPS 2020), Vancouver, Canada.",
                "page": 2,
                "rect": [72.0, 248.0, 504.0, 272.0],
            },
            {
                "text": "p√(xt−1|xt)",
                "page": 2,
                "rect": [72.0, 320.0, 180.0, 344.0],
            },
            {
                "text": "xT−! · · · −!xt−−−−! xt−1 −! · · · −!",
                "page": 2,
                "rect": [72.0, 360.0, 420.0, 384.0],
            },
            {
                "text": "x0 −! q(xt|xt−1) Figure 2: The directed graphical model considered in this work.",
                "page": 2,
                "rect": [72.0, 400.0, 504.0, 424.0],
            },
            {
                "text": "−!",
                "page": 2,
                "rect": [514.0, 402.0, 532.0, 424.0],
            },
            {
                "text": "The forward process gradually adds Gaussian noise to data.",
                "page": 2,
                "rect": [72.0, 470.0, 504.0, 490.0],
            },
        ]
    )

    figure_regions = [
        paragraph for paragraph in paragraphs if paragraph.get("kind") == BlockKind.figure
    ]
    plain_text = " ".join(
        paragraph["text"]
        for paragraph in paragraphs
        if paragraph.get("kind") != BlockKind.figure
    )

    assert len(figure_regions) == 1
    assert "Figure 2" in figure_regions[0]["text"]
    assert "p√(xt−1|xt)" in figure_regions[0]["text"]
    assert "xT−!" in figure_regions[0]["text"]
    assert "−!" in figure_regions[0]["text"]
    assert "p√(xt−1|xt)" not in plain_text
    assert "xT−!" not in plain_text
    assert " −! " not in f" {plain_text} "
    assert "Figure 1: Generated samples" in plain_text
    assert "The forward process gradually adds Gaussian noise to data." in plain_text


def test_diffusion_graphical_model_keeps_split_arrow_fragments_together():
    paragraphs = pdf_converter._merge_lines_into_paragraphs(
        [
            {
                "text": "p✓(xt−1|xt)",
                "page": 2,
                "rect": [276.0, 72.0, 315.1, 85.7],
            },
            {
                "text": "−! · · · −!",
                "page": 2,
                "rect": [185.1, 79.9, 243.6, 100.4],
            },
            {
                "text": "−−−−−! xt−1 −! · · · −! x0",
                "page": 2,
                "rect": [274.3, 79.9, 425.9, 101.6],
            },
            {
                "text": "xT",
                "page": 2,
                "rect": [162.5, 80.2, 175.2, 92.9],
            },
            {
                "text": "xt",
                "page": 2,
                "rect": [253.3, 80.2, 264.1, 92.9],
            },
            {
                "text": "−!",
                "page": 2,
                "rect": [270.0, 83.6, 297.7, 111.5],
            },
            {
                "text": "q(xt|xt−1)",
                "page": 2,
                "rect": [277.7, 106.7, 313.0, 120.4],
            },
            {
                "text": "Figure 2: The directed graphical model considered in this work.",
                "page": 2,
                "rect": [189.5, 120.8, 422.5, 132.8],
            },
            {
                "text": "This paper presents progress in diffusion probabilistic models.",
                "page": 2,
                "rect": [107.7, 140.9, 505.7, 152.9],
            },
        ]
    )

    figure_regions = [
        paragraph for paragraph in paragraphs if paragraph.get("kind") == BlockKind.figure
    ]
    plain_text = " ".join(
        paragraph["text"]
        for paragraph in paragraphs
        if paragraph.get("kind") != BlockKind.figure
    )

    assert len(figure_regions) == 1
    assert "p✓(xt−1|xt)" in figure_regions[0]["text"]
    assert "xT" in figure_regions[0]["text"]
    assert "q(xt|xt−1)" in figure_regions[0]["text"]
    assert "Figure 2" in figure_regions[0]["text"]
    assert "xT" not in plain_text
    assert "q(xt|xt−1)" not in plain_text
    assert "This paper presents progress" in plain_text


def test_diffusion_figure_clip_uses_full_page_width_to_avoid_cutting_graph():
    page = SimpleNamespace(rect=fitz.Rect(0, 0, 600, 800))
    line = {
        "kind": BlockKind.figure,
        "_figureMode": "diagram",
        "rect": [72, 320, 532, 424],
    }
    asset = DocumentAsset(
        id="fig-2",
        kind=AssetKind.figure,
        label="Figure 2",
        relativePath="assets/fig-2.png",
    )

    clip = pdf_converter._asset_clip(page, line, asset)

    assert clip.x0 == 0
    assert clip.x1 == 600
    assert clip.y0 <= 302
    assert clip.y1 >= 442


def test_diffusion_figure_clip_respects_following_text_bound():
    page = SimpleNamespace(rect=fitz.Rect(0, 0, 600, 800))
    line = {
        "kind": BlockKind.figure,
        "_figureMode": "diagram",
        "rect": [162, 72, 426, 133],
        "_clipBottom": 138,
    }
    asset = DocumentAsset(
        id="fig-2",
        kind=AssetKind.figure,
        label="Figure 2",
        relativePath="assets/fig-2.png",
    )

    clip = pdf_converter._asset_clip(page, line, asset)

    assert clip.y1 <= 138


def test_diffusion_conditioned_equation_is_equation_not_figure():
    paragraphs = pdf_converter._merge_lines_into_paragraphs(
        [
            {
                "text": "posterior q(x1:T |x0), called the forward process, is fixed to a Markov chain that",
                "page": 2,
                "rect": [108.0, 534.7, 504.0, 555.0],
            },
            {
                "text": "gradually adds Gaussian noise according to a variance schedule beta1, ..., betaT:",
                "page": 2,
                "rect": [108.0, 545.6, 454.6, 559.1],
            },
            {
                "text": "YT",
                "page": 2,
                "rect": [211.5, 562.0, 224.3, 599.7],
            },
            {
                "text": "q(x1:T |x0) :=",
                "page": 2,
                "rect": [151.6, 571.9, 208.6, 590.8],
            },
            {
                "text": "q(xt|xt-1), q(xt|xt-1) := N(xt;",
                "page": 2,
                "rect": [226.1, 572.0, 380.9, 589.3],
            },
            {
                "text": "1 - beta_t xt-1, beta_t I)(2)",
                "page": 2,
                "rect": [392.6, 570.5, 504.0, 589.3],
            },
            {
                "text": "Training is performed by optimizing the usual variational bound on negative log likelihood:",
                "page": 2,
                "rect": [107.7, 599.8, 472.2, 611.8],
            },
        ]
    )

    equation_regions = [
        paragraph
        for paragraph in paragraphs
        if paragraph.get("kind") == BlockKind.equation
    ]
    figure_regions = [
        paragraph for paragraph in paragraphs if paragraph.get("kind") == BlockKind.figure
    ]
    plain_text = " ".join(
        paragraph["text"]
        for paragraph in paragraphs
        if paragraph.get("kind") not in {BlockKind.equation, BlockKind.figure}
    )

    assert len(equation_regions) == 1
    assert not figure_regions
    assert "q(x1:T |x0)" in equation_regions[0]["text"]
    assert "beta_t I)(2)" in equation_regions[0]["text"]
    assert "YT" not in plain_text
    assert "Training is performed" in plain_text


def test_diffusion_introductory_prose_stays_out_of_equation_asset():
    paragraphs = pdf_converter._merge_lines_into_paragraphs(
        [
            {
                "text": "transitions starting at p(xT ) = N(xT ; 0, I):",
                "page": 2,
                "rect": [108.0, 474.8, 283.8, 493.6],
            },
            {
                "text": "YT",
                "page": 2,
                "rect": [202.3, 491.5, 215.0, 529.2],
            },
            {
                "text": "p_theta(x0:T ) := p(xT )",
                "page": 2,
                "rect": [124.1, 501.4, 200.4, 513.2],
            },
            {
                "text": "p_theta(xt-1|xt), p_theta(xt-1|xt) := N(xt-1; mu_theta(xt, t), Sigma_theta(xt, t)) (1)",
                "page": 2,
                "rect": [216.8, 501.5, 504.0, 518.7],
            },
            {
                "text": "What distinguishes diffusion models from other latent variable models is that the approximate",
                "page": 2,
                "rect": [107.5, 523.8, 504.0, 535.8],
            },
        ]
    )

    equation_regions = [
        paragraph
        for paragraph in paragraphs
        if paragraph.get("kind") == BlockKind.equation
    ]
    plain_text = " ".join(
        paragraph["text"]
        for paragraph in paragraphs
        if paragraph.get("kind") != BlockKind.equation
    )

    assert len(equation_regions) == 1
    assert "p_theta(x0:T )" in equation_regions[0]["text"]
    assert "transitions starting" not in equation_regions[0]["text"]
    assert "transitions starting at p(xT)" in plain_text
    assert "What distinguishes diffusion models" in plain_text
    assert "YT" not in plain_text


def test_diffusion_split_product_operator_stays_out_of_prose():
    paragraphs = pdf_converter._merge_lines_into_paragraphs(
        [
            {
                "text": "transitions starting at p(xT ) = N(xT ; 0, I):",
                "page": 2,
                "rect": [108.0, 474.8, 283.8, 493.6],
            },
            {
                "text": "T",
                "page": 2,
                "rect": [205.7, 491.5, 210.4, 498.5],
            },
            {
                "text": "Y",
                "page": 2,
                "rect": [202.3, 492.0, 215.0, 529.2],
            },
            {
                "text": "p_theta(x0:T ) := p(xT )",
                "page": 2,
                "rect": [124.1, 501.4, 200.4, 513.2],
            },
            {
                "text": "p_theta(xt-1|xt), p_theta(xt-1|xt) := N(xt-1; mu_theta(xt, t), Sigma_theta(xt, t)) (1)",
                "page": 2,
                "rect": [216.8, 501.5, 504.0, 518.7],
            },
        ]
    )

    equation_regions = [
        paragraph
        for paragraph in paragraphs
        if paragraph.get("kind") == BlockKind.equation
    ]
    plain_text = " ".join(
        paragraph["text"]
        for paragraph in paragraphs
        if paragraph.get("kind") != BlockKind.equation
    )

    assert len(equation_regions) == 1
    assert "T Y" in equation_regions[0]["text"]
    assert plain_text.endswith("I):")


def test_references_section_splits_numbered_entries():
    paragraphs = pdf_converter._merge_lines_into_paragraphs(
        [
            {
                "text": "References",
                "page": 12,
                "rect": [108.0, 60.0, 180.0, 74.0],
            },
            {
                "text": "[35] Ilya Sutskever, Oriol Vinyals, and Quoc VV Le. Sequence to sequence learning with neural",
                "page": 12,
                "rect": [108.0, 493.0, 504.0, 505.0],
            },
            {
                "text": "networks. In Advances in Neural Information Processing Systems, pages 3104-3112, 2014.",
                "page": 12,
                "rect": [129.6, 504.0, 494.1, 516.0],
            },
            {
                "text": "[36] Christian Szegedy, Vincent Vanhoucke, Sergey Ioffe, Jonathon Shlens, and Zbigniew Wojna.",
                "page": 12,
                "rect": [108.0, 527.4, 505.7, 539.4],
            },
            {
                "text": "Rethinking the inception architecture for computer vision. CoRR, abs/1512.00567, 2015.",
                "page": 12,
                "rect": [129.6, 538.3, 484.3, 550.3],
            },
        ]
    )

    reference_entries = [
        paragraph
        for paragraph in paragraphs
        if paragraph.get("kind") == BlockKind.reference
    ]

    assert len(reference_entries) == 2
    assert reference_entries[0]["text"].startswith("[35]")
    assert "3104-3112, 2014." in reference_entries[0]["text"]
    assert reference_entries[1]["text"].startswith("[36]")
    assert "Rethinking the inception" in reference_entries[1]["text"]


def test_reference_spans_marks_inline_citations_without_assets():
    spans = pdf_converter._reference_spans(
        "The input or output sequences [2, 19] are discussed in prior work [27].",
        {},
    )

    assert [(span.kind, span.label) for span in spans] == [
        (ReferenceKind.citation, "[2, 19]"),
        (ReferenceKind.citation, "[27]"),
    ]
    assert all(span.targetAssetId == "" for span in spans)


def _pdf_line(bbox, text):
    return {
        "bbox": bbox,
        "spans": [
            {
                "text": text,
                "bbox": bbox,
                "origin": (bbox[0], bbox[3] - 2),
                "size": 10.0,
            }
        ],
    }


def _png_dimensions(path):
    data = path.read_bytes()
    return int.from_bytes(data[16:20], "big"), int.from_bytes(data[20:24], "big")

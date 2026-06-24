from services.converter.app.conversion.pdf_converter import convert_pdf_to_package
from services.converter.tests.fixtures import (
    write_hyphenated_line_pdf,
    write_simple_paper_pdf,
    write_wrapped_paragraph_pdf,
)


def test_converts_simple_pdf_to_document_package(tmp_path):
    pdf_path = write_simple_paper_pdf(tmp_path / "paper.pdf")
    output_dir = tmp_path / "out"
    package = convert_pdf_to_package(pdf_path=pdf_path, output_dir=output_dir, document_id="doc-1")
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
    package = convert_pdf_to_package(pdf_path=pdf_path, output_dir=output_dir, document_id="doc-1")

    texts = [block.text for block in package.blocks if block.text]

    assert "The dominant sequence transduction models are based on complex recurrent or convolutional neural networks that include an encoder and a decoder." in texts
    assert "A new paragraph starts after a visual gap." in texts
    assert "The dominant sequence transduction models" not in texts


def test_joins_hyphenated_line_breaks_inside_words(tmp_path):
    pdf_path = write_hyphenated_line_pdf(tmp_path / "hyphenated.pdf")
    output_dir = tmp_path / "out"
    package = convert_pdf_to_package(pdf_path=pdf_path, output_dir=output_dir, document_id="doc-1")

    text = " ".join(block.text or "" for block in package.blocks)

    assert "transduction models" in text
    assert "transduc-" not in text

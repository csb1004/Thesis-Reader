from services.converter.app.conversion.pdf_converter import convert_pdf_to_package
from services.converter.tests.fixtures import write_simple_paper_pdf


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
        assert (output_dir / asset.relativePath).is_file()

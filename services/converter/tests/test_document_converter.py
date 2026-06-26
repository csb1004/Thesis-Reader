from services.converter.app.conversion.document_converter import convert_document_to_package


def test_uses_latex_source_when_arxiv_id_is_detected(tmp_path, monkeypatch):
    pdf_path = tmp_path / "2006.11239.pdf"
    pdf_path.write_bytes(b"%PDF-1.4 fake fixture")

    def fake_source_converter(**kwargs):
        class Package:
            conversionMode = "latex-source"
            fallbackReason = None

        return Package()

    monkeypatch.setattr(
        "services.converter.app.conversion.document_converter._convert_from_arxiv_source",
        fake_source_converter,
    )

    package = convert_document_to_package(pdf_path, tmp_path / "out", "doc-1")

    assert package.conversionMode == "latex-source"


def test_falls_back_to_pdf_when_source_conversion_fails(tmp_path, monkeypatch):
    pdf_path = tmp_path / "2006.11239.pdf"
    pdf_path.write_bytes(b"%PDF-1.4 fake fixture")

    def failing_source_converter(**kwargs):
        raise RuntimeError("source unavailable")

    def fake_pdf_converter(pdf_path, output_dir, document_id):
        from services.converter.app.models.document_package import (
            DocumentMetadata,
            DocumentPackage,
        )

        return DocumentPackage(
            packageVersion=1,
            documentId=document_id,
            metadata=DocumentMetadata(
                title="Fallback",
                sourceFilename=pdf_path.name,
                originalPdfSha256="abc123",
            ),
            sections=[],
            blocks=[],
            assets=[],
        )

    monkeypatch.setattr(
        "services.converter.app.conversion.document_converter._convert_from_arxiv_source",
        failing_source_converter,
    )
    monkeypatch.setattr(
        "services.converter.app.conversion.document_converter.convert_pdf_to_package",
        fake_pdf_converter,
    )

    package = convert_document_to_package(pdf_path, tmp_path / "out", "doc-1")

    assert package.conversionMode == "pdf-fallback"
    assert "source unavailable" in package.fallbackReason

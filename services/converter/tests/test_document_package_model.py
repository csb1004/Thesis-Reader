import pytest
from pydantic import ValidationError

from services.converter.app.models.document_package import (
    AssetKind,
    BlockKind,
    DocumentAsset,
    DocumentBlock,
    DocumentMetadata,
    DocumentPackage,
    DocumentSection,
)


def test_minimal_document_package_serializes_to_contract_keys():
    package = DocumentPackage(
        packageVersion=1,
        documentId="doc-1",
        metadata=DocumentMetadata(
            title="Attention Is All You Need",
            sourceFilename="paper.pdf",
            originalPdfSha256="abc123",
        ),
        sections=[
            DocumentSection(
                id="sec-abstract",
                title="Abstract",
                blockIds=["b1"],
            ),
        ],
        blocks=[
            DocumentBlock(
                id="b1",
                sectionId="sec-abstract",
                kind=BlockKind.paragraph,
                text="The model architecture is shown in Figure 1.",
                referenceSpans=[],
            ),
        ],
        assets=[
            DocumentAsset(
                id="fig-1",
                kind=AssetKind.figure,
                label="Figure 1",
                relativePath="assets/fig-1.png",
                caption="Model architecture.",
            ),
        ],
    )

    payload = package.model_dump(mode="json")

    assert {
        "packageVersion",
        "documentId",
        "metadata",
        "sections",
        "blocks",
        "assets",
    } <= payload.keys()
    assert payload["anchors"] == []
    assert payload["vocabulary"] == []
    assert payload["summaries"] == []
    assert payload["packageVersion"] == 1
    assert payload["metadata"]["sourceFilename"] == "paper.pdf"
    assert payload["blocks"][0]["kind"] == "paragraph"


def test_document_package_rejects_unexpected_fields():
    with pytest.raises(ValidationError):
        DocumentPackage(
            packageVersion=1,
            documentId="doc-1",
            metadata=DocumentMetadata(
                title="Attention Is All You Need",
                sourceFilename="paper.pdf",
                originalPdfSha256="abc123",
            ),
            sections=[],
            blocks=[],
            assets=[],
            unexpected="nope",
        )

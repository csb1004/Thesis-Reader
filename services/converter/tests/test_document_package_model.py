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


def test_document_package_serializes_conversion_metadata_and_latex_block():
    package = DocumentPackage(
        packageVersion=1,
        documentId="doc-1",
        metadata=DocumentMetadata(
            title="Denoising Diffusion Probabilistic Models",
            sourceFilename="2006.11239.pdf",
            originalPdfSha256="abc123",
            converterVersion="mvp-2",
        ),
        conversionMode="latex-source",
        fallbackReason=None,
        sourceInfo={"arxivId": "2006.11239", "mainTex": "main.tex"},
        sections=[DocumentSection(id="sec-1", title="Document", blockIds=["eq-1"])],
        blocks=[
            DocumentBlock(
                id="eq-1",
                sectionId="sec-1",
                kind=BlockKind.equation,
                latex=(
                    r"q(x_t \mid x_0) = \mathcal{N}"
                    r"(x_t; \sqrt{\bar\alpha_t}x_0, (1-\bar\alpha_t)I)"
                ),
                source={"mode": "latex", "environment": "equation"},
            )
        ],
        assets=[],
    )

    payload = package.model_dump(mode="json")

    assert payload["conversionMode"] == "latex-source"
    assert payload["fallbackReason"] is None
    assert payload["sourceInfo"]["arxivId"] == "2006.11239"
    assert payload["blocks"][0]["latex"].startswith("q(x_t")
    assert payload["blocks"][0]["source"]["environment"] == "equation"


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

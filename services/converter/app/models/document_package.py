from enum import Enum

from pydantic import BaseModel, ConfigDict, Field


class ContractModel(BaseModel):
    model_config = ConfigDict(use_enum_values=True)


class BlockKind(str, Enum):
    heading = "heading"
    paragraph = "paragraph"
    quote = "quote"
    figure = "figure"
    table = "table"
    equation = "equation"
    footnote = "footnote"
    reference = "reference"


class AssetKind(str, Enum):
    figure = "figure"
    table = "table"
    equation = "equation"
    pageRegion = "pageRegion"
    thumbnail = "thumbnail"


class ReferenceKind(str, Enum):
    figure = "figure"
    table = "table"
    equation = "equation"
    footnote = "footnote"
    citation = "citation"
    reference = "reference"


class ReadingAnchor(ContractModel):
    blockId: str
    textOffset: int
    originalPdfPage: int | None = None
    originalPdfRect: list[float] | None = None


class ReferenceSpan(ContractModel):
    start: int
    end: int
    targetAssetId: str
    kind: ReferenceKind
    label: str | None = None


class DocumentMetadata(ContractModel):
    title: str
    sourceFilename: str
    authors: list[str] = Field(default_factory=list)
    originalPdfSha256: str
    importedAtIso8601: str | None = None
    converterVersion: str | None = None


class DocumentSection(ContractModel):
    id: str
    title: str
    blockIds: list[str]


class DocumentBlock(ContractModel):
    id: str
    sectionId: str
    kind: BlockKind
    text: str | None = None
    assetId: str | None = None
    referenceSpans: list[ReferenceSpan] = Field(default_factory=list)
    anchor: ReadingAnchor | None = None


class DocumentAsset(ContractModel):
    id: str
    kind: AssetKind
    label: str
    relativePath: str
    caption: str | None = None


class VocabularyEntry(ContractModel):
    id: str
    documentId: str
    expression: str
    expressionKey: str
    meaningKo: str
    sourceSentence: str
    contextBefore: str | None = None
    contextAfter: str | None = None
    anchor: ReadingAnchor | None = None
    userMeaning: str | None = None
    userMemo: str | None = None


class SectionSummary(ContractModel):
    sectionId: str
    summaryKo: str
    createdAtIso8601: str


class DocumentPackage(ContractModel):
    packageVersion: int
    documentId: str
    metadata: DocumentMetadata
    sections: list[DocumentSection]
    blocks: list[DocumentBlock]
    assets: list[DocumentAsset]
    anchors: list[ReadingAnchor] = Field(default_factory=list)
    vocabulary: list[VocabularyEntry] = Field(default_factory=list)
    summaries: list[SectionSummary] = Field(default_factory=list)

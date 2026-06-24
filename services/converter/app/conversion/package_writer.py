import json
from pathlib import Path

from services.converter.app.models.document_package import DocumentPackage


def write_document_package(package: DocumentPackage, output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / "assets").mkdir(exist_ok=True)

    (output_dir / "package.json").write_text(
        package.model_dump_json(indent=2),
        encoding="utf-8",
    )
    source_map = {
        "documentId": package.documentId,
        "blocks": [
            {"blockId": block.id, "anchor": block.anchor.model_dump() if block.anchor else None}
            for block in package.blocks
        ],
    }
    (output_dir / "source-map.json").write_text(
        json.dumps(source_map, indent=2),
        encoding="utf-8",
    )

import hashlib
import shutil
from pathlib import Path

import fitz

from services.converter.app.conversion.arxiv_source import (
    detect_arxiv_id,
    fetch_arxiv_source,
    select_main_tex,
    unpack_arxiv_source,
)
from services.converter.app.conversion.latex_converter import convert_latex_source_to_package
from services.converter.app.conversion.package_writer import write_document_package
from services.converter.app.conversion.pdf_converter import convert_pdf_to_package
from services.converter.app.models.document_package import DocumentPackage


def convert_document_to_package(
    pdf_path: Path,
    output_dir: Path,
    document_id: str,
) -> DocumentPackage:
    pdf_text = _first_pages_text(pdf_path, page_limit=2)
    arxiv_id = detect_arxiv_id(filename=pdf_path.name, pdf_text=pdf_text)
    if arxiv_id:
        try:
            return _convert_from_arxiv_source(
                arxiv_id=arxiv_id,
                pdf_path=pdf_path,
                output_dir=output_dir,
                document_id=document_id,
            )
        except Exception as exc:
            package = convert_pdf_to_package(pdf_path, output_dir, document_id)
            package.conversionMode = "pdf-fallback"
            package.fallbackReason = str(exc)
            package.sourceInfo = {"arxivId": arxiv_id}
            write_document_package(package, output_dir)
            return package

    package = convert_pdf_to_package(pdf_path, output_dir, document_id)
    package.conversionMode = "pdf-layout"
    package.fallbackReason = "No arXiv ID detected"
    write_document_package(package, output_dir)
    return package


def _convert_from_arxiv_source(
    arxiv_id: str,
    pdf_path: Path,
    output_dir: Path,
    document_id: str,
) -> DocumentPackage:
    source_dir = output_dir.parent / "arxiv-source"
    shutil.rmtree(source_dir, ignore_errors=True)
    payload = fetch_arxiv_source(arxiv_id)
    bundle = unpack_arxiv_source(payload, source_dir)
    main_tex = select_main_tex(bundle)
    return convert_latex_source_to_package(
        main_tex=main_tex,
        output_dir=output_dir,
        document_id=document_id,
        source_filename=pdf_path.name,
        original_pdf_sha256=hashlib.sha256(pdf_path.read_bytes()).hexdigest(),
        source_info={
            "arxivId": arxiv_id,
            "mainTex": main_tex.relative_to(bundle.root).as_posix(),
        },
    )


def _first_pages_text(pdf_path: Path, page_limit: int) -> str:
    try:
        with fitz.open(pdf_path) as document:
            page_count = min(page_limit, document.page_count)
            return "\n".join(
                document.load_page(index).get_text() for index in range(page_count)
            )
    except Exception:
        return ""

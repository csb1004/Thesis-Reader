import gzip
import tarfile
from io import BytesIO

from services.converter.app.conversion.arxiv_source import (
    ArxivSourceBundle,
    detect_arxiv_id,
    select_main_tex,
    unpack_arxiv_source,
)


def test_detects_arxiv_id_from_filename():
    assert detect_arxiv_id(filename="2006.11239.pdf", pdf_text="") == "2006.11239"
    assert (
        detect_arxiv_id(filename="arxiv-1706.03762v7.pdf", pdf_text="")
        == "1706.03762v7"
    )


def test_detects_arxiv_id_from_pdf_text():
    assert (
        detect_arxiv_id(filename="renamed.pdf", pdf_text="arXiv:2006.11239v2 [cs.LG]")
        == "2006.11239v2"
    )


def test_unpacks_single_gzipped_tex_file(tmp_path):
    payload = gzip.compress(b"\\documentclass{article}\\begin{document}Hi\\end{document}")

    bundle = unpack_arxiv_source(payload, tmp_path)

    assert bundle.root == tmp_path
    assert [path.name for path in bundle.tex_files] == ["source.tex"]
    assert bundle.tex_files[0].read_text(encoding="utf-8").startswith("\\documentclass")


def test_unpacks_tar_gz_source_bundle(tmp_path):
    archive_bytes = BytesIO()
    with tarfile.open(fileobj=archive_bytes, mode="w:gz") as archive:
        data = b"\\documentclass{article}\\begin{document}Main\\end{document}"
        info = tarfile.TarInfo("paper/main.tex")
        info.size = len(data)
        archive.addfile(info, BytesIO(data))

    bundle = unpack_arxiv_source(archive_bytes.getvalue(), tmp_path)

    assert [path.name for path in bundle.tex_files] == ["main.tex"]


def test_selects_main_tex_by_documentclass(tmp_path):
    supplement = tmp_path / "supplement.tex"
    supplement.write_text("Supplement only", encoding="utf-8")
    main = tmp_path / "main.tex"
    main.write_text(
        "\\documentclass{article}\\begin{document}Main\\end{document}",
        encoding="utf-8",
    )

    bundle = ArxivSourceBundle(root=tmp_path, tex_files=[supplement, main])

    assert select_main_tex(bundle) == main

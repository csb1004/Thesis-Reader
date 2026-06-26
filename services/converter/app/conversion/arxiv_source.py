import gzip
import re
import tarfile
from dataclasses import dataclass
from io import BytesIO
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import urlopen

ARXIV_ID_PATTERN = re.compile(
    r"(?:arxiv:|arxiv-)?(?P<id>(?:\d{4}\.\d{4,5}|[a-z-]+(?:\.[A-Z]{2})?/\d{7})(?:v\d+)?)",
    re.IGNORECASE,
)


@dataclass(frozen=True)
class ArxivSourceBundle:
    root: Path
    tex_files: list[Path]


class ArxivSourceError(RuntimeError):
    pass


def detect_arxiv_id(filename: str, pdf_text: str) -> str | None:
    for candidate in (filename, pdf_text):
        match = ARXIV_ID_PATTERN.search(candidate or "")
        if match:
            return match.group("id")
    return None


def fetch_arxiv_source(arxiv_id: str, fetcher=urlopen) -> bytes:
    url = f"https://arxiv.org/e-print/{arxiv_id}"
    try:
        with fetcher(url, timeout=20) as response:
            return response.read()
    except (HTTPError, URLError, TimeoutError, OSError) as exc:
        raise ArxivSourceError(f"Could not fetch arXiv source for {arxiv_id}: {exc}") from exc


def unpack_arxiv_source(payload: bytes, output_dir: Path) -> ArxivSourceBundle:
    output_dir.mkdir(parents=True, exist_ok=True)
    try:
        with tarfile.open(fileobj=BytesIO(payload), mode="r:*") as archive:
            _safe_extract_tar(archive, output_dir)
    except tarfile.TarError:
        try:
            text = gzip.decompress(payload)
        except OSError:
            text = payload
        (output_dir / "source.tex").write_bytes(text)

    tex_files = sorted(output_dir.rglob("*.tex"))
    if not tex_files:
        raise ArxivSourceError("arXiv source did not contain any .tex files")
    return ArxivSourceBundle(root=output_dir, tex_files=tex_files)


def select_main_tex(bundle: ArxivSourceBundle) -> Path:
    def score(path: Path) -> tuple[int, int]:
        text = path.read_text(encoding="utf-8", errors="ignore")
        return (
            int("\\documentclass" in text) * 4 + int("\\begin{document}" in text) * 2,
            len(text),
        )

    return max(bundle.tex_files, key=score)


def _safe_extract_tar(archive: tarfile.TarFile, output_dir: Path) -> None:
    root = output_dir.resolve()
    safe_members = []
    for member in archive.getmembers():
        target = (output_dir / member.name).resolve()
        if not target.is_relative_to(root):
            raise ArxivSourceError(f"Unsafe arXiv source path: {member.name}")
        safe_members.append(member)
    archive.extractall(output_dir, members=safe_members)

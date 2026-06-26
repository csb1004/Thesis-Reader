import shutil
import subprocess
import tempfile
import textwrap
from pathlib import Path

import fitz
from PIL import Image, ImageDraw, ImageFont


def render_latex_equation_asset(
    latex: str,
    target_path: Path,
    environment: str | None = None,
) -> str:
    target_path.parent.mkdir(parents=True, exist_ok=True)

    if shutil.which("pdflatex"):
        try:
            _render_with_pdflatex(latex, target_path, environment)
            return "pdflatex"
        except (OSError, subprocess.SubprocessError, RuntimeError):
            pass

    _render_fallback_png(latex, target_path)
    return "fallback-png"


def _render_with_pdflatex(
    latex: str,
    target_path: Path,
    environment: str | None,
) -> None:
    with tempfile.TemporaryDirectory(prefix="thesis-reader-eq-") as temp_dir_name:
        temp_dir = Path(temp_dir_name)
        tex_path = temp_dir / "equation.tex"
        tex_path.write_text(
            _equation_document(latex, environment),
            encoding="utf-8",
        )

        result = subprocess.run(
            [
                "pdflatex",
                "-interaction=nonstopmode",
                "-halt-on-error",
                "-file-line-error",
                tex_path.name,
            ],
            cwd=temp_dir,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            timeout=30,
            check=False,
        )
        if result.returncode != 0:
            raise RuntimeError(result.stdout)

        pdf_path = temp_dir / "equation.pdf"
        if not pdf_path.exists():
            raise RuntimeError("pdflatex did not produce equation.pdf")

        with fitz.open(pdf_path) as document:
            if document.page_count == 0:
                raise RuntimeError("pdflatex produced an empty PDF")
            page = document[0]
            pixmap = page.get_pixmap(matrix=fitz.Matrix(3, 3), alpha=False)
            pixmap.save(target_path)


def _equation_document(latex: str, environment: str | None) -> str:
    return rf"""
\documentclass[varwidth=true,border=3pt]{{standalone}}
\usepackage{{amsmath}}
\usepackage{{amssymb}}
\usepackage{{bm}}
\usepackage{{mathtools}}
\pagestyle{{empty}}
\begin{{document}}
{_wrapped_equation(latex, environment)}
\end{{document}}
"""


def _wrapped_equation(latex: str, environment: str | None) -> str:
    display_environment = _display_environment(environment)
    if display_environment == "displaymath":
        return "\\[\n" + latex + "\n\\]"
    return (
        f"\\begin{{{display_environment}}}\n"
        f"{latex}\n"
        f"\\end{{{display_environment}}}"
    )


def _display_environment(environment: str | None) -> str:
    normalized = (environment or "displaymath").removesuffix("*")
    if normalized in {"align", "gather", "multline", "equation"}:
        return f"{normalized}*"
    return "displaymath"


def _render_fallback_png(latex: str, target_path: Path) -> None:
    font = _fallback_font()
    padding = 28
    lines = ["Equation preview unavailable", ""]
    lines.extend(textwrap.wrap(_fallback_latex_text(latex), width=78) or [""])
    text = "\n".join(lines)

    measure_image = Image.new("RGB", (1, 1), "white")
    draw = ImageDraw.Draw(measure_image)
    bbox = draw.multiline_textbbox((0, 0), text, font=font, spacing=8)
    width = min(max(bbox[2] - bbox[0] + padding * 2, 480), 1800)
    height = max(bbox[3] - bbox[1] + padding * 2, 140)

    image = Image.new("RGB", (width, height), "white")
    draw = ImageDraw.Draw(image)
    draw.multiline_text(
        (padding, padding),
        text,
        fill=(32, 32, 32),
        font=font,
        spacing=8,
    )
    image.save(target_path, format="PNG")


def _fallback_font() -> ImageFont.ImageFont:
    for font_name in ("DejaVuSans.ttf", "Arial.ttf", "LiberationSans-Regular.ttf"):
        try:
            return ImageFont.truetype(font_name, 24)
        except OSError:
            continue
    return ImageFont.load_default()


def _fallback_latex_text(latex: str) -> str:
    compact = " ".join(latex.split())
    return compact if len(compact) <= 900 else f"{compact[:900]}..."

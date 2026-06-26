from services.converter.app.conversion.latex_converter import convert_latex_source_to_package
from services.converter.app.models.document_package import BlockKind


def test_converts_latex_sections_paragraphs_equations_and_references(tmp_path):
    main_tex = tmp_path / "main.tex"
    main_tex.write_text(
        r"""
\documentclass{article}
\title{Denoising Diffusion Probabilistic Models}
\begin{document}
\maketitle
\begin{abstract}
Diffusion models are latent variable models \cite{sohl2015deep}.
\end{abstract}
\section{Background}
The forward process is fixed.
\begin{equation}
q(x_t \mid x_0) = \mathcal{N}(x_t; \sqrt{\bar\alpha_t}x_0, (1-\bar\alpha_t)I)
\end{equation}
\begin{thebibliography}{9}
\bibitem{sohl2015deep} Sohl-Dickstein et al. Deep Unsupervised Learning using Nonequilibrium Thermodynamics.
\end{thebibliography}
\end{document}
""",
        encoding="utf-8",
    )

    package = convert_latex_source_to_package(
        main_tex=main_tex,
        output_dir=tmp_path / "out",
        document_id="doc-1",
        source_filename="2006.11239.pdf",
        original_pdf_sha256="abc123",
        source_info={"arxivId": "2006.11239", "mainTex": "main.tex"},
    )

    assert package.metadata.title == "Denoising Diffusion Probabilistic Models"
    assert package.conversionMode == "latex-source"
    assert any(
        block.kind == BlockKind.heading and block.text == "Background"
        for block in package.blocks
    )
    assert any(
        block.kind == BlockKind.paragraph and "forward process" in (block.text or "")
        for block in package.blocks
    )
    equations = [block for block in package.blocks if block.kind == BlockKind.equation]
    assert len(equations) == 1
    assert r"\mathcal{N}" in equations[0].latex
    assert any(
        block.kind == BlockKind.reference and "Sohl-Dickstein" in (block.text or "")
        for block in package.blocks
    )
    assert (tmp_path / "out" / "package.json").exists()

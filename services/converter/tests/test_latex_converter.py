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


def test_preserves_ddpm_multiline_loss_equation_as_latex(tmp_path):
    main_tex = tmp_path / "main.tex"
    main_tex.write_text(
        r"""
\documentclass{article}
\title{Denoising Diffusion Probabilistic Models}
\begin{document}
\section{Background}
Equation (5) uses KL divergence:
\begin{align}
L &= D_{KL}(q(x_T \mid x_0) \| p(x_T)) \\
&+ \sum_{t>1} D_{KL}(q(x_{t-1} \mid x_t, x_0) \| p_\theta(x_{t-1} \mid x_t)) \\
&- \log p_\theta(x_0 \mid x_1)
\end{align}
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

    equations = [block for block in package.blocks if block.kind == BlockKind.equation]
    assert len(equations) == 1
    assert r"D_{KL}" in equations[0].latex
    assert r"\sum_{t>1}" in equations[0].latex
    body_text = " ".join(block.text or "" for block in package.blocks)
    assert "LT" not in body_text
    assert "L0" not in body_text
    assert "l{z}" not in body_text


def test_cleans_ddpm_inline_math_citations_and_refs(tmp_path):
    main_tex = tmp_path / "main.tex"
    main_tex.write_text(
        r"""
\documentclass{article}
\title{Denoising Diffusion Probabilistic Models}
\begin{document}
\section{Background}
The forward process variances $\beta_t$ can be learned by reparameterization
\citep{kingma2013auto} or held constant as hyperparameters. A notable property
admits sampling $\bx_t$ at an arbitrary timestep $t$ in closed form: using the
notation $\alpha_t\defeq1-\beta_t$ and $\bar\alpha_t\defeq\prod_{s=1}^t \alpha_s$, we have
\begin{equation}
q(\bx_t \mid \bx_0) = \mathcal{N}(\bx_t; \sqrt{\bar\alpha_t}\bx_0, (1-\bar\alpha_t)\bI)
\end{equation}
Efficient training is therefore possible by optimizing random terms of $L$ with
stochastic gradient descent. Further improvements come from rewriting $L$
\labelcref{eq:vb_original} as:
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

    body_text = " ".join(block.text or "" for block in package.blocks)
    assert "$" not in body_text
    assert r"\citep" not in body_text
    assert r"\eqref" not in body_text
    assert r"\labelcref" not in body_text
    assert "_t$" not in body_text
    assert "beta_t can be learned by reparameterization [kingma2013auto]" in body_text
    assert "sampling x_t at an arbitrary timestep t" in body_text
    assert "alpha_t:=1-beta_t" in body_text
    assert "prod_(s=1)^t alpha_s" in body_text
    assert "Equation vb original" in body_text


def test_normalizes_ddpm_display_math_custom_macros(tmp_path):
    main_tex = tmp_path / "main.tex"
    main_tex.write_text(
        r"""
\documentclass{article}
\title{Denoising Diffusion Probabilistic Models}
\begin{document}
\section{Background}
\begin{align}
\Ea{-\log p_\theta(\bx_0)} \leq \Eb{q}{ - \log \frac{p_\theta(\bx_{0:T})}{q(\bx_{1:T} | \bx_0)}}
  = \mathbb{E}_q\bigg[ -\log p(\bx_T) \bigg] \eqqcolon L \label{eq:vb_original}
\end{align}
\begin{equation}
q(\bx_t \mid \bx_0) = \mathcal{N}(\bx_t; \sqrt{\bar\alpha_t}\bx_0, (1-\bar\alpha_t)\bI)
\end{equation}
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

    latex = "\n".join(
        block.latex or "" for block in package.blocks if block.kind == BlockKind.equation
    )
    assert r"\Ea" not in latex
    assert r"\Eb" not in latex
    assert r"\bx" not in latex
    assert r"\bI" not in latex
    assert r"\label" not in latex
    assert r"\eqqcolon" not in latex
    assert r"\mathbf{x}" in latex
    assert r"\mathbf{I}" in latex
    assert r"\mathbb{E}" in latex
    assert ":= L" in latex


def test_renders_latex_equations_as_package_assets(tmp_path):
    main_tex = tmp_path / "main.tex"
    main_tex.write_text(
        r"""
\documentclass{article}
\title{Denoising Diffusion Probabilistic Models}
\begin{document}
\section{Background}
Training is performed by optimizing the variational bound:
\begin{align}
\Ea{-\log p_\theta(\bx_0)} \leq \Eb{q}{ - \log \frac{p_\theta(\bx_{0:T})}{q(\bx_{1:T} | \bx_0)}}
\end{align}
\end{document}
""",
        encoding="utf-8",
    )

    output_dir = tmp_path / "out"
    package = convert_latex_source_to_package(
        main_tex=main_tex,
        output_dir=output_dir,
        document_id="doc-1",
        source_filename="2006.11239.pdf",
        original_pdf_sha256="abc123",
        source_info={"arxivId": "2006.11239", "mainTex": "main.tex"},
    )

    equations = [block for block in package.blocks if block.kind == BlockKind.equation]
    assert len(equations) == 1
    assert equations[0].assetId == "eq-1"
    assert equations[0].source["mode"] == "latex-asset"

    assets = [asset for asset in package.assets if asset.id == equations[0].assetId]
    assert len(assets) == 1
    assert assets[0].kind == "equation"
    assert assets[0].relativePath == "assets/eq-1.png"
    assert (output_dir / assets[0].relativePath).read_bytes().startswith(b"\x89PNG")

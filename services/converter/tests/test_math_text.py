from services.converter.app.conversion.math_text import (
    latex_to_readable_math_text,
    normalize_readable_math_fragments,
)


def test_converts_common_latex_math_to_unicode_reader_text():
    assert latex_to_readable_math_text(r"10^{9}") == "10⁹"
    assert latex_to_readable_math_text(r"10^(9)") == "10⁹"
    assert latex_to_readable_math_text(r"\sqrt{d_k}") == "√dₖ"
    assert latex_to_readable_math_text(r"p_\theta(x_{t-1} \mid x_t)") == (
        "p_{θ}(xₜ₋₁|xₜ)"
    )
    assert latex_to_readable_math_text(r"\prod_{s=1}^t \alpha_s") == "∏ₛ₌₁ᵗ αₛ"


def test_converts_pdf_extracted_plain_math_names_to_symbols():
    readable = latex_to_readable_math_text(
        "p_theta(x_t) + sqrt(d_k) + 10^(9) + 2pi"
    )

    assert readable == "p_{θ}(xₜ)+√dₖ+10⁹+2π"


def test_converts_lost_bold_and_tilde_greek_math_names():
    readable = normalize_readable_math_fragments(
        "p_theta(x_t|x_t)=N(x_t;bmu_theta(x_t,t),bSigma_theta(x_t,t)) "
        "set bSigma_theta(x_t,t)=sigma_t^2 I and sigma_t^2=tildebeta_t"
    )

    assert readable == (
        "p_{θ}(xₜ|xₜ)=N(xₜ;μ_{θ}(xₜ,t),Σ_{θ}(xₜ,t)) "
        "set Σ_{θ}(xₜ,t)=σₜ² I and σₜ²=β̃ₜ"
    )


def test_converts_latex_bold_tilde_and_full_greek_alphabet_names():
    assert latex_to_readable_math_text(
        r"\bm{\mu}_\theta + \boldsymbol{\Sigma}_\theta + \tilde{\beta}_t"
    ) == "μ_{θ}+Σ_{θ}+β̃ₜ"

    readable = latex_to_readable_math_text(
        "zeta eta iota kappa xi upsilon chi psi vartheta varrho varsigma"
    )

    assert readable == "ζ η ι κ ξ υ χ ψ ϑ ϱ ς"


def test_converts_standalone_pdf_subscript_fragments():
    readable = normalize_readable_math_fragments(
        "p_theta(x_0):=int p_theta(x_0:T) dx_1:T, where x_1,...,x_T"
    )

    assert readable == "p_{θ}(x₀):=∫ p_{θ}(x₀:ₜ) dx₁:ₜ, where x₁,...,xₜ"
    assert normalize_readable_math_fragments("_theta _0 _T") == "_{θ} ₀ ₜ"


def test_converts_attention_positional_encoding_equation_to_readable_text():
    readable = latex_to_readable_math_text(
        r"""
        \mathrm{PE}_{(pos,2i)} = \sin(pos / 10000^{2i/d_{\mathrm{model}}}) \\
        \mathrm{PE}_{(pos,2i+1)} = \cos(pos / 10000^{2i/d_{\mathrm{model}}})
        """
    )

    assert "PE₍ₚₒₛ,₂ᵢ₎=sin(pos/10000" in readable
    assert "PE₍ₚₒₛ,₂ᵢ₊₁₎=cos(pos/10000" in readable
    assert "\\" not in readable


def test_fallback_equation_text_does_not_show_unavailable_message():
    readable = latex_to_readable_math_text(
        r"\mathrm{PE}_{(pos,2i)} = \sin(pos / 10000^{2i/d_{\mathrm{model}}})"
    )

    assert "Equation preview unavailable" not in readable
    assert "PE" in readable
    assert "sin" in readable

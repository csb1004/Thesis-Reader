from services.converter.app.conversion.math_text import latex_to_readable_math_text


def test_converts_common_latex_math_to_unicode_reader_text():
    assert latex_to_readable_math_text(r"10^{9}") == "10⁹"
    assert latex_to_readable_math_text(r"10^(9)") == "10⁹"
    assert latex_to_readable_math_text(r"\sqrt{d_k}") == "√dₖ"
    assert latex_to_readable_math_text(r"p_\theta(x_{t-1} \mid x_t)") == (
        "p_θ(xₜ₋₁|xₜ)"
    )
    assert latex_to_readable_math_text(r"\prod_{s=1}^t \alpha_s") == "∏ₛ₌₁ᵗ αₛ"


def test_converts_pdf_extracted_plain_math_names_to_symbols():
    readable = latex_to_readable_math_text(
        "p_theta(x_t) + sqrt(d_k) + 10^(9) + 2pi"
    )

    assert readable == "p_θ(xₜ)+√dₖ+10⁹+2π"


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

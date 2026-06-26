from pathlib import Path

from PIL import Image, ImageDraw

from services.converter.app.conversion.equation_renderer import (
    _crop_rendered_equation_whitespace,
    _fallback_equation_lines,
)


def test_crops_large_white_equation_canvas_to_readable_bounds(tmp_path):
    image_path = tmp_path / "equation.png"
    image = Image.new("RGB", (1200, 320), "white")
    draw = ImageDraw.Draw(image)
    draw.rectangle((520, 140, 680, 180), fill="black")
    image.save(image_path)

    _crop_rendered_equation_whitespace(image_path, padding=12)

    cropped = Image.open(image_path)
    assert cropped.width <= 190
    assert cropped.height <= 70
    assert cropped.width > 160
    assert cropped.height > 40


def test_fallback_equation_lines_use_readable_math_text():
    lines = _fallback_equation_lines(
        r"\mathrm{PE}_{(pos,2i)} = \sin(pos / 10000^{2i/d_{\mathrm{model}}})"
    )
    text = " ".join(lines)

    assert "Equation preview unavailable" not in text
    assert "PE" in text
    assert "sin" in text
    assert "\\" not in text

from pathlib import Path

from PIL import Image, ImageDraw

from services.converter.app.conversion.equation_renderer import (
    _crop_rendered_equation_whitespace,
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

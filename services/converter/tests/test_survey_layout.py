import os
from pathlib import Path

import fitz
import pytest
from reportlab.pdfgen import canvas

from services.converter.app.conversion.pdf_converter import convert_pdf_to_package, _reference_spans


def test_font_headings_and_indented_paragraphs_become_sections(tmp_path):
    path = tmp_path / 'survey.pdf'
    pdf = canvas.Canvas(str(path))
    pdf.setFont('Helvetica-Bold', 20)
    pdf.drawString(72, 750, 'A Test Survey')
    pdf.showPage()
    pdf.setFont('Helvetica-Bold', 26)
    pdf.drawString(270, 740, '1')
    pdf.setFont('Helvetica-Bold', 15)
    pdf.drawString(230, 700, 'Introduction')
    pdf.setFont('Helvetica', 11)
    pdf.drawString(72, 600, 'The first paragraph describes the experimental setup.')
    pdf.drawString(88, 584, 'Another paragraph begins with an indented line.')
    pdf.drawString(72, 568, 'Its second line continues without an indentation.')
    pdf.setFont('Helvetica-Bold', 11)
    pdf.drawString(72, 530, '1.1')
    pdf.drawString(98, 530, 'Experimental setup')
    pdf.setFont('Helvetica', 11)
    pdf.drawString(72, 500, 'This subsection contains the detailed experiment description.')
    pdf.save()
    package = convert_pdf_to_package(path, tmp_path / 'out', 'test')
    assert '1 Introduction' in [section.title for section in package.sections]
    assert '1.1 Experimental setup' in [section.title for section in package.sections]
    paragraph = next(block for block in package.blocks if (block.text or '').startswith('Another'))
    assert 'Its second line' in paragraph.text
    assert 'first paragraph' not in paragraph.text


def test_math_interval_is_not_a_citation_without_numbered_bibliography():
    assert _reference_spans('The parameter is in [0, 1].', {}, set()) == []


@pytest.mark.skipif(not os.environ.get('THESIS_SURVEY_PDF'), reason='Set THESIS_SURVEY_PDF to the supplied TU Delft PDF')
def test_tudelft_survey_complete_document(tmp_path):
    source = Path(os.environ['THESIS_SURVEY_PDF'])
    package = convert_pdf_to_package(source, tmp_path / 'out', 'survey')
    titles = [section.title for section in package.sections]
    assert titles.count('4.1 Basic considerations') == 1
    assert '5.2 How much budget do we allocate for planning and real data collection?' in titles
    assert len(titles) == 37
    section = next(s for s in package.sections if s.title == '4.1 Basic considerations')
    heading = next(b for b in package.blocks if b.id == section.blockIds[0])
    assert heading.anchor.originalPdfPage == 16
    background = [b for b in package.blocks if b.anchor.originalPdfPage == 10]
    assert len([b for b in background if b.kind == 'equation']) == 1
    assert len([b for b in background if b.kind == 'paragraph']) == 3
    assert any('\u2211' in (b.text or '') for b in background)
    assert all(not b.referenceSpans for b in background)
    assert all('\x0c' not in (b.text or '') for b in package.blocks)
    assert all(b.text != 'Introduction' for b in package.blocks if b.anchor.originalPdfPage == 8)
    equation = next(a for a in package.assets if a.label == '(2.1)')
    assert (tmp_path / 'out' / equation.relativePath).exists()
    assert any(a.label == '(7.2)' for a in package.assets)
    with fitz.open(source) as document:
        assert document.page_count == 122

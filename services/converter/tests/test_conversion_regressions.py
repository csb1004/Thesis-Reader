import json

import fitz
import pytest

from services.converter.app.conversion.arxiv_source import detect_arxiv_id
from services.converter.app.conversion.latex_converter import _expand_simple_includes, _clean_text_metadata
from services.converter.app.conversion.latex_converter import _expand_user_macros, _validate_source_identity
from services.converter.app.conversion.pdf_converter import _extract_lines, _merge_lines_into_paragraphs, _reference_spans
from services.converter.app.conversion.package_writer import write_document_package
from services.converter.app.models.document_package import DocumentPackage, DocumentMetadata, DocumentBlock


def test_does_not_select_cited_arxiv_paper():
    assert detect_arxiv_id('own-paper.pdf', 'Related work discusses arXiv:1706.03762.') is None
    assert detect_arxiv_id('own-paper.pdf', 'A reference\narXiv:1706.03762\nAnother reference') is None
    assert detect_arxiv_id('2006.11239.pdf', 'arXiv:1706.03762v7 [cs.CL]') is None


def test_two_columns_stay_in_reading_order(tmp_path):
    doc = fitz.open()
    page = doc.new_page(width=600, height=800)
    for x, y, text in [(40, 60, 'Left column first line continues'), (40, 80, 'Left column second line finishes.'),
                       (330, 60, 'Right column first line continues'), (330, 80, 'Right column second line finishes.')]:
        page.insert_text((x, y), text, fontsize=10)
    path = tmp_path / 'columns.pdf'
    doc.save(path)
    doc.close()
    lines = _extract_lines(path)
    assert [line['text'].split()[0] for line in lines] == ['Left', 'Left', 'Right', 'Right']
    paragraphs = _merge_lines_into_paragraphs(lines)
    assert all(not ('Left' in p['text'] and 'Right' in p['text']) for p in paragraphs)


def test_nested_includes_and_cycles(tmp_path):
    (tmp_path / 'one.tex').write_text(r'One \input{two}')
    (tmp_path / 'two.tex').write_text('Two actual contents')
    assert _expand_simple_includes(r'\input{one}', tmp_path) == 'One Two actual contents'
    (tmp_path / 'two.tex').write_text(r'\input{one}')
    with pytest.raises(ValueError, match='Cyclic'):
        _expand_simple_includes(r'\input{one}', tmp_path)
    with pytest.raises(ValueError, match='Missing'):
        _expand_simple_includes(r'\input{missing}', tmp_path)


def test_mention_does_not_create_phantom_asset():
    assets = {}
    assert _reference_spans('See Figure 7 and Table 2.', assets) == []
    assert assets == {}


def test_serialized_offsets_are_utf16_and_stable_on_rewrite(tmp_path):
    text, styles, refs = _clean_text_metadata('\U0001d6fc '+r'\textbf{bold} \cite{x}', {'x': '1'})
    package = DocumentPackage(packageVersion=1, documentId='test', metadata=DocumentMetadata(
        title='Test', sourceFilename='test.pdf', originalPdfSha256='hash'), sections=[], assets=[],
        blocks=[DocumentBlock(id='b', sectionId='s', kind='paragraph', text=text, textSpans=styles, referenceSpans=refs)])
    for _ in range(2):
        write_document_package(package, tmp_path)
        payload = json.loads((tmp_path / 'package.json').read_text(encoding='utf-8'))
        assert payload['blocks'][0]['textSpans'][0]['start'] == 3
        assert payload['blocks'][0]['referenceSpans'][0]['start'] == 8
        assert payload['sourceInfo']['offsetEncoding'] == 'utf-16'


def test_custom_math_macros_are_expanded_from_preamble():
    preamble = r'\newcommand{\dist}[1]{\mathcal{N}(#1)}' + '\n' + r'\newcommand{\prior}{\dist{x}}'
    assert _expand_user_macros(r'p(x)=\prior', preamble) == r'p(x)=\mathcal{N}(x)'


def test_unrelated_tex_is_rejected(tmp_path):
    doc = fitz.open()
    page = doc.new_page()
    page.insert_text((40, 60), 'A study of biology and cells')
    path = tmp_path / 'own-paper.pdf'
    doc.save(path)
    doc.close()
    with pytest.raises(ValueError, match='title does not match'):
        _validate_source_identity('Attention Is All You Need', [], path)


def test_figure_crop_uses_visual_not_mention(tmp_path):
    from services.converter.tests.fixtures import write_simple_paper_pdf
    from services.converter.app.conversion.pdf_converter import convert_pdf_to_package
    from PIL import Image
    package = convert_pdf_to_package(write_simple_paper_pdf(tmp_path / 'paper.pdf'), tmp_path / 'out', 'd')
    asset = package.assets[0]
    image = Image.open(tmp_path / 'out' / asset.relativePath)
    # The source drawing is 180pt wide, with its caption below it.
    assert 350 < image.width < 420
    assert 220 < image.height < 320


def test_failed_source_equation_does_not_publish_fake_image(tmp_path, monkeypatch):
    from services.converter.app.conversion.latex_converter import convert_latex_source_to_package
    title = 'Verified Paper'
    paragraph = 'This paper describes a detailed method for studying models and their results with several experiments on different datasets to establish reliable findings. Additional comparisons confirm consistent measurements across multiple independent studies.'
    doc = fitz.open()
    page = doc.new_page()
    page.insert_text((40, 60), title)
    page.insert_textbox(fitz.Rect(40, 100, 550, 400), paragraph)
    pdf = tmp_path / 'paper.pdf'
    doc.save(pdf)
    doc.close()
    source = tmp_path / 'main.tex'
    source.write_text(r'\documentclass{article}\title{Verified Paper}\begin{document}' + paragraph +
                      r'\begin{equation}\unknown{x}\end{equation}\end{document}')
    monkeypatch.setattr('services.converter.app.conversion.latex_converter.render_latex_equation_asset',
                        lambda *args, **kwargs: 'fallback-png')
    with pytest.raises(ValueError, match='Equation rendering failed'):
        convert_latex_source_to_package(source, tmp_path / 'out', 'd', 'paper.pdf', 'hash', {}, original_pdf_path=pdf)
    assert not (tmp_path / 'out' / 'package.json').exists()


def test_repeated_equation_numbers_do_not_reuse_other_images(tmp_path):
    from services.converter.app.conversion.pdf_converter import convert_pdf_to_package
    doc = fitz.open()
    for equation in ['x = y (1)', 'a = b (1)']:
        page = doc.new_page()
        page.insert_text((40, 40), 'Paper title')
        page.insert_text((100, 100), equation)
    path = tmp_path / 'repeated.pdf'
    doc.save(path)
    doc.close()
    package = convert_pdf_to_package(path, tmp_path / 'out', 'd')
    equations = [block for block in package.blocks if block.kind == 'equation']
    assert len(equations) == 2
    assert equations[0].assetId != equations[1].assetId
    assert len({asset.relativePath for asset in package.assets}) == 2

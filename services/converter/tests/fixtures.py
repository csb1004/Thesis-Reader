from pathlib import Path

from reportlab.pdfgen import canvas


def write_simple_paper_pdf(path: Path) -> Path:
    c = canvas.Canvas(str(path))
    c.setFont("Helvetica-Bold", 16)
    c.drawString(72, 760, "A Small Paper")
    c.setFont("Helvetica", 11)
    c.drawString(72, 720, "Abstract")
    c.drawString(72, 700, "The model architecture is shown in Figure 1.")
    c.rect(72, 560, 180, 90)
    c.drawString(72, 540, "Figure 1. Model architecture.")
    c.save()
    return path


def write_wrapped_paragraph_pdf(path: Path) -> Path:
    c = canvas.Canvas(str(path))
    c.setFont("Helvetica-Bold", 16)
    c.drawString(72, 760, "Wrapped Paper")
    c.setFont("Helvetica", 11)
    c.drawString(72, 720, "The dominant sequence transduction models")
    c.drawString(72, 704, "are based on complex recurrent or convolutional")
    c.drawString(72, 688, "neural networks that include an encoder and a decoder.")
    c.drawString(72, 648, "A new paragraph starts after a visual gap.")
    c.save()
    return path


def write_hyphenated_line_pdf(path: Path) -> Path:
    c = canvas.Canvas(str(path))
    c.setFont("Helvetica-Bold", 16)
    c.drawString(72, 760, "Hyphen Paper")
    c.setFont("Helvetica", 11)
    c.drawString(72, 720, "Attention mechanisms are used in compelling sequence modeling and transduc-")
    c.drawString(72, 704, "tion models in various tasks.")
    c.save()
    return path


def write_attention_equation_pdf(path: Path) -> Path:
    c = canvas.Canvas(str(path))
    c.setFont("Helvetica-Bold", 16)
    c.drawString(72, 760, "Equation Paper")
    c.setFont("Helvetica", 11)
    c.drawString(72, 720, "We compute the matrix of outputs as:")
    c.drawString(72, 704, "Attention(Q, K, V ) = softmax(QKT")
    c.drawString(72, 688, "√dk")
    c.drawString(72, 672, ")V")
    c.drawString(72, 656, "(1)")
    c.save()
    return path


def write_attention_equation_with_following_prose_pdf(path: Path) -> Path:
    c = canvas.Canvas(str(path))
    c.setFont("Helvetica-Bold", 16)
    c.drawString(72, 760, "Equation Paper")
    c.setFont("Helvetica", 11)
    c.drawString(72, 720, "We compute the matrix of outputs as:")
    c.drawString(180, 696, "Attention(Q, K, V ) = softmax(QKT")
    c.drawString(318, 680, "?쉊k")
    c.drawString(340, 696, ")V")
    c.drawString(440, 696, "(1)")
    c.drawString(
        72,
        656,
        "The two most commonly used attention functions are additive attention [2], and dot-product (multi-",
    )
    c.drawString(
        72,
        640,
        "plicative) attention. Dot-product attention is identical to our algorithm.",
    )
    c.save()
    return path


def write_unlabeled_equation_pdf(path: Path) -> Path:
    c = canvas.Canvas(str(path))
    c.setFont("Helvetica-Bold", 16)
    c.drawString(72, 760, "Unlabeled Equation Paper")
    c.setFont("Helvetica", 11)
    c.drawString(72, 720, "We compute the matrix of outputs as:")
    c.drawString(72, 704, "MultiHead(Q, K, V) = Concat(head1,...,headh)WO")
    c.drawString(72, 688, "headi = Attention(QWiQ, KWiK, VWiV)")
    c.drawString(72, 648, "Where the projections are parameter matrices.")
    c.save()
    return path


def write_complexity_table_pdf(path: Path) -> Path:
    c = canvas.Canvas(str(path))
    c.setFont("Helvetica-Bold", 16)
    c.drawString(72, 760, "Complexity Paper")
    c.setFont("Helvetica", 11)
    c.drawString(
        72,
        720,
        "Layer Type Complexity per Layer Sequential Operations Maximum Path Length",
    )

    x = 72
    y = 700
    c.drawString(x, y, "Self-Attention O(n")
    c.setFont("Helvetica", 7)
    c.drawString(x + 94, y + 5, "2")
    c.setFont("Helvetica", 11)
    c.drawString(x + 99, y, " · d) O(1) O(1)")

    y = 684
    c.drawString(x, y, "Recurrent O(n · d")
    c.setFont("Helvetica", 7)
    c.drawString(x + 88, y + 5, "2")
    c.setFont("Helvetica", 11)
    c.drawString(x + 93, y, ") O(n) O(n)")

    y = 668
    c.drawString(x, y, "Embedding dimension d")
    c.setFont("Helvetica", 7)
    c.drawString(x + 104, y - 3, "k")
    c.setFont("Helvetica", 11)
    c.drawString(x + 108, y, " is used for keys.")
    c.save()
    return path


def write_numbered_table_region_pdf(path: Path) -> Path:
    c = canvas.Canvas(str(path))
    c.setFont("Helvetica-Bold", 16)
    c.drawString(72, 760, "Table Paper")
    c.setFont("Helvetica", 11)
    c.drawString(
        72,
        720,
        "Table 1: Maximum path lengths, per-layer complexity and minimum number of sequential operations",
    )
    c.drawString(72, 704, "for different layer types.")
    c.drawString(90, 680, "Layer Type    Complexity per Layer    Sequential Operations")
    c.drawString(90, 664, "Self-Attention    O(n")
    c.setFont("Helvetica", 7)
    c.drawString(190, 669, "2")
    c.setFont("Helvetica", 11)
    c.drawString(195, 664, " · d)    O(1)")
    c.drawString(72, 620, "3.5 Positional Encoding")
    c.drawString(72, 596, "Since our model contains no recurrence and no convolution.")
    c.save()
    return path


def write_bleu_table_with_caption_gap_pdf(path: Path) -> Path:
    c = canvas.Canvas(str(path))
    c.setFont("Helvetica-Bold", 16)
    c.drawString(72, 760, "BLEU Table Paper")
    c.setFont("Helvetica", 8)
    c.drawString(
        72,
        720,
        "Table 2: The Transformer achieves better BLEU scores than previous state-of-the-art models.",
    )
    c.line(72, 670, 520, 670)
    c.drawString(190, 656, "BLEU")
    c.drawString(330, 656, "Training Cost (FLOPs)")
    c.drawString(180, 642, "EN-DE")
    c.drawString(230, 642, "EN-FR")
    c.drawString(330, 642, "EN-DE")
    c.drawString(390, 642, "EN-FR")
    c.line(72, 634, 520, 634)
    c.drawString(72, 618, "ByteNet [18]")
    c.drawString(180, 618, "23.75")
    c.drawString(72, 602, "Deep-Att + PosUnk [39]")
    c.drawString(180, 602, "39.2")
    c.drawString(330, 602, "1.0 · 10")
    c.setFont("Helvetica", 6)
    c.drawString(365, 606, "20")
    c.setFont("Helvetica", 8)
    c.drawString(72, 540, "3.1 Results")
    c.drawString(72, 516, "Transformer (big) outperforms previous ensembles.")
    c.save()
    return path


def write_bottom_footer_noise_pdf(path: Path) -> Path:
    c = canvas.Canvas(str(path))
    c.setFont("Helvetica-Bold", 16)
    c.drawString(72, 760, "Footer Noise Paper")
    c.setFont("Helvetica", 11)
    c.drawString(72, 720, "To evaluate the importance of different components,")
    c.drawString(72, 704, "we varied our base model in different ways.")
    c.setFont("Helvetica", 8)
    c.drawString(
        72,
        72,
        "⁵We used values of 2.8, 3.7, 6.0 and 9.5 TFLOPS for K80, K40, M40 and P100.",
    )
    c.setFont("Helvetica", 10)
    c.drawCentredString(306, 36, "8")
    c.save()
    return path

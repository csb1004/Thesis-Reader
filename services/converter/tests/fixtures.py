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

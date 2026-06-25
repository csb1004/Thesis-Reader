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

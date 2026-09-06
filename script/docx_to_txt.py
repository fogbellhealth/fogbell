#!/usr/bin/env python3
"""Throwaway corpus helper: convert a MaineCare rule .docx into the .txt form the
pipeline reads (parts separated by form-feed, so each numbered section becomes
one [PAGE N] part). Paragraphs and tables are emitted in document order.

Usage: python3 script/docx_to_txt.py corpus/maine/mainecare-101-iii-67.docx
       -> corpus/maine/mainecare-101-iii-67.txt (same stem), prints part count and sha256

Requires: pip3 install --user python-docx
"""
import hashlib, re, sys
from pathlib import Path

try:
    import docx
    from docx.table import Table
    from docx.text.paragraph import Paragraph
except ImportError:
    sys.exit("python-docx is not installed. Run: pip3 install --user python-docx")

SECTION = re.compile(r"^\s*(\d{2,3}\.\d{2}(-\d+)?)\b")  # e.g. 67.02, 67.02-3


def body_items(document):
    for child in document.element.body.iterchildren():
        tag = child.tag.rsplit("}", 1)[-1]
        if tag == "p":
            yield Paragraph(child, document).text
        elif tag == "tbl":
            for row in Table(child, document).rows:
                cells = [c.text.strip().replace("\n", " ") for c in row.cells]
                yield " | ".join(cells)


def main(path):
    src = Path(path)
    out = src.with_suffix(".txt")
    parts, current = [], []
    for text in body_items(docx.Document(str(src))):
        if SECTION.match(text) and current and len("\n".join(current)) > 200:
            parts.append("\n".join(current)); current = []
        current.append(text)
    parts.append("\n".join(current))
    out.write_text("\f".join(parts) + "\n", encoding="utf-8")
    print(f"wrote {out} — {len(parts)} parts, {sum(len(p) for p in parts):,} chars")
    print("sha256 (txt):", hashlib.sha256(out.read_bytes()).hexdigest())
    print("sha256 (docx):", hashlib.sha256(src.read_bytes()).hexdigest())


if __name__ == "__main__":
    main(sys.argv[1])

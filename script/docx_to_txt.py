#!/usr/bin/env python3
"""Throwaway corpus helper: convert a MaineCare rule .docx into the .txt form the
pipeline reads (parts separated by form-feed, so each numbered section becomes
one [PAGE N] part). Paragraphs and tables are emitted in document order.
Standard library only: a .docx is a zip whose word/document.xml holds the body.

Usage: python3 script/docx_to_txt.py corpus/maine/mainecare-101-iii-67.docx
       -> corpus/maine/mainecare-101-iii-67.txt (same stem); prints part count and sha256
"""
import hashlib, re, sys, zipfile
import xml.etree.ElementTree as ET
from pathlib import Path

W = "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}"
SECTION = re.compile(r"^\s*(\d{1,3}\.\d{1,2}(-\d+)?)\s+\S")  # e.g. 67.02, 67.02-3, 17.10, 1.1
MIN_PART_CHARS = 200


def para_text(p):
    out = []
    for node in p.iter():
        if node.tag == f"{W}t":
            out.append(node.text or "")
        elif node.tag in (f"{W}tab",):
            out.append("\t")
        elif node.tag in (f"{W}br", f"{W}cr"):
            out.append("\n")
    return "".join(out)


def body_items(root):
    body = root.find(f"{W}body")
    for child in body:
        if child.tag == f"{W}p":
            yield para_text(child)
        elif child.tag == f"{W}tbl":
            for row in child.iter(f"{W}tr"):
                cells = [" ".join(para_text(p) for p in cell.iter(f"{W}p")).strip() for cell in row.findall(f"{W}tc")]
                yield " | ".join(c.replace("\n", " ") for c in cells)


def main(path):
    src = Path(path)
    out = src.with_suffix(".txt")
    with zipfile.ZipFile(src) as z:
        root = ET.fromstring(z.read("word/document.xml"))
    parts, current = [], []
    for text in body_items(root):
        if SECTION.match(text) and current and len("\n".join(current)) > MIN_PART_CHARS:
            parts.append("\n".join(current)); current = []
        current.append(text)
    parts.append("\n".join(current))
    out.write_text("\f".join(parts) + "\n", encoding="utf-8")
    print(f"wrote {out} — {len(parts)} parts, {sum(len(p) for p in parts):,} chars")
    print("sha256 (txt): ", hashlib.sha256(out.read_bytes()).hexdigest())
    print("sha256 (docx):", hashlib.sha256(src.read_bytes()).hexdigest())


if __name__ == "__main__":
    main(sys.argv[1])

#!/usr/bin/env python3
"""Throwaway helper: cut one Chapter 3 section out of the RAI Manual PDF.

Why: the full manual (~33 MB, 1001 pages) exceeds the Anthropic native-PDF
input limit (32 MB / 600 pages), so `rulebook:extract MODE=pdf` needs a
per-section PDF. poppler/qpdf are unavailable on this machine; pypdf is.

Usage:
  python3 script/split_rai_section.py --section G
  python3 script/split_rai_section.py --section GG --dry-run
  python3 script/split_rai_section.py --pdf corpus/federal/<other>.pdf --section G --out <path>

Locating the range: prefers the PDF outline (top-level entry titled
"SECTION <X>: ..."; the range ends where the next top-level entry begins).
Falls back to scanning page text for a "SECTION <X>:" heading and the next
"SECTION <Y>:" / "CHAPTER" heading. Prints the 1-indexed page range, the
printed page labels (e.g. G-1 .. G-40), and the sha256 of the output so the
MANIFEST.md row can be filled in. Never guesses: if the section is not found,
it lists what the manual does contain and exits non-zero.
"""
import argparse
import hashlib
import re
import sys
from pathlib import Path

try:
    from pypdf import PdfReader, PdfWriter
except ImportError:
    sys.exit("pypdf is not installed. Run: pip3 install --user pypdf")

DEFAULT_PDF = Path("corpus/federal/rai-manual-v1.20.1.pdf")


def top_level_outline(reader):
    """[(title, page_index)] for top-level outline entries, in document order."""
    entries = []
    for item in reader.outline:
        if isinstance(item, list):  # children of the previous entry
            continue
        try:
            entries.append((item.title.strip(), reader.get_destination_page_number(item)))
        except Exception:  # broken destination; skip rather than guess
            continue
    return entries


def locate_via_outline(reader, section):
    heading = re.compile(rf"^SECTION {re.escape(section)}\s*:", re.I)
    entries = top_level_outline(reader)
    for i, (title, page) in enumerate(entries):
        if heading.match(title):
            if i + 1 >= len(entries):
                return page, len(reader.pages) - 1, title
            return page, entries[i + 1][1] - 1, title
    return None


def locate_via_text(reader, section):
    start_re = re.compile(rf"^\s*SECTION {re.escape(section)}\s*:", re.M)
    end_re = re.compile(rf"^\s*(SECTION (?!{re.escape(section)}\s*:)[A-Z]+\s*:|CHAPTER \d)", re.M)
    start = None
    for i, page in enumerate(reader.pages):
        text = page.extract_text() or ""
        if start is None:
            if start_re.search(text):
                start = i
        elif end_re.search(text):
            return start, i - 1, "text scan"
    if start is not None:
        return start, len(reader.pages) - 1, "text scan"
    return None


def page_labels(reader, first, last):
    labels = []
    for i in (first, last):
        m = re.search(r"Page ([A-Z]+-\d+)", reader.pages[i].extract_text() or "")
        labels.append(m.group(1) if m else "?")
    return labels


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--pdf", type=Path, default=DEFAULT_PDF)
    ap.add_argument("--section", default="G", help="section letter(s), e.g. G or GG")
    ap.add_argument("--out", type=Path, help="default: <pdf stem>-ch3-sec<X>.pdf beside the source")
    ap.add_argument("--dry-run", action="store_true", help="locate and report only; write nothing")
    args = ap.parse_args()

    section = args.section.upper()
    if not args.pdf.exists():
        sys.exit(f"Source PDF not found: {args.pdf}")
    out = args.out or args.pdf.with_name(f"{args.pdf.stem}-ch3-sec{section}.pdf")

    reader = PdfReader(str(args.pdf))
    found = locate_via_outline(reader, section) or locate_via_text(reader, section)
    if not found:
        sections = [t for t, _ in top_level_outline(reader) if t.upper().startswith("SECTION ")]
        print(f"Section {section} not found in {args.pdf} (outline and page-text scan).", file=sys.stderr)
        print("Top-level sections this manual contains:", file=sys.stderr)
        for t in sections:
            print(f"  {t}", file=sys.stderr)
        sys.exit(2)

    first, last, how = found
    labels = page_labels(reader, first, last)
    print(f"source:       {args.pdf}")
    print(f"located via:  {how}")
    print(f"page range:   {first + 1}-{last + 1} (1-indexed PDF pages, {last - first + 1} pages)")
    print(f"page labels:  {labels[0]} .. {labels[1]}")

    if args.dry_run:
        print("dry run: nothing written")
        return

    writer = PdfWriter()
    for i in range(first, last + 1):
        writer.add_page(reader.pages[i])
    writer.add_metadata({"/Title": f"{args.pdf.stem} - Chapter 3 Section {section} (pp. {first + 1}-{last + 1})"})
    with open(out, "wb") as fh:
        writer.write(fh)

    digest = hashlib.sha256(out.read_bytes()).hexdigest()
    size_mb = out.stat().st_size / 1_000_000
    print(f"wrote:        {out} ({size_mb:.1f} MB)")
    print(f"sha256:       {digest}")
    if size_mb > 32 or (last - first + 1) > 600:
        print("WARNING: output exceeds the 32 MB / 600-page API limit", file=sys.stderr)


if __name__ == "__main__":
    main()

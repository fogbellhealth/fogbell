#!/usr/bin/env python3
"""Throwaway review helper: check every citation quote in an extracted item
against the PDF text at its cited printed page label.

Usage: python3 script/verify_quotes.py tmp/first-real/D0500.json corpus/federal/rai-manual-v1.20.1-secD.pdf

For each `source` with a `quote`: normalises whitespace/dashes/quotes, splits on
"..." so stitched quotes are checked fragment by fragment, and reports
  VERBATIM        found on the cited page
  WRONG PAGE      found verbatim, but on a different page label
  NOT VERBATIM    not found; prints the closest window on the cited page
  IMAGE PAGE      the cited page has (almost) no text layer — check the rendered
                  page by eye; the text check cannot see what the model saw
  NO QUOTE        citation without a quote
Exit status is 1 if any WRONG PAGE / NOT VERBATIM remains.
"""
import difflib, json, re, sys
from pypdf import PdfReader

IMAGE_PAGE_MAX_CHARS = 400

def norm(s):
    for a, b in (("’", "'"), ("‘", "'"), ("“", '"'), ("”", '"'), ("–", "-"), ("—", "-"), (" ", " ")):
        s = s.replace(a, b)
    s = re.sub(r"-\s*\n\s*", "", s)
    s = re.sub(r"\s*©", "©", s)          # text layer sometimes puts a space before ©
    return re.sub(r"\s+", " ", s).strip().lower()

def load_pages(pdf):
    pages = {}
    for i, p in enumerate(PdfReader(pdf).pages):
        raw = p.extract_text() or ""
        m = re.search(r"Page ([A-Z]+-\d+)", raw)
        pages[m.group(1) if m else str(i + 1)] = (norm(raw), len(raw))
    return pages

def citations(node, path=()):
    if isinstance(node, dict):
        if "doc" in node and "loc" in node:
            yield ".".join(map(str, path)), node
        for k, v in node.items():
            yield from citations(v, path + (k,))
    elif isinstance(node, list):
        for i, v in enumerate(node):
            yield from citations(v, path + (i,))

def closest(frag, text):
    best, ratio, L = "", 0.0, len(frag)
    for s in range(0, max(1, len(text) - L), 20):
        win = text[s:s + L + 40]
        r = difflib.SequenceMatcher(None, frag, win).ratio()
        if r > ratio:
            ratio, best = r, win
    return ratio, best

def main(item_path, pdf_path):
    data = json.load(open(item_path))
    pages = load_pages(pdf_path)
    counts = {"VERBATIM": 0, "WRONG PAGE": 0, "NOT VERBATIM": 0, "IMAGE PAGE": 0, "NO QUOTE": 0}
    for path, c in citations(data):
        path = path.removesuffix(".source")
        label = c["loc"].replace("p.", "").strip()
        q = c.get("quote")
        if not q:
            counts["NO QUOTE"] += 1; print(f"NO QUOTE      {path}  {c['loc']}"); continue
        if label not in pages:
            counts["NOT VERBATIM"] += 1; print(f"NOT VERBATIM  {path}  {c['loc']} — label not in this PDF"); continue
        text, raw_len = pages[label]
        for frag in (norm(f) for f in q.split("...") if f.strip()):
            if frag in text:
                counts["VERBATIM"] += 1; continue
            if raw_len < IMAGE_PAGE_MAX_CHARS:
                counts["IMAGE PAGE"] += 1; print(f"IMAGE PAGE    {path}  {c['loc']}  ({raw_len} text chars) — verify by eye:\n    {frag[:160]}"); continue
            elsewhere = [l for l, (t, _) in pages.items() if frag in t]
            if elsewhere:
                counts["WRONG PAGE"] += 1; print(f"WRONG PAGE    {path}  cited {c['loc']}, found on {elsewhere}\n    {frag[:160]}"); continue
            ratio, win = closest(frag, text)
            counts["NOT VERBATIM"] += 1
            print(f"NOT VERBATIM  {path}  {c['loc']}  (closest match {ratio:.2f})\n    quote: {frag[:200]}\n    page : {win[:240]}")
    print("\n" + "  ".join(f"{k}: {v}" for k, v in counts.items()))
    return 1 if counts["WRONG PAGE"] or counts["NOT VERBATIM"] else 0

if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:3]))

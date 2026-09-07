#!/usr/bin/env python3
"""Throwaway review helper: check a layered item's state-document citations against the
converted .txt of that document. Every finding whose source.doc == DOC_ID must have a
quote that appears verbatim (whitespace/hyphen-insensitive) somewhere in the text, and its
loc (a section number like 16.2.3.3 or §22.2) must appear in the text as printed.
Usage: python3 script/verify_layer.py tmp/layer_state/D0500.json corpus/maine/mainecare-101-iii-67.txt mainecare-101-iii-67
"""
import json, re, sys
sys.path.insert(0, "script")
from verify_quotes import norm, squash

item_path, txt_path, doc_id = sys.argv[1:4]
text = open(txt_path, encoding="utf-8").read()
ntext, stext = norm(text), squash(norm(text))
data = json.load(open(item_path))
counts = {"VERBATIM": 0, "NOT VERBATIM": 0, "NO QUOTE": 0, "LOC NOT IN TEXT": 0}
def cites(node, path=()):
    if isinstance(node, dict):
        if "doc" in node and "loc" in node: yield ".".join(map(str, path)), node
        for k, v in node.items(): yield from cites(v, path + (k,))
    elif isinstance(node, list):
        for i, v in enumerate(node): yield from cites(v, path + (i,))
for path, c in cites(data):
    if c["doc"] != doc_id: continue
    loc = re.sub(r"^(§\s*|Principle\s+|Section\s+)", "", c["loc"]).strip()
    loc_key = re.sub(r"\s*\(.*$", "", loc)  # "16.2.3.3(2)" -> "16.2.3.3"
    if loc_key and loc_key not in text:
        counts["LOC NOT IN TEXT"] += 1; print(f"LOC NOT IN TEXT  {path}  {c['loc']}")
    q = c.get("quote")
    if not q:
        counts["NO QUOTE"] += 1; print(f"NO QUOTE         {path}  {c['loc']}"); continue
    ok = all((norm(f) in ntext or squash(norm(f)) in stext) for f in q.split("...") if f.strip())
    if ok: counts["VERBATIM"] += 1
    else:
        counts["NOT VERBATIM"] += 1; print(f"NOT VERBATIM     {path}  {c['loc']}\n    {q[:200]}")
print("  ".join(f"{k}: {v}" for k, v in counts.items()))
sys.exit(1 if counts["NOT VERBATIM"] or counts["LOC NOT IN TEXT"] else 0)

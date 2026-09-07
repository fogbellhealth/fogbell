#!/usr/bin/env python3
"""Throwaway review helper: summarize a batch directory of extracted items and list the
image-page quotes that still need an eye check.
Usage: python3 script/section_report.py tmp/first-real-K corpus/federal/rai-manual-v1.20.1-secK.pdf
"""
import glob, json, re, sys
from pypdf import PdfReader
d, pdf = sys.argv[1], sys.argv[2]
sys.path.insert(0, "script")
from verify_quotes import norm  # same normalisation as the verifier
r = PdfReader(pdf)
pages = {re.search(r"Page ([A-Z0-9]+-\d+)", p.extract_text() or "").group(1): norm(p.extract_text() or "") for p in r.pages}
print(f"{'item':10}{'lookback':9}{'levels':7}{'rules':6}{'doc':4}{'confl':6} not_found")
imgq = set()
for f in sorted(glob.glob(f"{d}/*.json")):
    it = json.load(open(f)); k = it["item_id"]
    print(f"{k:10}{str(it.get('lookback_days')):9}{len(it['coding_levels']):<7}{len(it['federal_coding_rules']):<6}{len(it['supportive_documentation']['federal']):<4}{len(it['conflicts']):<6}{','.join(x[:30] for x in it['not_found'])[:90]}")
    def walk(n):
        if isinstance(n, dict):
            if "loc" in n and n.get("quote"):
                lab = n["loc"].replace("p.", "").strip()
                for frag in n["quote"].split("..."):
                    if norm(frag) and norm(frag) not in pages.get(lab, ""): imgq.add((lab, k, frag.strip()[:170]))
            for v in n.values(): walk(v)
        elif isinstance(n, list):
            for v in n: walk(v)
    walk(it)
print("\nimage-page quotes to eye-check:")
for lab, k, q in sorted(imgq, key=lambda x: (int(x[0].split('-')[1]) if x[0].split('-')[1].isdigit() else 0, x[1])): print(f"  [{lab}] ({k}) {q}")

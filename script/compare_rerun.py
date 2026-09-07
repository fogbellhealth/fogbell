#!/usr/bin/env python3
"""Throwaway: compare re-extracted items in tmp batch dirs against the promoted versions.
Stops (exit 1) if any previously recorded conflict topic disappears, or lookback_days changes
away from a non-null value. Prints lookback before/after and whether the notes credit a convention.
Usage: python3 script/compare_rerun.py tmp/first-real-E E0100 E0200 ...
"""
import json, sys, re
d, ids = sys.argv[1], sys.argv[2:]
bad = 0
print(f"{'item':8}{'lb before':10}{'lb after':9}{'confl b/a':10}{'conv cited':11} note")
for k in ids:
    old = json.load(open(f"rulebook/items/{k}.json")); new = json.load(open(f"{d}/{k}.json"))
    ob, nb = old.get("lookback_days"), new.get("lookback_days")
    oc, nc = [c["topic"] for c in old["conflicts"]], [c["topic"] for c in new["conflicts"]]
    src = (new.get("lookback_source") or {}).get("loc", "-")
    notes = new.get("lookback_notes", "")
    conv = bool(re.search(r"convention|p\. 3-3|p\. 2-21|standard look-back", notes + src, re.I))
    flags = []
    if ob is not None and nb != ob: flags.append(f"LOOKBACK CHANGED {ob}->{nb}"); bad += 1
    if len(nc) < len(oc): flags.append(f"CONFLICT COUNT DROPPED {len(oc)}->{len(nc)}: {oc}"); bad += 1
    print(f"{k:8}{str(ob):10}{str(nb):9}{len(oc)}/{len(nc):<8}{str(conv):11}{src} | {notes[:90]}" + (("  !! " + "; ".join(flags)) if flags else ""))
sys.exit(1 if bad else 0)

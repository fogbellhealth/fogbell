#!/bin/zsh
# Throwaway: promote verified items from a batch dir into rulebook/items with changelog lines.
# Usage: script/promote.sh <SECTION_LETTER> <ID> [<ID> ...]   (reads tmp/first-real-<SECTION>/)
set -e
sec=$1; shift
for id in "$@"; do cp "tmp/first-real-$sec/$id.json" "rulebook/items/$id.json"; done
python3 - "$sec" "$@" <<'PY'
import sys, pathlib
sec, ids = sys.argv[1], sys.argv[2:]
tmp = pathlib.Path("tmp/changelog.md").read_text().splitlines(); out = []
for id_ in ids:
    ext = [l for l in tmp if f" · extract · {id_} · " in l and f"tmp/first-real-{sec}/" in l]; assert ext, id_
    out.append(ext[-1])
    out.append(f"- 2026-09-06 · promote · {id_} · doc=rai-manual-v1.20.1 pages=all model=claude-opus-5 · tmp/first-real-{sec}/{id_}.json -> rulebook/items/{id_}.json after schema validation and verify_quotes (image-page quotes checked by eye); MODE=pdf on rai-manual-v1.20.1-sec{sec}.pdf; template as of commit 02201d2")
c = pathlib.Path("rulebook/changelog.md"); c.write_text(c.read_text().rstrip("\n") + "\n" + "\n".join(out) + "\n")
print(f"promoted {len(ids)} items from section {sec}")
PY

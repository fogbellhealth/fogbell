# Backlog

Anything out of v1 scope gets one line here instead of getting built.

- Evidence-check UI (paste chart + ARD + item picker) — v1 definition-of-done, but not session 1.
- `rulebook:layer_state` — merge Maine deltas into items, surface fed/state conflicts (mood lookback first).
- `rulebook:review_pages` — generate `review/<ID>.md` one-pagers for the Verifier; document markup workflow.
- `rulebook:evals` — synthetic scenarios in `evals/scenarios/`, wired into CI on PRs touching `rulebook/` or `lib/prompts/`.
- MDS-RCA and MDS-AH core items as separate-instrument extraction passes.
- Local OCR fallback (`tesseract`) for scanned PDFs when the native-PDF API path is unavailable.
- Page-range cutting for PDF mode needs poppler (`pdfseparate`/`pdfunite`); consider a pure-Ruby fallback.
- Batch API for bulk extraction (50% cost) once item lists are long.
- `corpus:verify` task that checks on-disk sha256 against `MANIFEST.md`.
- G items: awaiting Verifier answer on Maine instrument; if G-via-OSA, acquire RAI v1.17.1 + OSA item set with their own manifest keys and extract from those editions.

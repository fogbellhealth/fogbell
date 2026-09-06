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
- Sub-item files repeat parent interview-level rules (~12 rules x 10 D0500 sub-items); consider a template line restricting sub-items to sub-item-specific content, decision pending Verifier's answer on whether Maine audits stems individually.
- Chapter-level definitions are invisible to item extraction: the resident mood interview (D0150) is 'conducted during the look-back period of the ARD' (p. D-2) with no day count on its pages, so lookback_days is honestly null; the general 7-day observation period is defined in Chapter 2/3.3. Consider a document-wide conventions preamble or a 'general conventions' item that items can cite.

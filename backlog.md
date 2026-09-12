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
- The extraction prompt never tells a hinted (CONV-*) extraction what `section` should be, so the model free-text's a section value (an area number, a descriptive phrase) instead of the literal `"CONV"` the engine's `section == "CONV"` filters depend on. Session 8's 30 New York items all needed a post-hoc correction. Consider making the extractor set `section` for hinted ids the same way it already sets `instrument`/`item_id` (`data["section"] ||= "CONV"` when `@hint` is present), rather than relying on the model to know the convention.
- poppler (`pdftotext`) is not installed on this dev machine; `TextSource` raises `MissingTool` for MODE=text/auto on any PDF. MODE=pdf sidesteps it entirely (used for the whole New York corpus this session — a clean born-digital PDF that would otherwise prefer MODE=text) and `script/verify_quotes.py` already reads PDFs with `pypdf` instead of `pdftotext`. Either install poppler, or teach `TextSource` a `pypdf`-based fallback so MODE=text keeps working without it.
- `instrument` is doing double duty as a program-scope field: 26 of the 30 New York CONV items (personnel files, immunizations, rate codes, criminal-history checks) have nothing to do with an assessment instrument at all — `UAS-NY` on those items means "New York's ALP audit program," not "this rule concerns the UAS-NY assessment." Evidence #1 that the schema may eventually want a separate `program` or `jurisdiction_scope` concept distinct from `instrument`. Schema stays frozen until a second piece of evidence appears — noted here, not acted on.

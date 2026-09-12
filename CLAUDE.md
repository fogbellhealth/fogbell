# CLAUDE.md — FOGBELL 🔔

## What Fogbell is

Fogbell turns public long-term-care regulatory documents (federal RAI Manual + Maine state materials) into a **versioned, citable, expert-verified rulebook**, and ships a Rails app that checks pasted chart documentation against it — flagging unsupported MDS items *while the lookback window is still open*, before a state case-mix auditor finds them. Like the bell at the point: it warns when you can't see.

**The rulebook is the asset. The app is a shell.** Every architectural decision follows from that.

Two-corpus ambition: the schema and pipeline must stay corpus-agnostic (a "rule item" is MDS item G0110A today; it could be a commercial payer's prior-auth policy later). Nothing Maine- or MDS-specific goes in the *engine* — that belongs in the *data* and prompt templates.

## Stack (decided — do not relitigate)

- **Rails 8 monolith**, Hotwire (Turbo + Stimulus), Tailwind. No React, no separate frontend, no microservices.
- **Rulebook = JSON files in git** (`rulebook/items/*.json`), validated with the `json_schemer` gem against `rulebook/schema.json`. NOT ActiveRecord — git gives us diffs, review, blame, and history, which IS the provenance story. A `Fogbell::Rulebook` module loads them read-only at boot into plain Ruby objects. A rulebook change is a reviewed commit.
- **Pipeline = rake tasks** (`lib/tasks/rulebook.rake`): `rulebook:extract`, `rulebook:layer_state`, `rulebook:review_pages`, `rulebook:evals`. Run locally, by hand. They shell out to `pdftotext -layout` (poppler) and call the Anthropic API (`anthropic` gem or plain Faraday). Form/scanned PDFs: prefer sending pages to Claude as native PDF/image input over local OCR; `tesseract` is the fallback. The pipeline never runs in production.
- **Database:** whatever `rails new` provided, used only when a real need appears (logged analysis runs; later, accounts). NEVER any real resident data — synthetic only, everywhere, always.
  - **`Facility` / `Resident` / `Assessment` are a demo fixture, not the product's data model.** They exist to drive the worklist (`db/seeds.rb`) with reproducible synthetic data — a `Resident` is a label only ("Resident 04": no name, no DOB), a `Check` (the real evidence-check record) is created per assessment and run once at seed time, and `Assessment#focus_item_id`/`#check` cache that result for the worklist card. This stands in for a future EHR feed; when real integration work starts, this schema gets replaced, not extended. `Check` itself still stores no resident identity (see its own comment) — that only lives on the fixture side.
- **Deploy:** Render, standard Rails deploy, service name `fogbell`. Anthropic API key server-side via credentials/env. The analysis call runs in a service object (`Fogbell::EvidenceCheck::Runner`) + Solid Queue job, results streamed to the page with Turbo.
- **Evals in CI:** `rulebook:evals` runs on every PR touching `rulebook/` or prompt templates; regressions block merge.

## Repository layout

```
corpus/           # source PDFs + MANIFEST.md (source URL, download date, version) — human-curated
  federal/  maine/  other-states/  insider/
rulebook/
  schema.json     # THE contract. Corpus-agnostic. Changes here get extra scrutiny.
  items/          # one JSON per item (G0110A.json …); MDS-RCA / MDS-AH items are separate instruments
  changelog.md    # append-only
review/           # generated markdown one-pagers for the Verifier (domain expert) to mark up
evals/scenarios/  # synthetic charts + expected outputs, authored with the Verifier
app/ …            # standard Rails
lib/tasks/rulebook.rake
backlog.md        # anything out of scope gets a line here instead of getting built
```

## The schema (create as rulebook/schema.json, then treat as near-frozen)

Each item file: `item_id`, `item_name`, `section`, `instrument` ("MDS-3.0" | "MDS-RCA" | "MDS-AH"), `lookback_days`, `lookback_notes`, `coding_levels[]` (each with `source`), `federal_coding_rules[]` (each `{rule, source: {doc, loc}}`), `supportive_documentation` (federal[] + per-state arrays, each criterion with `source`, `verified_by_expert`, `audit_weight`), `state_deltas`, `case_mix_relevance`, `conflicts[]` (BOTH sources preserved; `resolution: "unresolved — surface to user"` is valid), `common_audit_citations[]`, `provenance_summary` (extraction date, model, expert_review_status), `version`. **An item with any uncited rule fails validation.**

## Scope (v1 — resist expansion)

~30 case-mix-driving MDS 3.0 items only: G0110A–J, G0120, G0300, G0400 (**BLOCKED — pending Verifier ruling on Maine's current case-mix instrument (G-via-OSA vs GG vs other)**; Section G was retired from the federal MDS 3.0 in Oct 2023 and is absent from RAI Manual v1.20.1 — do not extract or cite G items to any manual until she answers); E0100–E1100; D0150, D0160 (D0200/D0300 retired from federal MDS; replaced by D0150/D0160 per v1.20.1), D0500, D0600; C0500, C1000; K0520 (K0510 retired; replaced by K0520 per v1.20.1), K0710; M0300 (A–G per-letter); O0110 (O0100 retired; replaced by O0110 per v1.20.1), O0400; N0350, N0415 (N0410 retired; replaced by N0415 per v1.20.1); Section I active diagnoses (case-mix subset, provisional: I0020, I2000, I2100, I2900, I4400, I4900, I5100, I5200, I5300, I6200, I6300). General conventions are extracted as citable `CONV-*` items (section CONV) from Chapter 2 pp. 2-9–2-21 and Chapter 3 pp. 3-1–3-4. Everything else → one line in `backlog.md`, move on. MDS-RCA core items follow as a separate-instrument pass.

## Working agreements (non-negotiable)

1. **Never invent a rule.** NOT_FOUND is a valid, common, correct answer. Confidently-wrong regulatory extraction is the project's biggest risk.
2. **Citations or it doesn't exist** — every rule carries `{doc, loc}`.
3. **Preserve conflicts** (fed-vs-state, doc-vs-doc) in `conflicts[]`. They are product features — Maine's 28-day mood lookback vs. the federal window is the canonical example.
4. **Small validated commits** — one item or one document per commit; schema validation must pass.
5. **Provenance hierarchy:** expert-verified > cited-extraction > nothing (not allowed). The Verifier (a 20+ year Maine MDS nurse) outranks the documents; the documents outrank the model.
6. **Synthetic data only.** If anything resembling real resident data appears anywhere, stop and flag it immediately.
7. **Analysis-prompt guardrails** (in `EvidenceCheck::Runner`): conservative coding only; evidence outside the lookback window is listed but never counted; action suggestions limited to contemporaneous charting of care actually occurring; never suggest documenting care that did not occur; all output is draft-for-nurse-review.
8. **Corpus-agnostic engine.** Hardcoding "Maine" or "MDS" anywhere outside `rulebook/` data or prompt templates means stop and generalize.

## Definition of done (v1)

- [ ] `schema.json` + validator + `Fogbell::Rulebook` loader, with tests
- [ ] 30 items extracted from the RAI Manual with citations, schema-valid
- [ ] Maine deltas merged; ≥1 fed/state conflict surfaced (mood lookback at minimum)
- [ ] 30 review pages generated; Verifier markup workflow documented
- [ ] ≥5 eval scenarios passing; evals wired into CI
- [ ] Evidence-check UI: paste chart + ARD + item picker → per-item status (supported / partial / unsupported), in-window evidence quotes with date+author, outside-window warnings, gaps, Maine flags, "chart today" action, mock-audit summary — every claim traceable to a cited rule via a "why?" disclosure
- [ ] Deployed to Render at app.fogbell.io

---

## Repo conventions (established session 1, 2026-09-05)

- **Rake arguments are env vars**, not bracket args (rake splits bracket args on commas):
  `bin/rails rulebook:extract DOC=corpus/federal/<file>.pdf ITEMS=G0110A,G0110B [DOC_ID=<manifest key>] [INSTRUMENT=MDS-3.0] [OUT=rulebook/items] [MODE=auto|text|pdf] [WINDOW=2] [MODEL=claude-opus-5] [LLM=anthropic|stub] [DRY_RUN=1] [FORCE=1]`
- **Prompt templates** live in `lib/prompts/*.md.erb` (Zeitwerk ignores that directory). They are reviewable files, never inline strings.
- **Citations use manifest keys.** A citation's `doc` is the `key` column of `corpus/MANIFEST.md`; `loc` is page-level (`p. 12`, `p. G-14`, `§67.02-3`).
- **`loc` uses the document's printed page label**, never the PDF's 1-indexed page number: `p. D-4`, not `p. 200`. The RAI Manual prints `Page D-4` in every header, so this is unambiguous. Section cuts of the manual (`corpus/federal/rai-manual-v1.20.1-sec<X>.pdf`) are transport artifacts for MODE=pdf: always pass `DOC_ID=rai-manual-v1.20.1` so citations point at the manual, not the cut.
- **`corpus/` is git-ignored** except `MANIFEST.md` and per-folder `README.md`. The manifest's `sha256` column is the integrity record; PDFs are large, public, and re-downloadable.
- **Nothing fake in `rulebook/items/`.** Smoke runs write to `tmp/`. The fake item X0100 exists only under `test/fixtures/`. The changelog is appended beside `OUT` (`OUT/../changelog.md`), so smoke runs never touch `rulebook/changelog.md`.
- **Rejected extractions** (schema-invalid model output) are written to `tmp/rulebook_rejects/` for inspection; nothing invalid is ever written into the rulebook.
- **Loader fails fast at boot** if any item in `rulebook/items/` is schema-invalid.
- **MODE=pdf is the default for `rai-manual-v1.20.1` section files.** The item forms are embedded images: page D-12 (the whole D0500 form) has a 210-character text layer, so `pdftotext` cannot see the item stems, codes or skip instructions at all. Text mode remains available for born-digital documents that verify well.
- **Dual-window items (provisional pending Verifier review).** `lookback_days` is the assessor's observation/look-back window, the period chart evidence is checked against (PHQ items: 7, the ARD look-back for conducting the interview). Any other window the document states (the 2-week symptom recall inside the PHQ questions) goes in `lookback_notes` with its wording, and the coexistence is filed in `conflicts[]` with both positions cited and resolution "dual-window item — surface to user". The Verifier's answer to which window Maine's auditors check evidence against outranks this ruling.
- **Multi-part items are split into per-letter item files** (`D0500A.json` … `D0500J.json`), consistent with `G0110A`. The parent (`D0500.json`) holds the interview-level rules: conduct, lookback, gateway logic. The schema gets no `sub_items` field.
- **Every extracted quote is checked** with `script/verify_quotes.py <item.json> <section.pdf>` before promotion; quotes on image pages are verified by eye against a rendered page.
- **Throwaway corpus tooling lives in `script/`** (e.g. `script/split_rai_section.py`). Python is permitted there only; the no-Python rule covers the product, not disposable corpus utilities.

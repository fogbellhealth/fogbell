# CLAUDE.md — FOGBELL 🔔
### Drop this file in the repo root after `rails new fogbell`, then paste the kickoff prompt (bottom) into Claude Code.

---

## What Fogbell is

Fogbell turns public long-term-care regulatory documents (federal RAI Manual + Maine state materials) into a **versioned, citable, expert-verified rulebook**, and ships a Rails app that checks pasted chart documentation against it — flagging unsupported MDS items *while the lookback window is still open*, before a state case-mix auditor finds them. Like the bell at the point: it warns when you can't see.

**The rulebook is the asset. The app is a shell.** Every architectural decision follows from that.

Two-corpus ambition: the schema and pipeline must stay corpus-agnostic (a "rule item" is MDS item G0110A today; it could be a commercial payer's prior-auth policy later). Nothing Maine- or MDS-specific goes in the *engine* — that belongs in the *data* and prompt templates.

## Stack (decided — do not relitigate)

- **Rails 8 monolith**, Hotwire (Turbo + Stimulus), Tailwind. No React, no separate frontend, no microservices.
- **Rulebook = JSON files in git** (`rulebook/items/*.json`), validated with the `json_schemer` gem against `rulebook/schema.json`. NOT ActiveRecord — git gives us diffs, review, blame, and history, which IS the provenance story. A `Fogbell::Rulebook` module loads them read-only at boot into plain Ruby objects. A rulebook change is a reviewed commit.
- **Pipeline = rake tasks** (`lib/tasks/rulebook.rake`): `rulebook:extract`, `rulebook:layer_state`, `rulebook:review_pages`, `rulebook:evals`. Run locally, by hand. They shell out to `pdftotext -layout` (poppler) and call the Anthropic API (`anthropic` gem or plain Faraday). Form/scanned PDFs: prefer sending pages to Claude as native PDF/image input over local OCR; `tesseract` is the fallback. The pipeline never runs in production.
- **Database:** whatever `rails new` provided, used only when a real need appears (logged analysis runs; later, accounts). No schema work up front. NEVER any real resident data — synthetic only, everywhere, always.
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

~30 case-mix-driving MDS 3.0 items only: G0110A–J, G0120, G0300, G0400; E0100–E1100; D0200, D0300, D0500, D0600; C0500, C1000; K0510, K0710; M0300; O0100, O0400; N0350, N0410; Section I active diagnoses. Everything else → one line in `backlog.md`, move on. MDS-RCA core items follow as a separate-instrument pass.

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

## KICKOFF PROMPT — paste everything below this line into Claude Code, from the repo root

Read CLAUDE.md in full — it is the project constitution. Follow its stack decisions and working agreements exactly, and push back on me if I later contradict them.

Session 1 goals, in order:

1. **Skeleton + schema.** Create the directory layout from CLAUDE.md. Draft `rulebook/schema.json` per the schema section — corpus-agnostic, citations mandatory — and SHOW ME THE SCHEMA FOR APPROVAL before writing any code against it. Then build the `Fogbell::Rulebook` loader with `json_schemer` validation and tests (failing first, then passing, including: a valid item loads; an item with an uncited rule fails; an unknown instrument fails).

2. **Corpus manifest.** Create `corpus/MANIFEST.md` with TODO entries for every document I need to download, each with its likely source site so I can go fetch them: RAI Manual MDS 3.0 current version + item sets + Section S state-items list (cms.gov / qtso.cms.gov); MaineCare Benefits Manual Ch. 101 §67 and §97/Appendix C (maine.gov/dhhs); MDS-RCA form + training manual and draft MDS-AH materials (Cutler Institute / USM pages); Maine MDS data submission specifications. Include an empty `corpus/insider/` section noting materials arriving from the Verifier.

3. **Pipeline.** Create `lib/tasks/rulebook.rake` with all four tasks stubbed, then fully implement `rulebook:extract`: arguments = corpus file path + item-id list; shells to `pdftotext -layout` with a documented fallback path that sends pages to the Anthropic API as native PDF for form/scanned documents; chunks text sensibly around the target items; calls the API with an extraction prompt that demands page-level citations for every rule and NOT_FOUND over inference; validates output against the schema with clear error reporting; writes `rulebook/items/<ID>.json`; appends to `rulebook/changelog.md`. Make the extraction prompt a reviewable template file, not an inline string.

4. **Smoke test.** Prove the pipeline end-to-end before any real documents exist: a test fixture containing a short fake "manual excerpt" for a fake item (e.g., X0100 with an invented definition, lookback, and two coding rules), run through the real extract path with the API call stubbed AND once for real when I provide an API key, producing a schema-valid JSON file.

Do not build any UI this session. Small commits, one concern each, descriptive messages. Start now with your plan for `schema.json`.

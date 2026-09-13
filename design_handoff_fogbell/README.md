# Handoff: Fogbell visual system

## Overview
Fogbell checks whether a nursing facility's chart documentation supports the MDS assessment codes it is about to submit, while the look-back window is still open. This package defines the visual system and four reference screens: Today (worklist), Check result, Rule detail, and the Reviewer queue (a separate application for rule reviewers that never loads resident data).

## About the design files
`Fogbell.dc.html` and `Fogbell Directions.dc.html` are **design references built in HTML**. They are not production code. Recreate them in the Rails + Tailwind codebase using ERB partials / ViewComponents and Tailwind utilities. Every value below maps to a Tailwind utility or a `tailwind.config.js` extension; no custom CSS beyond the config should be needed.

Open `Fogbell.dc.html` in a browser to see the screens. Row A is the timeline at three sizes, row B the Today and Check result screens (a Tweaks panel switches the verdict state), row D the Rule detail and Reviewer views, row C the component sheet. `Fogbell Directions.dc.html` shows the two rejected directions (1a, 1c) and can be ignored.

## Fidelity
**High-fidelity.** Colors, type sizes, spacing and copy are final. Match them exactly.

## Firm product rules the styling must enforce
1. Urgency is always time text: "Closes tomorrow", "Closes in 5 days", never "High priority".
2. Every status carries a shape glyph plus a label. Color is additive, never the only signal.
3. Four glyph families, never mixed: triangle = time, circle = verdict, square = rule provenance, diamond = data origin.
4. Only two accent colors exist. `closing` appears only on ≤1-day deadlines and the today marker. `supported` appears only on the Supported verdict badge/dot. Metrics, banners and headings are never colored.
5. "Synthetic data" chip in the header of every screen while demo data is used. Findings say "Provisional until the window closes". Rules show their provenance badge wherever they are named.
6. No shadows, no gradients, no icons from an icon font. Radius 3–4px only.

---

## Design tokens

### tailwind.config.js
```js
module.exports = {
  theme: {
    extend: {
      fontFamily: { sans: ['Figtree', 'system-ui', 'sans-serif'] },
      colors: {
        ink:       '#14202b', // text, primary button, ARD edge, selected states
        body:      '#3b4a58', // secondary text
        meta:      '#4a5a69', // citation source lines, chip text
        muted:     '#6a7a88', // labels, stranded evidence outline, placeholders
        faint:     '#9aa8b4', // day numbers outside window, disabled text
        rule:      '#c9d1d9', // every border
        window:    '#e4ecf3', // in-window day cells, verified chip, selected row
        ground:    '#f1f4f7', // outside-window cells, citation blocks, banner metric cell
        paper:     '#fbfcfd', // page background, card side panel
        closing:   '#b4471c', // ≤1 day left, today marker, Not supported outline
        supported: '#1f6a4e', // Supported verdict only
      },
    },
  },
}
```
Load Figtree 400/500/600/700 from Google Fonts in the layout head. Add `font-variant-numeric: tabular-nums` on `body` (`tabular-nums` utility on `<body>`).

### Type scale (Figtree)
| Role | Size / weight / tracking | Tailwind |
|---|---|---|
| Page title | 30px / 600 / −0.02em / lh 1.1 | `text-3xl font-semibold tracking-tight leading-none` |
| Item title (check result) | 26px / 600 / −0.02em | `text-[26px] font-semibold tracking-tight` |
| Big number (metric, deadline, banner) | 24–28px / 600 / −0.02em / lh 1 | `text-2xl` or `text-[28px] font-semibold tracking-tight leading-none` |
| Card title | 17px / 600 | `text-[17px] font-semibold` |
| Section title (verdict header) | 16px / 600 | `text-base font-semibold` |
| Body | 14px / 400 / lh 1.5 | `text-sm leading-relaxed` |
| Button | 13px / 600 | `text[13px] font-semibold` |
| Meta, source line | 12px / 600 | `text-xs font-semibold` |
| Uppercase label | 11px / 600 / .06em / uppercase | `text-[11px] font-semibold uppercase tracking-[.06em] text-muted` |
| Timeline day numbers | 10–11px / 600 | `text-[10px] font-semibold` |

Code numbers inside a title (D0500, N0350) are `text-muted font-medium` spans; the item name stays ink.

### Spacing
4, 8, 12, 16, 20, 24, 32 (Tailwind 1–8). Card padding `px-6 py-5`. Page padding `p-8`. Vertical rhythm between page blocks `gap-6` (24) or `gap-7` (28); between cards `gap-3` (12).

### Surfaces
- Page: `bg-paper`.
- Card: `bg-white border border-rule rounded`.
- Sub-panel inside a card: `bg-paper` (Today card right column) or `bg-ground` (citations, banner metric cell).
- Section dividers inside a card: `border-rule`. Top rule under a document title: `border-ink`.
- Screen header bar: `bg-white border-b border-rule px-8 py-3.5`. Reviewer app header: `bg-ink text-white` to make the different application unmistakable.

---

## Components

### Glyphs (`<span>` only)
```html
<!-- triangle (time) -->
<span class="inline-block w-0 h-0 border-x-[5px] border-x-transparent border-b-[9px] border-b-current"></span>
<!-- circle filled (verdict) -->      <span class="inline-block w-[9px] h-[9px] rounded-full bg-current"></span>
<!-- circle half (partial) -->        <span class="inline-block w-[9px] h-[9px] rounded-full border-[1.5px] border-current bg-[linear-gradient(90deg,currentColor_50%,transparent_50%)]"></span>
<!-- circle hollow (not supported) --> <span class="inline-block w-[9px] h-[9px] rounded-full border-2 border-current"></span>
<!-- circle dashed (stranded) -->     <span class="inline-block w-[9px] h-[9px] rounded-full border-[1.5px] border-dashed border-current"></span>
<!-- square filled (verified) -->     <span class="inline-block w-2 h-2 bg-current"></span>
<!-- square outline (pending) -->     <span class="inline-block w-2 h-2 border-[1.5px] border-current"></span>
<!-- square dashed (unreviewed) -->   <span class="inline-block w-2 h-2 border-[1.5px] border-dashed border-current"></span>
<!-- diamond (synthetic data) -->     <span class="inline-block w-2 h-2 border-[1.5px] border-current rotate-45"></span>
```

### Badge
Base: `inline-flex items-center gap-1.5 rounded px-2 py-1 text-xs font-semibold`.
| Badge | Classes | Glyph |
|---|---|---|
| Closes tomorrow / today | `bg-closing text-white` | triangle |
| Closes in N days | `border border-rule text-ink` | triangle |
| Closed (past) | `border border-rule text-muted` | none |
| Supported | `bg-supported text-white` | circle filled |
| Partial | `border border-ink text-ink` | circle half |
| Not supported | `border border-closing text-closing` | circle hollow |
| Verified | `bg-window text-ink` | square filled |
| Pending review | `border border-dashed border-muted text-body` | square outline |
| Unreviewed | `border border-dashed border-faint text-muted` | square dashed |
| Synthetic data | `border border-rule text-meta font-medium` | diamond |
| Provisional | `border border-rule text-meta font-medium` | square outline |

### Metric group
`inline-grid grid-flow-col border border-rule rounded bg-white`; each cell `px-5 py-3 flex flex-col gap-0.5 border-r border-rule last:border-r-0` with an uppercase label and a `text-2xl font-semibold tracking-tight` number. Never colored.

### Citation block
```html
<div class="bg-ground rounded px-4 py-3 flex flex-col gap-1.5">
  <p class="text-sm leading-relaxed text-ink">“The standard look-back period for the MDS 3.0 is 7 days, unless otherwise stated.”</p>
  <p class="text-xs font-semibold text-meta">RAI Manual v1.20.1, p. 3-3</p>
</div>
```
Quote first, source second, always both. When the verbatim quote has not been extracted yet, render the quote line as `text-muted italic` with the literal text `[verbatim quote from source — supplied by rule extraction]`.

### Audit projection banner
`grid grid-cols-[auto_1fr] border border-rule rounded bg-white`.
- Left cell: `bg-ground border-r border-rule px-5 py-4 min-w-[150px] flex flex-col gap-0.5`: label "Audit projection", `text-[28px] font-semibold tracking-tight leading-tight` "4 of 9", `text-xs text-body` "items lack support · 44%".
- Right cell: `px-5 py-4 text-sm leading-[1.55] text-ink [text-wrap:pretty]` with the banner copy verbatim. No color, no icon.

### Worklist card (Today)
`grid grid-cols-[1fr_300px] bg-white border border-rule rounded`.
Left `px-6 py-5 border-r border-rule flex flex-col gap-3.5`:
1. Title `text-[17px] font-semibold` — "Resident 07 <span class=text-muted font-medium>· quarterly</span>"
2. Item line `text-sm text-body leading-snug` — code in `font-semibold text-ink`, then name · look-back · coded vs supported
3. Small timeline (below), `max-w-[520px]`
4. Finding, `text-sm text-body leading-relaxed [text-wrap:pretty]`, one or two sentences.
Right `px-6 py-5 bg-paper flex flex-col justify-between gap-4`:
5. Deadline: label row `text-[11px] uppercase font-semibold tracking-[.06em] flex items-center gap-1.5` with triangle + "Closes"; then `text-[28px] font-semibold tracking-tight leading-none` "tomorrow" / "in 3 days"; then `text-xs text-muted mt-1` helper ("Charting today still counts" / weekday+date). Whole block `text-closing` when ≤1 day, otherwise label `text-meta`, number `text-ink`.
6. Actions `flex gap-2`: primary button + secondary button.
Cards are sorted by days remaining ascending. Below the cards: `border border-dashed border-rule rounded px-6 py-3.5 flex justify-between text-sm` — "6 more windows open · earliest closes in 8 days" / "Show all 9 →".

### Buttons
- Primary: `bg-ink text-white text-[13px] font-semibold px-3.5 py-2 rounded whitespace-nowrap`; hover `bg-body`.
- Secondary: `bg-white text-ink text-[13px] font-semibold px-3 py-2 border border-rule rounded whitespace-nowrap`; hover `bg-ground`.
- Focus: `focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ink`.

### Look-back timeline (the signature component)
One CSS grid, one column per day. Always render 2 days before the window plus the window days (7-day window → 9 columns; 14 → 16). Cells `rounded-sm` with `gap-0.5`.
- Outside-window day: `bg-ground`.
- In-window day: `bg-window`.
- ARD (last window day): add `border-r-4 border-ink` (6px at standalone size).
- Today: add `outline outline-2 -outline-offset-2 outline-closing`.
- Evidence inside the window: centered `rounded-full bg-ink` dot. Two pieces on one day: two dots `gap-0.5`.
- Evidence outside the window (stranded): centered `rounded-full border-2 border-dashed border-muted` hollow dot, on the plain ground. Never filled, never colored.
- Sparse evidence stays sparse: never draw connecting lines or fill empty days.

Sizes:
| Size | Cell height | Dot | Labels |
|---|---|---|---|
| Small (worklist card) | `h-7` (28px) | 10px | one row below: `grid grid-cols-[2fr_5fr_2fr] text-[10px] font-medium` — first outside date `text-faint`, window range `text-body`, "ARD Feb 4" right-aligned `text-ink` |
| Medium (check result) | `h-14` (56px) | 14px | day numbers above (`text-[11px] font-semibold text-faint`; window start `text-body`, today `text-closing`, ARD `text-ink`); evidence captions below in the same 9-column grid, spanning columns: name of source `font-semibold` + second line ("outside window", "1 episode"); "Today" `text-closing font-semibold`; "ARD" right-aligned |
| Standalone | `h-22` (88px), `gap-[3px]`, `rounded` | 20px, dashed 2.5px | day numbers above; annotation row below with `border-t-2` per span (dashed faint for stranded, ink for window and ARD, closing for today) and 12px explanatory copy |

Suggested ERB partial signature: `render "timeline", window_start:, ard:, today:, evidence: [{date:, inside: bool}], size: :small|:medium|:standalone`.

---

## Screens

### 1. Today
- Header bar: wordmark (13px ink bell glyph `rounded-t-full rounded-b-sm` + "Fogbell" 18/700), nav "Today · Residents · Rules" (`text-sm font-medium text-muted`, active `text-ink font-semibold border-b-2 border-ink pb-0.5`), right: Synthetic data chip + facility name `text-[13px] text-body`.
- Page `p-8 flex flex-col gap-7`. Top row `flex justify-between items-end flex-wrap gap-6`: left `text-[13px] text-muted` "Harborlight Care Center · Tuesday, Feb 3" over the page title "3 windows closing this week"; right the metric group (Windows open 9 · Items needing charting 6 · Projected error rate 56%).
- Card list `flex flex-col gap-3`, then the dashed "more" row. Card content in `Fogbell.dc.html` row B is the source of truth for copy.

### 2. Check result
- Header bar with breadcrumb "Today › Resident 07 › D0500" (`text-[13px] text-muted`, last crumb `text-ink font-semibold`).
- Page `px-8 pt-7 pb-9 flex flex-col gap-6`:
  1. Audit projection banner.
  2. Item header `flex justify-between items-start gap-6`: left — context line, item title, "7-day look-back · Jan 29 – Feb 4 · Provisional until the window closes"; right — deadline block as on the card (`shrink-0`).
  3. Verdict card (`bg-white border border-rule rounded`), sections divided by `border-b border-rule`:
     - Header `px-6 py-4 flex items-center gap-3`: 16px verdict glyph, "Partially supported" / "Not supported" / "Supported" `font-semibold`, then `text-sm text-body` "Coded 2 · documentation supports 1".
     - Medium timeline `px-6 py-5`.
     - Two-column `grid grid-cols-2 divide-x divide-rule`: Suggested coding (big number + scale label + explanation) | Documentation gap (what must be charted; primary "Chart today" + `text-xs text-muted` days remaining). Supported state shows "None identified. No action needed before the window closes." and no button.
     - Two-column: Supporting evidence · N (filled-circle label; each quote `text-sm text-ink` + `text-xs font-semibold text-meta` "Jan 30, 07:40 · Nursing note · J. Alvarez, RN") | Outside the window · N (`bg-paper`, dashed-circle label; quotes `text-body`, source line `text-muted` ending "— 1 day before window opened. Cannot be counted."). Empty states are one `text-sm text-muted` sentence.
  4. Why? disclosure card: header row `px-6 py-3.5 flex justify-between cursor-pointer` "Why? <span class=text-muted>Rules applied to this check · 2</span>" and "Hide/Show". Body: one row per rule, `grid grid-cols-2 gap-6 px-6 py-4.5`, left = rule name + provenance badge + plain-English line, right = citation block.
- Verdict glyph 16px: Supported `bg-supported rounded-full`; Partial half-filled ink with `border-2 border-ink`; Not supported `border-[2.5px] border-closing rounded-full`.

### 3. Rule detail
Reference-document layout. Header bar with Rules tab active and breadcrumb "Rules › MDS 3.0 › Section D › D0500".
- Page `px-12 pt-9 pb-12 flex flex-col gap-8`.
- Title block, `border-b border-ink pb-6`: context line "MDS 3.0 · Section D · Mood" with the provenance badge right-aligned; title `text-3xl`; fact row `grid grid-flow-col gap-x-8 w-fit` of four label/value pairs (Instrument, Look-back, Applies when, Extracted).
- Every section is `grid grid-cols-[160px_1fr] gap-6`; left `text-[13px] font-semibold text-muted` "§1 Coding levels" etc.
  - §1 Coding levels: `grid grid-cols-[48px_1fr_1fr] border-t border-ink`, rows `py-2.5 border-b border-rule`, code and name `font-semibold`, description `text-body`.
  - §2 Coding rules, §3 Documentation criteria: numbered lines `grid grid-cols-[28px_1fr] gap-2`, numbers `text-muted font-semibold`, source refs as `text-xs font-semibold text-muted` "[S1]".
  - §4 Conflicts: card with header row (conflict name + right-aligned `text-xs font-semibold text-body` resolution state "Unresolved · Fogbell applies 7 days until reviewed"), body `grid grid-cols-2 divide-x divide-rule`, each side: uppercase label "Position A · S1, general instructions", statement, source line. Both positions always shown; never pick a winner visually.
  - §5 Not stated in the sources: em-dash list `grid grid-cols-[16px_1fr]`, dash `text-faint`, text `text-body`.
  - §6 Sources: `grid grid-cols-[32px_1fr] gap-3` — "S1" label `text-xs font-semibold text-muted pt-3.5` + citation block; source line appends publisher and "public".

### 4. Reviewer queue (separate application)
- Header bar `bg-ink text-white`: "Fogbell <span class=text-faint font-medium>Review</span>", "14 rules awaiting judgment" `text-[13px] text-rule`; right: square-outline glyph + "No resident data in this application", reviewer name.
- Body `grid grid-cols-[300px_1fr] min-h-[640px]`.
  - Queue column `bg-white border-r border-rule`: header "Queue · oldest first" / "Filter"; rows `px-5 py-3.5 border-b border-rule flex flex-col gap-1`: code+name `text-sm font-semibold`, second line `text-xs` with provenance glyph+label and "3 sources · 1 conflict". Selected row `bg-window border-l-[3px] border-l-ink`.
  - Judgment panel `px-8 pt-7 pb-9 flex flex-col gap-6`:
    1. Title row, `border-b border-ink pb-4`: "Rule 3 of 14 · MDS 3.0 Section D", rule title `text-2xl`, secondary "Open full rule →".
    2. "Plain-English rendering · as Fogbell applies it": `text-base leading-[1.55]` paragraph.
    3. "Citations · 3": `grid grid-cols-2 gap-2.5` citation blocks, then `text-[13px] text-body` conflict note with square-outline glyph.
    4. "Your judgment": `grid grid-cols-3 gap-2.5` of option cards `border rounded px-4 py-3.5 cursor-pointer` — 14px radio circle `border-2 border-ink` (filled ink when selected), label `text-sm font-semibold` ("Correct" / "Wrong — how?" / "Auditors apply it differently — how?"), helper `text-xs text-body`. Selected: `border-ink bg-window`; unselected `border-rule bg-white`.
    5. When Wrong or Differently is selected, a required textarea appears labeled "How is it wrong?" / "How do auditors apply it differently?" (`border border-rule rounded bg-white px-4 py-3 min-h-[88px] text-sm`).
    6. "Notes · optional" textarea, `min-h-[64px]`, placeholder `text-faint`.
    7. Footer `border-t border-rule pt-4 flex justify-between`: `text-xs text-muted` "Your judgment is recorded with your name and date. A second reviewer confirms before the rule is marked verified." + secondary "Skip for now", primary "Submit judgment".
- This app must never render resident names, IDs, charts or timelines.

---

## Interactions
- Why? disclosure toggles open/closed; default open on first visit.
- Judgment option cards behave as a radio group; the "how" textarea is required unless "Correct" is selected; Submit disabled until valid.
- Hover: primary `bg-body`, secondary `bg-ground`, queue rows `bg-ground`. No transitions longer than 150ms; no motion otherwise.
- Print: everything must read in grayscale. Glyphs carry status; verify a printed Today page still distinguishes stranded (dashed hollow) from counted (filled) evidence.

## State
- Today: list of open windows sorted by days remaining; each with resident label, assessment type, item, look-back, window start, ARD, today, evidence[] (date, inside), finding text.
- Check result: verdict ∈ {supported, partial, unsupported}; suggested code; gaps; evidence inside/outside; rules applied with provenance ∈ {verified, pending, unreviewed}; audit projection numbers.
- Reviewer: selected rule; judgment ∈ {correct, wrong, differs}; how text; notes.

## Content notes
- Copy for Today cards, the audit banner and the S1 citation is the product owner's and is final. Verbatim quotes for S2/S3 and other rules come from extraction; use the italic placeholder text until they exist.
- Evidence quotes, author names, the facility name "Harborlight Care Center", reviewer name and the J1800 supported example are synthetic demo content.

## Assets
None. Figtree via Google Fonts; all glyphs are CSS spans.

## Files
- `Fogbell.dc.html` — the reference design (all four screens, timeline sizes, component sheet).
- `Fogbell Directions.dc.html` — earlier direction exploration; 1b was chosen.

# Rulebook changelog (append-only)

One line per pipeline action or reviewed edit. Newest at the bottom. Format:

`- YYYY-MM-DD · <action> · <ITEM_ID> · doc=<manifest key> pages=<pages> model=<model> · <note>`
- 2026-09-06 · template · ALL · doc=lib/prompts/extract_item.md.erb pages=- model=- · rule 1: federal_coding_rules limited to statements that determine coding or completion (rationale/interpretation/interviewing advice excluded); rule 2: a quote is one contiguous passage, no ellipses. Nothing in rulebook/items/ predates this change.
- 2026-09-06 · extract · D0500 · doc=rai-manual-v1.20.1 pages=all model=claude-opus-5 · written to tmp/first-real/D0500.json
- 2026-09-06 · promote · D0500 · doc=rai-manual-v1.20.1 pages=all model=claude-opus-5 · tmp/first-real/D0500.json -> rulebook/items/D0500.json after schema validation and verify_quotes (image-page quotes checked by eye against rendered pages); MODE=pdf on rai-manual-v1.20.1-secD.pdf; template as of commit a23e4af
- 2026-09-06 · extract · D0600 · doc=rai-manual-v1.20.1 pages=all model=claude-opus-5 · written to tmp/first-real/D0600.json
- 2026-09-06 · promote · D0600 · doc=rai-manual-v1.20.1 pages=all model=claude-opus-5 · tmp/first-real/D0600.json -> rulebook/items/D0600.json after schema validation and verify_quotes (image-page quotes checked by eye against rendered pages); MODE=pdf on rai-manual-v1.20.1-secD.pdf; template as of commit a23e4af
- 2026-09-06 · extract · D0160 · doc=rai-manual-v1.20.1 pages=all model=claude-opus-5 · written to tmp/first-real/D0160.json
- 2026-09-06 · promote · D0160 · doc=rai-manual-v1.20.1 pages=all model=claude-opus-5 · tmp/first-real/D0160.json -> rulebook/items/D0160.json after schema validation and verify_quotes (image-page quotes checked by eye against rendered pages); MODE=pdf on rai-manual-v1.20.1-secD.pdf; template as of commit a23e4af

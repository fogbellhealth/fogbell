# Corpus manifest

Human-curated register of every source document. The `key` column is the `doc` value used in every rulebook citation, so keys are stable, lowercase, version-suffixed, and never reused for a different edition. Files live beside this manifest but are git-ignored; `sha256` (`shasum -a 256 <file>`) is the integrity record.

Status: `TODO` (not yet downloaded) · `BLOCKED-pending-Verifier` (do not acquire or cite until the Verifier rules) · `downloaded` · `extracted` (at least one item cites it) · `superseded` (keep the file; newer edition exists).

URLs marked "likely" were not verified at the time of writing; confirm the landing page and record the exact file URL when downloading.

## Federal (`corpus/federal/`)

| key | title | version / date | source (likely) | downloaded | sha256 | status |
|---|---|---|---|---|---|---|
| `rai-manual-v1.20.1` | Long-Term Care Facility Resident Assessment Instrument 3.0 User's Manual (RAI Manual) | v1.20.1, Oct 2025 | https://www.cms.gov/medicare/quality/nursing-home-improvement/resident-assessment-instrument-manual | 2026-09-06 | `845a42b33644a56ca1002762b54df8173a286bfaeaf16eb269b5e3618da7b92e` | downloaded |
| `rai-manual-v1.20.1-errata` | RAI Manual errata / change tables for the current version | same page | https://www.cms.gov/medicare/quality/nursing-home-improvement/resident-assessment-instrument-manual | | | TODO |
| `rai-manual-v1.17.1` | RAI Manual v1.17.1 — last edition with full Chapter 3 Section G (G0110–G0900) coding instructions; contingent source for G items if Maine audits G via the OSA | v1.17.1, Oct 2019 | https://www.cms.gov/medicare/quality/nursing-home-improvement/resident-assessment-instrument-manual (archived/prior versions section) — confirm | | | BLOCKED-pending-Verifier |
| `mds3-osa-item-set` | MDS 3.0 Optional State Assessment (OSA) item set — carries Section G for states running RUG-based Medicaid case-mix | current (record version) | https://www.cms.gov/medicare/quality/nursing-home-improvement/mds-30-technical-information (item sets) — confirm; Maine's use of the OSA is the Verifier's call | | | BLOCKED-pending-Verifier |
| `mds3-item-sets-v1.20.1` | MDS 3.0 Item Sets (NC, NQ, ND, NP, NT, NO, SP, ST, SD, SO, IPA, OSA) | matching RAI version | https://www.cms.gov/medicare/quality/nursing-home-improvement/mds-30-technical-information | | | TODO |
| `mds3-data-specs-v4.x` | MDS 3.0 Data Submission Specifications (item definitions, valid values, edits) | current V4.x | https://www.cms.gov/medicare/quality/nursing-home-improvement/mds-30-technical-information (also https://qtso.cms.gov/) | | | TODO |
| `mds3-section-s-state-items` | Section S state-optional items: list of which states use which S items | current | https://qtso.cms.gov/ (Section S / state items) — confirm; Maine's own S items are in the Maine submission spec below | | | TODO |
| `pdpm-classification-walkthrough` | PDPM case-mix classification materials (nursing component item mapping) | current | https://www.cms.gov/medicare/payment/prospective-payment-systems/skilled-nursing-facility-snf/patient-driven-payment-model | | | TODO |

### Section cuts of `rai-manual-v1.20.1` (transport artifacts, not sources)

The full manual (33 MB, 1001 pages) exceeds the Anthropic native-PDF limit (32 MB / 600 pages), so each Chapter 3 section is cut into its own file with `script/split_rai_section.py --section <X> --out corpus/federal/rai-manual-v1.20.1-sec<X>.pdf`. **Citations still use doc key `rai-manual-v1.20.1`** with the manual's printed page labels (`p. D-4`); pass `DOC_ID=rai-manual-v1.20.1` to `rulebook:extract`. These keys exist only so the bytes actually sent to the model are on record. All cuts made 2026-09-06 from the sha256 above; every cut starts at label `<X>-1` and its page count equals its last label, so the cut is exactly the labeled section. Section GG is cut but NOT in v1 scope — do not extract from it until the Verifier rules.

| key | section | PDF pages (1-indexed) | printed labels | size | sha256 | status |
|---|---|---|---|---|---|---|
| `rai-manual-v1.20.1-secd` | Section D | 197-215 | D-1 .. D-19 | 1.3 MB | `acc12effc56d810febcbe8c52032daf0d8fdb8f1787361b304110a22c64ca582` | downloaded |
| `rai-manual-v1.20.1-sece` | Section E | 216-238 | E-1 .. E-23 | 1.3 MB | `19a39fe19070f227a673156e935b9d03a69d73e8ff6dcc6455dc2e77a423718f` | downloaded |
| `rai-manual-v1.20.1-secc` | Section C | 162-196 | C-1 .. C-35 | 1.9 MB | `d0a885fed13b5c099b31f5d096b3f8ced26d1b9e2cd70b4d836124dd95a2ebb1` | downloaded |
| `rai-manual-v1.20.1-seck` | Section K | 408-426 | K-1 .. K-19 | 1.1 MB | `21087d2b29a9aceb222f30b69f8718ab85197bfd396fa7e5212677267b59b703` | downloaded |
| `rai-manual-v1.20.1-secm` | Section M | 430-473 | M-1 .. M-44 | 2.2 MB | `96bfb0e63ea4593a49d30ea41523ff142a1b62d2ff649c95cc43f82423321327` | downloaded |
| `rai-manual-v1.20.1-secn` | Section N | 474-501 | N-1 .. N-28 | 1.4 MB | `c900467f16563c3ebbd54c8acb026cc96487525ff913fcd21d2fdcd721d8ff23` | downloaded |
| `rai-manual-v1.20.1-seco` | Section O | 502-551 | O-1 .. O-50 | 2.5 MB | `a4bed125601877585ccf810d5320c4776066fa7aa1fecb89e54bb99a4251802d` | downloaded |
| `rai-manual-v1.20.1-secgg` | Section GG | 257-323 | GG-1 .. GG-67 | 7.6 MB | `5ec11e95bd8beb02b162acc9465f208c90dae18aa5cab1991843e1647a6e45dc` | downloaded |
| `rai-manual-v1.20.1-seci` | Section I | 339-356 | I-1 .. I-18 | 1.6 MB | `22933649c3bcf097fa3892b616fd93b541a88d5373da081bff3a88aff6b7bbb4` | downloaded |
| `rai-manual-v1.20.1-ch2-observation-period` | Chapter 2 pp. 2-9–2-21: assessment types, ARD, observation/look-back period definitions and the assessment summary table | 30-42 | 2-9 .. 2-21 | 0.4 MB | `32fb27639aec37e101e806da6db6c54a5b91867953f87e595bf2c7548a16d7c5` | downloaded |
| `rai-manual-v1.20.1-ch3-conventions` | Chapter 3 pp. 3-1–3-4: 3.1–3.3 including Coding Conventions | 80-83 | 3-1 .. 3-4 | 0.4 MB | `7ddccea53bb7e0b22bb509cb7df5e22f3a0049c97ce94f36b598c03950b5d8e1` | downloaded |

## Maine (`corpus/maine/`)

| key | title | version / date | source (likely) | downloaded | sha256 | status |
|---|---|---|---|---|---|---|
| `mainecare-101-ii-67` | MaineCare Benefits Manual, Chapter 101, Chapter II, Section 67: Nursing Facility Services | LUP 09.15.2014 (per filename; effective date to confirm inside) | https://www.maine.gov/sos/sites/maine.gov.sos/files/inline-files/c2s067-LUP%2009.15.2014%20NSC.docx — Word file at `mainecare-101-ii-67.docx`; `script/docx_to_txt.py` produces the `.txt` the pipeline reads | 2026-09-06 | `641f25a1d503ccb12ed09dea48df41d7436b8acc8961ee80f0325a8d3f3fb7ae` (docx) | downloaded |
| `mainecare-101-iii-67` | MaineCare Benefits Manual, Chapter 101, Chapter III, Section 67: Principles of Reimbursement for Nursing Facilities (case-mix, RUG/PDPM rules, MDS audit) | amended eff. 2025-04-21 (filing 2025-091); nonsubstantive corrections 2026-05-14 (per document history) | https://www.maine.gov/sos/sites/maine.gov.sos/files/inline-files/c3s067-2025-091%20NSC.docx — Word file at `mainecare-101-iii-67.docx`; `script/docx_to_txt.py` produces the `.txt` the pipeline reads | 2026-09-06 | `467d80274fdebbfa911f31f54baeb5144b4a87aac3cd682f1039653a8a2edea5` (docx) | downloaded |
| `mainecare-101-ii-97` | MaineCare Benefits Manual, Chapter 101, Chapter II, Section 97: Private Non-Medical Institution Services | current adopted rule | https://www.maine.gov/sos/cec/rules/10/ch101.htm (Ch. II §97) | | | TODO |
| `mainecare-101-ii-97-appx-c` | Section 97 Appendix C: Residential Care Facilities (MDS-RCA requirement lives here) | current adopted rule | https://www.maine.gov/sos/cec/rules/10/ch101.htm (Ch. II §97 Appendix C) | | | TODO |
| `mainecare-101-iii-97` | MaineCare Benefits Manual, Chapter 101, Chapter III, Section 97: Principles of Reimbursement for PNMIs (Appendix C rates / case-mix) | current adopted rule | https://www.maine.gov/sos/cec/rules/10/ch101.htm (Ch. III §97) | | | TODO |
| `mds-rca-form` | Maine MDS-RCA (Residential Care Assessment) form / item set | current | Cutler Institute, USM (Muskie School): https://cutlerinstitute.usm.maine.edu/ and Maine DHHS OADS pages — confirm exact page | | | TODO |
| `mds-rca-manual` | MDS-RCA training / user manual | current | Cutler Institute, USM — confirm | | | TODO |
| `mds-ah-draft` | Draft MDS-AH (Assisted Housing) form and guidance | draft, record date | Cutler Institute, USM / Maine DHHS OADS — confirm | | | TODO |
| `maine-mds-submission-spec` | Maine MDS 3.0 data submission specifications, including Maine Section S items | current | Maine DHHS Division of Licensing and Certification / Maine MDS help desk pages: https://www.maine.gov/dhhs/dlc/ — confirm | | | TODO |
| `maine-case-mix-audit-guidance` | Maine case-mix MDS review / audit procedures (supporting documentation standards) | current | Maine DHHS DLC or OADS; may arrive via the Verifier instead (see Insider) | | | TODO |

## Other states (`corpus/other-states/`)

Not v1 scope. Add a row here before adding a file.

| key | title | version / date | source | downloaded | sha256 | status |
|---|---|---|---|---|---|---|

## Insider (`corpus/insider/`)

Materials arriving from the Verifier. Possibly non-public; never containing real resident data (redact first, note it here). Record each with a sha256 exactly like the public documents. Citations may point at these keys; the review page will show the Verifier which claims rest on insider material.

| key | title | version / date | provided by | received | sha256 | status |
|---|---|---|---|---|---|---|
| | *(empty — awaiting Verifier materials)* | | | | | |

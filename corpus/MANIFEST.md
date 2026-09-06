# Corpus manifest

Human-curated register of every source document. The `key` column is the `doc` value used in every rulebook citation, so keys are stable, lowercase, version-suffixed, and never reused for a different edition. Files live beside this manifest but are git-ignored; `sha256` (`shasum -a 256 <file>`) is the integrity record.

Status: `TODO` (not yet downloaded) · `downloaded` · `extracted` (at least one item cites it) · `superseded` (keep the file; newer edition exists).

URLs marked "likely" were not verified at the time of writing; confirm the landing page and record the exact file URL when downloading.

## Federal (`corpus/federal/`)

| key | title | version / date | source (likely) | downloaded | sha256 | status |
|---|---|---|---|---|---|---|
| `rai-manual-v1.20.1` | Long-Term Care Facility Resident Assessment Instrument 3.0 User's Manual (RAI Manual) | v1.20.1, Oct 2025 | https://www.cms.gov/medicare/quality/nursing-home-improvement/resident-assessment-instrument-manual | 2026-09-06 | `845a42b33644a56ca1002762b54df8173a286bfaeaf16eb269b5e3618da7b92e` | downloaded |
| `rai-manual-v1.20.1-errata` | RAI Manual errata / change tables for the current version | same page | https://www.cms.gov/medicare/quality/nursing-home-improvement/resident-assessment-instrument-manual | | | TODO |
| `mds3-item-sets-v1.20.1` | MDS 3.0 Item Sets (NC, NQ, ND, NP, NT, NO, SP, ST, SD, SO, IPA, OSA) | matching RAI version | https://www.cms.gov/medicare/quality/nursing-home-improvement/mds-30-technical-information | | | TODO |
| `mds3-data-specs-v4.x` | MDS 3.0 Data Submission Specifications (item definitions, valid values, edits) | current V4.x | https://www.cms.gov/medicare/quality/nursing-home-improvement/mds-30-technical-information (also https://qtso.cms.gov/) | | | TODO |
| `mds3-section-s-state-items` | Section S state-optional items: list of which states use which S items | current | https://qtso.cms.gov/ (Section S / state items) — confirm; Maine's own S items are in the Maine submission spec below | | | TODO |
| `pdpm-classification-walkthrough` | PDPM case-mix classification materials (nursing component item mapping) | current | https://www.cms.gov/medicare/payment/prospective-payment-systems/skilled-nursing-facility-snf/patient-driven-payment-model | | | TODO |

## Maine (`corpus/maine/`)

| key | title | version / date | source (likely) | downloaded | sha256 | status |
|---|---|---|---|---|---|---|
| `mainecare-101-ii-67` | MaineCare Benefits Manual, Chapter 101, Chapter II, Section 67: Nursing Facility Services | current adopted rule (record effective date) | https://www.maine.gov/sos/cec/rules/10/ch101.htm (Ch. II §67) | | | TODO |
| `mainecare-101-iii-67` | MaineCare Benefits Manual, Chapter 101, Chapter III, Section 67: Principles of Reimbursement for Nursing Facilities (case-mix, RUG/PDPM rules, MDS audit) | current adopted rule | https://www.maine.gov/sos/cec/rules/10/ch101.htm (Ch. III §67) | | | TODO |
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

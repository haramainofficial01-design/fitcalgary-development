# Phase 2 Client-approved data import

Verified 2026-09-07 against the three supplied JSON files. The JSON sources are authoritative; the supplied PDF exports were used only as reference.

## Import result

| Dataset | Supplied | Imported | Skipped | Duplicate source IDs |
|---|---:|---:|---:|---:|
| Gyms | 273 | 273 | 0 | 0 |
| Sport clubs | 743 | 743 | 0 | 0 |
| Competitions | 531 | 531 | 0 | 0 |
| **Total** | **1,547** | **1,547** | **0** | **0** |

Seven club-name groups contain eight additional distinct records. They were retained separately using their Client source IDs rather than incorrectly merged.

## Mapping and data quality

- Public product tables contain the supported searchable/display fields; every original JSON object is also retained in `client_source_records` with dataset, source ID, entity ID and import metadata.
- 120 gyms have a comparable supplied price record. The other 153 correctly show contact-for-pricing behavior. No zero price was inserted for unknown, quoted or blank values.
- The competition source provides human schedule descriptions rather than a consistent exact event timestamp. All 531 remain `UNSCHEDULED`; the supplied wording is preserved in the description and no date/time is fabricated.
- Blank, quote-only and unknown values remain absent. Missing links are hidden. HTTP(S) links are preserved as source/event websites.
- Existing development fixture infrastructure remains available for automated tests, but fixture records are archived from the normal published catalog.

## Verification

- Import completed twice against PostgreSQL with identical counts, demonstrating idempotence.
- Public gym search/filter/detail, club search/filter/detail and competition search/filter/detail returned Client records.
- Saved-gym state survived an import rerun; admin catalog access returned the imported records.
- Go tests, vet and builds passed; Flutter analysis and targeted catalog widget tests passed; web typecheck, lint and production build passed.

No supplied record failed validation and no source field was silently discarded: fields without a direct public schema column remain available in the provenance payload for later administration/import evolution.

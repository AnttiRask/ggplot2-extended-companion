## Context

The Notion database export is available at `data-raw/notion_export_part_1.csv` (455 rows, 14 columns). A second file (`_part_2`) is identical. The export uses display-name categories with commas and spaces (e.g., "scales and guides", "interactive plots"). The target format for `packages_curated.csv` uses snake_case pipe-separated categories (e.g., "scales_and_guides|interactive_plots").

Key data observations from analysis:
- 455 packages, all with names
- 437/455 have categories (18 empty → map to "na")
- No `is_essential` or `date_added` columns in Notion
- Categories use 19 distinct display names matching our `categories.csv` (after snake_case conversion)
- Some packages have multiple comma-separated categories

## Goals / Non-Goals

**Goals:**
- Produce `packages_curated.csv` with all 455 packages, correctly formatted
- Build reusable validation functions in `R/fct_validation.R` that can be used in CI
- Every package has at least one valid category
- Migration script is idempotent — can be re-run safely

**Non-Goals:**
- No manual curation of `is_essential` flags (all default to `FALSE`; manual curation happens later)
- No fetching of live data from APIs (that's M2)
- No changes to the categories list itself (already finalised in M0)
- No `date_added` precision — all existing packages get today's date as their add date

## Decisions

### 1. Category mapping: display name → snake_case lookup table

**Decision**: Build a lookup table from `categories.csv` that maps `display_name` → `category` (snake_case). Parse the Notion comma-separated categories, look up each one, and join with pipe separator.

**Rationale**: Direct string replacement is fragile. A lookup table is explicit, testable, and will catch any categories that don't match the canonical list.

**Alternative**: Regex-based conversion (e.g., `tolower() |> gsub(" ", "_")`) — rejected because it wouldn't catch typos or non-canonical values.

### 2. Validation as package functions, not script-only

**Decision**: Validation logic goes in `R/fct_validation.R` as exported-or-internal functions, tested with testthat. The migration script calls these functions, and CI can call them too.

**Rationale**: SPEC section 4.4 requires validation as a CI step on push/PR. Functions in the package are testable and reusable. A standalone script would duplicate logic.

### 3. Use `notes` column for original Notion metadata

**Decision**: The curated CSV includes a `notes` column (from SPEC section 3.1 mention of `packages_curated.csv`). Store any migration-relevant info there (e.g., "no category in Notion" for the 18 uncategorized packages).

**Rationale**: Preserves provenance without cluttering the primary fields.

## Risks / Trade-offs

- **[Risk] Category display names may not match exactly** → Mitigated by the lookup table approach. Any unmatched categories will cause the validation to fail loudly rather than silently dropping data.
- **[Risk] Notion export may have encoding issues** → Read with `UTF-8` encoding explicitly. The data looks clean from initial analysis.
- **[Risk] Multi-line descriptions in Notion CSV** → Some `Short.description` values span multiple lines. Use `read.csv()` with proper quoting to handle this.

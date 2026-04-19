## Context

The ggplot2 extended companion app has a curated CSV (`data-raw/packages_curated.csv`) as its source of truth for ~455 packages. The CSV already has an `is_essential` boolean column with corresponding validation. We need to add an analogous `is_archived` column to mark packages that are no longer viable for use. This is the data foundation for the archived packages UI (M2).

## Goals / Non-Goals

**Goals:**
- Add `is_archived` column to `packages_curated.csv` with valid TRUE/FALSE values for all rows
- Validate the column using the same pattern as `validate_is_essential()`
- Integrate validation into the existing `validate_curated_csv()` function
- Maintain backward compatibility with the pipeline

**Non-Goals:**
- UI changes (handled by M2: Archived Packages — UI)
- Pipeline modifications to propagate `is_archived` to parquet (handled by M3: Non-CRAN Enrichment)
- Deciding which specific packages to mark as archived (maintainer decision)

## Decisions

**1. Mirror the `validate_is_essential()` pattern exactly**
- Rationale: Consistency with existing code. The validation function structure (`list(valid, errors)`) is established. The column has identical constraints (logical, no NAs).
- Alternative: A generic `validate_boolean_column()` — rejected as over-engineering for two columns.

**2. Add `is_archived` column with all FALSE defaults initially**
- Rationale: No packages should disappear from the directory until the maintainer explicitly marks them. The maintainer will mark ~10 packages during implementation.
- Alternative: Pre-populate based on CRAN archive status — rejected because `is_archived` is an editorial decision independent of CRAN status (per spec §3.1).

**3. Position `validate_is_archived()` after `validate_is_essential()` in the checks list**
- Rationale: Logical grouping of boolean column validators. Matches the column order in the CSV.

## Risks / Trade-offs

- [Risk] CSV edited manually without `is_archived` column → Mitigated by `validate_curated_csv()` catching missing column
- [Risk] Non-logical values in `is_archived` (e.g., "yes"/"no" strings from CSV editing) → Mitigated by `read.csv(stringsAsFactors = FALSE)` + explicit `is.logical()` check. Note: R reads TRUE/FALSE from CSV as logical automatically.

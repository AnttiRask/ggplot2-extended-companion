## Why

The app needs its source-of-truth package list (`data-raw/packages_curated.csv`) populated with the ~455 ggplot2 extension packages currently tracked in a Notion database. Without this data, no downstream milestones (pipeline, UI, detail views) can function. The Notion export is available as CSV files — the migration must clean, transform, and validate this data into the format expected by the pipeline (M2) and app (M3+).

## What Changes

- Create `data-raw/migrate_notion.R` — a migration script that reads the Notion CSV export, transforms columns (rename, remap categories from display names to snake_case, add missing fields), and writes `data-raw/packages_curated.csv`
- Create `data-raw/packages_curated.csv` — the populated curated package list (~455 rows) with columns: `package_name`, `categories` (pipe-separated snake_case), `is_essential`, `website_url`, `repo_url`, `date_added`
- Create `R/fct_validation.R` — reusable CSV validation functions for CI and development use
- Create `tests/testthat/test-fct_validation.R` — tests for all validation rules
- The existing `data-raw/categories.csv` (19 categories from M0) serves as the canonical category reference

## Capabilities

### New Capabilities
- `notion-migration`: Migration script that transforms Notion CSV export into the curated CSV format
- `csv-validation`: Validation functions that enforce data integrity rules on packages_curated.csv (no duplicates, valid categories, required fields, well-formed pipe-separation)

### Modified Capabilities
<!-- None — M0 capabilities are unchanged -->

## Impact

- **New files**: `data-raw/migrate_notion.R`, `data-raw/packages_curated.csv`, `R/fct_validation.R`, `tests/testthat/test-fct_validation.R`
- **Input data**: `data-raw/notion_export_part_1.csv` (455 packages, 14 columns)
- **Dependencies**: No new package dependencies — uses base R and tidyverse (dplyr already in DESCRIPTION)
- **Downstream**: `packages_curated.csv` becomes the input for the M2 data pipeline (`read_curated_csv()` target)

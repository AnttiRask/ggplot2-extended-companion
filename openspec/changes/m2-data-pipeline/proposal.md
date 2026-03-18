## Why

The app needs live package metadata (descriptions, versions, licenses, download counts, GitHub activity) that can't be stored in the curated CSV. M2 builds the data pipeline that fetches this data from CRAN, cranlogs, and GitHub APIs, merges it with the curated data, and writes Parquet files that the Shiny app will read at startup.

## What Changes

- Create `R/fct_pipeline.R` — functions to fetch CRAN metadata, download stats, and GitHub metadata for all ~455 packages, with per-package error handling
- Create `R/fct_urls.R` — URL construction functions (CRAN page, reference manual, vignettes)
- Create `_targets.R` — {targets} pipeline definition with DAG from curated CSV → API fetches → merge → Parquet output
- Create `tests/testthat/test-fct_pipeline.R` and `test-fct_urls.R` with mocked API responses
- Create `tests/testthat/fixtures/` with mock API response files
- Produce `data/packages.parquet`, `data/downloads.parquet`, `data/metadata.parquet`

## Capabilities

### New Capabilities
- `pipeline-fetch`: Functions to fetch CRAN metadata, download stats, and GitHub metadata with error handling
- `url-construction`: Pattern-based URL construction for CRAN, reference manual, and vignette URLs
- `pipeline-orchestration`: {targets} DAG definition that orchestrates the full pipeline
- `parquet-output`: Functions to merge data and write Parquet output files

### Modified Capabilities
<!-- None -->

## Impact

- **New dependencies**: targets, pkgsearch, cranlogs (added to DESCRIPTION)
- **New files**: R/fct_pipeline.R, R/fct_urls.R, _targets.R, test files, fixtures, Parquet outputs
- **External APIs**: CRAN (pkgsearch), cranlogs, GitHub (gh) — all with rate-limiting considerations
- **Downstream**: Parquet files are read by fct_data.R (M3) for the Shiny app

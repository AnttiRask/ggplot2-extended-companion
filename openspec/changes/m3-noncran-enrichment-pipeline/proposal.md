## Why

Non-CRAN packages (~115 of 456) currently have missing metadata (title, description, license, maintainer, version) because the pipeline only fetches from the CRAN API. By fetching DESCRIPTION files from GitHub, we can fill in these gaps and provide a unified `version` field across all packages.

## What Changes

- Add `desc` package dependency
- New `fetch_github_descriptions()` function: fetches and parses GitHub DESCRIPTION files for non-CRAN packages, caches results
- Update `merge_package_data()`: accept optional `github_desc` parameter, load from cache on daily runs, derive `version` field
- Update `export_json()`: add `is_archived` and `version` fields to JSON output
- Update `_targets.R`: add step 4.5 (weekly), update step 6 to pass enrichment data

## Capabilities

### New Capabilities
- `github-description-enrichment`: Fetch and parse DESCRIPTION files from GitHub for non-CRAN packages
- `version-derivation`: Derive unified version field from CRAN or GitHub source
- `json-export-v11-fields`: Add is_archived and version to JSON export

### Modified Capabilities

## Impact

- **Code**: `R/fct_pipeline.R`, `_targets.R`
- **Dependencies**: `desc` package added to Imports
- **Data**: New `data/github_descriptions.rds` cache file
- **Tests**: `tests/testthat/test-fct_pipeline.R`, `tests/testthat/test-fct_json.R`

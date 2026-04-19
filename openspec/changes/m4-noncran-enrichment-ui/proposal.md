## Why

M3 added enriched metadata and a unified `version` field to the pipeline. The UI still shows "CRAN Version" labels and "Not available on CRAN." for non-CRAN packages. M4 updates the UI to use source-agnostic labels and display GitHub metadata fallbacks.

## What Changes

- Browse table: rename "CRAN Version" to "Version", display derived `version` field, hide `cran_version` and github_* columns
- Detail view `build_version_card()`: source-agnostic "Latest Version" label, remove "Not available on CRAN" text, show GitHub last updated for all packages
- Detail view `build_header_card()`: fallback to github_* fields for title, description, maintainer, license when CRAN data is NA

## Capabilities

### New Capabilities
- `version-display-rename`: Source-agnostic version display in browse and detail views
- `noncran-metadata-fallbacks`: GitHub metadata fallbacks in detail view header

### Modified Capabilities

## Impact

- **Code**: `R/mod_browse.R`, `R/mod_detail.R`
- **Tests**: No new test files — UI module changes verified by full test suite

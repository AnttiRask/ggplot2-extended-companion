## Why

The ggplot2 extended companion directory includes ~455 packages, but some are no longer actively maintained or viable for use. Users need a way to distinguish archived packages from active ones. Adding `is_archived` to the data model with proper validation ensures data integrity before building the UI layer (M2) on top of it.

## What Changes

- Add `is_archived` boolean column to `data-raw/packages_curated.csv` (all rows default to `FALSE`; maintainer marks ~10 as `TRUE`)
- Add `validate_is_archived()` validation function mirroring existing `validate_is_essential()` pattern
- Integrate `validate_is_archived()` into `validate_curated_csv()` checks list
- Add comprehensive tests for the new validation function
- Add integration test verifying the real CSV passes validation with the new column

## Capabilities

### New Capabilities
- `archived-package-validation`: Validation logic for the `is_archived` column in the curated CSV, ensuring every row has a valid TRUE/FALSE value with no NAs permitted.

### Modified Capabilities
<!-- No existing spec-level capabilities are changing — this adds a new validation check alongside existing ones. -->

## Impact

- **Data**: `data-raw/packages_curated.csv` gains a new column; all downstream pipeline outputs (`packages.parquet`, `packages.json`) will carry `is_archived` through once the pipeline is updated (M3)
- **Code**: `R/fct_validation.R` modified to add new validation function and integrate it
- **Tests**: `tests/testthat/test-fct_validation.R` gains new test cases
- **Dependencies**: None — uses only base R and existing validation patterns

## 1. CSV Data Update

- [x] 1.1 Add `is_archived` column to `data-raw/packages_curated.csv` with all values set to `FALSE`

## 2. Validation Function

- [x] 2.1 Write failing tests for `validate_is_archived()`: valid data, missing column, NA values, non-logical values
- [x] 2.2 Implement `validate_is_archived()` in `R/fct_validation.R` mirroring `validate_is_essential()` pattern
- [x] 2.3 Run tests to confirm they pass

## 3. Integration into validate_curated_csv

- [x] 3.1 Write failing test: `validate_curated_csv()` catches missing `is_archived` column
- [x] 3.2 Add `validate_is_archived()` call to `validate_curated_csv()` checks list (after `validate_is_essential()`)
- [x] 3.3 Run tests to confirm integration test passes

## 4. Integration Test with Real CSV

- [x] 4.1 Add integration test that loads `data-raw/packages_curated.csv` and validates `is_archived` column passes
- [x] 4.2 Run full test suite (`devtools::test()`) to confirm no regressions

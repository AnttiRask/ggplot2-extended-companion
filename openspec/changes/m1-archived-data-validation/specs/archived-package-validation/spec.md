## ADDED Requirements

### Requirement: is_archived column exists in curated CSV
The `data-raw/packages_curated.csv` file SHALL contain an `is_archived` column of type logical for every row.

#### Scenario: Column present with valid values
- **WHEN** `packages_curated.csv` is loaded and all rows have `is_archived` set to `TRUE` or `FALSE`
- **THEN** `validate_is_archived()` SHALL return `list(valid = TRUE, errors = character(0))`

#### Scenario: Column missing from CSV
- **WHEN** `packages_curated.csv` is loaded and the `is_archived` column does not exist
- **THEN** `validate_is_archived()` SHALL return `list(valid = FALSE, errors = "Missing required column: is_archived")`

#### Scenario: Column contains NA values
- **WHEN** `packages_curated.csv` is loaded and one or more rows have `NA` for `is_archived`
- **THEN** `validate_is_archived()` SHALL return `list(valid = FALSE, errors = ...)` with one error message per invalid row identifying the package name

#### Scenario: Column contains non-logical values
- **WHEN** `packages_curated.csv` is loaded and `is_archived` contains non-logical values (e.g., strings)
- **THEN** `validate_is_archived()` SHALL return `list(valid = FALSE, errors = ...)` with one error message per invalid row

### Requirement: validate_curated_csv includes is_archived validation
The `validate_curated_csv()` function SHALL include `validate_is_archived()` in its checks list.

#### Scenario: Integration with existing validation
- **WHEN** `validate_curated_csv()` is called with valid data including `is_archived`
- **THEN** the validation SHALL pass (no errors from `is_archived` check)

#### Scenario: Invalid is_archived caught by validate_curated_csv
- **WHEN** `validate_curated_csv()` is called with data missing the `is_archived` column
- **THEN** the overall validation SHALL fail and include the `is_archived` error in the errors list

### Requirement: Default is_archived value is FALSE
All existing packages in `packages_curated.csv` SHALL default to `is_archived = FALSE`. The maintainer SHALL manually set specific packages to `TRUE`.

#### Scenario: All existing packages default to FALSE
- **WHEN** the `is_archived` column is added to the CSV
- **THEN** all existing rows SHALL have `is_archived = FALSE`

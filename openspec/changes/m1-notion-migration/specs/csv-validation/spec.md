## ADDED Requirements

### Requirement: No duplicate package names
The validation function SHALL detect duplicate `package_name` values.

#### Scenario: Valid CSV with unique names
- **WHEN** `validate_no_duplicates()` is called on a CSV with all unique package names
- **THEN** it SHALL return no errors

#### Scenario: CSV with duplicate names
- **WHEN** `validate_no_duplicates()` is called on a CSV containing duplicate package names
- **THEN** it SHALL return an error identifying the duplicated names

### Requirement: All categories match canonical list
The validation function SHALL verify every category in every row exists in `data-raw/categories.csv`.

#### Scenario: Valid categories
- **WHEN** `validate_categories()` is called on a CSV where all categories are in the canonical list
- **THEN** it SHALL return no errors

#### Scenario: Invalid category detected
- **WHEN** `validate_categories()` is called on a CSV containing a category not in the canonical list
- **THEN** it SHALL return an error identifying the invalid category and which package has it

### Requirement: Required fields are non-empty
The validation function SHALL verify that `package_name`, `categories`, and `date_added` are non-empty for every row.

#### Scenario: All required fields present
- **WHEN** `validate_required_fields()` is called on a CSV with all required fields populated
- **THEN** it SHALL return no errors

#### Scenario: Missing required field
- **WHEN** `validate_required_fields()` is called on a CSV with an empty `package_name`
- **THEN** it SHALL return an error identifying the row with the missing field

### Requirement: is_essential is boolean
The validation function SHALL verify that `is_essential` contains only `TRUE` or `FALSE`.

#### Scenario: Valid boolean values
- **WHEN** `validate_is_essential()` is called on a CSV where all `is_essential` values are TRUE or FALSE
- **THEN** it SHALL return no errors

#### Scenario: Invalid boolean value
- **WHEN** `validate_is_essential()` is called on a CSV with `is_essential` value "yes"
- **THEN** it SHALL return an error identifying the invalid value

### Requirement: Pipe-separated categories are well-formed
The validation function SHALL verify that categories use proper pipe separation (no trailing pipes, no spaces around pipes, no empty segments).

#### Scenario: Well-formed categories
- **WHEN** `validate_category_format()` is called on "geoms|stats|themes"
- **THEN** it SHALL return no errors

#### Scenario: Trailing pipe detected
- **WHEN** `validate_category_format()` is called on "geoms|stats|"
- **THEN** it SHALL return an error

#### Scenario: Spaces around pipes detected
- **WHEN** `validate_category_format()` is called on "geoms | stats"
- **THEN** it SHALL return an error

### Requirement: Top-level validation function runs all checks
A single `validate_curated_csv()` function SHALL run all individual validation checks and return a combined result.

#### Scenario: Valid CSV passes all checks
- **WHEN** `validate_curated_csv()` is called on a valid packages_curated.csv
- **THEN** it SHALL return a result indicating all checks passed

#### Scenario: Invalid CSV reports all failures
- **WHEN** `validate_curated_csv()` is called on a CSV with multiple issues
- **THEN** it SHALL return all errors from all checks (not stop at the first failure)

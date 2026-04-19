## ADDED Requirements

### Requirement: is_featured column exists in curated CSV

The `data-raw/packages_curated.csv` file SHALL contain an `is_featured` column of type logical for every row. The column replaces the v1.1 `is_essential` column with identical values and identical semantics ("packages covered in the companion book").

#### Scenario: Column present with valid values

- **WHEN** `packages_curated.csv` is loaded and all rows have `is_featured` set to `TRUE` or `FALSE`
- **THEN** `validate_is_featured()` SHALL return `list(valid = TRUE, errors = character(0))`

#### Scenario: Column missing from CSV

- **WHEN** `packages_curated.csv` is loaded and the `is_featured` column does not exist
- **THEN** `validate_is_featured()` SHALL return `list(valid = FALSE, errors = "Missing required column: is_featured")`

#### Scenario: Column contains NA values

- **WHEN** `packages_curated.csv` is loaded and one or more rows have `NA` for `is_featured`
- **THEN** `validate_is_featured()` SHALL return `list(valid = FALSE, errors = ...)` with one error message per invalid row identifying the package name

#### Scenario: Column contains non-logical values

- **WHEN** `packages_curated.csv` is loaded and `is_featured` contains non-logical values (e.g., strings)
- **THEN** `validate_is_featured()` SHALL return `list(valid = FALSE, errors = ...)` with one error message per invalid row

### Requirement: validate_curated_csv dispatches validate_is_featured

The `validate_curated_csv()` function SHALL invoke `validate_is_featured()` in its checks list in place of the legacy `validate_is_essential()`.

#### Scenario: Integration with existing validation

- **WHEN** `validate_curated_csv()` is called with valid data including `is_featured`
- **THEN** the validation SHALL pass (no errors from the `is_featured` check)

#### Scenario: Missing is_featured caught by validate_curated_csv

- **WHEN** `validate_curated_csv()` is called with data missing the `is_featured` column
- **THEN** the overall validation SHALL fail and include the `is_featured` error in the errors list

### Requirement: filter_packages uses featured_only argument

The `filter_packages()` function SHALL accept a `featured_only` logical argument (default `FALSE`) in place of `essential_only`, filtering by `.data$is_featured == TRUE` when set.

#### Scenario: featured_only = TRUE keeps only featured packages

- **WHEN** `filter_packages(data, featured_only = TRUE)` is called on data containing both featured and non-featured packages
- **THEN** the returned tibble SHALL contain only rows where `is_featured == TRUE`

#### Scenario: featured_only = FALSE does not filter by featured flag

- **WHEN** `filter_packages(data, featured_only = FALSE)` is called
- **THEN** the returned tibble SHALL NOT be narrowed by the `is_featured` column

### Requirement: JSON export uses is_featured key

The `export_json()` function SHALL write each package object with an `is_featured` key (type logical) in place of the v1.1 `is_essential` key. No dual-key transitional period is provided — this is a hard break called out in v1.2 release notes.

#### Scenario: JSON object has is_featured, not is_essential

- **WHEN** `export_json()` runs
- **THEN** each package object in the output JSON SHALL contain the key `is_featured` and SHALL NOT contain the key `is_essential`

### Requirement: Sidebar exposes Featured in the Book filter

The sidebar module SHALL render a checkbox input with the label `"Featured in the Book"`, namespaced input ID `featured_only`. When checked, the browse view SHALL show only packages with `is_featured == TRUE`.

#### Scenario: Label text on checkbox

- **WHEN** the sidebar UI renders
- **THEN** the "Featured in the Book" label SHALL be visible next to the checkbox

#### Scenario: Checkbox filters the table

- **WHEN** the user checks the "Featured in the Book" checkbox
- **THEN** the browse table SHALL display only packages where `is_featured == TRUE`

### Requirement: Detail view badge reads "Featured in the book"

The detail view module SHALL render a badge with the literal text `"⭐ Featured in the book"` when the current package's `is_featured` field is `TRUE`.

#### Scenario: Featured package detail view

- **WHEN** the detail view renders for a package where `is_featured == TRUE`
- **THEN** a badge containing `"⭐ Featured in the book"` SHALL appear in the header card

#### Scenario: Non-featured package detail view

- **WHEN** the detail view renders for a package where `is_featured == FALSE`
- **THEN** no featured badge SHALL appear in the header card

### Requirement: Browse table cell aria-label reads "Featured in the book"

The browse table's Name column cell SHALL render a star glyph with CSS class `.badge-featured`, `title` attribute, and `aria-label` attribute all equal to `"Featured in the book"` when the row's `is_featured` is `TRUE`.

#### Scenario: Screen reader announces "Featured in the book"

- **WHEN** a screen reader focuses a star glyph in the browse table Name column
- **THEN** the announced label SHALL be `"Featured in the book"`

### Requirement: Zero residual legacy tokens

After the M0 rename lands, the repository SHALL contain no occurrences of the tokens `is_essential`, `essential_only`, `Essential Extension`, or `badge-essential` under `R/`, `inst/`, `tests/`, or `data-raw/`.

#### Scenario: Grep sweep returns no matches

- **WHEN** `grep -rn "is_essential\|essential_only\|Essential Extension\|badge-essential" R/ inst/ tests/ data-raw/` runs
- **THEN** the exit status SHALL be non-zero (no matches found)

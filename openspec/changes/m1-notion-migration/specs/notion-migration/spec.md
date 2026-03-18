## ADDED Requirements

### Requirement: Migration script produces packages_curated.csv
The migration script `data-raw/migrate_notion.R` SHALL read the Notion export and produce a valid `data-raw/packages_curated.csv`.

#### Scenario: Script produces CSV with correct columns
- **WHEN** `source("data-raw/migrate_notion.R")` is executed
- **THEN** `data-raw/packages_curated.csv` SHALL exist with columns: `package_name`, `categories`, `is_essential`, `website_url`, `repo_url`, `date_added`, `notes`

#### Scenario: All 455 packages are migrated
- **WHEN** the output CSV is read
- **THEN** it SHALL contain exactly 455 rows (one per package in the Notion export)

#### Scenario: Package names are preserved exactly
- **WHEN** the output CSV is read
- **THEN** the `package_name` column SHALL contain the exact values from the Notion `Name` column

### Requirement: Categories are converted to snake_case pipe-separated format
The migration script SHALL convert Notion's comma-separated display-name categories to pipe-separated snake_case identifiers matching `data-raw/categories.csv`.

#### Scenario: Single category conversion
- **WHEN** a Notion row has Category "scales and guides"
- **THEN** the output `categories` value SHALL be "scales_and_guides"

#### Scenario: Multiple category conversion
- **WHEN** a Notion row has Category "animation, interactive plots"
- **THEN** the output `categories` value SHALL be "animation|interactive_plots"

#### Scenario: Empty category mapping
- **WHEN** a Notion row has an empty Category field
- **THEN** the output `categories` value SHALL be "na"

### Requirement: Missing fields have sensible defaults
The migration script SHALL add fields not present in the Notion export.

#### Scenario: is_essential defaults to FALSE
- **WHEN** the output CSV is read
- **THEN** all `is_essential` values SHALL be `FALSE`

#### Scenario: date_added is set
- **WHEN** the output CSV is read
- **THEN** all `date_added` values SHALL be a valid date string

### Requirement: URL fields are mapped correctly
The migration script SHALL map Notion URL columns to curated CSV URL columns.

#### Scenario: Website URL mapping
- **WHEN** a Notion row has a Website value
- **THEN** the output `website_url` SHALL contain that value

#### Scenario: Repo URL mapping
- **WHEN** a Notion row has a GitHub.GitLab value
- **THEN** the output `repo_url` SHALL contain that value

#### Scenario: Missing URLs are NA
- **WHEN** a Notion row has an empty Website or GitHub.GitLab value
- **THEN** the corresponding output field SHALL be NA

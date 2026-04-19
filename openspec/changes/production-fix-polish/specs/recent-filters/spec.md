## ADDED Requirements

### Requirement: Recently Added sidebar checkbox filter
The sidebar SHALL include a "Recently Added" checkbox. When checked, the browse table SHALL show only packages where `date_added` is within the past 7 days of the current date.

#### Scenario: Recently Added filter shows new packages
- **WHEN** the user checks the "Recently Added" checkbox
- **THEN** the table shows only packages with `date_added >= Sys.Date() - 7`

#### Scenario: Recently Added filter unchecked shows all
- **WHEN** the "Recently Added" checkbox is unchecked
- **THEN** the filter has no effect on the table results

### Requirement: Recently Updated sidebar checkbox filter
The sidebar SHALL include a "Recently Updated" checkbox. When checked, the browse table SHALL show only packages where `max(cran_published, github_updated)` is within the past 7 days of the current date.

#### Scenario: Recently Updated filter shows updated packages
- **WHEN** the user checks the "Recently Updated" checkbox
- **THEN** the table shows only packages where the most recent of `cran_published` and `github_updated` is within 7 days of the current date

#### Scenario: Package with only CRAN update
- **WHEN** a package has `cran_published` within 7 days but `github_updated` is older than 7 days
- **THEN** the package is flagged as `recently_updated = TRUE`

#### Scenario: Package with only GitHub update
- **WHEN** a package has `github_updated` within 7 days but `cran_published` is older or NA
- **THEN** the package is flagged as `recently_updated = TRUE`

### Requirement: OR logic between Recently Added and Recently Updated
When both "Recently Added" and "Recently Updated" checkboxes are checked simultaneously, the table SHALL show the union (OR) of packages matching either flag. This OR logic applies only between these two checkboxes — all other sidebar filters (category, CRAN status, license, essential) remain AND-composed.

#### Scenario: Both recent checkboxes checked shows union
- **WHEN** both "Recently Added" and "Recently Updated" are checked
- **THEN** the table shows packages matching `recently_added == TRUE OR recently_updated == TRUE`

#### Scenario: Recent filters compose with other filters via AND
- **WHEN** "Recently Added" is checked AND category is set to "Geoms"
- **THEN** the table shows only packages that are both recently added AND in the Geoms category

### Requirement: Derived flags computed at app startup
The `recently_added` and `recently_updated` flags SHALL be computed at data load time in `load_app_data()`, not stored in the Parquet files. The 7-day window is relative to the current date.

#### Scenario: Flags are fresh on each app startup
- **WHEN** the app starts and loads data from Parquet
- **THEN** `recently_added` is computed as `date_added >= Sys.Date() - 7` and `recently_updated` is computed as `pmax(cran_published, github_updated, na.rm = TRUE) >= Sys.Date() - 7`

#### Scenario: Flags are not persisted to Parquet
- **WHEN** the pipeline writes `data/packages.parquet`
- **THEN** the file does NOT contain `recently_added` or `recently_updated` columns

### Requirement: Recently Added/Updated cards removed
The existing "Recently Added" and "Recently Updated" cards above the browse table (rendered by `mod_recent.R`) SHALL be removed. The `R/mod_recent.R` file SHALL be deleted. The browse table SHALL occupy the space previously held by these cards.

#### Scenario: No recent cards above table
- **WHEN** the app loads in browse view
- **THEN** the browse table appears directly below the header intro text with no cards between them

#### Scenario: mod_recent module removed
- **WHEN** the codebase is inspected
- **THEN** `R/mod_recent.R` does not exist and no code references `mod_recent_ui` or `mod_recent_server`

## ADDED Requirements

### Requirement: filter_packages hides archived packages by default
`filter_packages()` SHALL accept a `show_archived` parameter (default FALSE). When FALSE, packages with `is_archived == TRUE` SHALL be excluded.

#### Scenario: Default hides archived
- **WHEN** `filter_packages()` is called with default `show_archived = FALSE` and data contains archived packages
- **THEN** archived packages SHALL NOT appear in the result

#### Scenario: show_archived TRUE includes archived
- **WHEN** `filter_packages()` is called with `show_archived = TRUE`
- **THEN** archived packages SHALL appear in the result alongside non-archived packages

#### Scenario: Composes with other filters via AND
- **WHEN** `show_archived = TRUE` and other filters are active (e.g., category, CRAN status)
- **THEN** archived packages SHALL be subject to all other active filters normally

### Requirement: Sidebar has Show Archived Packages checkbox
The sidebar SHALL include a "Show Archived Packages" checkbox, unchecked by default, positioned after the "Recently Updated" checkbox.

#### Scenario: Checkbox default state
- **WHEN** the app loads
- **THEN** the "Show Archived Packages" checkbox SHALL be unchecked

### Requirement: app_server passes show_archived to filter_packages
`app_server.R` SHALL read `sidebar_values$show_archived()` and pass it to `filter_packages()`.

#### Scenario: Toggling checkbox updates filter
- **WHEN** user checks "Show Archived Packages"
- **THEN** `filter_packages()` SHALL be called with `show_archived = TRUE`

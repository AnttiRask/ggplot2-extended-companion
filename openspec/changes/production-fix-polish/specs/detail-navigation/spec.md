## ADDED Requirements

### Requirement: Previous and next navigation arrows
The package detail view SHALL include "← Prev" and "Next →" navigation buttons that move between packages in alphabetical order by `package_name`.

#### Scenario: Navigate to next package
- **WHEN** a user is viewing package "ggrepel" and clicks "Next →"
- **THEN** the detail view updates to show the next package alphabetically after "ggrepel"

#### Scenario: Navigate to previous package
- **WHEN** a user is viewing package "ggrepel" and clicks "← Prev"
- **THEN** the detail view updates to show the previous package alphabetically before "ggrepel"

#### Scenario: URL updates on navigation
- **WHEN** a user clicks "Next →" or "← Prev"
- **THEN** the browser URL updates to `?package={new_package_name}`

### Requirement: Navigation boundary handling
At the first and last packages in alphabetical order, the corresponding navigation arrow SHALL be disabled.

#### Scenario: First package disables previous button
- **WHEN** a user is viewing the first package alphabetically in the full package list
- **THEN** the "← Prev" button is disabled (greyed out, not clickable)

#### Scenario: Last package disables next button
- **WHEN** a user is viewing the last package alphabetically in the full package list
- **THEN** the "Next →" button is disabled (greyed out, not clickable)

### Requirement: Navigation arrows use full package list
The navigation arrows SHALL traverse the complete alphabetically-sorted list of all packages, regardless of current sidebar filter state. The navigation order is always alphabetical by `package_name`.

#### Scenario: Navigation ignores filters
- **WHEN** the sidebar has category filter set to "Geoms" and the user navigates via arrows
- **THEN** the arrows move through ALL packages alphabetically, not just Geoms packages

### Requirement: Navigation arrow placement
The navigation arrows SHALL be displayed alongside the back button in a horizontal flex row at the top of the detail view.

#### Scenario: Arrow button layout
- **WHEN** the detail view renders
- **THEN** "← Back to all packages", "← Prev", and "Next →" appear in a horizontal row at the top of the detail view

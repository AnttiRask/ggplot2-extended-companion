## ADDED Requirements

### Requirement: Browse table shows archived emoji
Archived packages in the browse table SHALL display a 📁 emoji before the package name, after any ⭐ essential badge.

#### Scenario: Archived package in browse table
- **WHEN** an archived package appears in the browse table
- **THEN** it SHALL show 📁 before the package name link

### Requirement: Detail view shows archived badge
Archived packages in the detail view header SHALL display a "📁 Archived Package" badge (bg-secondary) alongside any essential badge.

#### Scenario: Archived package detail header
- **WHEN** user views an archived package's detail view
- **THEN** the header SHALL include a "📁 Archived Package" badge

### Requirement: Detail view shows archived warning banner
Archived packages SHALL display a warning banner above the header card with "This package is no longer actively maintained." and the notes field content when populated.

#### Scenario: Archived package with notes
- **WHEN** user views an archived package with non-empty notes
- **THEN** the warning banner SHALL show the notes text below the warning message

#### Scenario: Archived package without notes
- **WHEN** user views an archived package with empty/NA notes
- **THEN** the warning banner SHALL show only the warning message

### Requirement: is_archived hidden in browse table
The `is_archived` column SHALL be hidden in the browse table (present in data but not displayed as a column).

#### Scenario: Column hidden
- **WHEN** the browse table renders
- **THEN** `is_archived` SHALL NOT be visible as a table column

## ADDED Requirements

### Requirement: Browse table shows Version column
The browse table SHALL display a "Version" column using the derived `version` field. The `cran_version` column SHALL be hidden.

#### Scenario: CRAN package version displayed
- **WHEN** a CRAN package has version="0.9.6"
- **THEN** the Version column SHALL show "0.9.6"

#### Scenario: Non-CRAN package with GitHub version
- **WHEN** a non-CRAN package has version="0.2.1" (from GitHub)
- **THEN** the Version column SHALL show "0.2.1"

### Requirement: Detail view shows Latest Version
The version card SHALL show "Latest Version:" instead of "Latest CRAN version:" and SHALL NOT show "Not available on CRAN." for non-CRAN packages.

#### Scenario: Version card for any package
- **WHEN** a package has a version value
- **THEN** the card SHALL show "Latest Version: X.Y.Z"

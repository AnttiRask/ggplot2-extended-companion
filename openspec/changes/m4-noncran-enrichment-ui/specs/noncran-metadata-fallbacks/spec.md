## ADDED Requirements

### Requirement: Header card uses GitHub fallbacks for non-CRAN packages
For title, description, maintainer, and license: the header card SHALL prefer CRAN data, falling back to github_* fields when CRAN data is NA.

#### Scenario: CRAN package shows CRAN data
- **WHEN** a CRAN package has title from CRAN
- **THEN** the CRAN title SHALL be displayed (not GitHub)

#### Scenario: Non-CRAN package shows GitHub data
- **WHEN** a non-CRAN package has github_title but no CRAN title
- **THEN** the github_title SHALL be displayed

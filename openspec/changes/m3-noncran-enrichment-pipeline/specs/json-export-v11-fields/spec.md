## ADDED Requirements

### Requirement: export_json includes is_archived and version
`export_json()` SHALL include `is_archived` and `version` fields in each package's JSON object.

#### Scenario: Package with is_archived and version
- **WHEN** a package has is_archived=TRUE and version="1.0.0"
- **THEN** the JSON output SHALL include is_archived: true and version: "1.0.0"

#### Scenario: Package with NA version
- **WHEN** a package has version=NA
- **THEN** the JSON output SHALL include version: null

## ADDED Requirements

### Requirement: merge_package_data derives version field
`merge_package_data()` SHALL derive a `version` field using CRAN version for CRAN packages and GitHub version for non-CRAN packages.

#### Scenario: CRAN package gets cran_version
- **WHEN** on_cran is TRUE and cran_version is not NA
- **THEN** version SHALL equal cran_version

#### Scenario: Non-CRAN package gets github_version
- **WHEN** on_cran is FALSE and github_version is not NA
- **THEN** version SHALL equal github_version

#### Scenario: No version available
- **WHEN** neither cran_version nor github_version is available
- **THEN** version SHALL be NA_character_

### Requirement: merge_package_data loads cached enrichment on daily runs
When github_desc is NULL, `merge_package_data()` SHALL attempt to load from github_desc_cache_path. If the file doesn't exist, it SHALL proceed without enrichment.

#### Scenario: Daily run with cache available
- **WHEN** github_desc is NULL and cache file exists
- **THEN** cached enrichment data SHALL be loaded and joined

#### Scenario: Daily run without cache
- **WHEN** github_desc is NULL and cache file doesn't exist
- **THEN** the function SHALL proceed without github_* fields

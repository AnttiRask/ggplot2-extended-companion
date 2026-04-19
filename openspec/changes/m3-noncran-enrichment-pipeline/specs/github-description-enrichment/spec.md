## ADDED Requirements

### Requirement: fetch_github_descriptions returns enrichment tibble
`fetch_github_descriptions()` SHALL return a tibble with columns: package_name, github_title, github_description, github_license, github_maintainer, github_version for all input packages.

#### Scenario: Non-CRAN package with GitHub repo
- **WHEN** a package has on_cran=FALSE and repo_url containing github.com
- **THEN** the function SHALL fetch and parse its DESCRIPTION file, returning extracted fields

#### Scenario: CRAN package returns NA fields
- **WHEN** a package has on_cran=TRUE
- **THEN** all github_* fields SHALL be NA (no API call made)

#### Scenario: Non-GitHub repo returns NA fields
- **WHEN** a package has no repo_url or a non-GitHub repo_url
- **THEN** all github_* fields SHALL be NA (no API call made)

#### Scenario: API error returns NA row with warning
- **WHEN** the GitHub API returns a 404 or other error for a package
- **THEN** the function SHALL log a warning and return NA fields for that package

#### Scenario: Results cached to disk
- **WHEN** the function completes
- **THEN** the result SHALL be saved to cache_path via saveRDS()

## ADDED Requirements

### Requirement: read_curated_csv reads the curated package list
`read_curated_csv()` SHALL read `data-raw/packages_curated.csv` and return a tibble.

#### Scenario: Successful read
- **WHEN** `read_curated_csv()` is called
- **THEN** it SHALL return a tibble with 455 rows and columns including `package_name`, `categories`, `is_essential`, `website_url`, `repo_url`, `date_added`

### Requirement: fetch_cran_metadata retrieves CRAN data for all packages
`fetch_cran_metadata()` SHALL fetch description, version, license, published date, and maintainer for each package from CRAN.

#### Scenario: Package on CRAN
- **WHEN** a package is on CRAN
- **THEN** the result SHALL include `description`, `maintainer`, `license`, `cran_version`, `cran_published`, and `on_cran = TRUE`

#### Scenario: Package not on CRAN
- **WHEN** a package is not on CRAN (API returns error)
- **THEN** the result SHALL have `on_cran = FALSE` and metadata fields set to NA

#### Scenario: API error for individual package
- **WHEN** the API call fails for one package
- **THEN** a warning SHALL be logged and that package SHALL have NA metadata, but the function SHALL continue processing remaining packages

### Requirement: fetch_download_stats retrieves download counts
`fetch_download_stats()` SHALL fetch download counts and compute 7d, 30d, 365d, and all-time aggregates.

#### Scenario: Package with download data
- **WHEN** a package has download data available
- **THEN** the result SHALL include `downloads_7d`, `downloads_30d`, `downloads_365d`, `downloads_all` as integers

#### Scenario: Package not on CRAN (no download data)
- **WHEN** a package is not on CRAN
- **THEN** all download counts SHALL be NA

### Requirement: fetch_github_metadata retrieves GitHub data
`fetch_github_metadata()` SHALL fetch the last update date from GitHub for packages with GitHub repo URLs.

#### Scenario: Package with GitHub URL
- **WHEN** a package has a valid GitHub repo_url
- **THEN** the result SHALL include `github_updated` as a date

#### Scenario: Package without repo URL
- **WHEN** a package has no repo_url (NA)
- **THEN** `github_updated` SHALL be NA

#### Scenario: GitHub API error
- **WHEN** the GitHub API call fails for one package
- **THEN** a warning SHALL be logged and `github_updated` SHALL be NA for that package

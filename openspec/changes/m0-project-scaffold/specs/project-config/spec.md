## ADDED Requirements

### Requirement: Custom CSS file exists
The file `inst/app/www/styles.css` SHALL contain custom CSS for dark mode colours and font imports.

#### Scenario: CSS file created
- **WHEN** `inst/app/www/styles.css` is read
- **THEN** it SHALL contain font imports for Inter (Google Fonts) and Fira Code, and custom dark mode colour overrides

### Requirement: gitignore configured
The `.gitignore` SHALL exclude R package build artefacts, renv library, IDE files, and Docker-specific files.

#### Scenario: renv library ignored
- **WHEN** `.gitignore` is checked
- **THEN** it SHALL include `renv/library/`, `renv/staging/`, and `renv/sandbox/` but NOT `renv/activate.R`

#### Scenario: Build artefacts ignored
- **WHEN** `.gitignore` is checked
- **THEN** it SHALL include `*.Rproj.user`, `.Rhistory`, `.RData`, `*.tar.gz`, `*.Rcheck/`

### Requirement: Rbuildignore configured
The `.Rbuildignore` SHALL exclude non-package files from `R CMD check`.

#### Scenario: Dev files excluded
- **WHEN** `.Rbuildignore` is checked
- **THEN** it SHALL exclude `dev/`, `data-raw/`, `_targets/`, `Dockerfile`, `.github/`, `renv/`, `openspec/`, and spec documents

### Requirement: dockerignore configured
The `.dockerignore` SHALL exclude development-only files from Docker builds.

#### Scenario: Test and dev files excluded
- **WHEN** `.dockerignore` is checked
- **THEN** it SHALL exclude `tests/`, `dev/`, `.git/`, `renv/library/`, `_targets/`, and spec documents

### Requirement: renv dependency management
The project SHALL use renv for reproducible dependency management with a committed lockfile.

#### Scenario: renv initialized
- **WHEN** the project is checked
- **THEN** `renv.lock` SHALL exist and `renv/activate.R` SHALL exist

#### Scenario: Core dependencies captured
- **WHEN** `renv.lock` is read
- **THEN** it SHALL include entries for shiny, golem, bslib, and other DESCRIPTION dependencies

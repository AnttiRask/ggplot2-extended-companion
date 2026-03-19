# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**ggplot2 Extended Companion** — A searchable, filterable directory of ~455 ggplot2 extension packages with daily-refreshed metadata, download statistics, and pre-rendered code examples. Built as a Shiny app using the golem framework.

- **Framework**: golem (R package structure)
- **UI**: bslib (Bootstrap 5) with dark mode default, reactable for tables
- **Data**: Parquet files read via arrow, produced by a {targets} pipeline
- **Deployment**: Docker on Google Cloud Run via GitHub Actions

## Build & Run

```r
# Run the app locally
pkgload::load_all()
run_app()

# Or via golem
golem::run_app()

# Run the data pipeline
targets::tar_make()

# Run tests
devtools::test()

# Build Docker image
# docker build -t ggplot2-companion .
# docker run -p 3838:3838 ggplot2-companion
```

## Testing

```r
# Run all tests (226 tests)
devtools::test()

# Run a specific test file
testthat::test_file("tests/testthat/test-fct_validation.R")

# Validate the curated CSV
pkgload::load_all(export_all = TRUE)
curated <- read.csv("data-raw/packages_curated.csv", stringsAsFactors = FALSE)
cats <- read.csv("data-raw/categories.csv", stringsAsFactors = FALSE)
validate_curated_csv(curated, cats$category)
```

## Architecture

### Shiny Modules

| Module | File | Purpose |
|---|---|---|
| Browse | `R/mod_browse.R` | Main package table (reactable) with search, sort, pagination |
| Detail | `R/mod_detail.R` | Full package info: header, links, downloads, version, examples |
| Sidebar | `R/mod_sidebar.R` | Filter controls: category, CRAN status, license, essential, sort |
| Recent | `R/mod_recent.R` | Recently added / recently updated package lists |
| Header | `R/mod_header.R` | Collapsible intro accordion |
| Footer | `R/mod_footer.R` | Disclaimer, credits, data freshness, submission link |

### Data Flow

```
packages_curated.csv → targets pipeline → Parquet files → Shiny app
                          ↓
                    CRAN API (pkgsearch)
                    cranlogs API
                    GitHub API (gh)
```

### Key Files

| File | Purpose |
|---|---|
| `R/fct_data.R` | Load Parquet data, recent lists, metadata |
| `R/fct_pipeline.R` | Pipeline: fetch APIs, merge data, write Parquet/JSON |
| `R/fct_urls.R` | Construct CRAN-derived URLs |
| `R/fct_validation.R` | CSV validation (no duplicates, valid categories, etc.) |
| `R/fct_filters.R` | Filter and sort package data |
| `R/fct_examples.R` | Code example extraction and rendering |
| `_targets.R` | Pipeline DAG definition |
| `data-raw/packages_curated.csv` | Source of truth: 455 packages |
| `data-raw/categories.csv` | 19 canonical categories |

### Data Files

| File | Contents | Produced By |
|---|---|---|
| `data/packages.parquet` | Core package metadata (455 rows) | Pipeline |
| `data/downloads.parquet` | Download stats (7d, 30d, 365d, all) | Pipeline |
| `data/examples.parquet` | Code example metadata | Weekly pipeline |
| `data/metadata.parquet` | Pipeline run timestamps | Pipeline |
| `inst/app/www/data/packages.json` | Machine-readable JSON export | Pipeline |

## Dependencies

Managed by renv. Key packages:

- **App**: shiny, golem, bslib, reactable, htmltools
- **Data**: arrow, duckdb, dplyr, dbplyr
- **Pipeline**: targets, pkgsearch, cranlogs, gh
- **Examples**: callr (subprocess rendering)
- **Logging**: logger
- **Testing**: testthat, withr

## Conventions

- Use Tidyverse syntax and packages
- Follow tidyverse style guide (snake_case, pipe operators)
- Use base pipe `|>` (R >= 4.3.0)
- Every function gets roxygen2 documentation (`@noRd` for internal functions)
- Every R file gets a file-level header comment with purpose and milestone
- Tests follow pattern: `R/fct_foo.R` → `tests/testthat/test-fct_foo.R`
- Shiny modules: `mod_<name>_ui()` / `mod_<name>_server()` in `R/mod_<name>.R`
- Validation functions return `list(valid = TRUE/FALSE, errors = character())`
- Pipeline functions use `tryCatch` per-package with `logger::log_warn` on failure

## Environment Variables

| Variable | Purpose | Required |
|---|---|---|
| `GITHUB_PAT` | GitHub API auth (5,000 req/hr) | Pipeline |
| `GCP_PROJECT_ID` | Google Cloud project | CI deploy |
| `GCP_REGION` | Cloud Run region | CI deploy |
| `GCP_SERVICE_NAME` | Cloud Run service name | CI deploy |
| `SHINY_PORT` | Shiny port in container | No (default: 3838) |

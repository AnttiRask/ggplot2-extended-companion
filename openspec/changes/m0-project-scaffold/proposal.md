## Why

The ggplot2 Extended Companion app needs a properly structured project foundation before any features can be built. M0 establishes the golem framework, dependency management (renv), bslib dark theme, and an empty app shell — the base on which all subsequent milestones (M1–M11) depend.

## What Changes

- Initialize a golem-based R package project with `DESCRIPTION`, `NAMESPACE`, `app.R`, and core R files (`app_ui.R`, `app_server.R`, `app_config.R`, `run_app.R`)
- Set up `renv` for reproducible dependency management with initial lockfile
- Configure bslib Bootstrap 5 dark theme with the spec's colour palette (primary: `#C1272D`, dark bg: `#191414`)
- Create `inst/app/www/styles.css` with custom CSS for dark mode colours and font imports (Gotham/Inter/Fira Code)
- Create `data-raw/categories.csv` with the canonical 15-category list from SPEC section 4.5
- Create `data-raw/license_allowlist.csv` with initial license allowlist for code example rendering
- Create `.gitignore`, `.Rbuildignore`, `.dockerignore` configured for golem + renv + Docker workflow

## Capabilities

### New Capabilities
- `golem-scaffold`: Golem R package structure with DESCRIPTION, NAMESPACE, entry points, and configuration
- `bslib-theme`: bslib Bootstrap 5 theme with dark/light mode support and custom colour palette
- `curated-data-schema`: Canonical data files for categories and license allowlist
- `project-config`: Project configuration files (.gitignore, .Rbuildignore, .dockerignore, renv)

### Modified Capabilities
<!-- None — this is the initial project setup -->

## Impact

- **New files**: ~15 files establishing the project structure
- **Dependencies**: shiny, golem, bslib, reactable, duckdb, dplyr, arrow, logger, jsonlite (declared in DESCRIPTION, managed by renv)
- **No existing code affected** — this is the initial scaffold

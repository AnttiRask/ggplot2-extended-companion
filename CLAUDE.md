# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Setup

When creating CLAUDE.md files for repositories, always analyze the codebase first, add the file to .Rbuildignore for R packages, commit, and push in one workflow.

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

## Tech Stack & Conventions

This project ecosystem primarily uses R/Shiny, CSS, YAML, and Markdown. When making changes, always check for: bs_theme() dark/light mode configuration, renv.lock consistency, and .Rbuildignore updates.

### Coding Conventions

- Use Tidyverse syntax and packages
- Follow tidyverse style guide (snake_case, pipe operators)
- Use base pipe `|>` (R >= 4.3.0)
- Every function gets roxygen2 documentation (`@noRd` for internal functions)
- Every R file gets a file-level header comment with purpose and milestone
- Tests follow pattern: `R/fct_foo.R` → `tests/testthat/test-fct_foo.R`
- Shiny modules: `mod_<name>_ui()` / `mod_<name>_server()` in `R/mod_<name>.R`
- Validation functions return `list(valid = TRUE/FALSE, errors = character())`
- Pipeline functions use `tryCatch` per-package with `logger::log_warn` on failure

## Git Workflow

Every change — feature, fix, or review-fix iteration — lands on `main` via a GitHub pull request. No direct commits to `main`.

**Branch naming**: `feature/<milestone>-<slug>` (e.g. `feature/m1-per-view-layout`), `fix/<slug>`, `chore/<slug>`. Milestone slugs track SPEC-v1.2 §9 (`m1-`, `m2-`, …).

**The flow:**
1. Branch off latest `main`: `git checkout main && git pull && git checkout -b feature/<slug>`.
2. Work in small TDD increments (RED → GREEN → REFACTOR → commit). Follow the agent rules in the session system prompt for commit cadence and types.
3. Before opening the PR: run `devtools::test()` and `openspec validate <change-id>` locally; both must be green.
4. Push the branch: `git push -u origin <branch>`.
5. Open the PR via `gh pr create --base main` with a title like `feat: M1 per-view layout (v1.2)` and a body that summarises scope, links the OpenSpec change folder, and lists the Definition-of-Done items from SPEC-v1.2 §9.
6. Stakeholder (@AnttiRask) reviews on GitHub. Review-fix loop: requested changes go as new commits on the **same** branch — never a new branch, never `--amend`. Push, request re-review.
7. When the stakeholder approves, Claude asks for explicit permission to merge ("ready to merge PR #N — OK to go?"). On a clear go-ahead, Claude runs `gh pr merge <n> --merge --delete-branch` — **standard merge commit, not squash, not rebase**. Without explicit permission: do not merge.
8. After the merge lands on `main`:
   - Verify: `git log --oneline -5 origin/main` shows the merge commit, or `gh pr view <n>` reports `state: MERGED`.
   - `git checkout main && git pull` locally.
   - Delete the local branch: `git branch -d <branch>` (the remote branch is already gone from step 7).
   - Mark the OpenSpec change complete: check off task boxes as you merge, and after the feature PR is merged, open a small follow-up `chore/archive-<id>` PR that runs `openspec archive <change-id>` and commits the moved folder (see M0 → PRs #3 feature, #4 archive for the canonical pattern).

**What NOT to do without explicit stakeholder instruction:**
- Merge a PR without an explicit go-ahead from the stakeholder for that specific PR.
- Squash or rebase-merge (the house style is merge commits).
- Force-push to a branch under review.
- Skip hooks or GPG signing.
- Leave an OpenSpec change "in progress" after its PR has merged, or mark it complete before the PR has merged.

**Verify before moving on**: after any merge, run `git log --oneline -5` and/or check `gh pr view <n>` to confirm the merge commit exists on `main` before updating OpenSpec or starting the next milestone.

## Debugging Guidelines

Before attempting fixes, diagnose the root cause fully. Do not patch around symptoms — especially for CSS/theming issues (e.g., bs_theme dark/light mode) and CI pipeline failures. State your diagnosis before making changes.

## Deployment

When deploying to Google Cloud Run, reuse the existing GCP project ID from the codebase rather than asking the user. Check Dockerfiles for duckdb compilation issues, non-ASCII characters, and system dependency requirements before building.

## Environment Variables

| Variable | Purpose | Required |
|---|---|---|
| `GITHUB_PAT` | GitHub API auth (5,000 req/hr) | Pipeline |
| `GCP_PROJECT_ID` | Google Cloud project | CI deploy |
| `GCP_REGION` | Cloud Run region | CI deploy |
| `GCP_SERVICE_NAME` | Cloud Run service name | CI deploy |
| `SHINY_PORT` | Shiny port in container | No (default: 3838) |

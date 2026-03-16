## Context

This is a greenfield project. The repository currently contains only specification documents (SPEC.md, REQUIREMENTS.md, etc.) and a git repo initialized on `main`. No R code, no package structure, no dependencies exist yet.

The SPEC.md defines a golem-based Shiny app with bslib Bootstrap 5 theming, reactable tables, DuckDB/Parquet data layer, and Docker deployment. M0 establishes the foundation that all 11 subsequent milestones build on.

## Goals / Non-Goals

**Goals:**
- A working golem R package that passes `R CMD check` (with expected notes for a golem app)
- `golem::run_app()` launches a Shiny app with dark-themed bslib layout
- renv manages all dependencies with a committed lockfile
- Canonical data files (categories, license allowlist) are in place
- Project ignores are correctly configured for R package + renv + Docker workflow

**Non-Goals:**
- No data loading, no pipeline, no modules beyond the app shell
- No deployment configuration (Docker, CI/CD — that's M10)
- No tests beyond verifying the app launches (testing infrastructure comes with M1)
- No actual package data or Parquet files

## Decisions

### 1. Use golem's manual setup rather than `golem::create_golem()`

**Decision**: Create files manually following golem conventions rather than running `golem::create_golem()` interactively.

**Rationale**: We need precise control over the file contents to match the SPEC.md exactly — custom theme, specific dependencies, and the right placeholder structure. The golem scaffold generator creates files we'd need to immediately modify.

**Alternative**: Run `golem::create_golem()` then modify — rejected because it creates unnecessary dev scripts and boilerplate that would clutter the initial commit.

### 2. Use base pipe `|>` throughout

**Decision**: Use R's native pipe `|>` (R >= 4.1) instead of magrittr `%>%`.

**Rationale**: SPEC requires R >= 4.3.0. Base pipe has no dependency overhead and is the modern R standard. Consistent with tidyverse style guide recommendations for new projects.

### 3. Dark mode as default via bslib

**Decision**: Set `bs_theme(preset = "shiny", bg = "#191414", fg = "#FFFFFF")` with `input_dark_mode(mode = "dark")` as default.

**Rationale**: SPEC section 7 explicitly requires dark mode as the default colour mode.

### 4. renv initialized with explicit dependencies

**Decision**: Initialize renv and declare all M0 dependencies in DESCRIPTION, then `renv::snapshot()`.

**Rationale**: SPEC section 2.3 requires renv. Starting from M0 ensures all developers have reproducible environments from day one.

## Risks / Trade-offs

- **[Risk] Gotham font may have licensing issues** → SPEC section 14 flags this. We'll include the CDN link matching BiblioStatus but note it as an open question. Montserrat as fallback.
- **[Risk] renv lockfile may be large and slow on first restore** → Acceptable for M0. Only core dependencies are included initially.
- **[Risk] golem manual setup may miss conventions** → Mitigated by following golem source code patterns exactly and testing with `golem::run_app()`.

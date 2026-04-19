## Context

The ggplot2 extended (companion) Shiny app is a deployed golem-based application serving ~455 ggplot2 extension packages. It uses bslib (Bootstrap 5) for theming, reactable for the browse table, and a {targets} pipeline feeding Parquet files. The app is deployed on Google Cloud Run via Docker.

A production review revealed 18 must-have fixes and 5 should-have enhancements. The existing architecture (golem/bslib/reactable/arrow) is sound and unchanged — all work is at the UI layer, data labels, filter behaviour, and content. The full technical specification is in `SPEC.md` (sections 3–12).

Key constraint: all changes must work within the existing stack. No new framework dependencies.

## Goals / Non-Goals

**Goals:**
- Fix all 18 must-have issues (data labels, dark/light mode, sidebar controls, content)
- Remove dead UI (mod_recent cards) and dead code (sort functions)
- Add category-specific badge colours that work in both dark and light modes
- Add shareable package links and navigation arrows (should-have)
- Maintain all 226 existing tests and add coverage for new functionality

**Non-Goals:**
- No architecture changes (golem, bslib, reactable, targets all stay)
- No new package dependencies
- No mobile-specific design work
- No Google Form creation (submission link stays disabled)
- No download trend chart (deferred to v1.1)
- No changes to CI/CD pipeline configuration or Docker setup

## Decisions

### 1. Sorting: Reactable column headers instead of sidebar dropdown

**Decision**: Remove the Sort by dropdown from the sidebar entirely. All sorting handled by reactable's built-in column-header click-to-sort.

**Rationale**: The existing dropdown was non-functional (reactable's `defaultSorted` overrode server-side sort). Rather than fix the wiring, column-header sorting is more discoverable UX and removes code. reactable handles client-side sorting natively with no extra logic.

**Impact**: Delete `sort_packages()` from `fct_filters.R`. Remove `sort_by` from sidebar server return values. Make Category and License columns `sortable = TRUE` in reactable (they were `FALSE`). reactable's stable sort naturally handles ties by preserving original row order (alphabetical by package_name).

**Alternative considered**: Fix the server-side sort wiring by removing `defaultSorted` and letting row order drive display. Rejected because it requires re-rendering the entire reactable on every sort change, which is slower than client-side sorting.

### 2. Category badge colours: Semi-transparent with matched text

**Decision**: Each of the 19 categories gets a distinct hex colour. Badges use semi-transparent backgrounds (`rgba` at 15–20% opacity) with full-saturation matching text colour. This extends the existing pattern already used for the generic red badges in dark mode.

**Rationale**: Semi-transparent backgrounds work well in both dark and light modes without needing separate colour definitions. The approach is already proven in the codebase (`[data-bs-theme="dark"] .badge-category` uses `rgba(193, 39, 45, 0.25)`). 19 colours are drawn from the Tailwind CSS palette, which provides good visual separation.

**Implementation**: A new file `R/fct_categories.R` holds the colour map as a named list. Badge HTML is generated via a `build_category_badge()` helper that applies inline styles. This avoids needing 19×2 CSS classes (dark + light) and keeps colours co-located with category definitions.

**Alternative considered**: CSS classes per category (`.badge-cat-animation`, etc.). Rejected because inline styles are simpler for 19 categories and avoid stylesheet bloat. The colour map in R is the single source of truth.

### 3. Recently Added/Updated: OR logic between the two checkboxes

**Decision**: When both "Recently Added" and "Recently Updated" are checked, show packages matching *either* flag (OR / union). All other filters remain AND.

**Rationale**: AND (intersection) would almost always return 0–2 results because a package just added to the CSV that also had a CRAN/GitHub update in the same 7-day window is extremely rare. OR gives a useful "show me what's new" combined filter.

**Implementation**: Derived flags `recently_added` and `recently_updated` are computed at data load time in `load_app_data()` (not stored in Parquet, since the 7-day window is relative to current date). The `filter_packages()` function applies them with OR logic:
```r
if (recently_added_checked || recently_updated_checked) {
  result <- result |> filter(
    (recently_added & recently_added_checked) |
    (recently_updated & recently_updated_checked)
  )
}
```

### 4. Shareable links: Query parameter approach

**Decision**: Use `?package={name}` query parameters via `shiny::updateQueryString()` and `shiny::parseQueryString()`. No routing library.

**Rationale**: Simplest approach with no new dependencies. Two lines of code: update URL on package select, parse URL on app load. The `?package=ggrepel` format is clean, shareable, and human-readable.

**Alternative considered**: Hash routing (`#package/ggrepel`) via `shiny.router`. Rejected because it adds a dependency for a single feature, and query parameters are more conventional for Shiny apps.

### 5. Vignettes detection: pkgsearch response field

**Decision**: Check `response$vignettes` from `pkgsearch::cran_package()` during the pipeline. If the field is missing or empty, set `has_vignettes = FALSE`.

**Rationale**: The pkgsearch API already returns vignette metadata when available, and the pipeline already calls this endpoint for every package. No additional HTTP requests needed.

**Fallback**: If `pkgsearch` doesn't reliably include vignettes data, add an HTTP HEAD request to the vignettes URL as a fallback. This adds ~455 lightweight requests per pipeline run — acceptable but not preferred.

### 6. Title/Description field split in pipeline

**Decision**: Update `parse_cran_response()` to store `response$Title` as `title` and `response$Description` as `description`. This is a breaking change to the Parquet schema but is handled within the same deployment (pipeline runs before Docker build).

**Migration**: No user-facing migration needed. The pipeline produces new Parquet files, the Docker image bundles them, and the app reads the new schema. Old containers are replaced atomically by Cloud Run deployment.

### 7. Dark/light mode fix approach

**Decision**: Fix via CSS rules rather than restructuring the rendering approach. Add explicit `[data-bs-theme="light"]` CSS rules for all components that currently only have dark-mode rules. Ensure `renderUI()` output inherits the theme by using `bslib::card()` components consistently.

**Rationale**: The root cause is incomplete CSS — dark mode has explicit rules, but light mode falls back to defaults that don't always match. Adding symmetric light-mode rules is the minimal fix. bslib cards automatically respect the `data-bs-theme` attribute, so the dynamically rendered detail view cards should work correctly once CSS is complete.

## Risks / Trade-offs

- **19 category colours may be hard to distinguish** → Mitigated by using Tailwind palette with good hue separation. Semi-transparent backgrounds reduce visual weight so colours don't need to be maximally distinct.
- **`pkgsearch` may not include `vignettes` field for all packages** → Fallback to HEAD request is ready to implement if detection is unreliable. False negatives are low-impact (manual link still provides access).
- **Removing mod_recent.R deletes working code** → Replaced by sidebar checkboxes which provide equivalent functionality with better UX (stackable with other filters).
- **Reactable client-side sort doesn't support Creator (hidden column)** → Accepted trade-off. Creator sort was rarely useful. All important sort dimensions (name, title, downloads, dates, category, license) are available via visible column headers.
- **Recently added/updated flags are computed at app startup, not stored** → The 7-day window is relative to current date, so storing in Parquet would be incorrect after day 1. Computing at load time is correct and has negligible performance cost for ~455 rows.

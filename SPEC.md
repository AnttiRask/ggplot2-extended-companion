# SPEC.md
## ggplot2 extended (companion) — Technical Specification

### 1. Overview
- **App name**: ggplot2 extended (companion)
- **One-line description**: A searchable, filterable directory of ~455 ggplot2 extension packages with daily-refreshed metadata, download statistics, and pre-rendered code examples.
- **Technology**: R Shiny (golem framework)
- **Target deployment**: Docker on Google Cloud Run
- **Repository structure**: Mono-repo (private GitHub repository) containing the Shiny app, data pipeline, and deployment configuration.
- **Spec version note**: This spec supersedes the original SPEC.md. It incorporates all corrections and additions from the production fix & polish round (REQUIREMENTS.md v2). Changes from the original spec are noted inline where significant.

### 2. Architecture

#### 2.1 Application Structure
- **Framework**: golem — app is structured as an R package with `DESCRIPTION`, `NAMESPACE`, and `roxygen2` documentation.
- **UI framework**: bslib (Bootstrap 5) with dark mode as the default colour mode.
- **Routing approach**: Single-page app using `bslib::page_sidebar()` with a main browsing table and a detail view. The detail view replaces the table content when a package is selected. **URL updates with query parameter** (`?package={name}`) for shareable links — the app reads this on load to navigate directly to a package detail view.
- **Table package**: reactable for the main browsing table (client-side sorting, server-side filtering via sidebar controls).
- **Module list**:

| Module | File | Responsibility |
|---|---|---|
| Browse | `R/mod_browse.R` | Main package table with search, column-header sorting, pagination |
| Detail | `R/mod_detail.R` | Package detail view with full metadata, links, downloads, code example, nav arrows |
| Sidebar | `R/mod_sidebar.R` | Filter controls (category, CRAN status, license, essential, recently added, recently updated) |
| Header | `R/mod_header.R` | App introductory text (plain text, always visible) |
| Footer | `R/mod_footer.R` | Disclaimer, credits, book link, data freshness, submission link |

**Removed module**: `mod_recent.R` — the Recently Added/Updated cards have been replaced by sidebar checkbox filters. This module should be deleted.

#### 2.2 Data Architecture
- **Storage**: Parquet files bundled inside the Docker image, read by `arrow::read_parquet()` into tibbles at app startup.
- **Caching**: No runtime caching needed — data is loaded once at app startup from Parquet files. Data is static for the lifetime of a container instance.
- **Refresh mechanism**: GitHub Actions runs the `{targets}` pipeline daily, producing updated Parquet files. A new Docker image is built and deployed to Cloud Run, replacing the running container.

#### 2.3 Infrastructure
- **Hosting**: Google Cloud Run (Docker container). Single container, auto-scaling (min 0, max 3 instances).
- **CI/CD**: GitHub Actions workflows for:
  1. Daily data pipeline (`pipeline.yml`) — runs `{targets}`, builds Docker image, deploys to Cloud Run.
  2. Weekly code example rendering (`examples.yml`) — extends the pipeline to re-render code examples.
  3. PR checks (`check.yml`) — runs `R CMD check`, `testthat` tests, and CSV validation on pull requests.
- **Dependency management**: `renv` for app dependencies. Pipeline dependencies declared in the same `renv.lock`.
- **Container registry**: Google Artifact Registry (same project as Cloud Run).
- **Environment variables**:

| Variable | Purpose | Required | Default |
|---|---|---|---|
| `GITHUB_PAT` | GitHub API access (5,000 req/hr) | Yes | N/A |
| `GCP_PROJECT_ID` | Google Cloud project | Yes (CI only) | N/A |
| `GCP_REGION` | Cloud Run region | Yes (CI only) | `europe-north1` |
| `GCP_SERVICE_NAME` | Cloud Run service name | Yes (CI only) | `ggplot2-companion` |
| `SHINY_PORT` | Port for Shiny app in container | No | `3838` |

### 3. Data Model

#### 3.1 Package Entity (Core)

| Field | Column Name | Type | Source | Update Frequency | Used For |
|---|---|---|---|---|---|
| Package name | `package_name` | character | Curated CSV | On add | Display, search, sort, primary key |
| Title | `title` | character | CRAN API (`response$Title`) | Daily | Display (table column, detail subtitle), search |
| Description | `description` | character | CRAN API (`response$Description`) | Daily | Display (detail view paragraph) |
| Creator/Maintainer | `maintainer` | character | CRAN API (parsed from `Maintainer` field) | Daily | Display (detail view) |
| Categories | `categories` | character (pipe-separated) | Curated CSV | On edit | Display, filter |
| Is essential | `is_essential` | logical | Curated CSV | On edit | Filter, display |
| On CRAN | `on_cran` | logical | Derived (CRAN API response) | Daily | Filter, display |
| License | `license` | character | CRAN API | Daily | Display, filter |
| Latest CRAN version | `cran_version` | character | CRAN API | Daily | Display |
| CRAN published date | `cran_published` | date | CRAN API | Daily | Display, sort |
| GitHub last update | `github_updated` | date | GitHub API (`pushed_at`, with `updated_at` fallback) | Daily | Display, sort |
| Has vignettes | `has_vignettes` | logical | CRAN API (`response$vignettes`) or HEAD request fallback | Daily | Conditional display of vignettes link |
| CRAN URL | `cran_url` | character | Derived (pattern: `https://cran.r-project.org/package={name}`) | On add | Display (link) |
| Website URL | `website_url` | character | Curated CSV (manual) | On edit | Display (link) |
| GitHub/GitLab URL | `repo_url` | character | Curated CSV | On edit | Display (link) |
| Reference manual URL | `manual_url` | character | Derived (pattern-based) | Daily | Display (link) |
| Vignettes URL | `vignettes_url` | character | Derived (pattern-based), set NA when `has_vignettes == FALSE` | Daily | Display (link) |
| Date added to app | `date_added` | date | Curated CSV | On add | Filter (recently added) |
| Last checked | `last_checked` | date | Pipeline metadata | Daily | Internal only |

**Changes from original spec:**
- `description` field split into `title` (CRAN Title — short one-liner) and `description` (CRAN Description — longer paragraph).
- `has_vignettes` added to support conditional vignettes link display.
- `github_updated` now documented as sourced from `pushed_at` (not `updated_at`), which represents actual code pushes rather than issue/PR activity.

**Derived flags (computed at app startup in `load_app_data()`):**
- `recently_added` (logical): `TRUE` when `date_added >= Sys.Date() - 7`.
- `recently_updated` (logical): `TRUE` when `pmax(cran_published, github_updated, na.rm = TRUE) >= Sys.Date() - 7`.

These flags are computed at data load time, not stored in Parquet, because the 7-day window is relative to the current date.

#### 3.2 Download Statistics Entity

| Field | Column Name | Type | Source | Update Frequency | Used For |
|---|---|---|---|---|---|
| Package name | `package_name` | character | Foreign key | Daily | Join |
| Downloads (7 days) | `downloads_7d` | integer | cranlogs API | Daily | Display (detail) |
| Downloads (30 days) | `downloads_30d` | integer | cranlogs API | Daily | Display (table + detail), sort |
| Downloads (365 days) | `downloads_365d` | integer | cranlogs API | Daily | Display (detail) |
| Downloads (all time, 2015–) | `downloads_all` | integer | cranlogs API | Daily | Display (table + detail), sort |

#### 3.3 Code Examples Entity

| Field | Column Name | Type | Source | Update Frequency | Used For |
|---|---|---|---|---|---|
| Package name | `package_name` | character | Foreign key | Weekly | Join |
| Code snippet | `example_code` | character | Package documentation | Weekly | Display (detail) |
| Output image path | `example_image` | character | Pre-rendered PNG filename | Weekly | Display (detail) |
| Render success | `example_success` | logical | Pipeline | Weekly | Conditional display |
| Last rendered | `example_rendered_at` | datetime | Pipeline | Weekly | Display (detail, "last updated" note) |
| License allowed | `license_allowed` | logical | Derived (allowlist check) | Weekly | Gate for rendering |

#### 3.4 Pipeline Metadata Entity

| Field | Column Name | Type | Source | Update Frequency | Used For |
|---|---|---|---|---|---|
| Source name | `source` | character | Pipeline | Each run | Internal |
| Last successful run | `last_run` | datetime | Pipeline | Each run | Display (footer), internal |
| Status | `status` | character | Pipeline | Each run | Internal, monitoring |

#### 3.5 Category Reference

Defined in `data-raw/categories.csv` with columns `category`, `display_name`, `description`. The app and sidebar use `display_name` values for user-facing display; `category` (technical name) is used internally for filtering and data storage.

| category | display_name |
|---|---|
| `animation` | Animation |
| `annotations` | Annotations |
| `arranging_plots` | Arranging Plots |
| `coords` | Coords |
| `data` | Data |
| `facets` | Facets |
| `finishing_touches` | Finishing Touches |
| `geoms` | Geoms |
| `helpers` | Helpers |
| `interactive_plots` | Interactive Plots |
| `interactive_tools` | Interactive Tools |
| `maps` | Maps |
| `networks` | Networks |
| `python` | Python |
| `scales_and_guides` | Scales & Guides |
| `sports` | Sports |
| `stats` | Stats |
| `themes` | Themes |
| `na` | NA |

**Category badge colour map** (19 colours). Each category gets a distinct colour used for badge rendering in both dark and light modes. Badge styling uses semi-transparent backgrounds with matching text colour (consistent with the existing dark-mode badge pattern). Defined as a named list in `R/fct_categories.R`:

| category | Badge colour (hex) | Usage |
|---|---|---|
| `animation` | `#8B5CF6` | Purple |
| `annotations` | `#3B82F6` | Blue |
| `arranging_plots` | `#06B6D4` | Cyan |
| `coords` | `#14B8A6` | Teal |
| `data` | `#10B981` | Emerald |
| `facets` | `#22C55E` | Green |
| `finishing_touches` | `#84CC16` | Lime |
| `geoms` | `#C1272D` | Red (primary accent) |
| `helpers` | `#F59E0B` | Amber |
| `interactive_plots` | `#F97316` | Orange |
| `interactive_tools` | `#EF4444` | Red-orange |
| `maps` | `#0EA5E9` | Sky blue |
| `networks` | `#A855F7` | Violet |
| `python` | `#FBBF24` | Yellow |
| `scales_and_guides` | `#EC4899` | Pink |
| `sports` | `#6366F1` | Indigo |
| `stats` | `#D946EF` | Fuchsia |
| `themes` | `#78716C` | Stone |
| `na` | `#9CA3AF` | Grey (muted) |

**Badge rendering approach (both modes)**:
- **Dark mode**: Background `rgba({r}, {g}, {b}, 0.20)`, text colour at full hex, border `rgba({r}, {g}, {b}, 0.40)`.
- **Light mode**: Background `rgba({r}, {g}, {b}, 0.15)`, text colour darkened ~20% from hex, border `rgba({r}, {g}, {b}, 0.30)`.

This is implemented via CSS classes `.badge-cat-{category}` generated in `styles.css`, or via inline styles in the reactable cell renderer and detail view.

#### 3.6 Data Sources

- **CRAN metadata**: `pkgsearch::cran_package(package_name)` — returns `Title`, `Description`, `Version`, `License`, `Published`, `Maintainer`, `vignettes` list, etc. No authentication required. Rate limit: be polite (1 req/sec recommended). ~455 calls per pipeline run.
- **cranlogs API**: `cranlogs::cran_downloads(packages, from, to)` — returns daily download counts. No authentication. Documented rate limits are generous. Aggregate across time windows in R.
- **GitHub API**: `gh::gh("GET /repos/{owner}/{repo}")` — returns `pushed_at`, `updated_at`, repo metadata. Requires `GITHUB_PAT` for 5,000 req/hr (unauthenticated: 60 req/hr). ~455 calls per pipeline run.
- **Package documentation**: `tools::Rd_db()` or parsing installed package `\examples{}` sections. Runs locally during example rendering.

#### 3.7 Data Storage Schema

**Parquet files** (produced by pipeline, bundled in Docker image):

| File | Contents | Key Columns |
|---|---|---|
| `data/packages.parquet` | Core package data — one row per package | `package_name` (PK), all fields from 3.1 |
| `data/downloads.parquet` | Download statistics — one row per package | `package_name` (FK), all fields from 3.2 |
| `data/examples.parquet` | Code example metadata — one row per package | `package_name` (FK), all fields from 3.3 |
| `data/metadata.parquet` | Pipeline run metadata — one row per source | `source` (PK), all fields from 3.4 |

**Static files** (produced by pipeline, bundled in Docker image):

| Directory | Contents |
|---|---|
| `inst/app/www/examples/` | PNG files of pre-rendered code example outputs, named `{package_name}.png` |
| `inst/app/www/data/packages.json` | Machine-readable JSON export of all packages for AI agent consumption |

**Curated data files** (version-controlled in repo):

| File | Contents |
|---|---|
| `data-raw/packages_curated.csv` | Source of truth for curated fields: `package_name`, `categories`, `is_essential`, `website_url`, `repo_url`, `date_added`, `notes` |
| `data-raw/categories.csv` | 19 canonical categories with `category`, `display_name`, `description` |
| `data-raw/license_allowlist.csv` | Allowlist of licenses that permit example rendering: `license_pattern`, `allowed` |

### 4. Data Pipeline

#### 4.1 Pipeline Overview
- **Orchestration**: `{targets}` DAG defined in `_targets.R` at project root.
- **Runner**: GitHub Actions. Two schedules:
  - **Daily** (06:00 UTC): Fetches CRAN metadata, download stats, GitHub metadata. Produces `packages.parquet`, `downloads.parquet`, `metadata.parquet`. Builds and deploys Docker image.
  - **Weekly** (Sunday 04:00 UTC): Same as daily, plus re-renders code examples. Produces `examples.parquet` and PNG files. Builds and deploys.
- **Manual trigger**: `workflow_dispatch` with optional `refresh_examples` boolean parameter.
- **Outputs**: Parquet files + PNG files → Docker image → Cloud Run.

#### 4.2 Pipeline Steps

| Step | Target Name | Function | Input | Output | Error Handling |
|---|---|---|---|---|---|
| 1. Load curated list | `curated_packages` | `read_curated_csv()` | `data-raw/packages_curated.csv` | tibble of ~455 packages with curated fields | Fail pipeline (source of truth missing) |
| 2. Fetch CRAN metadata | `cran_metadata` | `fetch_cran_metadata()` | `curated_packages$package_name` | tibble with title, description, version, license, published date, maintainer, has_vignettes | Per-package: log warning, use cached. If all fail: use previous target value. |
| 3. Fetch download stats | `download_stats` | `fetch_download_stats()` | `curated_packages$package_name` | tibble with 7d, 30d, 365d, all-time counts | Per-package: log warning, set counts to NA. If cranlogs API down: use previous target value. |
| 4. Fetch GitHub metadata | `github_metadata` | `fetch_github_metadata()` | `curated_packages$repo_url` | tibble with last update date (from `pushed_at`) | Per-package: log warning, set to NA. Rate limit: use cached. |
| 5. Construct URLs | `constructed_urls` | `construct_urls()` | `curated_packages`, `cran_metadata` | tibble with `cran_url`, `manual_url`, `vignettes_url` (vignettes_url set NA when `has_vignettes == FALSE`) | Pattern-based, no external calls — cannot fail. |
| 5b. Fix non-CRAN downloads | `download_stats_fixed` | `fix_non_cran_downloads()` | `download_stats`, `cran_metadata` | downloads with NA for non-CRAN packages | Cannot fail (join only). |
| 6. Merge all data | `packages_combined` | `merge_package_data()` | Steps 1–5 outputs | Single tibble with all fields | Cannot fail (joins only). |
| 7. Write packages.parquet | `packages_parquet` | `write_parquet_output()` | `packages_combined` | `data/packages.parquet` | Fail pipeline if write fails. |
| 8. Write downloads.parquet | `downloads_parquet` | `write_parquet_output()` | `download_stats_fixed` | `data/downloads.parquet` | Fail pipeline if write fails. |
| 10. Render code examples | `code_examples` | `render_examples()` | `packages_combined`, license allowlist | `data/examples.parquet` + PNG files in `inst/app/www/examples/` | Per-package: log warning, flag `example_success = FALSE`. Timeout: 30s per example. |
| 11. Write examples.parquet | `examples_parquet` | `write_parquet_output()` | `code_examples` | `data/examples.parquet` | Fail pipeline if write fails. |
| 12. Export JSON | `packages_json` | `export_json()` | `packages_combined`, `download_stats_fixed` | `inst/app/www/data/packages.json` | Cannot fail. |
| 13. Write metadata | `pipeline_metadata` | `write_metadata()` | Timestamps from steps 2–4, 10 | `data/metadata.parquet` | Cannot fail. |

**Pipeline changes for this round:**
- Step 2 (`fetch_cran_metadata` / `parse_cran_response`): Now stores `response$Title` as `title` and `response$Description` as `description` (previously stored `response$Title` as `description`). Also extracts `has_vignettes` from `response$vignettes` (truthy check: `length(response$vignettes) > 0` or presence of vignettes field).
- Step 5 (`construct_urls`): `vignettes_url` is now set to `NA` when `has_vignettes == FALSE`, not just when `on_cran == FALSE`.
- Step 12 (`export_json`): JSON export updated to include both `title` and `description` fields.

#### 4.3 Code Example Rendering (Step 10 Detail)

For each package where `license_allowed == TRUE`:

1. Install the package in an isolated library path (within the GitHub Actions runner).
2. Extract the first example from the package's primary function documentation using `tools::Rd_db()`.
3. If no example found, check for a `README` example or vignette code block. If still nothing, set `example_success = FALSE`.
4. Execute the example code in a `callr::r()` subprocess with a 30-second timeout.
5. Capture the last plot via `ggplot2::ggsave()` as a PNG (800x600px, 150 DPI).
6. If execution fails or times out, set `example_success = FALSE`, store code snippet only.
7. Store: code text in `examples.parquet`, PNG in `inst/app/www/examples/{package_name}.png`.

**Schedule**: Weekly only (Sunday 04:00 UTC), or on manual trigger with `refresh_examples: true`. The daily pipeline skips step 10 and reuses the existing `examples.parquet` and PNG files.

#### 4.4 Manual Package Addition

**Process** (target: under 5 minutes):

1. Maintainer adds a row to `data-raw/packages_curated.csv` with: `package_name`, `categories`, `is_essential`, `website_url` (if non-standard), `repo_url`, `date_added`.
2. Commit and push to `main`.
3. Manually trigger the GitHub Actions pipeline via `workflow_dispatch` (with `refresh_examples: true` if a code example is desired immediately).
4. Pipeline fetches all automated fields for the new package, merges, builds, and deploys.
5. Package appears in the app within ~5–10 minutes.

**Validation** (CI step on push/PR):
- No duplicate `package_name` values in `packages_curated.csv`.
- All `categories` values match the known category set (defined in `data-raw/categories.csv`).
- Required fields (`package_name`, `categories`, `date_added`) are non-empty.
- `is_essential` is `TRUE` or `FALSE`.
- Pipe-separated `categories` are well-formed (no trailing pipes, no spaces around pipes).

### 5. UI Specification

#### 5.1 Navigation Structure

The app uses `bslib::page_sidebar()` as the primary layout. The sidebar contains filter controls. The main panel switches between the browse view (table) and the detail view (single package).

**URL routing**: When a package is selected, the browser URL updates to include `?package={package_name}` via `shiny::updateQueryString()`. On app load, `session$clientData$url_search` is parsed — if a `package` parameter is present, the app navigates directly to that package's detail view. This enables shareable links to individual packages.

```
+----------------------------------------------------------+
|  [ggplot2 extended (companion)]          [dark/light] sun |
+------------+---------------------------------------------+
|            |                                             |
|  SIDEBAR   |  MAIN CONTENT                              |
|            |                                             |
|  Filters   |  [Intro text — always visible]              |
|  Category  |                                             |
|  CRAN      |  +-------------------------------------+   |
|  License   |  |  Package Table (reactable)          |   |
|  Essential |  |  -----------------------------------  |   |
|  Recently  |  |  name | title | cat | 30d | all | …|   |
|    Added   |  |  -----------------------------------  |   |
|  Recently  |  |  ...                                |   |
|    Updated |  |  ...                                |   |
|            |  +-------------------------------------+   |
|  --------  |                                             |
|  Suggest   |  [Footer / Disclaimer / Links]             |
|  [disabled]|                                             |
|            |                                             |
+------------+---------------------------------------------+
```

When a package is clicked, the main content area replaces the table with the detail view. A "← Back to all packages" button returns to the table. Navigation arrows allow moving to next/previous package alphabetically.

#### 5.2 Browse View (`mod_browse`)

- **Purpose**: Discover and evaluate ggplot2 extension packages.
- **Layout**: Full-width `reactable` table in the main panel, directly below the intro text (no Recently Added/Updated cards above it).
- **Components**:
  - **Package table** (`reactable`):
    - **Columns**:

| Column | Data Field | Width | Sortable | Notes |
|---|---|---|---|---|
| Name | `package_name` | 150px | Yes (alpha) | Clickable link → detail view. Bold text. Essential packages get star badge. |
| Title | `title` | Flex | Yes (alpha) | Truncated to ~100 chars with ellipsis. **Changed**: was labeled "Description", now labeled "Title" and mapped to CRAN Title field. |
| Category | `categories` | 180px | Yes (alpha, sorts by first category) | **All categories shown as separate badges** with category-specific colours and `display_name` values. No "+N" truncation. Badges wrap within the cell. Secondary sort by `package_name` for ties. |
| License | `license` | 100px | Yes (alpha) | Plain text. Secondary sort by `package_name` for ties. |
| Downloads (30d) | `downloads_30d` | 100px | Yes (numeric) | Formatted with comma separators. |
| Downloads (All) | `downloads_all` | 100px | Yes (numeric) | Formatted with comma separators. |
| CRAN Version | `cran_version` | 90px | No | Shows version string, or "—" if not on CRAN. |
| CRAN Published | `cran_published` | 110px | Yes (date) | Format: `YYYY-MM-DD`. |
| GitHub Updated | `github_updated` | 110px | Yes (date) | Format: `YYYY-MM-DD`. |

  - **Pagination**: 25 rows per page, client-side pagination.
  - **Search**: Built-in `reactable` search bar (searches across visible text). Positioned above the table.
  - **"Essential Extensions" badge**: Packages with `is_essential == TRUE` get a star icon next to their name.
  - **Sorting**: Handled entirely by reactable column headers (click to sort, click again to reverse). **No Sort dropdown in the sidebar.** Default initial sort: `package_name` ascending. All columns marked `sortable = TRUE` above support click-to-sort.

- **Interactions**:
  - Click package name → navigate to detail view (`mod_detail`), URL updates to `?package={name}`.
  - Type in search bar → table filters instantly (client-side).
  - Change sidebar filters → table updates (server-side filter, then re-render reactable).
  - Click column header → sort by that column (reactable built-in, client-side).

- **Reactive dependencies**:
  - `filtered_packages()` — a reactive expression that applies sidebar filters to the full dataset.
  - `selected_package()` — a `reactiveVal` holding the currently selected package name (or `NULL` for browse view).

#### 5.3 Sidebar Controls (`mod_sidebar`)

- **Purpose**: Filter the package table.
- **Layout**: `bslib::sidebar()` with vertically stacked controls. Compact padding to ensure all controls and the "Suggest a Package" button are visible without scrolling on a standard desktop viewport (~900px height).
- **Components**:

| Control | Type | Options | Default | Behaviour |
|---|---|---|---|---|
| Category | `selectInput` | All categories (using `display_name`) + "All" | "All" | Single-select. Filters packages containing the selected category. Category dropdown displays `display_name` values (e.g., "Arranging Plots"), but filters internally using the `category` technical name. |
| CRAN status | `radioButtons` | "All", "On CRAN", "Not on CRAN" | "All" | Filters by `on_cran`. |
| License | `selectInput` | All unique licenses + "All" | "All" | Single-select. Filters by `license`. |
| Essential Only | `checkboxInput` | Toggle | Unchecked | When checked, filters to `is_essential == TRUE`. **Label**: "Essential Extensions Only" (capital O). |
| Recently Added | `checkboxInput` | Toggle | Unchecked | When checked, filters to `recently_added == TRUE` (packages with `date_added` within 7 days). |
| Recently Updated | `checkboxInput` | Toggle | Unchecked | When checked, filters to `recently_updated == TRUE` (packages with `max(cran_published, github_updated)` within 7 days). |
| Suggest a Package | `tags$a` (styled button) | — | Disabled | **Disabled** with `"Coming soon"` tooltip. Not clickable. Styled as `btn btn-outline-primary w-100 disabled`. |

**Removed control**: Sort by dropdown — sorting is now handled entirely via reactable column headers.

- **Filter logic**: All filters are combined with AND logic. The Recently Added and Recently Updated checkboxes use **OR logic with each other** — when both are checked, packages matching *either* flag are shown. All other filters remain AND. Implementation:
  ```r
  # Pseudocode for filter composition
  result <- data
  result <- filter by category (AND)
  result <- filter by cran_status (AND)
  result <- filter by license (AND)
  result <- filter by essential_only (AND)
  # Recently Added / Recently Updated use OR with each other
  if (recently_added || recently_updated) {
    result <- result |> filter(
      (recently_added & recently_added_checked) |
      (recently_updated & recently_updated_checked)
    )
  }
  ```

- **Interactions**:
  - Any filter change → `filtered_packages()` reactive updates → table re-renders.

- **Styling**: Reduce default padding/margins on sidebar controls so all elements fit without scrolling. Apply compact spacing via CSS: `.sidebar .form-group { margin-bottom: 0.5rem; }` and reduce the sidebar title margin.

#### 5.4 Detail View (`mod_detail`)

- **Purpose**: View full information about a single package.
- **Trigger**: User clicks a package name in the browse table, or navigates via URL `?package={name}`.
- **Layout**: Replaces the main content area. Structured as a vertical stack of `bslib::card()` components.

**Components (top to bottom)**:

1. **Navigation bar**: Back button + next/previous arrows.
   - `actionButton` — "← Back to all packages". Returns to browse view, restoring previous filter state. URL updates to remove the `?package=` parameter.
   - **Styling**: `btn btn-outline-secondary` with **red border** (`border-color: #C1272D`) and **red on hover/active** (`background-color: rgba(193, 39, 45, 0.1); border-color: #C1272D; color: #C1272D`).
   - **Next/Previous arrows** (should-have): Two small buttons ("← Prev" / "Next →") that navigate to the previous/next package in **alphabetical order** (by `package_name`). The full alphabetically-sorted package list is passed to `mod_detail_server()`. At the first/last package, the corresponding arrow is disabled. When navigating, the URL updates to reflect the new package name.

2. **Package header card**:
   - Package name (large heading, `<h2>`).
   - "Essential Extension" badge (if `is_essential == TRUE`).
   - **Title** as subtitle directly under the package name — styled as `<h4>` or `<p class="lead">`, displaying the CRAN Title (short one-liner).
   - **Description** as a full paragraph below the Title — styled as `<p>`, displaying the CRAN Description (longer paragraph). If description is NA, show "No description available."
   - Creator/Maintainer name.
   - Category badges (all categories, using `display_name` values and category-specific colours).
   - License.

3. **Links card**:
   - Row of icon-buttons/links: Website, **Repo (GitHub, etc.)**, CRAN, Reference Manual, Vignettes.
   - Each link opens in a new tab. Links that are `NA` are hidden (not greyed out).
   - **Vignettes link**: Hidden when `has_vignettes == FALSE` OR when `vignettes_url` is `NA`. This is the key change — previously the vignettes link was shown for all CRAN packages regardless of whether vignettes actually existed.
   - **Label change**: "GitHub/GitLab" → **"Repo (GitHub, etc.)"**.

4. **Download statistics card**:
   - Header: "Download Statistics"
   - Four `bslib::value_box()` components in a row:
     - "Last 7 days" — `downloads_7d`
     - "Last 30 days" — `downloads_30d`
     - "Last 365 days" — `downloads_365d`
     - **"Since 2015"** — `downloads_all` (**changed** from "All time (since 2015)")
   - **No graph emoji** in the `showcase` parameter. Remove `showcase = htmltools::tags$span("\U0001F4C8")` from all four value boxes. Use `showcase = NULL` or omit the parameter entirely.
   - Download trend chart: Deferred to v1.1.

5. **Version info card**:
   - Latest CRAN version + published date.
   - GitHub last update date.

6. **Code example card**:
   - Syntax-highlighted code block (using `htmltools::pre()` + `code()` with a highlight.js or Prism.js integration via CSS class).
   - **Prepended code** (should-have, if feasible): At the top of the code block, prepend `install.packages("{package_name}")` and `library({package_name})` so users can copy the full runnable snippet. The package name is always known, so this is straightforward — no dependency detection needed. Separated from the example code by a blank line and a comment: `# Example:`.
   - "Copy to clipboard" button (JavaScript `navigator.clipboard.writeText()`).
   - Rendered output image (`<img>` tag pointing to `examples/{package_name}.png`).
   - If `example_success == FALSE`: show code only, with a note "Output preview not available for this package."
   - "Example last rendered: {example_rendered_at}" timestamp at the bottom of the card.
   - If `license_allowed == FALSE`: show a note "Code example not available — package license could not be verified." and no code.

- **Reactive dependencies**:
  - `selected_package()` — drives which package data is displayed.
  - `all_packages_sorted()` — alphabetically sorted list of all `package_name` values for next/prev navigation.

#### 5.5 Header / Intro (`mod_header`)

- **Purpose**: Brief introduction to ggplot2 extensions for new visitors.
- **Layout**: **Plain text** (always visible) above the main table. **Not** a collapsible accordion.
- **Content**:
  - "What are ggplot2 extensions?" — 2–3 sentences explaining the concept.
  - Link: **"ggplot2 extended (the book)"** → `https://ggplot2-extended-book.com/` (opens in new tab).
  - Link: **"ggplot2 documentation"** → `https://ggplot2.tidyverse.org/` (opens in new tab).
- **Design**: Understated — not a hero banner. Informative for newcomers, unobtrusive for regulars. Use `<p>` tags with `text-muted` styling.

**Changed from original spec**: Was a collapsible `bslib::accordion()`, collapsed by default. Now plain text, always visible. Links updated: "ggplot2 extensions gallery" removed, replaced with "ggplot2 extended (the book)".

#### 5.6 Footer / Disclaimer (`mod_footer`)

- **Purpose**: Legal disclaimer, credits, and cross-links.
- **Layout**: Full-width footer below the main content area, styled with `border-top`.
- **Content** (in order):

  1. **Data freshness**: "Package data last updated: {last_run from metadata}."
  2. **Disclaimer**: "If you have concerns about information presented on this site (licensing, metadata accuracy, etc.), please reach out via email at [anttilennartrask@gmail.com](mailto:anttilennartrask@gmail.com) to have it corrected or removed."
  3. **Submission link**: "Know a ggplot2 extension we're missing? Submit it here." — "Submit it here" is styled as dotted-underline text with `cursor: default` and a `title="Package submission form coming soon"` tooltip. Not clickable.
  4. **Book link**: "Check out the book (in progress): [ggplot2 extended](https://ggplot2-extended-book.com/)."
  5. **Machine-readable data**: "Machine-readable data: [packages.json](data/packages.json)."
  6. **Credits**: "Created by [Antti Rask](https://youcanbeapirate.com) | [youcanbeapirate.com](https://youcanbeapirate.com)"

**Changes from original spec**:
- Email changed from `antti@youcanbeapirate.com` to `anttilennartrask@gmail.com`.
- Removed: "ggplot2 extensions gallery | youcanbeapirate.com" line.
- Added: Book link line.
- Submission link is disabled with tooltip (was previously an active link to a Google Form that doesn't exist yet).

### 6. Package Submission

#### 6.1 Submission Mechanism
- **Type**: External link to a Google Form (opens in new tab). **Currently disabled** — the Google Form has not been created yet.
- **Location in app**: Sidebar (disabled button with "Coming soon" tooltip) + footer (disabled text with tooltip).
- **Status**: Parked for a future iteration.

#### 6.2 Google Form Fields (future)

| Field | Type | Required | Notes |
|---|---|---|---|
| Package name | Short text | Yes | |
| Link | URL | Yes | CRAN, GitHub, pkgdown, or other |
| Category suggestion | Dropdown (from category list) | No | "I'm not sure" as an option |
| Any other notes | Long text | No | |

#### 6.3 Submission Processing (future)
- **Storage**: Google Form responses stored in linked Google Sheet.
- **Notification**: Google Forms sends email notification to maintainer on each submission.
- **Approval flow**: Maintainer reviews submission → adds row to `data-raw/packages_curated.csv` → commits and pushes → triggers pipeline manually → package goes live.

### 7. Styling & Theming

- **Theme**: bslib `bs_theme()` with Bootstrap 5, dark mode as default.
- **Colour palette**:

| Role | Hex | Usage |
|---|---|---|
| Primary accent | `#C1272D` | Buttons, links, active states |
| Background (dark) | `#191414` | Page background in dark mode |
| Foreground (dark) | `#FFFFFF` | Text colour in dark mode |
| Background (light) | `#FFFFFF` | Page background in light mode |
| Foreground (light) | `#1a1a1a` | Text colour in light mode |
| Muted text | `#9ca3af` | Secondary text, timestamps, footnotes |
| Card background (dark) | `#2a2a2e` | Card surfaces in dark mode |
| Success | `#22c55e` | "On CRAN" badge |
| Warning | `#f59e0b` | Stale data indicator, essential badge |

- **Category badge colours**: 19 distinct colours defined in §3.5. Semi-transparent background with matching text. See §3.5 for the full colour map.

- **Typography**:
  - Headings: Montserrat (Google Fonts, with Inter as fallback).
  - Body text: Inter (Google Fonts).
  - Code blocks: `"Fira Code", "Source Code Pro", monospace`.
  - Base font size: 16px (1rem).

- **Component styling**:
  - **Cards**: Subtle border, rounded corners (0.5rem), slight shadow in dark mode.
  - **Badges** (categories): Pill-shaped, category-specific colours (semi-transparent background + matching text). See §3.5.
  - **Essential badge**: Star icon (⭐) next to package name.
  - **Table**: Striped rows (subtle), hover highlight, compact row height.
  - **Value boxes**: Primary colour accent on the left border. **No emoji/icon in showcase slot.**
  - **Buttons**: Primary colour, rounded, consistent padding.
  - **Back button**: `btn-outline-secondary` with red border (`#C1272D`), red text/background on hover.

- **Dark/light mode toggle**: `bslib::input_dark_mode()` in the navbar/header area. Dark mode is the default (`mode = "dark"`).

- **Dark/light mode consistency** (critical fix):
  - The selected colour mode **must persist** when navigating between browse and detail views. The root cause is likely that `renderUI()` in `mod_detail` generates new HTML that doesn't inherit the current `data-bs-theme` attribute. Fix approach: ensure all dynamically rendered UI uses `bslib` components that respect the theme, or explicitly pass the theme context.
  - **Search box**: Must respect the current colour mode. The reactable search input must inherit colours from the active Bootstrap theme, not hardcode dark-mode styles. The existing CSS rule `[data-bs-theme="dark"] .rt-search` handles dark mode, but a matching `[data-bs-theme="light"] .rt-search` rule is needed to ensure light mode renders correctly (white background, dark text, light border).
  - **Light mode background**: Must be `#FFFFFF`, not grey. Verify that `bslib::bs_theme(bg = "#191414")` doesn't bleed into light mode — the `bg` parameter sets the dark-mode background. For light mode, Bootstrap 5's `[data-bs-theme="light"]` should use the default white background. If needed, add explicit CSS: `[data-bs-theme="light"] body { background-color: #FFFFFF; color: #1a1a1a; }`.
  - **Detail view cards**: Must use the correct card background in both modes. The existing CSS rules handle this (`[data-bs-theme="dark"] .card` and `[data-bs-theme="light"] .card`), but the dynamically rendered cards from `renderUI()` may not pick up the theme. Ensure cards are wrapped in a container that inherits `data-bs-theme`.

- **Responsive**: Desktop-first. bslib's Bootstrap 5 grid handles basic responsiveness. Sidebar collapses on mobile. No mobile-specific design work in v1.

### 8. AI Agent Compatibility

- **Semantic HTML**: bslib and reactable produce reasonably semantic markup. Ensure headings (`<h1>` through `<h4>`), table elements, and links use proper HTML tags.
- **Meta tags**: `tags$head()` includes:
  - `<meta name="description" content="Searchable directory of 455+ ggplot2 extension packages with download statistics and code examples.">`
  - `<meta property="og:title" content="ggplot2 extended (companion)">`
  - `<meta property="og:description" content="...">`
  - `<meta property="og:type" content="website">`
- **Static JSON export**: `www/data/packages.json` — machine-readable export of all package data, regenerated on each pipeline run. Linked from the footer: "Machine-readable data: packages.json".
- **Structure of `packages.json`**:
  ```json
  {
    "generated_at": "2026-03-15T06:00:00Z",
    "package_count": 455,
    "packages": [
      {
        "name": "ggrepel",
        "title": "Automatically Position Non-Overlapping Text Labels with ggplot2",
        "description": "Provides geoms for ggplot2 to repel overlapping text labels...",
        "categories": ["annotations"],
        "is_essential": true,
        "on_cran": true,
        "license": "MIT",
        "cran_version": "0.9.6",
        "cran_published": "2024-09-07",
        "github_updated": "2024-12-01",
        "downloads_30d": 512000,
        "downloads_all": 15000000,
        "cran_url": "https://cran.r-project.org/package=ggrepel",
        "website_url": "https://ggrepel.slowkow.com/",
        "repo_url": "https://github.com/slowkow/ggrepel"
      }
    ]
  }
  ```

### 9. Testing Strategy

| Layer | Framework | What Is Tested | Location |
|---|---|---|---|
| Unit | `testthat` | Data processing functions: `fetch_cran_metadata()`, `fetch_download_stats()`, `merge_package_data()`, `construct_urls()`, `render_examples()`, CSV validation, `filter_packages()`, category display name mapping | `tests/testthat/` |
| Integration | `testthat` | Full pipeline: `targets::tar_make()` with mocked API responses produces valid Parquet files with correct `title`/`description`/`has_vignettes` fields | `tests/testthat/` |
| UI | `shinytest2` | Key user flows: browse → filter → select package → view detail → back to browse; dark/light mode toggle persistence; shareable link loading | `tests/testthat/` |
| Snapshot | `testthat` | reactable output structure, value box rendering, category badge rendering | `tests/testthat/` |
| CSV validation | `testthat` (+ CI) | `packages_curated.csv` structure and content validity | `tests/testthat/` |

**Mocking strategy**: Use `httptest2` to mock CRAN, cranlogs, and GitHub API responses in tests. Store mock fixtures in `tests/testthat/fixtures/`.

### 10. File & Directory Structure

```
ggplot2-extended-companion/
├── DESCRIPTION                          # golem package metadata, dependencies
├── NAMESPACE                            # Auto-generated by roxygen2
├── LICENSE                              # Project license
├── LICENSE.md                           # Full license text
├── .Rbuildignore                        # Files excluded from R CMD check
├── .gitignore                           # Git ignores
├── renv.lock                            # Dependency lockfile
├── renv/                                # renv library (gitignored except activate.R)
│   └── activate.R
├── _targets.R                           # targets pipeline definition
├── app.R                                # golem entry point (golem::run_app())
├── R/
│   ├── app_config.R                     # golem app configuration
│   ├── app_server.R                     # Main server: loads data, calls modules, handles URL routing
│   ├── app_ui.R                         # Main UI: bslib layout, theme, meta tags
│   ├── run_app.R                        # golem::run_app() wrapper
│   ├── mod_browse.R                     # Browse view: reactable table with column sorting
│   ├── mod_detail.R                     # Detail view: full package info, nav arrows
│   ├── mod_sidebar.R                    # Sidebar: filters (category, CRAN, license, essential, recent)
│   ├── mod_header.R                     # Introductory text (plain, always visible)
│   ├── mod_footer.R                     # Disclaimer, credits, book link
│   ├── fct_data.R                       # Data loading functions (arrow + Parquet)
│   ├── fct_pipeline.R                   # Pipeline functions (fetch, merge, write)
│   ├── fct_examples.R                   # Code example extraction and rendering
│   ├── fct_urls.R                       # URL construction logic
│   ├── fct_validation.R                 # CSV validation functions
│   ├── fct_filters.R                    # Filter functions (no sort — sorting is client-side)
│   ├── fct_categories.R                 # Category display name mapping and badge colour definitions
│   └── utils_helpers.R                  # Shared utility functions
├── data/
│   ├── packages.parquet                 # Core package data (pipeline output)
│   ├── downloads.parquet                # Download statistics (pipeline output)
│   ├── examples.parquet                 # Code example metadata (pipeline output)
│   └── metadata.parquet                 # Pipeline run metadata (pipeline output)
├── data-raw/
│   ├── packages_curated.csv             # Curated package list (source of truth)
│   ├── categories.csv                   # Canonical category definitions with display_name
│   ├── license_allowlist.csv            # Allowed licenses for example rendering
│   └── migrate_notion.R                 # One-time Notion migration script
├── inst/
│   └── app/
│       └── www/
│           ├── styles.css               # Custom CSS: badge colours, dark/light mode fixes, compact sidebar
│           ├── favicon.png              # App favicon
│           ├── logo.png                 # App logo (if available)
│           ├── clipboard.js             # Copy-to-clipboard JavaScript helper
│           ├── data/
│           │   └── packages.json        # Machine-readable JSON export
│           └── examples/
│               ├── ggrepel.png          # Pre-rendered example output
│               ├── gganimate.png
│               └── ...                  # One PNG per package with successful render
├── tests/
│   ├── testthat.R                       # Test runner
│   └── testthat/
│       ├── test-fct_data.R              # Tests for data loading (incl. recently_added/updated flags)
│       ├── test-fct_pipeline.R          # Tests for pipeline functions (title/description split)
│       ├── test-fct_examples.R          # Tests for example rendering
│       ├── test-fct_urls.R              # Tests for URL construction (vignettes conditional)
│       ├── test-fct_validation.R        # Tests for CSV validation
│       ├── test-fct_filters.R           # Tests for filter functions (incl. recently_added/updated OR logic)
│       ├── test-fct_categories.R        # Tests for category display names and badge colours
│       ├── test-mod_browse.R            # UI tests for browse module
│       ├── test-mod_detail.R            # UI tests for detail module
│       └── fixtures/
│           ├── cran_response.json       # Mock CRAN API response (with Title + Description)
│           ├── cranlogs_response.json   # Mock cranlogs API response
│           └── github_response.json     # Mock GitHub API response
├── Dockerfile                           # Production Docker image
├── .dockerignore                        # Files excluded from Docker build
├── .github/
│   └── workflows/
│       ├── pipeline.yml                 # Daily data pipeline + deploy
│       ├── examples.yml                 # Weekly code example rendering + deploy
│       └── check.yml                    # PR checks (R CMD check, tests, CSV validation)
└── dev/
    ├── 01_start.R                       # golem dev helper: initial setup
    ├── 02_dev.R                         # golem dev helper: development
    └── 03_deploy.R                      # golem dev helper: deployment
```

**Files to delete**: `R/mod_recent.R` — replaced by sidebar checkbox filters.
**Files to create**: `R/fct_categories.R` — category display name mapping and badge colour definitions.

### 11. Implementation Milestones

These milestones are ordered by priority (must-haves first) and dependency. Each milestone is independently testable.

#### M1: Pipeline — Title/Description Split & Vignettes Detection
- **Goal**: Update the data pipeline to fetch CRAN Title and Description as separate fields, and detect whether packages have vignettes.
- **Depends on**: Nothing (pipeline changes are independent of UI)
- **Files modified**:
  - `R/fct_pipeline.R` — Update `parse_cran_response()`: store `response$Title` as `title`, `response$Description` as `description`, derive `has_vignettes` from `length(response$vignettes) > 0`. Update `merge_package_data()` to include new fields.
  - `R/fct_urls.R` — Update `construct_urls()`: set `vignettes_url = NA` when `has_vignettes == FALSE` (not just when `on_cran == FALSE`). The function now needs `has_vignettes` as input.
  - `R/fct_pipeline.R` — Update `export_json()`: include both `title` and `description` in JSON output.
  - `_targets.R` — Pass `has_vignettes` from `cran_metadata` to `construct_urls()`.
  - `tests/testthat/test-fct_pipeline.R` — Update `parse_cran_response()` tests for new field mapping. Add test for `has_vignettes` detection.
  - `tests/testthat/test-fct_urls.R` — Add tests for `vignettes_url` being NA when `has_vignettes == FALSE`.
  - `tests/testthat/fixtures/cran_response.json` — Update mock to include `Description` and `vignettes` fields.
- **Definition of done**: `targets::tar_make()` produces `packages.parquet` with `title`, `description`, and `has_vignettes` columns. The `title` column contains CRAN Title (short), `description` contains CRAN Description (long). `vignettes_url` is NA for packages without vignettes. All pipeline tests pass.
- **Testable outcome**: `arrow::read_parquet("data/packages.parquet") |> dplyr::select(package_name, title, description, has_vignettes) |> head()` shows correct field separation. Packages known to lack vignettes have `has_vignettes == FALSE`.

#### M2: Category Infrastructure — Display Names & Badge Colours
- **Goal**: Create the category helper module with display name mapping and 19-colour badge palette.
- **Depends on**: Nothing
- **Files created**:
  - `R/fct_categories.R` — Contains:
    - `get_category_display_names()`: reads `data-raw/categories.csv` and returns a named vector mapping `category` → `display_name`.
    - `get_category_colours()`: returns a named list mapping `category` → hex colour (the 19-colour palette from §3.5).
    - `category_to_display_name(category_technical)`: converts a single technical name to display name.
    - `build_category_badge(category_technical, display_names, colours)`: returns an `htmltools::span()` with the correct colour styling for a given category.
  - `tests/testthat/test-fct_categories.R` — Tests for all category functions: mapping completeness (all 19 categories have display names and colours), badge HTML output structure.
- **Definition of done**: `get_category_display_names()` returns a complete named vector. `get_category_colours()` returns 19 distinct hex colours. `build_category_badge("arranging_plots", ...)` returns an HTML span with text "Arranging Plots" and correct colour styling.
- **Testable outcome**: All tests in `test-fct_categories.R` pass.

#### M3: App Rename & Meta Tags
- **Goal**: Rename the app from "ggplot2 Extended Companion" to "ggplot2 extended (companion)" everywhere.
- **Depends on**: Nothing
- **Files modified**:
  - `R/app_ui.R` — Update `title` and `window_title` in `page_sidebar()` to "ggplot2 extended (companion)". Update `app_title` in `golem_add_external_resources()`. Update `og:title` meta tag.
- **Definition of done**: App title bar shows "ggplot2 extended (companion)". Page source shows correct meta tags. No references to "ggplot2 Extended Companion" remain in user-facing text.
- **Testable outcome**: `golem::run_app()` shows the updated title. `grep -r "Extended Companion" R/ inst/` returns no user-facing matches.

#### M4: Sidebar Overhaul — Filters Without Sort
- **Goal**: Update the sidebar: remove Sort dropdown, add Recently Added / Recently Updated checkboxes, fix category display names, fix "Essential Extensions Only" label, reduce padding, ensure Suggest button is visible without scrolling.
- **Depends on**: M2 (category display names)
- **Files modified**:
  - `R/mod_sidebar.R` — Remove `sort_by` selectInput. Add `recently_added` and `recently_updated` checkboxInputs. Fix `essential_only` label to "Essential Extensions Only". Change category dropdown choices to use `display_name` values (from `get_category_display_names()`). Update server return list to include `recently_added` and `recently_updated` reactive values, remove `sort_by`.
  - `R/fct_filters.R` — Remove `sort_packages()` function entirely. Update `filter_packages()` to accept `recently_added` and `recently_updated` boolean parameters. Implement OR logic between the two: when either or both are checked, filter to packages matching any checked flag.
  - `R/fct_data.R` — Update `load_app_data()` to compute `recently_added` and `recently_updated` derived columns at load time.
  - `R/app_server.R` — Remove `sort_packages()` call. Pass `recently_added` and `recently_updated` from sidebar values to `filter_packages()`. Remove `sort_by` from sidebar values access. Update category choices to use display names with a reverse mapping for filtering.
  - `inst/app/www/styles.css` — Add compact sidebar CSS: `.sidebar .form-group { margin-bottom: 0.5rem; }`, reduce sidebar title margin, reduce padding on radio buttons.
  - `tests/testthat/test-fct_filters.R` — Update tests: remove sort tests, add filter tests for `recently_added` and `recently_updated` (individual and combined OR logic).
- **Definition of done**: Sidebar shows: Category (display names), CRAN Status, License, Essential Extensions Only, Recently Added, Recently Updated, hr, Suggest a Package (disabled). No Sort dropdown. All controls visible without scrolling on ~900px viewport. Checking "Recently Added" filters table to packages added in last 7 days. Checking both "Recently Added" and "Recently Updated" shows the union. Category dropdown shows "Arranging Plots" not "arranging_plots".
- **Testable outcome**: `filter_packages(data, recently_added = TRUE, recently_updated = TRUE)` returns the union of both flags. Sidebar renders with no Sort dropdown. "Essential Extensions Only" has capital O.

#### M5: Browse Table — Title Column, All Category Badges, Column Sorting
- **Goal**: Rename Description → Title column, show all category badges with colours, make all meaningful columns sortable via reactable headers, remove server-side sort.
- **Depends on**: M1 (title field), M2 (category badges), M4 (sort removal)
- **Files modified**:
  - `R/mod_browse.R` — In `build_package_table()`:
    - Rename `description` colDef to use field `title`, label "Title", `sortable = TRUE`.
    - Update `categories` colDef: render ALL categories as separate badges using `build_category_badge()` from `fct_categories.R`. Increase `minWidth` to 180. Set `sortable = TRUE` with a custom `sortMethod` that sorts by the first category's display name.
    - Update `license` colDef: set `sortable = TRUE`.
    - Remove `defaultSorted = list(package_name = "asc")` — let reactable use natural data order (which is alphabetical from the server). Or keep `defaultSorted = list(package_name = "asc")` as initial state since sorting is now fully client-side.
    - Update hidden columns list: `description` is now a separate field (not displayed in table), add it to `show = FALSE` list.
  - `R/app_server.R` — Ensure `filtered_data()` returns data sorted by `package_name` ascending as default (simple `dplyr::arrange()`), since there's no sort dropdown.
- **Definition of done**: Table column header says "Title" (not "Description"). Title column shows CRAN Title data. All categories shown as coloured badges with display names — no "+N" truncation. Clicking any sortable column header sorts the table. Clicking again reverses. Category column sorts alphabetically by first category display name. License column sorts alphabetically. Default sort is Name A–Z.
- **Testable outcome**: Table for a package with categories "animation|geoms" shows two badges: "Animation" (purple) and "Geoms" (red). Clicking "Title" header sorts by title. Clicking "License" sorts by license.

#### M6: Detail View Fixes — Labels, Downloads, Title/Description, Links
- **Goal**: Fix all detail view issues: title/description layout, link labels, download card cleanup, vignettes conditional display.
- **Depends on**: M1 (title/description/has_vignettes data), M2 (category badges)
- **Files modified**:
  - `R/mod_detail.R`:
    - `build_header_card()`: Show `title` as subtitle (`<p class="lead">`) under the `<h2>` package name. Show `description` as a separate `<p>` paragraph below. Use `build_category_badge()` for category badges with display names and colours.
    - `build_links_card()`: Change "GitHub/GitLab" label to "Repo (GitHub, etc.)". Add condition for vignettes: only show when `has_vignettes == TRUE` AND `vignettes_url` is not NA.
    - `build_downloads_card()`: Remove `showcase = htmltools::tags$span("\U0001F4C8")` from all four value boxes. Change fourth value box title from "All time (since 2015)" to "Since 2015".
    - `build_back_button()`: Change class from `btn btn-outline-secondary` to include red border styling. Add CSS class `btn-back` and define in `styles.css`.
  - `inst/app/www/styles.css` — Add `.btn-back` styles: `border-color: #C1272D;` and hover state `background-color: rgba(193, 39, 45, 0.1); border-color: #C1272D; color: #C1272D;`.
  - `tests/testthat/test-mod_detail.R` — Update tests for new title/description layout, link labels, download card labels.
- **Definition of done**: Detail view shows Title as subtitle under package name, Description as paragraph below. "Repo (GitHub, etc.)" label on repo link. No graph emoji on download cards. "Since 2015" label. Vignettes link hidden for packages without vignettes. Back button has red border and red hover.
- **Testable outcome**: Navigate to a package with known vignettes → vignettes link visible. Navigate to a package without vignettes → no vignettes link. Download cards show no emoji. Fourth card says "Since 2015".

#### M7: Dark/Light Mode Consistency
- **Goal**: Fix colour mode persistence across browse/detail views. Fix search box in light mode. Fix light mode background.
- **Depends on**: M5, M6 (need complete UI to test against)
- **Files modified**:
  - `inst/app/www/styles.css`:
    - Add `[data-bs-theme="light"] .rt-search` rule: white background, dark text, light grey border.
    - Add `[data-bs-theme="light"] body` rule: `background-color: #FFFFFF; color: #1a1a1a;` (if not already handled by bslib).
    - Verify all `renderUI()` generated elements inherit theme correctly. If not, add explicit theme-aware CSS for dynamically rendered components.
    - Ensure value boxes, cards, and badges all have both `[data-bs-theme="dark"]` and `[data-bs-theme="light"]` rules.
  - `R/mod_detail.R` — If `renderUI()` content doesn't inherit theme, wrap detail content in a `div` that explicitly reads the theme state, or use `bslib::card()` components consistently (they respect the theme automatically).
  - `R/app_ui.R` — Verify `bslib::input_dark_mode()` placement and configuration.
- **Definition of done**: Toggle to light mode → entire app (browse table, search box, sidebar, detail view, cards, value boxes, footer) renders with white background, dark text, light borders. Toggle back to dark → everything returns to dark theme. Navigate to detail view → theme persists. Navigate back → theme persists. No element renders in the wrong mode.
- **Testable outcome**: Manual visual inspection in both modes across all views. `shinytest2` test: toggle to light mode → navigate to detail → verify background colour is white.

#### M8: Header & Footer Content Updates
- **Goal**: Convert header to plain text with updated links. Update footer content.
- **Depends on**: Nothing (independent of other UI changes)
- **Files modified**:
  - `R/mod_header.R` — Replace `bslib::accordion()` with plain `htmltools::tagList()` of `<p>` tags. Update links: remove "ggplot2 extensions gallery", add "ggplot2 extended (the book)" → `https://ggplot2-extended-book.com/`. Keep "ggplot2 documentation" → `https://ggplot2.tidyverse.org/`.
  - `R/mod_footer.R` — Update email to `anttilennartrask@gmail.com`. Remove "ggplot2 extensions gallery | youcanbeapirate.com" line. Add book link: "Check out the book (in progress): ggplot2 extended" → `https://ggplot2-extended-book.com/`.
- **Definition of done**: Header shows plain text (no accordion). Links: "ggplot2 extended (the book)" and "ggplot2 documentation". Footer shows updated email, book link, no gallery line. Submission text is disabled with tooltip.
- **Testable outcome**: Visually confirm header is always visible (no expand/collapse). Footer email links to `anttilennartrask@gmail.com`. Book link opens `https://ggplot2-extended-book.com/`.

#### M9: Remove mod_recent & Clean Up
- **Goal**: Remove the Recently Added/Updated cards module. Clean up dead code (sort functions, old references).
- **Depends on**: M4 (sidebar has replacement filters), M5 (table is positioned correctly)
- **Files deleted**:
  - `R/mod_recent.R` — delete entirely.
- **Files modified**:
  - `R/app_ui.R` — Remove `mod_recent_ui("recent")` call and the spacer div above the table.
  - `R/app_server.R` — Remove `mod_recent_server("recent", ...)` call. Remove `on_select` callback for recent packages.
  - `R/fct_filters.R` — Remove `sort_packages()` function (if not already removed in M4).
  - `R/fct_data.R` — `get_recently_added()` and `get_recently_updated()` can be kept (they're useful utilities) but are no longer called from `mod_recent`. They can be removed if no other code references them.
- **Definition of done**: No "Recently Added" / "Recently Updated" cards appear above the table. Main table sits directly below the intro text. App runs without errors. No dead code references to `mod_recent`. `R CMD check` passes.
- **Testable outcome**: App loads with table immediately below intro text. `R CMD check --as-cran` passes. No warnings about unused imports.

#### M10: Shareable Package Links (should-have)
- **Goal**: URL updates with `?package={name}` when viewing a package. App loads directly to a package detail view when the URL contains a `package` parameter.
- **Depends on**: M6 (detail view must be complete)
- **Files modified**:
  - `R/app_server.R` — Add URL routing logic:
    - On app load: parse `session$clientData$url_search` for `package` parameter. If present, set `selected_package()` to that value.
    - When `selected_package()` changes: call `shiny::updateQueryString(paste0("?package=", selected_package()))` when a package is selected, or `shiny::updateQueryString("?")` when returning to browse.
  - `R/mod_detail.R` — No changes needed (already driven by `selected_package()` reactive).
- **Definition of done**: Navigating to `{app_url}?package=ggrepel` opens directly to the ggrepel detail view. Clicking a package in the table updates the URL. Clicking "Back" removes the `?package=` parameter. Copying the URL and opening in a new tab shows the same package.
- **Testable outcome**: `shinytest2` test: set URL to `?package=ggrepel` → detail view renders for ggrepel. Navigate back → URL is clean.

#### M11: Navigation Arrows Between Packages (should-have)
- **Goal**: Add previous/next navigation arrows in the detail view to move between packages alphabetically.
- **Depends on**: M6 (detail view), M10 (shareable links — arrows should update URL)
- **Files modified**:
  - `R/mod_detail.R`:
    - Add `all_packages_alpha` parameter to `mod_detail_server()` — a reactive containing the alphabetically sorted vector of all `package_name` values.
    - Build navigation arrows: find current package's index in the sorted vector, determine prev/next. Disable the arrow at the boundaries (first/last package).
    - Add `input$prev_pkg` and `input$next_pkg` observers that call `on_navigate(pkg_name)` callback.
    - Render arrows alongside the back button in a flex row.
  - `R/app_server.R` — Pass `all_packages_alpha` reactive to `mod_detail_server()`. Add `on_navigate` callback that sets `selected_package()` to the new package name.
- **Definition of done**: Detail view shows "← Prev" and "Next →" buttons next to the back button. Clicking "Next →" navigates to the next package alphabetically. URL updates. At the first package alphabetically, "← Prev" is disabled. At the last, "Next →" is disabled.
- **Testable outcome**: Navigate to "aaa" (first alpha package) → "← Prev" is disabled. Click "Next →" → navigates to next package. URL updates.

#### M12: Code Example Enhancements (should-have)
- **Goal**: Prepend `install.packages()` and `library()` calls to code examples in the detail view.
- **Depends on**: M6 (detail view code example card)
- **Files modified**:
  - `R/mod_detail.R` — In `build_example_card()`, when `example_code` is not NA and `license_allowed == TRUE`, prepend:
    ```r
    # Install and load the package
    install.packages("{package_name}")
    library({package_name})

    # Example:
    {original_example_code}
    ```
    This is purely a display-time transformation — the stored `example_code` in `examples.parquet` is not modified. The package name is available from `example$package_name`.
- **Definition of done**: Code example block in detail view starts with `install.packages()` and `library()` lines. Copy-to-clipboard copies the full block including the prepended lines.
- **Testable outcome**: Navigate to any package with a code example → code block starts with install/library lines. Click "Copy" → paste into editor → install and library lines are present.

### 12. Configuration & Environment

- **Environment variables**:

| Variable | Purpose | Required | Default |
|---|---|---|---|
| `GITHUB_PAT` | GitHub API authentication (5,000 req/hr) | Yes (pipeline) | N/A |
| `GCP_PROJECT_ID` | Google Cloud project ID | Yes (CI deploy) | N/A |
| `GCP_REGION` | Cloud Run region | Yes (CI deploy) | `europe-north1` |
| `GCP_SERVICE_NAME` | Cloud Run service name | Yes (CI deploy) | `ggplot2-companion` |
| `GCP_SA_KEY` | Service account key JSON for CI/CD | Yes (CI deploy) | N/A |
| `SHINY_PORT` | Shiny server port inside container | No | `3838` |
| `RENDER_EXAMPLES` | Whether to render code examples (set by weekly pipeline) | No | `""` (false) |

- **R version**: >= 4.3.0
- **Key package versions** (pinned in `renv.lock`):

| Package | Purpose |
|---|---|
| `shiny` (>= 1.9.0) | Core Shiny framework |
| `golem` (>= 0.5.0) | App framework |
| `bslib` (>= 0.9.0) | Bootstrap 5 UI |
| `reactable` (>= 0.4.4) | Interactive table |
| `arrow` (>= 17.0.0) | Parquet read/write |
| `dplyr` (>= 1.1.0) | Data manipulation |
| `targets` (>= 1.7.0) | Pipeline orchestration |
| `pkgsearch` (>= 3.1.0) | CRAN metadata API |
| `cranlogs` (>= 2.1.1) | CRAN download counts |
| `gh` (>= 1.4.0) | GitHub API client |
| `jsonlite` (>= 1.8.0) | JSON export |
| `callr` (>= 3.7.0) | Subprocess for example rendering |
| `logger` (>= 0.3.0) | Structured logging |
| `htmltools` (>= 0.5.8) | HTML generation |

### 13. Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| CRAN/cranlogs API downtime during pipeline | Medium | Low | `{targets}` uses cached previous values. Pipeline logs warning but continues. Data is at most 1 day stale. |
| GitHub API rate limit exceeded | Low | Low | Use `GITHUB_PAT` (5,000 req/hr). ~455 requests per run is well within limit. Cache with `{targets}`. |
| Code example rendering takes too long | High | Medium | 30-second timeout per package. Run weekly, not daily. Skip packages that consistently fail. |
| Docker image size too large | Medium | Medium | Multi-stage build. Only include app code + Parquet files + PNG examples in final image. Target: < 1 GB. |
| Dark/light mode inconsistency in dynamically rendered UI | Medium | High | Primary UX issue. Test all `renderUI()` output in both modes. Use `bslib::card()` components that respect theme. Add explicit CSS rules for both modes. |
| 19-colour category palette insufficient contrast | Low | Medium | Colours chosen from Tailwind palette with good separation. Semi-transparent backgrounds reduce visual weight. Test in both dark and light modes. |
| `pkgsearch` response doesn't include vignettes field | Low | Medium | Fallback: send HTTP HEAD request to the vignettes URL during pipeline. If 404, set `has_vignettes = FALSE`. |
| Cloud Run cold starts | Medium | Low | Lightweight app (Parquet + arrow, no external DB calls on startup). Cold start should be < 10 seconds. |
| `has_vignettes` detection is inaccurate | Low | Low | Some packages may have vignettes not listed in pkgsearch. HEAD request fallback catches most cases. False negatives (hiding link when vignettes exist) are low-impact — the Manual link still provides access. |
| Reactable column sort doesn't handle ties well | Low | Low | Category and License columns will have many ties. Reactable's built-in sort is stable (preserves original order for ties), so the default alphabetical order by package_name serves as the secondary sort. |

### 14. Open Questions

1. ~~Which GitHub API field populates `github_updated`?~~ **Resolved**: Uses `pushed_at` (with `updated_at` as fallback). `pushed_at` represents actual code pushes, which is more meaningful than `updated_at` (which includes issue/PR activity).
2. ~~Is the CRAN Description field currently fetched?~~ **Resolved**: No, the pipeline currently stores `response$Title` as `description`. M1 fixes this by splitting into `title` (from `response$Title`) and `description` (from `response$Description`).
3. ~~Is the Sort dropdown a bug or unbuilt feature?~~ **Resolved**: The `sort_packages()` function works correctly, but the reactable's `defaultSorted` parameter overrides the server-side sort order. **Decision**: Remove the Sort dropdown entirely. Sorting is handled by reactable column headers (client-side).
4. ~~How to check if a package has vignettes?~~ **Resolved**: Check `pkgsearch::cran_package()` response for `vignettes` field. If empty or missing, set `has_vignettes = FALSE`. HEAD request fallback if needed.
5. ~~Recently Added + Recently Updated: AND or OR?~~ **Resolved**: OR logic. When both are checked, show packages matching either flag.
6. ~~Is prepending install/library to examples straightforward?~~ **Resolved**: Yes. The package name is always known. Prepend at display time in `build_example_card()`, not in the stored data. Implemented in M12 as a should-have.

### 15. Appendix

#### A. API Reference

**CRAN metadata via `pkgsearch`**:
- Function: `pkgsearch::cran_package(package_name)`
- Returns: List with fields including `Package`, `Version`, `Title`, `Description`, `License`, `Maintainer`, `Published`, `URL`, `BugReports`, `vignettes` (list), etc.
- Rate limit: No documented limit, but be polite (~1 req/sec).
- No authentication required.
- **Key fields for this app**: `Title` (short one-liner → `title` column), `Description` (longer paragraph → `description` column), `vignettes` (list → `has_vignettes` flag).

**CRAN downloads via `cranlogs`**:
- Function: `cranlogs::cran_downloads(packages, from, to)`
- Returns: Data frame with `date`, `count`, `package` columns.
- Rate limit: Generous. Batch requests supported.
- No authentication required.
- Note: Data is typically 2 days behind.

**GitHub API via `gh`**:
- Function: `gh::gh("GET /repos/{owner}/{repo}")`
- Returns: List with `pushed_at`, `updated_at`, `description`, `html_url`, etc.
- Rate limit: 5,000 req/hr with PAT, 60 req/hr without.
- Authentication: `GITHUB_PAT` environment variable.
- **Key field**: `pushed_at` is used for `github_updated` (represents last code push, not last issue/PR activity).

#### B. URL Construction Patterns

| URL Type | Pattern | Condition |
|---|---|---|
| CRAN page | `https://cran.r-project.org/package={package_name}` | `on_cran == TRUE` |
| Reference manual | `https://cran.r-project.org/web/packages/{package_name}/{package_name}.pdf` | `on_cran == TRUE` |
| Vignettes (directory) | `https://cran.r-project.org/web/packages/{package_name}/vignettes/` | `on_cran == TRUE` AND `has_vignettes == TRUE` |

#### C. Glossary

| Term | Definition |
|---|---|
| ggplot2 extension | An R package that extends ggplot2's functionality by adding new geoms, stats, scales, themes, or other components. |
| CRAN | The Comprehensive R Archive Network — the main repository for R packages. |
| Essential Extension | A manually curated tag indicating a package is particularly useful for beginners or widely applicable. |
| Pipeline | The automated data processing workflow that fetches, transforms, and stores package data. |
| Parquet | A columnar data storage format, efficient for analytical queries. Used as the app's data layer. |
| golem | An R package framework for building production-grade Shiny applications as R packages. |
| targets | An R package for defining and running reproducible data pipelines as directed acyclic graphs (DAGs). |
| display_name | The human-readable category name (e.g., "Arranging Plots") as opposed to the technical identifier (e.g., "arranging_plots"). |

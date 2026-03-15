# SPEC.md
## ggplot2 Extended Companion — Technical Specification

### 1. Overview
- **App name**: ggplot2 Extended Companion
- **One-line description**: A searchable, filterable directory of ~455 ggplot2 extension packages with daily-refreshed metadata, download statistics, and pre-rendered code examples.
- **Technology**: R Shiny (golem framework)
- **Target deployment**: Docker on Google Cloud Run
- **Repository structure**: Mono-repo (private GitHub repository) containing the Shiny app, data pipeline, and deployment configuration.

### 2. Architecture

#### 2.1 Application Structure
- **Framework**: golem — app is structured as an R package with `DESCRIPTION`, `NAMESPACE`, and `roxygen2` documentation.
- **UI framework**: bslib (Bootstrap 5) with dark mode as the default colour mode.
- **Routing approach**: Single-page app using `bslib::page_sidebar()` with a main browsing table and a detail view. The detail view replaces the table content when a package is selected (no URL routing in v1).
- **Table package**: reactable for the main browsing table (client-side filtering, sorting, search).
- **Module list**:

| Module | File | Responsibility |
|---|---|---|
| Browse | `R/mod_browse.R` | Main package table with search, filters, sorting |
| Detail | `R/mod_detail.R` | Package detail view with full metadata, links, code example |
| Sidebar | `R/mod_sidebar.R` | Filter controls (category, CRAN status, license, essential) and sort selector |
| Recent | `R/mod_recent.R` | Recently added and recently updated package lists |
| Header | `R/mod_header.R` | App title, introductory text, onboarding content |
| Footer | `R/mod_footer.R` | Disclaimer, links to book/resources, submission link, footer credits |

#### 2.2 Data Architecture
- **Storage**: Parquet files bundled inside the Docker image, queried in-process by DuckDB via `dplyr`/`dbplyr`.
- **Caching**: No runtime caching needed — data is loaded once at app startup from Parquet files into DuckDB. Data is static for the lifetime of a container instance.
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
| Short description | `description` | character | CRAN API (preferred), curated CSV (fallback) | Daily | Display, search (stretch) |
| Creator/Maintainer | `maintainer` | character | CRAN API (parsed from `Maintainer` field) | Daily | Display, sort |
| Categories | `categories` | character (pipe-separated) | Curated CSV | On edit | Display, filter |
| Is essential | `is_essential` | logical | Curated CSV | On edit | Filter |
| On CRAN | `on_cran` | logical | Derived (CRAN API response) | Daily | Filter, display |
| License | `license` | character | CRAN API | Daily | Display, filter |
| Latest CRAN version | `cran_version` | character | CRAN API | Daily | Display |
| CRAN published date | `cran_published` | date | CRAN API | Daily | Display, sort |
| GitHub last update | `github_updated` | date | GitHub API | Daily | Display, sort |
| CRAN URL | `cran_url` | character | Derived (pattern: `https://cran.r-project.org/package={name}`) | On add | Display (link) |
| Website URL | `website_url` | character | Curated CSV (manual) | On edit | Display (link) |
| GitHub/GitLab URL | `repo_url` | character | Curated CSV | On edit | Display (link) |
| Reference manual URL | `manual_url` | character | Derived (pattern-based) | Daily | Display (link) |
| Vignettes URL | `vignettes_url` | character | Derived (pattern-based) | Daily | Display (link) |
| Date added to app | `date_added` | date | Curated CSV | On add | Display, sort (nice-to-have), recent list |
| Last checked | `last_checked` | date | Pipeline metadata | Daily | Internal only |

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

#### 3.5 Data Sources

- **CRAN metadata**: `pkgsearch::cran_package()` — returns description, version, license, published date, maintainer, etc. No authentication required. Rate limit: be polite (1 req/sec recommended). ~455 calls per pipeline run.
- **cranlogs API**: `cranlogs::cran_downloads()` — returns daily download counts. No authentication. Documented rate limits are generous. Aggregate across time windows in R.
- **GitHub API**: `gh::gh()` — returns last push date, repo metadata. Requires `GITHUB_PAT` for 5,000 req/hr (unauthenticated: 60 req/hr). ~455 calls per pipeline run.
- **Package documentation**: `tools::Rd_db()` or parsing installed package `\examples{}` sections. Runs locally during example rendering.

#### 3.6 Data Storage Schema

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
| 2. Fetch CRAN metadata | `cran_metadata` | `fetch_cran_metadata()` | `curated_packages$package_name` | tibble with description, version, license, published date, maintainer | Per-package: log warning, use cached. If all fail: use previous target value. |
| 3. Fetch download stats | `download_stats` | `fetch_download_stats()` | `curated_packages$package_name` | tibble with 7d, 30d, 365d, all-time counts | Per-package: log warning, set counts to NA. If cranlogs API down: use previous target value. |
| 4. Fetch GitHub metadata | `github_metadata` | `fetch_github_metadata()` | `curated_packages$repo_url` | tibble with last update date, repo info | Per-package: log warning, set to NA. Rate limit: use cached. |
| 5. Construct URLs | `constructed_urls` | `construct_urls()` | `curated_packages`, `cran_metadata` | tibble with `cran_url`, `manual_url`, `vignettes_url` | Pattern-based, no external calls — cannot fail. |
| 6. Merge all data | `packages_combined` | `merge_package_data()` | Steps 1–5 outputs | Single tibble with all fields | Cannot fail (joins only). |
| 7. Write packages.parquet | `packages_parquet` | `write_parquet_output()` | `packages_combined` | `data/packages.parquet` | Fail pipeline if write fails. |
| 8. Write downloads.parquet | `downloads_parquet` | `write_parquet_output()` | `download_stats` | `data/downloads.parquet` | Fail pipeline if write fails. |
| 9. Derive recent lists | `recent_packages` | `derive_recent()` | `packages_combined` | Included in `packages.parquet` (sorted/flagged) | Cannot fail. |
| 10. Render code examples | `code_examples` | `render_examples()` | `packages_combined`, license allowlist | `data/examples.parquet` + PNG files in `inst/app/www/examples/` | Per-package: log warning, flag `example_success = FALSE`. Timeout: 30s per example. |
| 11. Write examples.parquet | `examples_parquet` | `write_parquet_output()` | `code_examples` | `data/examples.parquet` | Fail pipeline if write fails. |
| 12. Export JSON | `packages_json` | `export_json()` | `packages_combined`, `download_stats` | `inst/app/www/data/packages.json` | Cannot fail. |
| 13. Write metadata | `pipeline_metadata` | `write_metadata()` | Timestamps from steps 2–4, 10 | `data/metadata.parquet` | Cannot fail. |

#### 4.3 Code Example Rendering (Step 10 Detail)

For each package where `license_allowed == TRUE`:

1. Install the package in an isolated library path (within the GitHub Actions runner).
2. Extract the first example from the package's primary function documentation using `tools::Rd_db()`.
3. If no example found, check for a `README` example or vignette code block. If still nothing, set `example_success = FALSE`.
4. Execute the example code in a `callr::r()` subprocess with a 30-second timeout.
5. Capture the last plot via `ggplot2::ggsave()` as a PNG (800×600px, 150 DPI).
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

#### 4.5 Category Reference

A separate file `data-raw/categories.csv` defines the canonical category list:

```csv
category,display_name,description
animation,"Animation","Packages for creating animated plots"
annotations,"Annotations","Packages for adding text, labels, and annotations"
arranging_plots,"Arranging Plots","Packages for combining multiple plots"
colours,"Colours","Colour palettes and colour-related tools"
geoms,"Geoms","New geometric objects for ggplot2"
helpers,"Helpers","Utility packages that assist ggplot2 workflows"
interactive_plots,"Interactive Plots","Packages for creating interactive visualisations"
maps,"Maps","Packages for geographic/spatial visualisation"
networks,"Networks","Packages for network and graph visualisation"
rendering,"Rendering","Packages for rendering and output"
scales_and_guides,"Scales & Guides","Custom scales, axes, legends, and guides"
sports,"Sports","Sports-specific visualisation packages"
stats,"Stats","Statistical layers and transformations"
themes,"Themes","Custom themes and styling"
transformations,"Transformations","Coordinate and data transformations"
```

This list will be refined during the Notion migration/category audit.

### 5. UI Specification

#### 5.1 Navigation Structure

The app uses `bslib::page_sidebar()` as the primary layout. The sidebar contains filter and sort controls. The main panel switches between the browse view (table) and the detail view (single package).

```
┌──────────────────────────────────────────────────────────┐
│  [ggplot2 Extended Companion]           [dark/light] ☀️  │
├────────────┬─────────────────────────────────────────────┤
│            │                                             │
│  SIDEBAR   │  MAIN CONTENT                              │
│            │                                             │
│  Search    │  [Header / Intro text]                     │
│  ________  │                                             │
│            │  [Recently Added] [Recently Updated]        │
│  Filters   │                                             │
│  Category  │  ┌─────────────────────────────────────┐   │
│  CRAN      │  │  Package Table (reactable)          │   │
│  License   │  │  ─────────────────────────────────  │   │
│  Essential │  │  name | desc | cat | 30d | all | …  │   │
│            │  │  ─────────────────────────────────  │   │
│  Sort by   │  │  ...                                │   │
│  [dropdown]│  │  ...                                │   │
│            │  └─────────────────────────────────────┘   │
│            │                                             │
│  ────────  │  [Footer / Disclaimer / Links]             │
│  Submit    │                                             │
│  [link]    │                                             │
│            │                                             │
│  Footer    │                                             │
│  links     │                                             │
│            │                                             │
└────────────┴─────────────────────────────────────────────┘
```

When a package is clicked, the main content area replaces the table with the detail view. A "← Back to all packages" button returns to the table.

#### 5.2 Browse View (`mod_browse`)

- **Purpose**: Discover and evaluate ggplot2 extension packages.
- **Layout**: Full-width `reactable` table in the main panel.
- **Components**:
  - **Package table** (`reactable`):
    - **Columns**:

| Column | Data Field | Width | Sortable | Notes |
|---|---|---|---|---|
| Name | `package_name` | 150px | Yes (alpha) | Clickable link → detail view. Bold text. |
| Description | `description` | Flex | No | Truncated to ~100 chars with ellipsis. |
| Category | `categories` | 140px | No | Displayed as badge(s). First category shown, "+N" if multiple. |
| License | `license` | 100px | No | Plain text. |
| Downloads (30d) | `downloads_30d` | 100px | Yes (numeric) | Formatted with comma separators. |
| Downloads (All) | `downloads_all` | 100px | Yes (numeric) | Formatted with comma separators. |
| CRAN Version | `cran_version` | 90px | No | Shows version string, or "—" if not on CRAN. |
| CRAN Published | `cran_published` | 110px | Yes (date) | Format: `YYYY-MM-DD`. |
| GitHub Updated | `github_updated` | 110px | Yes (date) | Format: `YYYY-MM-DD`. |

  - **Pagination**: 25 rows per page, client-side pagination.
  - **Search**: Built-in `reactable` search bar (searches `package_name` column). Positioned above the table.
  - **"Essential Extensions" badge**: Packages with `is_essential == TRUE` get a small star icon or badge next to their name.

- **Interactions**:
  - Click package name → navigate to detail view (`mod_detail`).
  - Type in search bar → table filters instantly (client-side).
  - Change sidebar filters → table updates (server-side filter, then re-render reactable).
  - Change sort dropdown → table re-sorts.
  - Click column header → sort by that column (reactable built-in).

- **Reactive dependencies**:
  - `filtered_packages()` — a reactive expression that applies sidebar filters to the full dataset.
  - `selected_package()` — a `reactiveVal` holding the currently selected package name (or `NULL` for browse view).

#### 5.3 Sidebar Controls (`mod_sidebar`)

- **Purpose**: Filter and sort the package table.
- **Layout**: `bslib::sidebar()` with vertically stacked controls.
- **Components**:

| Control | Type | Options | Default | Behaviour |
|---|---|---|---|---|
| Search | `textInput` | Free text | Empty | Filters `package_name` (passed to reactable search). |
| Category | `selectInput` | All categories + "All" | "All" | Single-select. Filters packages containing the selected category. |
| CRAN status | `radioButtons` | "All", "On CRAN", "Not on CRAN" | "All" | Filters by `on_cran`. |
| License | `selectInput` | All unique licenses + "All" | "All" | Single-select. Filters by `license`. |
| Essential only | `checkboxInput` | Toggle | Unchecked | When checked, filters to `is_essential == TRUE`. |
| Sort by | `selectInput` | "Name (A–Z)", "Name (Z–A)", "Creator (A–Z)", "Creator (Z–A)", "Downloads (30d) ↓", "Downloads (All) ↓", "CRAN Published (newest)", "CRAN Published (oldest)", "GitHub Updated (newest)", "GitHub Updated (oldest)" | "Name (A–Z)" | Sets the default sort on the reactable. |
| Submit a package | `actionLink` | — | — | Opens Google Form in new tab. Styled as a button. |

- **Interactions**:
  - Any filter change → `filtered_packages()` reactive updates → table re-renders.
  - Sort change → table re-renders with new default sort.

#### 5.4 Detail View (`mod_detail`)

- **Purpose**: View full information about a single package.
- **Trigger**: User clicks a package name in the browse table.
- **Layout**: Replaces the main content area. Structured as a vertical stack of `bslib::card()` components.

**Components (top to bottom)**:

1. **Back button**: `actionButton` — "← Back to all packages". Returns to browse view, restoring previous filter/sort state.

2. **Package header card**:
   - Package name (large heading, `<h2>`).
   - "Essential Extension" badge (if applicable).
   - Full description text.
   - Creator/Maintainer name.
   - Category badges (all categories).
   - License.

3. **Links card**:
   - Row of icon-buttons/links: Website, GitHub/GitLab, CRAN, Reference Manual, Vignettes.
   - Each link opens in a new tab. Links that are `NA` are hidden (not greyed out).

4. **Download statistics card**:
   - Four `bslib::value_box()` components in a row:
     - "Last 7 days" — `downloads_7d`
     - "Last 30 days" — `downloads_30d`
     - "Last 365 days" — `downloads_365d`
     - "All time (since 2015)" — `downloads_all`
   - Download trend chart (nice-to-have): `plotly` or `echarts4r` line chart of monthly downloads. Deferred to v1.1 if time permits.

5. **Version info card**:
   - Latest CRAN version + published date.
   - GitHub last update date.

6. **Code example card**:
   - Syntax-highlighted code block (using `htmltools::pre()` + `code()` with a highlight.js or Prism.js integration via CSS class).
   - "Copy to clipboard" button (JavaScript `navigator.clipboard.writeText()`).
   - Rendered output image (`<img>` tag pointing to `examples/{package_name}.png`).
   - If `example_success == FALSE`: show code only, with a note "Output preview not available for this package."
   - "Example last rendered: {example_rendered_at}" timestamp at the bottom of the card.
   - If `license_allowed == FALSE`: show a note "Code example not available — package license could not be verified." and no code.

- **Reactive dependencies**:
  - `selected_package()` — drives which package data is displayed.
  - Package data is looked up from the DuckDB connection by `package_name`.

#### 5.5 Recently Added / Recently Updated (`mod_recent`)

- **Purpose**: Highlight new and recently updated packages.
- **Layout**: Two horizontally arranged `bslib::card()` components above the main table, each containing a compact list.
- **Components**:
  - **"Recently Added" card**: Last 10 packages by `date_added`, descending. Each entry: package name (clickable → detail view) + date added.
  - **"Recently Updated" card**: Last 10 packages by `max(cran_published, github_updated)`, descending. Each entry: package name (clickable → detail view) + update date + source label ("CRAN" or "GitHub").
- **Interactions**: Click package name → navigate to detail view.

#### 5.6 Header / Intro (`mod_header`)

- **Purpose**: Brief introduction to ggplot2 extensions for new visitors.
- **Layout**: A collapsible `bslib::accordion()` panel above the recent lists. Collapsed by default (so returning users skip it).
- **Content**:
  - "What are ggplot2 extensions?" — 2–3 sentences explaining the concept.
  - Link to the ggplot2 extended book.
  - Link to ggplot2 documentation.
- **Design**: Understated — not a hero banner. Informative for newcomers, ignorable for regulars.

#### 5.7 Footer / Disclaimer (`mod_footer`)

- **Purpose**: Legal disclaimer, credits, and cross-links.
- **Layout**: Full-width footer below the main content area, styled consistently with BiblioStatus footer.
- **Content**:
  - **Disclaimer**: "If you have concerns about information presented on this site (licensing, metadata accuracy, etc.), please reach out via email at [email] to have it corrected or removed."
  - **Data freshness**: "Package data last updated: {last_run from metadata}."
  - **Links**: ggplot2 extended book, youcanbeapirate.com, other youcanbeapirate apps.
  - **Submission link**: "Know a ggplot2 extension we're missing? [Submit it here]" → Google Form.
  - **Credit**: "Created by Antti Rask | youcanbeapirate.com"

### 6. Package Submission

#### 6.1 Submission Mechanism
- **Type**: External link to a Google Form (opens in new tab).
- **Location in app**: Sidebar (always visible) + footer.
- **Link text**: "Suggest a Package" (sidebar), "Know a ggplot2 extension we're missing? Submit it here" (footer).

#### 6.2 Google Form Fields

| Field | Type | Required | Notes |
|---|---|---|---|
| Package name | Short text | Yes | |
| Link | URL | Yes | CRAN, GitHub, pkgdown, or other |
| Category suggestion | Dropdown (from category list) | No | "I'm not sure" as an option |
| Any other notes | Long text | No | |

#### 6.3 Submission Processing
- **Storage**: Google Form responses stored in linked Google Sheet.
- **Notification**: Google Forms sends email notification to maintainer on each submission.
- **Approval flow**: Maintainer reviews submission → adds row to `data-raw/packages_curated.csv` → commits and pushes → triggers pipeline manually → package goes live.

### 7. Styling & Theming

- **Theme**: bslib `bs_theme()` with Bootstrap 5, dark mode as default.
- **Colour palette**:

| Role | Hex | Usage |
|---|---|---|
| Primary accent | `#C1272D` | Buttons, links, active states, badges |
| Background (dark) | `#191414` | Page background in dark mode |
| Foreground (dark) | `#FFFFFF` | Text colour in dark mode |
| Background (light) | `#FFFFFF` | Page background in light mode |
| Foreground (light) | `#1a1a1a` | Text colour in light mode |
| Muted text | `#9ca3af` | Secondary text, timestamps, footnotes |
| Card background (dark) | `#2a2a2e` | Card surfaces in dark mode |
| Success | `#22c55e` | "On CRAN" badge |
| Warning | `#f59e0b` | Stale data indicator |

- **Typography**:
  - Headings: Gotham (loaded via CDN, with Inter as fallback).
  - Body text: Inter (Google Fonts).
  - Code blocks: `"Fira Code", "Source Code Pro", monospace`.
  - Base font size: 16px (1rem).
- **Component styling**:
  - **Cards**: Subtle border, rounded corners (0.5rem), slight shadow in dark mode.
  - **Badges** (categories): Pill-shaped, primary colour background, white text.
  - **Essential badge**: Star icon (⭐) or distinct colour variant.
  - **Table**: Striped rows (subtle), hover highlight, compact row height.
  - **Value boxes**: Primary colour accent on the left border.
  - **Buttons**: Primary colour, rounded, consistent padding.
- **Dark/light mode toggle**: `bslib::input_dark_mode()` in the navbar/header area. Dark mode is the default (`mode = "dark"`).
- **Responsive**: Desktop-first. bslib's Bootstrap 5 grid handles basic responsiveness. Sidebar collapses on mobile. No mobile-specific design work in v1.

### 8. AI Agent Compatibility

- **Semantic HTML**: bslib and reactable produce reasonably semantic markup. Ensure headings (`<h1>` through `<h4>`), table elements, and links use proper HTML tags.
- **Meta tags**: `tags$head()` includes:
  - `<meta name="description" content="Searchable directory of 455+ ggplot2 extension packages with download statistics and code examples.">`
  - `<meta property="og:title" content="ggplot2 Extended Companion">`
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
        "description": "...",
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
| Unit | `testthat` | Data processing functions: `fetch_cran_metadata()`, `fetch_download_stats()`, `merge_package_data()`, `construct_urls()`, `render_examples()`, CSV validation | `tests/testthat/` |
| Integration | `testthat` | Full pipeline: `targets::tar_make()` with mocked API responses produces valid Parquet files | `tests/testthat/` |
| UI | `shinytest2` | Key user flows: browse → filter → select package → view detail → back to browse | `tests/testthat/` |
| Snapshot | `testthat` | reactable output structure, value box rendering | `tests/testthat/` |
| CSV validation | `testthat` (+ CI) | `packages_curated.csv` structure and content validity | `tests/testthat/` |

**Mocking strategy**: Use `httptest2` to mock CRAN, cranlogs, and GitHub API responses in tests. Store mock fixtures in `tests/testthat/fixtures/`.

### 10. File & Directory Structure

```
ggplot2-extended-companion/
├── DESCRIPTION                          # golem package metadata, dependencies
├── NAMESPACE                            # Auto-generated by roxygen2
├── LICENSE                              # Project license (e.g., MIT)
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
│   ├── app_server.R                     # Main server function, loads data, calls modules
│   ├── app_ui.R                         # Main UI function, bslib layout, theme, meta tags
│   ├── run_app.R                        # golem::run_app() wrapper
│   ├── mod_browse.R                     # Browse view: reactable table
│   ├── mod_detail.R                     # Detail view: full package info
│   ├── mod_sidebar.R                    # Sidebar: filters, sort, submission link
│   ├── mod_recent.R                     # Recently added / recently updated lists
│   ├── mod_header.R                     # Introductory text / onboarding accordion
│   ├── mod_footer.R                     # Disclaimer, credits, links
│   ├── fct_data.R                       # Data loading functions (DuckDB + Parquet)
│   ├── fct_pipeline.R                   # Pipeline functions (fetch, merge, write)
│   ├── fct_examples.R                   # Code example extraction and rendering
│   ├── fct_urls.R                       # URL construction logic
│   ├── fct_validation.R                 # CSV validation functions
│   └── utils_helpers.R                  # Shared utility functions
├── data/
│   ├── packages.parquet                 # Core package data (pipeline output)
│   ├── downloads.parquet                # Download statistics (pipeline output)
│   ├── examples.parquet                 # Code example metadata (pipeline output)
│   └── metadata.parquet                 # Pipeline run metadata (pipeline output)
├── data-raw/
│   ├── packages_curated.csv             # Curated package list (source of truth)
│   ├── categories.csv                   # Canonical category definitions
│   ├── license_allowlist.csv            # Allowed licenses for example rendering
│   └── migrate_notion.R                # One-time Notion migration script
├── inst/
│   └── app/
│       └── www/
│           ├── styles.css               # Custom CSS overrides
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
│       ├── test-fct_data.R              # Tests for data loading
│       ├── test-fct_pipeline.R          # Tests for pipeline functions
│       ├── test-fct_examples.R          # Tests for example rendering
│       ├── test-fct_urls.R              # Tests for URL construction
│       ├── test-fct_validation.R        # Tests for CSV validation
│       ├── test-mod_browse.R            # UI tests for browse module
│       ├── test-mod_detail.R            # UI tests for detail module
│       └── fixtures/
│           ├── cran_response.json       # Mock CRAN API response
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

### 11. Implementation Milestones

#### M0: Project Scaffold
- **Goal**: Initialise golem project structure, set up renv, configure bslib theme, create empty app shell that runs.
- **Files created**:
  - `DESCRIPTION` — package metadata with initial dependencies (`shiny`, `bslib`, `golem`, `reactable`, `duckdb`, `dplyr`, `arrow`, `logger`, `jsonlite`)
  - `NAMESPACE` — auto-generated
  - `app.R` — golem entry point
  - `R/app_ui.R` — bslib `page_sidebar()` with dark theme, placeholder content
  - `R/app_server.R` — empty server function
  - `R/app_config.R` — golem configuration
  - `R/run_app.R` — `run_app()` function
  - `inst/app/www/styles.css` — initial custom CSS (dark mode colours, font imports)
  - `renv.lock` — initial lockfile
  - `.gitignore`, `.Rbuildignore`, `.dockerignore`
  - `data-raw/categories.csv` — initial category list
  - `data-raw/license_allowlist.csv` — initial license allowlist
- **Definition of done**: `golem::run_app()` launches a Shiny app showing a dark-themed page with the title "ggplot2 Extended Companion", a sidebar placeholder, and a main content area placeholder. No data, no functionality.
- **Testable outcome**: App launches without errors. Dark theme is visible. Page title is correct.

#### M1: Notion Migration & Curated Data
- **Goal**: Migrate ~455 packages from Notion CSV export into `packages_curated.csv`. Audit and standardise categories.
- **Depends on**: M0
- **Files created**:
  - `data-raw/migrate_notion.R` — migration script
  - `data-raw/packages_curated.csv` — populated with ~455 packages
  - `data-raw/categories.csv` — refined category list based on audit
  - `R/fct_validation.R` — CSV validation functions
  - `tests/testthat/test-fct_validation.R` — validation tests
- **Definition of done**: `packages_curated.csv` contains all ~455 packages with: `package_name`, `categories` (pipe-separated, from canonical list), `is_essential`, `website_url`, `repo_url`, `date_added`. Validation script passes with zero errors. Category audit is complete (every package has at least one valid category).
- **Testable outcome**: `source("data-raw/migrate_notion.R")` produces the CSV. `testthat::test_file("tests/testthat/test-fct_validation.R")` passes.

#### M2: Data Pipeline (Core)
- **Goal**: Build the `{targets}` pipeline that fetches CRAN metadata, download stats, and GitHub metadata, then produces Parquet files.
- **Depends on**: M1
- **Files created**:
  - `_targets.R` — pipeline definition
  - `R/fct_pipeline.R` — `fetch_cran_metadata()`, `fetch_download_stats()`, `fetch_github_metadata()`, `merge_package_data()`, `write_parquet_output()`
  - `R/fct_urls.R` — `construct_urls()` for CRAN, manual, vignette URLs
  - `tests/testthat/test-fct_pipeline.R` — pipeline function tests with mocked APIs
  - `tests/testthat/test-fct_urls.R` — URL construction tests
  - `tests/testthat/fixtures/` — mock API response files
  - `data/packages.parquet` — first real output
  - `data/downloads.parquet` — first real output
  - `data/metadata.parquet` — first real output
- **Definition of done**: `targets::tar_make()` runs successfully, producing three Parquet files with complete data for all ~455 packages. `packages.parquet` contains all fields from the data model (section 3.1). `downloads.parquet` contains 7d, 30d, 365d, and all-time download counts. Pipeline handles individual package failures gracefully (logs warning, continues).
- **Testable outcome**: `targets::tar_make()` completes. `arrow::read_parquet("data/packages.parquet") |> nrow()` returns ~455. `tar_visnetwork()` shows a clean DAG with all targets up to date.

#### M3: Data Loading & Browse Table
- **Goal**: Wire the Parquet data into the Shiny app. Display all packages in a searchable, sortable `reactable` table.
- **Depends on**: M0, M2
- **Files created/modified**:
  - `R/fct_data.R` — `load_packages()`, `load_downloads()` functions using DuckDB
  - `R/mod_browse.R` — `mod_browse_ui()` / `mod_browse_server()` with reactable
  - `R/app_server.R` — updated to load data at startup and call browse module
  - `R/app_ui.R` — updated to include browse module UI in main panel
  - `tests/testthat/test-fct_data.R` — data loading tests
  - `tests/testthat/test-mod_browse.R` — basic table rendering test
- **Definition of done**: App launches and displays a `reactable` table with all ~455 packages. Table columns: Name, Description (truncated), Category (badge), License, Downloads (30d), Downloads (All), CRAN Version, CRAN Published, GitHub Updated. Table is searchable by package name (reactable built-in search). Columns are sortable by clicking headers.
- **Testable outcome**: `golem::run_app()` shows a populated table. Typing "ggrepel" in the search bar filters to matching packages. Clicking the "Downloads (30d)" column header sorts by download count.

#### M4: Sidebar Filters & Sorting
- **Goal**: Add all filter controls to the sidebar and wire them to the table.
- **Depends on**: M3
- **Files created/modified**:
  - `R/mod_sidebar.R` — `mod_sidebar_ui()` / `mod_sidebar_server()` with all filter controls
  - `R/app_server.R` — updated to connect sidebar outputs to browse module inputs
  - `R/app_ui.R` — updated to include sidebar module
- **Definition of done**: Sidebar displays: category dropdown (populated from data), CRAN status radio buttons, license dropdown (populated from data), essential-only checkbox, sort-by dropdown. Changing any filter updates the table reactively. Selecting "themes" in category shows only theme packages. Checking "Essential only" shows only essential packages. Sort dropdown changes the table's default sort order. All filters can be combined.
- **Testable outcome**: Select category "geoms" → table shows only geom packages. Check "Essential only" → table shows only essential packages. Select sort "Downloads (30d) ↓" → table sorts by 30-day downloads descending.

#### M5: Package Detail View
- **Goal**: Build the full detail view for a single package, accessible by clicking a package name.
- **Depends on**: M4
- **Files created/modified**:
  - `R/mod_detail.R` — `mod_detail_ui()` / `mod_detail_server()` with all cards
  - `R/mod_browse.R` — updated to handle row click → set `selected_package()`
  - `R/app_server.R` — updated to toggle between browse and detail views
  - `R/app_ui.R` — updated to include detail module UI (conditionally shown)
  - `tests/testthat/test-mod_detail.R` — detail view tests
- **Definition of done**: Clicking a package name in the table shows the detail view with: package header (name, description, maintainer, categories, license), links card (website, GitHub, CRAN, manual, vignettes — only shown if URL exists), download statistics (four value boxes: 7d, 30d, 365d, all-time), version info (CRAN version + published date, GitHub updated). "← Back to all packages" button returns to the table with previous filter/sort state preserved.
- **Testable outcome**: Click "ggrepel" → detail view shows full metadata. All links open in new tabs. Back button returns to table. Filter state is preserved after returning.

#### M6: Code Examples Pipeline & Display
- **Goal**: Add code example rendering to the pipeline and display examples in the detail view.
- **Depends on**: M2, M5
- **Files created/modified**:
  - `R/fct_examples.R` — `extract_example()`, `render_example()`, `render_examples()` functions
  - `_targets.R` — updated with code example targets
  - `R/mod_detail.R` — updated to show code example card
  - `inst/app/www/clipboard.js` — copy-to-clipboard JavaScript
  - `data/examples.parquet` — code example metadata
  - `inst/app/www/examples/*.png` — rendered example images
  - `data-raw/license_allowlist.csv` — populated with standard licenses
  - `tests/testthat/test-fct_examples.R` — example rendering tests
- **Definition of done**: Pipeline renders code examples for packages with allowed licenses. Detail view shows: syntax-highlighted code block, "Copy to clipboard" button, rendered output image (if successful), "Output preview not available" message (if failed), "Example last rendered: {date}" timestamp. Packages with disallowed licenses show "Code example not available" message.
- **Testable outcome**: `targets::tar_make()` produces `examples.parquet` and PNG files. Detail view for a CRAN package shows code + image. Copy button copies code to clipboard. Failed examples show graceful fallback.

#### M7: Recently Added / Updated & Header
- **Goal**: Add recently added/updated lists, introductory text, and complete the footer.
- **Depends on**: M4
- **Files created/modified**:
  - `R/mod_recent.R` — `mod_recent_ui()` / `mod_recent_server()`
  - `R/mod_header.R` — `mod_header_ui()` / `mod_header_server()`
  - `R/mod_footer.R` — `mod_footer_ui()` / `mod_footer_server()`
  - `R/app_ui.R` — updated to include all three modules
  - `R/app_server.R` — updated to call all three modules
- **Definition of done**: Above the table: collapsible accordion with introductory text (collapsed by default). Two cards showing "Recently Added" (last 10 by `date_added`) and "Recently Updated" (last 10 by latest update date). Package names in both lists are clickable → detail view. Below the table/detail: footer with disclaimer text, data freshness timestamp, submission link, book link, credits, cross-links to other youcanbeapirate apps.
- **Testable outcome**: Recently added list shows 10 packages sorted by date_added descending. Recently updated list shows 10 packages sorted by most recent CRAN/GitHub update. Accordion expands/collapses. Footer displays complete disclaimer text.

#### M8: AI Agent Compatibility & JSON Export
- **Goal**: Add semantic HTML improvements, meta tags, and static JSON export.
- **Depends on**: M2, M7
- **Files created/modified**:
  - `R/app_ui.R` — updated with `<meta>` tags, Open Graph tags
  - `R/fct_pipeline.R` — updated with `export_json()` function
  - `_targets.R` — updated with JSON export target
  - `inst/app/www/data/packages.json` — generated JSON file
  - `R/mod_footer.R` — updated with link to `packages.json`
- **Definition of done**: App HTML includes descriptive `<meta>` tags and Open Graph tags. `packages.json` is accessible at `{app_url}/data/packages.json` and contains all package data in the structure defined in section 8. Footer includes "Machine-readable data" link. JSON is regenerated on each pipeline run.
- **Testable outcome**: `{app_url}/data/packages.json` returns valid JSON with ~455 packages. JSON structure matches the spec. Meta tags are present in page source.

#### M9: Polish & Theming
- **Goal**: Refine styling, loading states, error handling, and dark/light mode toggle.
- **Depends on**: M7
- **Files created/modified**:
  - `inst/app/www/styles.css` — refined custom CSS
  - `R/app_ui.R` — updated with `input_dark_mode()` toggle, favicon, logo
  - `R/mod_browse.R` — loading spinner while table renders
  - `R/mod_detail.R` — loading spinner while detail loads
  - `R/app_server.R` — structured logging with `{logger}`
  - `inst/app/www/favicon.png` — app favicon
- **Definition of done**: Dark mode is the default. Light/dark toggle works in the navbar. Loading spinners appear while data renders. Error states display user-friendly messages (not raw R errors). All colours match the palette defined in section 7. Typography (Gotham headings, Inter body, Fira Code for code) renders correctly. Category badges are styled as pills. Value boxes have accent borders. Footer matches BiblioStatus style.
- **Testable outcome**: App loads in dark mode by default. Toggle switches to light mode and back. No unstyled components. Fonts load correctly. No visible layout glitches.

#### M10: Docker & Cloud Run Deployment
- **Goal**: Containerise the app and deploy to Google Cloud Run. Set up CI/CD.
- **Depends on**: M9
- **Files created/modified**:
  - `Dockerfile` — multi-stage build: R base + system deps + renv restore + app files + Parquet data
  - `.dockerignore` — exclude dev files, renv cache, tests
  - `.github/workflows/pipeline.yml` — daily pipeline: targets → Docker build → push to Artifact Registry → deploy to Cloud Run
  - `.github/workflows/examples.yml` — weekly pipeline: same as daily + example rendering
  - `.github/workflows/check.yml` — PR checks: R CMD check, tests, CSV validation
  - `dev/03_deploy.R` — golem deployment helper updated for Docker
- **Definition of done**: `docker build` produces a working image. `docker run -p 3838:3838` serves the app locally. GitHub Actions `pipeline.yml` runs successfully: executes `tar_make()`, builds Docker image, pushes to Google Artifact Registry, deploys to Cloud Run. App is accessible at the Cloud Run URL. GitHub Actions `check.yml` runs on PRs and passes. Daily schedule is configured (06:00 UTC cron). Weekly schedule is configured (Sunday 04:00 UTC cron). Manual `workflow_dispatch` trigger works.
- **Testable outcome**: App is live on Cloud Run URL. Daily pipeline runs automatically. Manual trigger deploys a fresh version within 10 minutes. PR checks pass on a clean PR.

#### M11: Documentation & Handoff
- **Goal**: Write maintenance documentation. Ensure the project is self-documenting.
- **Depends on**: M10
- **Files created/modified**:
  - `CLAUDE.md` — updated with complete project guidance for AI agents
  - `dev/MAINTENANCE.md` — maintenance guide: how to add packages, trigger pipeline, monitor failures, update categories
- **Definition of done**: A new maintainer (or AI agent) can: add a new package by following `MAINTENANCE.md`, understand the project structure from `CLAUDE.md`, run the pipeline locally with `targets::tar_make()`, deploy manually via `workflow_dispatch`. All golem dev scripts (`dev/01_start.R`, `dev/02_dev.R`, `dev/03_deploy.R`) are up to date.
- **Testable outcome**: Follow `MAINTENANCE.md` to add a test package → pipeline runs → package appears in app.

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

- **R version**: >= 4.3.0
- **Key package versions** (pinned in `renv.lock`):

| Package | Purpose |
|---|---|
| `shiny` (>= 1.9.0) | Core Shiny framework |
| `golem` (>= 0.5.0) | App framework |
| `bslib` (>= 0.9.0) | Bootstrap 5 UI |
| `reactable` (>= 0.4.4) | Interactive table |
| `duckdb` (>= 1.0.0) | In-process analytical database |
| `arrow` (>= 17.0.0) | Parquet read/write |
| `dplyr` (>= 1.1.0) | Data manipulation |
| `dbplyr` (>= 2.5.0) | DuckDB/dplyr integration |
| `targets` (>= 1.7.0) | Pipeline orchestration |
| `pkgsearch` (>= 3.1.0) | CRAN metadata API |
| `cranlogs` (>= 2.1.1) | CRAN download counts |
| `gh` (>= 1.4.0) | GitHub API client |
| `httr2` (>= 1.0.0) | HTTP requests (fallback) |
| `jsonlite` (>= 1.8.0) | JSON export |
| `callr` (>= 3.7.0) | Subprocess for example rendering |
| `logger` (>= 0.3.0) | Structured logging |
| `htmltools` (>= 0.5.8) | HTML generation |

### 13. Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| CRAN/cranlogs API downtime during pipeline | Medium | Low | `{targets}` uses cached previous values. Pipeline logs warning but continues. Data is at most 1 day stale. |
| GitHub API rate limit exceeded | Low | Low | Use `GITHUB_PAT` (5,000 req/hr). ~455 requests per run is well within limit. Cache with `{targets}`. |
| Code example rendering takes too long | High | Medium | 30-second timeout per package. Run weekly, not daily. Skip packages that consistently fail. Total weekly budget: ~4 hours on GitHub Actions (free tier: 2,000 min/month). |
| Docker image size too large | Medium | Medium | Multi-stage build. Only include app code + Parquet files + PNG examples in final image. Do not install all 455 packages in the app image (only in the pipeline runner). Target: < 1 GB. |
| Gotham font CDN unavailable | Low | Low | Inter (Google Fonts) as fallback. Both declared in `font_collection()`. |
| Cloud Run cold starts | Medium | Low | Lightweight app (Parquet + DuckDB, no external DB calls on startup). Cold start should be < 10 seconds. Min instances = 0 is acceptable for a non-critical app. |
| Notion export has unexpected format | Medium | Medium | Migration script includes validation and error reporting. Run interactively, review output before committing. |
| Package removed from CRAN after addition | Low | Low | Pipeline detects missing packages (CRAN API returns error), sets `on_cran = FALSE`. Package stays in directory with a "No longer on CRAN" indicator. |
| `{targets}` cache corruption on GitHub Actions | Low | Medium | Cache is a performance optimisation, not required. If cache fails, full pipeline re-run completes in ~15 minutes. |

### 14. Open Questions

1. **Notion database structure**: The Notion export format needs to be verified during M1. The migration script may need adjustments based on the actual export columns. The existing `packages_ggplot2.csv` in the CRAN repos has ~235 packages — the Notion database has ~455. These need to be reconciled.
2. **Category taxonomy finalisation**: The category list in section 4.5 is based on the existing CSV data. During the Notion migration audit (M1), categories should be reviewed, consolidated, and finalised. Some categories may be too granular or too broad.
3. **Google Cloud Run configuration**: Exact Cloud Run settings (memory, CPU, max instances, concurrency) should be determined during M10 based on local Docker testing. Starting point: 512 MB memory, 1 vCPU, max 3 instances, 80 concurrent requests.
4. **Gotham font licensing**: Gotham is a commercial font. The CDN link used in BiblioStatus (`fonts.cdnfonts.com`) may have licensing implications. Verify this is acceptable, or switch to a similar free alternative (e.g., `Montserrat`).
5. **Google Form setup**: The Google Form for package submissions needs to be created before M7. Fields are defined in section 6.2.
6. **Domain/URL**: Will the app use a custom subdomain (e.g., `extensions.youcanbeapirate.com` or `ggplot2extended.youcanbeapirate.com`) or the default Cloud Run URL? To be decided before M10.
7. **Download trend chart**: Listed as nice-to-have. If pursued, it would require storing historical daily download data in an additional Parquet file. This would significantly increase data size (~455 packages × ~3,650 days × row). Decision deferred to after v1 core is complete.

### 15. Appendix

#### A. API Reference

**CRAN metadata via `pkgsearch`**:
- Function: `pkgsearch::cran_package(package_name)`
- Returns: List with fields including `Package`, `Version`, `Title`, `Description`, `License`, `Maintainer`, `Published`, `URL`, `BugReports`, etc.
- Rate limit: No documented limit, but be polite (~1 req/sec).
- No authentication required.

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
- Note: Parse `repo_url` from curated CSV to extract `owner` and `repo`.

#### B. URL Construction Patterns

| URL Type | Pattern | Condition |
|---|---|---|
| CRAN page | `https://cran.r-project.org/package={package_name}` | `on_cran == TRUE` |
| Reference manual | `https://cran.r-project.org/web/packages/{package_name}/{package_name}.pdf` | `on_cran == TRUE` |
| Vignettes (directory) | `https://cran.r-project.org/web/packages/{package_name}/vignettes/` | `on_cran == TRUE` (validate with HEAD request in pipeline) |
| Vignettes (single) | `https://cran.r-project.org/web/packages/{package_name}/vignettes/{name}.html` | Discovered via CRAN metadata `vignettes` field |

#### C. Glossary

| Term | Definition |
|---|---|
| ggplot2 extension | An R package that extends ggplot2's functionality by adding new geoms, stats, scales, themes, or other components. |
| CRAN | The Comprehensive R Archive Network — the main repository for R packages. |
| Essential Extension | A manually curated tag indicating a package is particularly useful for beginners or widely applicable. |
| Pipeline | The automated data processing workflow that fetches, transforms, and stores package data. |
| Parquet | A columnar data storage format, efficient for analytical queries. Used as the app's data layer. |
| DuckDB | An in-process analytical database engine that can query Parquet files directly. |
| golem | An R package framework for building production-grade Shiny applications as R packages. |
| targets | An R package for defining and running reproducible data pipelines as directed acyclic graphs (DAGs). |

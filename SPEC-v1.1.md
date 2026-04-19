# SPEC-v1.1.md
## ggplot2 extended (companion) — v1.1 Technical Specification

### 1. Overview
- **App name**: ggplot2 extended (companion)
- **One-line description**: v1.1 adds package submission via Google Form, archived package support with toggle visibility, and automated metadata enrichment for non-CRAN packages via GitHub DESCRIPTION files.
- **Technology**: R Shiny (golem framework) — unchanged from v1
- **Target deployment**: Docker on Google Cloud Run — unchanged from v1
- **Scope**: This spec covers only the v1.1 changes. The v1 SPEC.md remains the reference for all existing functionality. Where v1.1 modifies existing code, the affected files and functions are called out explicitly.

### 2. Architecture Changes

#### 2.1 Application Structure Changes
- **No new modules.** All three features are implemented by modifying existing modules and pipeline functions.
- **Modified modules**: `mod_sidebar.R`, `mod_footer.R`, `mod_browse.R`, `mod_detail.R`
- **Modified pipeline functions**: `fct_pipeline.R`, `fct_filters.R`, `fct_validation.R`
- **Modified config**: `inst/golem-config.yml`
- **New dependency**: `desc` package (for parsing GitHub DESCRIPTION files)

#### 2.2 Data Architecture Changes
- **New column in curated CSV**: `is_archived` (boolean)
- **New pipeline step**: `fetch_github_descriptions()` — weekly only, fetches DESCRIPTION files from GitHub for non-CRAN packages
- **New cached artifact**: `data/github_descriptions.rds` — persists GitHub DESCRIPTION data between weekly runs for daily pipeline reuse
- **Renamed fields in UI only**: "CRAN Version" → "Version", "Latest CRAN Version" → "Latest Version" (internal field names in parquet remain `cran_version` for backward compatibility; a new `version` field is derived at merge time)

#### 2.3 Infrastructure Changes
- **No hosting changes.**
- **No new environment variables.** GitHub DESCRIPTION enrichment reuses the existing `GITHUB_PAT` and the existing `RENDER_EXAMPLES` env var to gate weekly-only execution.
- **New R dependency**: `desc` — must be added to `DESCRIPTION` Imports and `renv.lock`.

### 3. Data Model Changes

#### 3.1 Changes to `packages_curated.csv`

| Field | Type | Change | Default | Notes |
|---|---|---|---|---|
| `is_archived` | logical | **New column** | `FALSE` | Manually curated by maintainer. `TRUE` means the package is no longer viable for use. Independent of CRAN archive status. |

All other columns unchanged. The `notes` column (already existing) gains new significance: for archived packages, its content is displayed in the detail view below the warning banner.

#### 3.2 New Pipeline Output: `data/github_descriptions.rds`

A tibble with one row per package (all packages, not just non-CRAN), produced weekly by `fetch_github_descriptions()`:

| Field | Type | Source | Notes |
|---|---|---|---|
| `package_name` | character | Input | Join key |
| `github_title` | character | DESCRIPTION `Title` | NA if not fetchable |
| `github_description` | character | DESCRIPTION `Description` | NA if not fetchable |
| `github_license` | character | DESCRIPTION `License` | NA if not fetchable |
| `github_maintainer` | character | DESCRIPTION `Maintainer` or parsed `Authors@R` | NA if not fetchable |
| `github_version` | character | DESCRIPTION `Version` | NA if not fetchable |

#### 3.3 Changes to `packages.parquet` (Merged Output)

New derived fields added by `merge_package_data()`:

| Field | Type | Source | Logic |
|---|---|---|---|
| `is_archived` | logical | `packages_curated.csv` | Pass-through from curated CSV |
| `version` | character | Derived | `cran_version` if `on_cran == TRUE`; otherwise `github_version` from enrichment |
| `github_title` | character | `github_descriptions.rds` | Raw value from enrichment (used as fallback for `title` display) |
| `github_description` | character | `github_descriptions.rds` | Raw value from enrichment (used as fallback for `description` display) |
| `github_license` | character | `github_descriptions.rds` | Raw value from enrichment (used as fallback for `license` display) |
| `github_maintainer` | character | `github_descriptions.rds` | Raw value from enrichment (used as fallback for `maintainer` display) |
| `github_version` | character | `github_descriptions.rds` | Raw value from enrichment |

**Important**: The existing `title`, `description`, `license`, `maintainer`, and `cran_version` fields remain unchanged (sourced from CRAN API). The `github_*` fields are stored alongside them. The UI layer decides which to display based on `on_cran` status. This avoids overwriting CRAN data and keeps the data lineage clear.

#### 3.4 Changes to `packages.json` (JSON Export)

Add two new fields to the per-package JSON object in `export_json()`:

| Field | JSON key | Source |
|---|---|---|
| `is_archived` | `is_archived` | Direct from merged data |
| `version` | `version` | Derived field (CRAN or GitHub version) |

Rename no existing fields — the JSON export adds new keys alongside existing ones for backward compatibility.

### 4. Data Pipeline Changes

#### 4.1 Pipeline Overview

The pipeline gains one new step (Step 4.5) and modifications to Step 6 and Step 12.

**Updated pipeline modes:**
- **Daily** (06:00 UTC): Steps 1–8, 12–13. Step 4.5 is **skipped** but `merge_package_data()` loads cached `data/github_descriptions.rds` from the last weekly run.
- **Weekly** (04:00 UTC Sundays): All steps including 4.5 (GitHub DESCRIPTION enrichment) and 10–11 (code examples).

#### 4.2 New Pipeline Step: Step 4.5 — Fetch GitHub DESCRIPTION Files

**Target definition in `_targets.R`:**
```r
# Step 4.5: Fetch DESCRIPTION from GitHub for non-CRAN packages (weekly only)
if (should_render_examples()) {
  tar_target(
    github_descriptions,
    fetch_github_descriptions(
      curated_packages$package_name,
      curated_packages$repo_url,
      cran_metadata$on_cran,
      cache_path = "data/github_descriptions.rds"
    ),
    format = "rds"
  )
} else {
  NULL
},
```

**Position in DAG**: After Step 4 (`github_metadata`), before Step 6 (`packages_combined`). Depends on `curated_packages` and `cran_metadata`.

#### 4.3 New Function: `fetch_github_descriptions()`

**File**: `R/fct_pipeline.R`

```r
#' Fetch DESCRIPTION files from GitHub for non-CRAN packages
#'
#' For packages where `on_cran` is FALSE and `repo_url` points to GitHub,
#' fetches the DESCRIPTION file via the GitHub Contents API and parses it
#' with the `desc` package to extract Title, Description, License,
#' Maintainer, and Version.
#'
#' Results are cached to `cache_path` so that daily pipeline runs can
#' reuse the last weekly enrichment without additional API calls.
#'
#' @param package_names Character vector of all package names.
#' @param repo_urls Character vector of repository URLs (same length).
#' @param on_cran Logical vector indicating CRAN availability (same length).
#' @param cache_path Path to write the cached RDS file.
#'
#' @return A tibble with columns: package_name, github_title,
#'   github_description, github_license, github_maintainer, github_version.
#'
#' @noRd
fetch_github_descriptions <- function(package_names, repo_urls, on_cran,
                                       cache_path = "data/github_descriptions.rds") {
```

**Logic:**
1. Build a tibble of all packages. For packages where `on_cran == TRUE` OR `repo_url` does not contain `github.com`, return NA for all `github_*` fields (no API call needed).
2. For eligible packages (`on_cran == FALSE` AND `repo_url` contains `github.com`):
   a. Parse `repo_url` with the existing `parse_github_url()` helper to extract `owner` and `repo`.
   b. Call `gh::gh("GET /repos/{owner}/{repo}/contents/DESCRIPTION", owner = owner, repo = repo, .token = Sys.getenv("GITHUB_PAT", ""))`.
   c. Decode the base64 `content` field from the response.
   d. Write decoded content to a temp file, parse with `desc::desc(file = tempfile)`.
   e. Extract: `desc$get("Title")`, `desc$get("License")`, `desc$get("Version")`, `desc$get("Description")`.
   f. For maintainer: try `desc$get_maintainer()` first (handles both `Maintainer` and `Authors@R`). If that returns `NA` or fails, fall back to `desc$get("Maintainer")`.
   g. Clean extracted strings: `trimws()`, collapse multi-line values, remove email addresses from maintainer if desired.
3. Wrap each package fetch in `tryCatch()`. On error, log with `logger::log_warn("GitHub DESCRIPTION failed for '{pkg}': {e$message}")` and return NA row.
4. Bind all rows into a single tibble.
5. Save to `cache_path` via `saveRDS()`.
6. Return the tibble.

**Error handling per package** (following existing `fetch_github_metadata()` pattern):
- 404 (repo removed or DESCRIPTION missing): log warning, return NA row
- Rate limit (403): log warning, return NA row (partial results are acceptable)
- Network error: log warning, return NA row

**Rate limit consideration**: 115 eligible packages × 1 API call each = 115 calls per weekly run. Well within the 5,000/hr budget.

#### 4.4 Modified Function: `merge_package_data()`

**File**: `R/fct_pipeline.R`

**Current signature:**
```r
merge_package_data <- function(curated, cran_meta, github_meta, urls)
```

**New signature:**
```r
merge_package_data <- function(curated, cran_meta, github_meta, urls,
                                github_desc = NULL,
                                github_desc_cache_path = "data/github_descriptions.rds")
```

**Logic changes:**
1. If `github_desc` is NULL (daily run), attempt to load from `github_desc_cache_path` via `readRDS()`. If the file doesn't exist (first run before any weekly run), proceed without enrichment (all `github_*` fields will be absent).
2. If `github_desc` is provided (weekly run) or loaded from cache, left-join onto the result by `package_name`.
3. After joining, derive the `version` field:
   ```r
   dplyr::mutate(
     version = dplyr::case_when(
       on_cran & !is.na(cran_version) ~ cran_version,
       !on_cran & !is.na(github_version) ~ github_version,
       TRUE ~ NA_character_
     )
   )
   ```

**Updated target in `_targets.R` (Step 6):**
```r
tar_target(
  packages_combined,
  merge_package_data(
    curated_packages,
    cran_metadata,
    github_metadata,
    constructed_urls,
    github_desc = if (should_render_examples()) github_descriptions else NULL
  ),
  format = "rds"
),
```

#### 4.5 Modified Function: `export_json()`

**File**: `R/fct_pipeline.R`

Add `is_archived` and `version` to the per-package JSON object:

```r
# Inside the pkg_list construction, add:
is_archived = row$is_archived,
version = if (is.na(row$version)) NULL else row$version,
```

#### 4.6 GitHub Actions Changes

**No workflow file changes needed.** The weekly `examples.yml` already sets `RENDER_EXAMPLES=true`, which gates both code example rendering and (now) GitHub DESCRIPTION enrichment. The daily `pipeline.yml` skips both, and `merge_package_data()` loads cached enrichment data from disk.

**Cache consideration**: The `data/github_descriptions.rds` file is written to the `data/` directory, which is committed to the repo by the pipeline workflows (they commit updated parquet/json files). This means the cached RDS persists across runs without needing a separate GitHub Actions cache step.

### 5. UI Specification — Changes

#### 5.1 Sidebar Changes (`R/mod_sidebar.R`)

##### 5.1.1 "Suggest a Package" Button Activation

**Current state** (lines 90–97):
```r
htmltools::tags$a(
  href = "javascript:void(0)",
  class = "btn btn-outline-primary w-100 disabled",
  `aria-disabled` = "true",
  title = "Package submission form coming soon",
  "Suggest a Package"
)
```

**New state:**
```r
htmltools::tags$a(
  href = get_golem_config("google_form_url"),
  target = "_blank",
  rel = "noopener noreferrer",
  class = "btn btn-outline-primary w-100",
  "Suggest a Package"
)
```

Changes:
- `href` → Google Form URL from golem config
- Add `target = "_blank"` and `rel = "noopener noreferrer"`
- Remove `disabled` class, `aria-disabled`, and `title` tooltip

##### 5.1.2 "Show Archived Packages" Checkbox

**Position**: After the existing "Recently Updated" checkbox (last checkbox in the filter list).

```r
shiny::checkboxInput(
  ns("show_archived"),
  label = "Show Archived Packages",
  value = FALSE
)
```

**Default state**: Unchecked (archived packages hidden).

##### 5.1.3 Server Return Value

Add `show_archived` to the returned list of reactive expressions:

```r
list(
  category         = reactive(input$category),
  cran_status      = reactive(input$cran_status),
  license          = reactive(input$license),
  essential_only   = reactive(input$essential_only),
  recently_added   = reactive(input$recently_added),
  recently_updated = reactive(input$recently_updated),
  show_archived    = reactive(input$show_archived)
)
```

#### 5.2 Footer Changes (`R/mod_footer.R`)

##### 5.2.1 "Submit it here" Link Activation

**Current state** (lines 38–49):
```r
htmltools::tags$span(
  class = "text-muted",
  title = "Package submission form coming soon",
  style = "text-decoration: underline dotted; cursor: default;",
  "Submit it here"
)
```

**New state:**
```r
htmltools::tags$a(
  href = get_golem_config("google_form_url"),
  target = "_blank",
  rel = "noopener noreferrer",
  "Submit it here"
)
```

Changes:
- `<span>` → `<a>` tag
- Add `href`, `target`, `rel`
- Remove `text-muted` class, `title` tooltip, and inline style
- The surrounding `<p>` and text ("Know a ggplot2 extension we're missing? ... .") remain unchanged

#### 5.3 Browse View Changes (`R/mod_browse.R`)

##### 5.3.1 Archived Package Emoji in Name Column

In `build_package_table()`, the Name column cell renderer currently shows ⭐ for essential packages. Add 📁 for archived packages:

```r
is_essential <- data$is_essential[index]
is_archived <- data$is_archived[index]

essential_badge <- if (isTRUE(is_essential)) {
  htmltools::span(class = "badge-essential", "\u2B50 ")
} else {
  NULL
}

archived_badge <- if (isTRUE(is_archived)) {
  htmltools::span(class = "badge-archived", "\U0001F4C1 ")
} else {
  NULL
}

htmltools::tagList(
  essential_badge,
  archived_badge,
  htmltools::tags$a(
    class = "package-link",
    href = "#",
    onclick = sprintf(
      "Shiny.setInputValue('%s', '%s', {priority: 'event'})",
      ns("selected_pkg"), value
    ),
    value
  )
)
```

**Display order**: ⭐ (if essential) then 📁 (if archived) then package name. A package could theoretically be both essential and archived, though this is unlikely.

##### 5.3.2 Version Column Rename

Change the `cran_version` column definition:

**Current:**
```r
cran_version = reactable::colDef(
  name = "CRAN Version",
  ...
)
```

**New:**
```r
cran_version = reactable::colDef(
  name = "Version",
  minWidth = 90,
  sortable = FALSE,
  cell = function(value, index) {
    # Use derived version field if available, fall back to cran_version
    version_val <- data$version[index]
    if (is.na(version_val)) "\u2014" else version_val
  }
)
```

**Note**: The column is still bound to the `cran_version` data field in reactable, but the cell renderer reads from the derived `version` field instead for display. Alternatively, the column could be bound to `version` directly — this depends on whether `version` is included in the columns passed to reactable.

**Simpler approach**: Ensure `version` is in the data passed to `build_package_table()` and add it as a visible column, hiding `cran_version`:

```r
version = reactable::colDef(
  name = "Version",
  minWidth = 90,
  sortable = FALSE,
  cell = function(value) {
    if (is.na(value)) "\u2014" else value
  }
),
cran_version = reactable::colDef(show = FALSE),
```

##### 5.3.3 Hidden Columns

Add `is_archived` and `version`-related fields to hidden columns:

```r
is_archived = reactable::colDef(show = FALSE),
github_title = reactable::colDef(show = FALSE),
github_description = reactable::colDef(show = FALSE),
github_license = reactable::colDef(show = FALSE),
github_maintainer = reactable::colDef(show = FALSE),
github_version = reactable::colDef(show = FALSE),
```

#### 5.4 Detail View Changes (`R/mod_detail.R`)

##### 5.4.1 Archived Badge in Header Card

In `build_header_card()`, add an archived badge alongside the existing essential badge:

```r
essential_badge <- if (isTRUE(pkg$is_essential)) {
  htmltools::span(
    class = "badge bg-warning text-dark ms-2",
    "\u2B50 Essential Extension"
  )
}

archived_badge <- if (isTRUE(pkg$is_archived)) {
  htmltools::span(
    class = "badge bg-secondary ms-2",
    "\U0001F4C1 Archived Package"
  )
}
```

Both badges appear next to the package name `<h2>`. A package could have both (unlikely but handled).

##### 5.4.2 Archived Warning Banner

In the detail view rendering (inside `output$detail_content`), add a warning banner **above** the header card when the package is archived:

```r
# Warning banner for archived packages
archived_banner <- if (isTRUE(pkg$is_archived)) {
  htmltools::div(
    class = "alert alert-warning d-flex align-items-center mb-3",
    role = "alert",
    htmltools::tags$strong("This package is no longer actively maintained."),
    if (!is.na(pkg$notes) && nchar(trimws(pkg$notes)) > 0) {
      htmltools::tags$p(class = "mb-0 mt-2", pkg$notes)
    }
  )
}
```

**Position**: After the top navigation bar, before the header card. This ensures it's the first thing the user sees after navigating to the package.

##### 5.4.3 Version Card Update

In `build_version_card()`:

**Current:**
```r
build_version_card <- function(pkg) {
  bslib::card(
    bslib::card_header("Version Info"),
    bslib::card_body(
      if (isTRUE(pkg$on_cran)) {
        htmltools::tagList(
          htmltools::tags$p(
            htmltools::tags$strong("Latest CRAN version: "),
            ...
          ),
          htmltools::tags$p(
            htmltools::tags$strong("Published: "),
            ...
          )
        )
      } else {
        htmltools::tags$p(class = "text-muted", "Not available on CRAN.")
      },
      ...
    )
  )
}
```

**New:**
```r
build_version_card <- function(pkg) {
  # Determine version to display (CRAN or GitHub)
  display_version <- if (!is.na(pkg$version)) pkg$version else NA_character_

  bslib::card(
    bslib::card_header("Version Info"),
    bslib::card_body(
      # Version line (source-agnostic)
      htmltools::tags$p(
        htmltools::tags$strong("Latest Version: "),
        if (is.na(display_version)) "\u2014" else display_version
      ),

      # Date context: Published date for CRAN, GitHub updated for non-CRAN
      if (isTRUE(pkg$on_cran) && !is.na(pkg$cran_published)) {
        htmltools::tags$p(
          htmltools::tags$strong("Published: "),
          format(as.Date(pkg$cran_published), "%Y-%m-%d")
        )
      },

      # GitHub last updated (shown for all packages with GitHub data)
      if (!is.na(pkg$github_updated)) {
        htmltools::tags$p(
          htmltools::tags$strong("GitHub last updated: "),
          format(as.Date(pkg$github_updated), "%Y-%m-%d")
        )
      }
    )
  )
}
```

**Key changes:**
- "Latest CRAN version" → "Latest Version"
- Removed "Not available on CRAN." text — the version field now shows the GitHub version for non-CRAN packages, or an em dash if no version is available at all
- Published date shown only for CRAN packages (where it's meaningful)
- GitHub last updated always shown when available (both CRAN and non-CRAN)

##### 5.4.4 Non-CRAN Metadata Fallbacks in Header Card

In `build_header_card()`, update the display logic for title, description, maintainer, and license to use GitHub fallbacks:

```r
# Title: prefer CRAN title, fall back to GitHub title
display_title <- if (!is.na(pkg$title)) {
  pkg$title
} else if (!is.na(pkg$github_title)) {
  pkg$github_title
} else {
  NULL
}

# Description: prefer CRAN description, fall back to GitHub description
display_description <- if (!is.na(pkg$description)) {
  pkg$description
} else if (!is.na(pkg$github_description)) {
  pkg$github_description
} else {
  NULL
}

# Maintainer: prefer CRAN maintainer, fall back to GitHub maintainer
display_maintainer <- if (!is.na(pkg$maintainer)) {
  pkg$maintainer
} else if (!is.na(pkg$github_maintainer)) {
  pkg$github_maintainer
} else {
  NULL
}

# License: prefer CRAN license, fall back to GitHub license
display_license <- if (!is.na(pkg$license)) {
  pkg$license
} else if (!is.na(pkg$github_license)) {
  pkg$github_license
} else {
  NULL
}
```

This ensures CRAN data takes priority (it's more authoritative) and GitHub data fills in only for non-CRAN packages.

#### 5.5 Filter Changes (`R/fct_filters.R`)

##### 5.5.1 New `show_archived` Parameter

**Current signature:**
```r
filter_packages <- function(data, category = "All", cran_status = "All",
                            license_filter = "All", essential_only = FALSE,
                            recently_added = FALSE, recently_updated = FALSE)
```

**New signature:**
```r
filter_packages <- function(data, category = "All", cran_status = "All",
                            license_filter = "All", essential_only = FALSE,
                            recently_added = FALSE, recently_updated = FALSE,
                            show_archived = FALSE)
```

**Logic** (added as the first filter, before category):
```r
# Filter archived packages (default: hidden)
if (isFALSE(show_archived)) {
  result <- result |>
    dplyr::filter(!isTRUE(.data$is_archived))
}
```

**Composition**: AND logic with all other filters. When `show_archived = TRUE`, archived packages appear and are subject to all other active filters (category, CRAN status, etc.) normally.

#### 5.6 App Server Changes (`R/app_server.R`)

Pass the new `show_archived` reactive to `filter_packages()`:

```r
filtered_data <- reactive({
  # ... existing filter value extraction ...
  show_archived <- sidebar_values$show_archived() %||% FALSE

  filter_packages(
    app_data_raw,
    category = category,
    cran_status = cran_status,
    license_filter = license_filter,
    essential_only = essential_only,
    recently_added = recently_added,
    recently_updated = recently_updated,
    show_archived = show_archived
  )
})
```

### 6. Configuration Changes

#### 6.1 `inst/golem-config.yml`

Add the Google Form URL:

```yaml
default:
  golem_name: ggplot2.extended.companion
  golem_version: 0.0.0.9000
  app_prod: no
  google_form_url: "https://docs.google.com/forms/d/e/FORM_ID_HERE/viewform"

production:
  app_prod: yes
```

The `FORM_ID_HERE` placeholder is replaced with the actual Google Form ID after the form is created (see §8).

### 7. Styling Changes

#### 7.1 CSS Addition (`inst/app/www/styles.css`)

Add a `.badge-archived` class mirroring `.badge-essential`:

```css
.badge-archived {
  color: #6b7280;  /* Gray-500 — neutral, not alarming */
  font-size: 0.9rem;
}
```

This matches the approach used for `.badge-essential` (amber `#f59e0b`). The archived badge uses gray to signal "inactive" without being alarming.

### 8. Package Submission (Google Form)

#### 8.1 Google Form Specification

**Form title**: "Suggest a ggplot2 Extension Package"

**Fields (in order):**

| # | Field Label | Type | Required | Validation | Notes |
|---|---|---|---|---|---|
| 1 | Package name | Short text | Yes | — | — |
| 2 | CRAN URL | Short text | No | URL pattern | e.g., `https://cran.r-project.org/package=...` |
| 3 | GitHub URL | Short text | No | URL pattern | e.g., `https://github.com/owner/repo` |
| 4 | Suggested category/categories | Checkboxes | Yes | At least 1 | 19 categories + "Other" with free-text follow-up |
| 5 | Brief reason for suggesting | Long text (paragraph) | Yes | — | Why this package should be included |
| 6 | Your name | Short text | Yes | — | Submitter's name |
| 7 | Your email | Short text | Yes | Email validation | For optional follow-up |

**Category checklist values** (matching `data-raw/categories.csv`):
Animation, Annotations, Arranging Plots, Coords, Data, Facets, Finishing Touches, Geoms, Helpers, Interactive Plots, Interactive Tools, Maps, Networks, Python, Scales & Guides, Sports, Stats, Themes, NA, Other

When "Other" is selected, a free-text field appears for the submitter to describe the proposed category.

#### 8.2 Form Settings
- **Email notifications**: Enabled — the maintainer receives an email for each submission.
- **Response destination**: Google Sheets (default) for easy review.
- **Confirmation message**: "Thank you for your suggestion! We'll review it and may reach out if we have questions."

#### 8.3 Review Workflow
1. Maintainer receives email notification from Google Forms.
2. Maintainer evaluates the submission (check package exists, is a ggplot2 extension, fits a category).
3. If accepted: add package to `data-raw/packages_curated.csv` with appropriate fields, re-run pipeline.
4. If declined: optionally email submitter. No further action required.
5. No in-app status tracking or automated feedback loop.

### 9. Validation Changes

#### 9.1 New Function: `validate_is_archived()`

**File**: `R/fct_validation.R`

```r
#' Validate the is_archived column
#'
#' Checks that every row has a valid logical value (TRUE or FALSE) for
#' is_archived. NA values are not permitted.
#'
#' @param df Data frame to validate.
#'
#' @return A list with `valid` (logical) and `errors` (character vector).
#'
#' @noRd
validate_is_archived <- function(df) {
  errors <- character(0)

  if (!"is_archived" %in% names(df)) {
    errors <- c(errors, "Missing required column: is_archived")
    return(list(valid = FALSE, errors = errors))
  }

  invalid_rows <- which(is.na(df$is_archived) | !is.logical(df$is_archived))
  if (length(invalid_rows) > 0) {
    bad_pkgs <- df$package_name[invalid_rows]
    errors <- c(errors, paste0(
      "Invalid is_archived value for package '", bad_pkgs,
      "' (must be TRUE or FALSE)"
    ))
  }

  list(valid = length(errors) == 0, errors = errors)
}
```

**Pattern**: Mirrors `validate_is_essential()` exactly.

#### 9.2 Add to `validate_curated_csv()`

Add `validate_is_archived(df)` to the checks list in `validate_curated_csv()`, after `validate_is_essential(df)`.

### 10. Testing Strategy

#### 10.1 New Tests

| Test File | What Is Tested | Framework |
|---|---|---|
| `tests/testthat/test-fct_pipeline.R` | `fetch_github_descriptions()` — parsing DESCRIPTION content, error handling, NA fallbacks, cache write | `testthat` with `.rds` fixtures |
| `tests/testthat/test-fct_pipeline.R` | `merge_package_data()` — new `github_desc` parameter, `version` derivation, cache loading | `testthat` |
| `tests/testthat/test-fct_filters.R` | `filter_packages()` — `show_archived` parameter: hidden by default, visible when TRUE, composes with other filters | `testthat` |
| `tests/testthat/test-fct_validation.R` | `validate_is_archived()` — valid TRUE/FALSE, invalid NA, missing column | `testthat` |
| `tests/testthat/test-fct_json.R` | `export_json()` — `is_archived` and `version` fields present in output | `testthat` |

#### 10.2 Test Fixtures Needed

**New fixture**: `tests/testthat/fixtures/github_description_response.rds`
- A serialized GitHub API response for a DESCRIPTION file request (base64-encoded content)
- Used to test `fetch_github_descriptions()` without making real API calls

**New fixture**: `tests/testthat/fixtures/parsed_description.rds`
- A serialized `desc` object for testing field extraction logic

#### 10.3 Modified Tests

- `test-fct_filters.R`: Update `make_test_data()` helper to include `is_archived` column (default `FALSE`, with one `TRUE` row for testing)
- `test-fct_pipeline.R`: Update `merge_package_data()` tests to include `github_desc` parameter
- `test-fct_validation.R`: Add integration test that loads the real `packages_curated.csv` and validates `is_archived` column

### 11. File & Directory Structure — Changes Only

```
ggplot2-extended-companion/
├── R/
│   ├── app_config.R              — unchanged (golem config helpers)
│   ├── fct_filters.R             — MODIFIED: add show_archived parameter
│   ├── fct_pipeline.R            — MODIFIED: add fetch_github_descriptions(),
│   │                                update merge_package_data(), update export_json()
│   ├── fct_validation.R          — MODIFIED: add validate_is_archived()
│   ├── mod_browse.R              — MODIFIED: archived badge, version column rename
│   ├── mod_detail.R              — MODIFIED: archived badge, warning banner,
│   │                                notes display, version card, metadata fallbacks
│   ├── mod_footer.R              — MODIFIED: activate submission link
│   ├── mod_sidebar.R             — MODIFIED: activate button, add show_archived checkbox
│   └── app_server.R              — MODIFIED: pass show_archived to filter_packages()
├── data/
│   ├── github_descriptions.rds   — NEW: cached GitHub DESCRIPTION enrichment (weekly)
│   └── ...                         (existing parquet files unchanged in schema name,
│                                    but packages.parquet gains new columns)
├── data-raw/
│   └── packages_curated.csv      — MODIFIED: add is_archived column
├── inst/
│   ├── app/www/styles.css        — MODIFIED: add .badge-archived CSS class
│   └── golem-config.yml          — MODIFIED: add google_form_url
├── tests/
│   └── testthat/
│       ├── test-fct_filters.R    — MODIFIED: add show_archived tests
│       ├── test-fct_json.R       — MODIFIED: add is_archived and version tests
│       ├── test-fct_pipeline.R   — MODIFIED: add fetch_github_descriptions tests,
│       │                            update merge_package_data tests
│       ├── test-fct_validation.R — MODIFIED: add validate_is_archived tests
│       └── fixtures/
│           ├── github_description_response.rds  — NEW: mock API response
│           └── parsed_description.rds           — NEW: mock desc object
├── _targets.R                    — MODIFIED: add step 4.5, update step 6
├── DESCRIPTION                   — MODIFIED: add desc to Imports
├── renv.lock                     — MODIFIED: add desc package
└── README.md                     — MODIFIED: final step, document v1.1 features
```

### 12. Implementation Milestones

#### M0: Google Form & Submission Links
- **Goal**: Create the Google Form and activate both submission links in the app.
- **Depends on**: Nothing (can start immediately).
- **Files created/modified**:
  - `inst/golem-config.yml` — add `google_form_url` with the real Google Form URL
  - `R/mod_sidebar.R` — activate "Suggest a Package" button: change `href` to `get_golem_config("google_form_url")`, add `target="_blank"`, remove `disabled` class and `aria-disabled`
  - `R/mod_footer.R` — activate "Submit it here" link: change `<span>` to `<a>` with `href`, `target="_blank"`, remove tooltip and inline styles
- **Definition of done**:
  - Google Form exists with all 7 fields as specified in §8.1
  - Clicking "Suggest a Package" in sidebar opens the form in a new tab
  - Clicking "Submit it here" in footer opens the same form in a new tab
  - Both links use the URL from `golem-config.yml` (single source of truth)
  - Form submission sends email notification to maintainer
- **Testable outcome**: Manual — click both links, verify form opens, submit a test response, verify email notification received.

#### M1: Archived Packages — Data & Validation
- **Goal**: Add `is_archived` to the data model with validation, and mark initial packages as archived.
- **Depends on**: Nothing (can run in parallel with M0).
- **Files created/modified**:
  - `data-raw/packages_curated.csv` — add `is_archived` column (all `FALSE` initially; maintainer marks ~10 as `TRUE`)
  - `R/fct_validation.R` — add `validate_is_archived()` function, add it to `validate_curated_csv()` checks list
  - `tests/testthat/test-fct_validation.R` — add tests for `validate_is_archived()`: valid data, invalid NA, missing column, integration test with real CSV
- **Definition of done**:
  - `packages_curated.csv` has `is_archived` column with valid TRUE/FALSE values
  - `validate_curated_csv()` catches invalid `is_archived` values
  - All existing tests pass
  - New validation tests pass
  - Running the pipeline produces `packages.parquet` with `is_archived` column
- **Testable outcome**: `devtools::test()` passes. `validate_curated_csv(curated, cats$category)` succeeds with the updated CSV.

#### M2: Archived Packages — UI (Filter, Browse, Detail)
- **Goal**: Implement the full archived packages UI: sidebar checkbox, browse emoji, detail view banner and notes.
- **Depends on**: M1 (needs `is_archived` in the data).
- **Files created/modified**:
  - `R/fct_filters.R` — add `show_archived` parameter to `filter_packages()`
  - `R/app_server.R` — pass `show_archived` reactive to `filter_packages()`
  - `R/mod_sidebar.R` — add "Show Archived Packages" checkbox (last position), add to server return list
  - `R/mod_browse.R` — add 📁 emoji for archived packages in Name column, add `is_archived` to hidden columns
  - `R/mod_detail.R` — add archived badge in header, warning banner with notes, position above header card
  - `inst/app/www/styles.css` — add `.badge-archived` CSS class
  - `tests/testthat/test-fct_filters.R` — update `make_test_data()` with `is_archived`, add `show_archived` filter tests
- **Definition of done**:
  - "Show Archived Packages" checkbox appears last in sidebar, unchecked by default
  - With checkbox unchecked, archived packages do not appear in browse results
  - With checkbox checked, archived packages appear with 📁 emoji next to name
  - Clicking an archived package shows: 📁 "Archived Package" badge, warning banner "This package is no longer actively maintained.", and notes text below banner (when populated)
  - Archived packages sort and filter normally alongside other packages
  - All filter tests pass including new `show_archived` tests
- **Testable outcome**: Run app locally, verify checkbox toggles archived visibility, verify browse emoji, verify detail view banner and notes for an archived package.

#### M3: Non-CRAN Enrichment — Pipeline
- **Goal**: Implement GitHub DESCRIPTION fetching and integrate into the pipeline with caching.
- **Depends on**: Nothing (pipeline change independent of UI).
- **Files created/modified**:
  - `DESCRIPTION` — add `desc` to Imports
  - `renv.lock` — add `desc` package (via `renv::install("desc"); renv::snapshot()`)
  - `R/fct_pipeline.R` — add `fetch_github_descriptions()` function, update `merge_package_data()` signature and logic (cache loading, `version` derivation), update `export_json()`
  - `_targets.R` — add Step 4.5 target (`github_descriptions`), update Step 6 target to pass `github_desc`
  - `tests/testthat/fixtures/github_description_response.rds` — new fixture with mock API response
  - `tests/testthat/test-fct_pipeline.R` — add tests for `fetch_github_descriptions()` (parsing, error handling, caching), update `merge_package_data()` tests
  - `tests/testthat/test-fct_json.R` — add tests for `is_archived` and `version` in JSON export
- **Definition of done**:
  - `fetch_github_descriptions()` fetches and parses DESCRIPTION files for non-CRAN GitHub packages
  - Function handles errors gracefully (404, rate limit, network) with per-package `tryCatch` and `logger::log_warn`
  - Results cached to `data/github_descriptions.rds`
  - `merge_package_data()` loads cache on daily runs, joins enrichment on weekly runs
  - Derived `version` field correctly uses CRAN version for CRAN packages and GitHub version for non-CRAN
  - `export_json()` includes `is_archived` and `version` fields
  - Running `RENDER_EXAMPLES=true Rscript -e 'targets::tar_make()'` produces enriched data
  - Running `targets::tar_make()` (daily mode) loads cached enrichment
  - All pipeline tests pass
- **Testable outcome**: Run weekly pipeline locally, inspect `data/github_descriptions.rds` for populated fields, inspect `data/packages.parquet` for non-CRAN packages with title/license/version data. Run daily pipeline, verify enrichment persists.

#### M4: Non-CRAN Enrichment — UI (Version Rename & Metadata Fallbacks)
- **Goal**: Rename version labels to source-agnostic names and display enriched metadata for non-CRAN packages.
- **Depends on**: M3 (needs enriched data in parquet).
- **Files created/modified**:
  - `R/mod_browse.R` — rename "CRAN Version" column to "Version", display derived `version` field, hide `cran_version`
  - `R/mod_detail.R` — update `build_version_card()` with source-agnostic labels, update `build_header_card()` with GitHub metadata fallbacks for title/description/maintainer/license
- **Definition of done**:
  - Browse table shows "Version" column (not "CRAN Version") with CRAN or GitHub version as appropriate
  - Detail view shows "Latest Version: X.Y.Z" (not "Latest CRAN version")
  - Non-CRAN packages with GitHub enrichment display: title, description, license, maintainer, version
  - Non-CRAN packages without enrichment display em dashes or omit fields gracefully
  - CRAN packages display unchanged (CRAN data takes priority)
  - "Not available on CRAN." text removed from version card
- **Testable outcome**: Run app locally, compare a CRAN package detail view (should show CRAN data with "Latest Version") with a non-CRAN package (should show GitHub data). Check browse table "Version" column for both.

#### M5: Polish & README
- **Goal**: Final polish, full test pass, README update.
- **Depends on**: M0–M4 all complete.
- **Files created/modified**:
  - `README.md` — update to document v1.1 features: package submission, archived packages, non-CRAN enrichment, version label changes
  - Any bug fixes identified during integration testing
- **Definition of done**:
  - `devtools::test()` passes all tests (existing + new)
  - Full pipeline runs successfully in both daily and weekly modes
  - App runs locally with all three features working end-to-end
  - README.md accurately describes all v1.1 features
  - No regressions in existing functionality
- **Testable outcome**: Full manual walkthrough: submit a form, toggle archived packages, view non-CRAN enriched metadata, verify version labels, check browse and detail views for CRAN/non-CRAN/archived packages.

### 13. Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| GitHub DESCRIPTION not found (404) for some non-CRAN packages | Medium | Low | Per-package `tryCatch` returns NA row. 7 packages have no repo_url, 1 is GitLab — these gracefully degrade to missing metadata. |
| `desc` package fails to parse some DESCRIPTION files (encoding, malformed) | Low | Low | `tryCatch` per package. Malformed files return NA. Log warnings for debugging. |
| GitHub API rate limit hit during weekly enrichment | Very Low | Low | 115 calls is well within 5,000/hr. If hit (due to other pipeline steps), partial results are cached and missing packages get NA. |
| Google Form URL changes | Very Low | Low | URL stored in single location (`golem-config.yml`). One-line change + redeploy. |
| `is_archived` column missing from CSV after manual edit | Low | Medium | `validate_curated_csv()` catches this in CI and local validation. |
| Daily pipeline runs before first weekly run (no cached enrichment) | Once | Low | `merge_package_data()` handles missing cache file — non-CRAN packages simply have no enriched metadata until first weekly run. |
| `desc` package version incompatibility with renv | Very Low | Low | Pin version in `renv.lock`. `desc` is stable and well-maintained. |

### 14. Open Questions

| # | Question | Who Resolves | When |
|---|---|---|---|
| 1 | Which ~10 packages should be marked as `is_archived = TRUE` initially? | Maintainer (Antti) | During M1, before merging |
| 2 | What is the actual Google Form URL? | Maintainer (Antti) | During M0, after creating the form |
| 3 | Should the `data/github_descriptions.rds` cache file be git-committed (like parquet files) or git-ignored? | Developer | During M3 implementation |

### 15. Appendix

#### A. API Reference — New Endpoint

**GitHub Contents API (DESCRIPTION file)**
- **Endpoint**: `GET /repos/{owner}/{repo}/contents/DESCRIPTION`
- **Authentication**: `GITHUB_PAT` Bearer token
- **Rate limit**: 5,000 requests/hour (authenticated)
- **Response format**: JSON with `content` field (base64-encoded file content), `encoding` field ("base64")
- **Error codes**: 404 (file not found or repo not found), 403 (rate limit or forbidden)
- **Example response**:
  ```json
  {
    "name": "DESCRIPTION",
    "path": "DESCRIPTION",
    "content": "UGFja2FnZTogZ2d0aGVtcg...",
    "encoding": "base64"
  }
  ```
- **Decoding**: `base64enc::base64decode(response$content) |> rawToChar()`

#### B. Glossary

| Term | Definition |
|---|---|
| Archived package | A package marked by the maintainer as no longer viable for use. Independent of CRAN archive status. |
| Non-CRAN package | A package where `on_cran == FALSE` in the pipeline (pkgsearch returns NULL). May or may not have a GitHub repository. |
| Enrichment | The process of fetching metadata from GitHub DESCRIPTION files for non-CRAN packages to supplement missing CRAN data. |
| Curated CSV | `data-raw/packages_curated.csv` — the manually maintained source of truth for the package list. |

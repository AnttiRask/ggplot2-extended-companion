# Maintenance Guide

## Adding a New Package

**Time required**: Under 5 minutes.

### Steps

1. **Edit the curated CSV**:
   Open `data-raw/packages_curated.csv` and add a new row:

   ```csv
   package_name,categories,is_essential,website_url,repo_url,date_added,notes
   new_package,geoms|stats,FALSE,https://example.com,https://github.com/user/repo,2026-03-17,
   ```

   - `package_name`: Exact CRAN or GitHub package name
   - `categories`: Pipe-separated, must match `data-raw/categories.csv`
   - `is_essential`: `TRUE` or `FALSE`
   - `website_url`: Package website (or leave empty for NA)
   - `repo_url`: GitHub/GitLab URL (or leave empty for NA)
   - `date_added`: Today's date (YYYY-MM-DD)
   - `notes`: Optional notes

2. **Validate locally** (optional but recommended):

   ```r
   pkgload::load_all(export_all = TRUE)
   curated <- read.csv("data-raw/packages_curated.csv", stringsAsFactors = FALSE)
   cats <- read.csv("data-raw/categories.csv", stringsAsFactors = FALSE)
   result <- validate_curated_csv(curated, cats$category)
   result$valid  # Should be TRUE
   ```

3. **Commit and push** to `main`.

4. **Trigger the pipeline**: Go to GitHub Actions → "Daily Pipeline" → "Run workflow". Check "Also re-render code examples" if you want an example image immediately.

5. **Verify**: The new package appears in the app within ~10 minutes after the pipeline completes.

### Validation Rules

The CI automatically validates on every push/PR:

- No duplicate `package_name` values
- All categories exist in `data-raw/categories.csv`
- Required fields (`package_name`, `categories`, `date_added`) are non-empty
- `is_essential` is `TRUE` or `FALSE`
- Categories are well-formed (no trailing pipes, no spaces around pipes)

## Running the Pipeline Locally

```r
# Full pipeline (fetches from CRAN, cranlogs, GitHub)
targets::tar_make()

# Check pipeline status
targets::tar_progress()

# Visualise the DAG
targets::tar_visnetwork()

# Clean and re-run from scratch
targets::tar_destroy(ask = FALSE)
targets::tar_make()
```

**Note**: GitHub API requires `GITHUB_PAT` for 5,000 req/hr. Without it, you're limited to 60 req/hr and most GitHub metadata will be NA.

```r
# Set for the current session
Sys.setenv(GITHUB_PAT = "ghp_your_token_here")
```

## Updating Categories

1. Edit `data-raw/categories.csv` — add, rename, or remove categories.
2. Update any affected packages in `data-raw/packages_curated.csv`.
3. Run validation to verify consistency.
4. Commit and push.

**Current categories** (19):

animation, annotations, arranging_plots, coords, data, facets,
finishing_touches, geoms, helpers, interactive_plots, interactive_tools,
maps, networks, python, scales_and_guides, sports, stats, themes, na

## Monitoring Pipeline Failures

The pipeline handles failures gracefully:

- **Individual package failure**: Logged as warning, continues with NA values
- **Entire API down**: Uses previous cached values via {targets}
- **Pipeline metadata**: Check `data/metadata.parquet` for source statuses

```r
# Check last pipeline run status
arrow::read_parquet("data/metadata.parquet")
```

The app footer shows "Package data last updated: {timestamp}" from metadata.

## Docker

```bash
# Build locally
docker build -t ggplot2-companion .

# Run locally
docker run -p 3838:3838 ggplot2-companion

# Access at http://localhost:3838
```

The Docker image includes:
- R 4.5.3 + all renv dependencies
- App code (R/, inst/, NAMESPACE, DESCRIPTION)
- Parquet data files (data/)
- Curated CSV files for validation

## CI/CD Workflows

| Workflow | Schedule | Purpose |
|---|---|---|
| `check.yml` | On PR/push | R CMD check, tests, CSV validation |
| `pipeline.yml` | Daily 06:00 UTC | Fetch data → build Docker → deploy to Cloud Run |
| `examples.yml` | Sunday 04:00 UTC | Same + render code examples (4hr timeout) |

All workflows can be triggered manually via `workflow_dispatch`.

## Project Structure

```
R/
  app_config.R      # golem configuration helpers
  app_server.R      # main server: data loading, module wiring
  app_ui.R          # main UI: bslib layout, theme, meta tags
  run_app.R         # golem entry point
  mod_browse.R      # browse table module
  mod_detail.R      # detail view module
  mod_sidebar.R     # sidebar filter/sort module
  mod_recent.R      # recently added/updated module
  mod_header.R      # intro accordion module
  mod_footer.R      # footer module
  fct_data.R        # data loading functions
  fct_pipeline.R    # pipeline fetch/merge/write functions
  fct_urls.R        # URL construction
  fct_validation.R  # CSV validation
  fct_filters.R     # filter/sort logic
  fct_examples.R    # code example extraction/rendering
data-raw/
  packages_curated.csv   # source of truth (455 packages)
  categories.csv         # 19 canonical categories
  license_allowlist.csv  # licenses that allow example rendering
  migrate_notion.R       # one-time Notion migration script
data/
  packages.parquet       # core package metadata
  downloads.parquet      # download statistics
  examples.parquet       # code example metadata
  metadata.parquet       # pipeline run status
```

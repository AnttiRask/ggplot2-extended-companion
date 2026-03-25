# ggplot2 extended (companion)

A searchable, filterable directory of 450+ ggplot2 extension packages with daily-refreshed metadata, download statistics, and code examples.

**Live app:** [companion.ggplot2-extended-book.com](https://companion.ggplot2-extended-book.com/)

**The book:** [ggplot2-extended-book.com](https://ggplot2-extended-book.com/)

## What is this?

ggplot2 extensions are R packages that build on top of ggplot2 to add new geoms, stats, scales, themes, and other capabilities. This companion app catalogues them in one place with:

- **Browse & search** all 450+ packages in a sortable, filterable table
- **Category badges** with 19 distinct categories (Geoms, Themes, Maps, etc.)
- **Download statistics** from CRAN (7-day, 30-day, 365-day, all-time)
- **Code examples** extracted from package documentation
- **Direct links** to CRAN, GitHub, reference manuals, and vignettes
- **Dark and light mode** with persistent toggle
- **Shareable links** to individual packages via `?package={name}`
- **Package submission** via Google Form ("Suggest a Package" in sidebar and footer)
- **Archived packages** toggle — packages no longer maintained are hidden by default, with visual indicators when shown
- **Non-CRAN enrichment** — packages not on CRAN get title, description, license, maintainer, and version from their GitHub DESCRIPTION file

## Tech stack

- **Framework:** [golem](https://thinkr-open.github.io/golem/) (R package structure for Shiny apps)
- **UI:** [bslib](https://rstudio.github.io/bslib/) (Bootstrap 5) + [reactable](https://glin.github.io/reactable/) for the data table
- **Data:** [arrow](https://arrow.apache.org/docs/r/) (Parquet files) produced by a [targets](https://docs.ropensci.org/targets/) pipeline
- **APIs:** [pkgsearch](https://r-hub.github.io/pkgsearch/) (CRAN metadata), [cranlogs](https://r-hub.github.io/cranlogs/) (download stats), [gh](https://gh.r-lib.org/) (GitHub metadata)
- **Deployment:** Docker on Google Cloud Run via GitHub Actions

## Run locally

```r
# Install dependencies
renv::restore()

# Run the app
pkgload::load_all()
run_app()
```

## Data pipeline

The data is refreshed daily via GitHub Actions:

- **Daily pipeline** (`pipeline.yml`): Fetches CRAN metadata, download stats, and GitHub activity for all 450+ packages. Builds and deploys the Docker image.
- **Weekly examples & enrichment** (`examples.yml`): Extracts code examples from CRAN package documentation (Rd files) and fetches DESCRIPTION files from GitHub for non-CRAN packages. Runs Sundays.

To run the pipeline locally:

```r
# Requires GITHUB_PAT environment variable for GitHub API
targets::tar_make()
```

## Data sources

| Source | What | How |
|---|---|---|
| `data-raw/packages_curated.csv` | Package list, categories, essential/archived flags | Manually curated |
| `data-raw/categories.csv` | 19 category definitions with display names | Manually curated |
| CRAN (pkgsearch) | Title, description, license, version, published date, vignettes | Daily pipeline |
| cranlogs | Download counts (7d, 30d, 365d, all-time since 2015) | Daily pipeline |
| GitHub API | Last push date | Daily pipeline |
| GitHub Contents API | DESCRIPTION file for non-CRAN packages (title, version, license, maintainer) | Weekly pipeline |

## Project structure

```
R/
  app_ui.R              # Main UI (bslib page_sidebar layout)
  app_server.R          # Server: data loading, filtering, URL routing
  mod_browse.R          # Browse table (reactable)
  mod_detail.R          # Package detail view (cards, nav arrows)
  mod_sidebar.R         # Filter controls
  mod_header.R          # Collapsible intro accordion
  mod_footer.R          # Footer with credits and links
  fct_data.R            # Load Parquet data at startup
  fct_pipeline.R        # Pipeline: fetch APIs, merge, write Parquet
  fct_filters.R         # Filter logic for sidebar controls
  fct_categories.R      # Category display names, colours, badges
  fct_urls.R            # Construct CRAN-derived URLs
  fct_examples.R        # Extract and render code examples
  fct_validation.R      # CSV validation
tests/testthat/         # 457 tests
data-raw/               # Curated CSVs (source of truth)
data/                   # Generated Parquet files (gitignored)
inst/app/www/           # CSS, JS, examples
_targets.R              # Pipeline DAG definition
Dockerfile              # Multi-stage Docker build
.github/workflows/      # CI/CD (check, pipeline, examples)
```

## Contributing

Know a ggplot2 extension we're missing? [Suggest it via our Google Form](https://forms.gle/RkviFqae7aAdUA4q9), or open an issue / submit a PR adding it to `data-raw/packages_curated.csv`.

## License

MIT

## Author

Created by [Antti Rask](https://youcanbeapirate.com)

# =============================================================================
# _targets.R
#
# Defines the {targets} pipeline DAG for the ggplot2 Extended Companion app.
# Orchestrates data fetching from CRAN, cranlogs, and GitHub APIs, merging
# with curated package data, and writing Parquet output files.
#
# The pipeline has two modes controlled by the RENDER_EXAMPLES env var:
#   - Daily (default): Steps 1-8, 12-13. Skips code example rendering.
#   - Weekly (RENDER_EXAMPLES=true): All steps including 10-11 which render
#     code examples and produce examples.parquet + PNG files.
#
# Usage:
#   targets::tar_make()                              # Daily pipeline
#   RENDER_EXAMPLES=true Rscript -e 'targets::tar_make()'  # Weekly pipeline
#   targets::tar_visnetwork()                        # Visualise the DAG
#
# Part of Milestone 2: Data Pipeline (Core) / Milestone 6: Code Examples
# =============================================================================

library(targets)

# Load package functions
pkgload::load_all(export_all = TRUE, helpers = FALSE, attach_testthat = FALSE)

# Pipeline definition
list(
  # Step 1: Load the curated package list (source of truth)
  tar_target(
    curated_packages,
    read_curated_csv("data-raw/packages_curated.csv"),
    format = "rds"
  ),

  # Step 2: Fetch CRAN metadata for all packages
  tar_target(
    cran_metadata,
    fetch_cran_metadata(curated_packages$package_name),
    format = "rds"
  ),

  # Step 3: Fetch download statistics from cranlogs
  tar_target(
    download_stats,
    fetch_download_stats(curated_packages$package_name),
    format = "rds"
  ),

  # Step 4: Fetch GitHub metadata for packages with repo URLs
  tar_target(
    github_metadata,
    fetch_github_metadata(
      curated_packages$package_name,
      curated_packages$repo_url
    ),
    format = "rds"
  ),

  # Step 5: Construct CRAN-derived URLs
  tar_target(
    constructed_urls,
    construct_urls(
      data.frame(
        package_name = cran_metadata$package_name,
        on_cran = cran_metadata$on_cran,
        has_vignettes = cran_metadata$has_vignettes,
        stringsAsFactors = FALSE
      )
    ),
    format = "rds"
  ),

  # Step 5b: Fix non-CRAN downloads (set 0 -> NA for packages not on CRAN)
  tar_target(
    download_stats_fixed,
    fix_non_cran_downloads(download_stats, cran_metadata),
    format = "rds"
  ),

  # Step 6: Merge all data sources (excluding downloads — those go in
  # downloads.parquet only, per SPEC §3.6)
  tar_target(
    packages_combined,
    merge_package_data(
      curated_packages,
      cran_metadata,
      github_metadata,
      constructed_urls
    ),
    format = "rds"
  ),

  # Step 7: Write packages.parquet (no download columns — SPEC §3.6)
  tar_target(
    packages_parquet,
    write_parquet_output(packages_combined, "data/packages.parquet"),
    format = "file"
  ),

  # Step 8: Write downloads.parquet (with NA for non-CRAN packages)
  tar_target(
    downloads_parquet,
    write_parquet_output(download_stats_fixed, "data/downloads.parquet"),
    format = "file"
  ),

  # Step 10: Render code examples (weekly pipeline only)
  # Only runs when RENDER_EXAMPLES env var is "true" (set by examples.yml).
  # The daily pipeline skips this and reuses existing examples.parquet + PNGs.
  if (should_render_examples()) {
    tar_target(
      code_examples,
      render_examples(
        packages_combined,
        allowlist_path = "data-raw/license_allowlist.csv",
        output_dir = "inst/app/www/examples"
      ),
      format = "rds"
    )
  } else {
    NULL
  },

  # Step 11: Write examples.parquet (weekly pipeline only)
  if (should_render_examples()) {
    tar_target(
      examples_parquet,
      write_parquet_output(code_examples, "data/examples.parquet"),
      format = "file"
    )
  } else {
    NULL
  },

  # Step 12: Export JSON for AI agent consumption
  tar_target(
    packages_json,
    export_json(packages_combined, download_stats_fixed, "inst/app/www/data/packages.json"),
    format = "file"
  ),

  # Step 13: Write pipeline metadata
  # Includes examples status when the weekly pipeline renders examples
  tar_target(
    pipeline_metadata,
    write_metadata(
      output_path = "data/metadata.parquet",
      cran_status = if (is.data.frame(cran_metadata)) "success" else "failed",
      downloads_status = if (is.data.frame(download_stats)) "success" else "failed",
      github_status = if (is.data.frame(github_metadata)) "success" else "failed",
      examples_status = if (should_render_examples()) {
        if (is.data.frame(code_examples)) "success" else "failed"
      } else {
        NULL
      }
    ),
    format = "file"
  )
)

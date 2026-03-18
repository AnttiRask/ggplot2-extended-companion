# =============================================================================
# _targets.R
#
# Defines the {targets} pipeline DAG for the ggplot2 Extended Companion app.
# Orchestrates data fetching from CRAN, cranlogs, and GitHub APIs, merging
# with curated package data, and writing Parquet output files.
#
# Usage:
#   targets::tar_make()        # Run the full pipeline
#   targets::tar_visnetwork()  # Visualise the DAG
#
# Part of Milestone 2: Data Pipeline (Core)
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
        stringsAsFactors = FALSE
      )
    ),
    format = "rds"
  ),

  # Step 6: Merge all data sources
  tar_target(
    packages_combined,
    merge_package_data(
      curated_packages,
      cran_metadata,
      download_stats,
      github_metadata,
      constructed_urls
    ),
    format = "rds"
  ),

  # Step 7: Write packages.parquet
  tar_target(
    packages_parquet,
    write_parquet_output(packages_combined, "data/packages.parquet"),
    format = "file"
  ),

  # Step 8: Write downloads.parquet
  tar_target(
    downloads_parquet,
    write_parquet_output(download_stats, "data/downloads.parquet"),
    format = "file"
  ),

  # Step 13: Write pipeline metadata
  tar_target(
    pipeline_metadata,
    write_metadata(
      output_path = "data/metadata.parquet",
      cran_status = if (is.data.frame(cran_metadata)) "success" else "failed",
      downloads_status = if (is.data.frame(download_stats)) "success" else "failed",
      github_status = if (is.data.frame(github_metadata)) "success" else "failed"
    ),
    format = "file"
  )
)

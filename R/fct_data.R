# =============================================================================
# fct_data.R
#
# Data loading functions for the Shiny app. Reads Parquet files produced by
# the pipeline and returns tibbles for use in the app's reactive data flow.
# Uses arrow for Parquet reading (DuckDB used for more complex queries if
# needed in future milestones).
#
# Part of Milestone 3: Data Loading & Browse Table
# =============================================================================

#' Load package data from Parquet
#'
#' Reads `data/packages.parquet` and returns it as a tibble. Contains all
#' core package metadata from SPEC §3.1 (name, description, maintainer,
#' categories, license, versions, dates, URLs).
#'
#' @param path Path to the packages Parquet file.
#'
#' @return A tibble with package data, or NULL if the file doesn't exist.
#'
#' @noRd
load_packages <- function(path = "data/packages.parquet") {
  if (!file.exists(path)) {
    logger::log_warn("Package data file not found: {path}")
    return(NULL)
  }

  arrow::read_parquet(path) |>
    tibble::as_tibble()
}

#' Load download statistics from Parquet
#'
#' Reads `data/downloads.parquet` and returns it as a tibble. Contains
#' download counts for 7d, 30d, 365d, and all-time windows (SPEC §3.2).
#'
#' @param path Path to the downloads Parquet file.
#'
#' @return A tibble with download statistics, or NULL if the file doesn't exist.
#'
#' @noRd
load_downloads <- function(path = "data/downloads.parquet") {
  if (!file.exists(path)) {
    logger::log_warn("Downloads data file not found: {path}")
    return(NULL)
  }

  arrow::read_parquet(path) |>
    tibble::as_tibble()
}

#' Load and combine all app data
#'
#' Reads packages and downloads Parquet files, joins them on `package_name`,
#' and returns a single tibble ready for display in the browse table.
#' This is the main data loading function called at app startup.
#'
#' @param packages_path Path to packages.parquet.
#' @param downloads_path Path to downloads.parquet.
#'
#' @return A tibble with all package and download data combined, or NULL if
#'   files are missing.
#'
#' @noRd
load_app_data <- function(
  packages_path = "data/packages.parquet",
  downloads_path = "data/downloads.parquet"
) {
  packages <- load_packages(packages_path)
  downloads <- load_downloads(downloads_path)

  if (is.null(packages)) {
    logger::log_error("Cannot load app data — packages.parquet missing")
    return(NULL)
  }

  if (is.null(downloads)) {
    # Downloads are optional — app can work without them
    logger::log_warn("Downloads data missing — proceeding without download counts")
    return(packages)
  }

  # Join packages with downloads
  packages |>
    dplyr::left_join(downloads, by = "package_name")
}

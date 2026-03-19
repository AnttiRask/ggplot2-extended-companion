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
#' core package metadata from SPEC section 3.1 (name, description, maintainer,
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
#' download counts for 7d, 30d, 365d, and all-time windows (SPEC section 3.2).
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
    logger::log_error("Cannot load app data -- packages.parquet missing")
    return(NULL)
  }

  if (is.null(downloads)) {
    # Downloads are optional -- app can work without them
    logger::log_warn("Downloads data missing -- proceeding without download counts")
    return(packages)
  }

  # Join packages with downloads
  packages |>
    dplyr::left_join(downloads, by = "package_name")
}

#' Load code examples data from Parquet
#'
#' Reads `data/examples.parquet` and returns it as a tibble. Contains
#' code snippets, image paths, and render status (SPEC section 3.3).
#'
#' @param path Path to the examples Parquet file.
#'
#' @return A tibble with example data, or NULL if the file doesn't exist.
#'
#' @noRd
load_examples <- function(path = "data/examples.parquet") {
  if (!file.exists(path)) {
    logger::log_info("Examples data file not found: {path}")
    return(NULL)
  }

  arrow::read_parquet(path) |>
    tibble::as_tibble()
}

#' Get recently added packages
#'
#' Returns the last `n` packages sorted by `date_added` descending.
#' Used by the "Recently Added" card in mod_recent.
#'
#' @param data A tibble with at least `package_name` and `date_added` columns.
#' @param n Number of packages to return.
#'
#' @return A tibble with `n` rows sorted by date_added descending.
#'
#' @noRd
get_recently_added <- function(data, n = 10) {
  data |>
    dplyr::arrange(dplyr::desc(.data$date_added)) |>
    utils::head(n)
}

#' Get recently updated packages
#'
#' Returns the last `n` packages sorted by the most recent of `cran_published`
#' and `github_updated`. Adds `update_date` and `update_source` columns to
#' indicate when and where the update came from.
#'
#' @param data A tibble with `package_name`, `cran_published`, `github_updated`.
#' @param n Number of packages to return.
#'
#' @return A tibble with `n` rows, plus `update_date` and `update_source` columns.
#'
#' @noRd
get_recently_updated <- function(data, n = 10) {
  data |>
    dplyr::mutate(
      # Pick the more recent of CRAN published and GitHub updated
      update_date = pmax(.data$cran_published, .data$github_updated, na.rm = TRUE),
      # Label the source based on which date was used
      update_source = dplyr::case_when(
        is.na(.data$cran_published) & is.na(.data$github_updated) ~ NA_character_,
        is.na(.data$cran_published) ~ "GitHub",
        is.na(.data$github_updated) ~ "CRAN",
        .data$github_updated >= .data$cran_published ~ "GitHub",
        TRUE ~ "CRAN"
      )
    ) |>
    dplyr::arrange(dplyr::desc(.data$update_date)) |>
    utils::head(n)
}

#' Load pipeline metadata from Parquet
#'
#' Reads `data/metadata.parquet` for the footer "Data last updated" display.
#'
#' @param path Path to the metadata Parquet file.
#'
#' @return A tibble with metadata, or NULL if the file doesn't exist.
#'
#' @noRd
load_metadata <- function(path = "data/metadata.parquet") {
  if (!file.exists(path)) {
    logger::log_warn("Metadata file not found: {path}")
    return(NULL)
  }

  arrow::read_parquet(path) |>
    tibble::as_tibble()
}

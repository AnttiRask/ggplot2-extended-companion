# =============================================================================
# fct_pipeline.R
#
# Data pipeline functions for fetching, merging, and writing package data.
# Fetches metadata from CRAN (pkgsearch), download counts (cranlogs), and
# GitHub activity (gh). Handles per-package errors gracefully — logs warnings
# and continues with NA values.
#
# Part of Milestone 2: Data Pipeline (Core)
# =============================================================================

#' Read the curated package list
#'
#' Reads `data-raw/packages_curated.csv` and returns it as a tibble.
#' This is the source of truth for curated fields (package_name, categories,
#' is_essential, website_url, repo_url, date_added).
#'
#' @param path Path to the curated CSV file.
#'
#' @return A tibble with curated package data.
#'
#' @noRd
read_curated_csv <- function(path = "data-raw/packages_curated.csv") {
  df <- read.csv(path, stringsAsFactors = FALSE)
  tibble::as_tibble(df)
}

# -----------------------------------------------------------------------------
# CRAN Metadata
# -----------------------------------------------------------------------------

#' Parse a CRAN API response into a standardised row
#'
#' Extracts description, maintainer, license, version, and published date
#' from a pkgsearch response. Returns a one-row tibble. If the response is
#' NULL (package not on CRAN), returns a row with NA values and on_cran = FALSE.
#'
#' @param package_name The package name.
#' @param response A list returned by `pkgsearch::cran_package()`, or NULL.
#'
#' @return A one-row tibble with standardised CRAN metadata fields.
#'
#' @noRd
parse_cran_response <- function(package_name, response) {
  if (is.null(response)) {
    return(tibble::tibble(
      package_name   = package_name,
      description    = NA_character_,
      maintainer     = NA_character_,
      license        = NA_character_,
      cran_version   = NA_character_,
      cran_published = as.Date(NA),
      on_cran        = FALSE
    ))
  }

  # Parse maintainer: "Name <email>" -> "Name"
  maintainer_raw <- response$Maintainer %||% NA_character_
  maintainer <- sub("\\s*<.*>$", "", maintainer_raw)

  tibble::tibble(
    package_name   = package_name,
    description    = response$Title %||% NA_character_,
    maintainer     = maintainer,
    license        = response$License %||% NA_character_,
    cran_version   = response$Version %||% NA_character_,
    cran_published = as.Date(response$Published %||% NA_character_),
    on_cran        = TRUE
  )
}

#' Fetch CRAN metadata for all packages
#'
#' Calls `pkgsearch::cran_package()` for each package name. Handles errors
#' per-package: if a package is not on CRAN or the API fails, logs a warning
#' and returns NA values for that package.
#'
#' @param package_names Character vector of package names.
#'
#' @return A tibble with one row per package and CRAN metadata columns.
#'
#' @noRd
fetch_cran_metadata <- function(package_names) {
  results <- lapply(package_names, function(pkg) {
    tryCatch(
      {
        response <- pkgsearch::cran_package(pkg)
        parse_cran_response(pkg, response)
      },
      error = function(e) {
        logger::log_warn("CRAN metadata failed for '{pkg}': {e$message}")
        parse_cran_response(pkg, NULL)
      }
    )
  })

  dplyr::bind_rows(results)
}

# -----------------------------------------------------------------------------
# Download Statistics
# -----------------------------------------------------------------------------

#' Aggregate download counts into time windows
#'
#' Takes raw daily download data and computes 7-day, 30-day, 365-day, and
#' all-time (since 2015) totals. If the data is empty, returns NA for all
#' counts.
#'
#' @param package_name The package name.
#' @param daily_data A data frame with `date`, `count`, `package` columns
#'   (from cranlogs::cran_downloads).
#'
#' @return A one-row tibble with download count columns.
#'
#' @noRd
aggregate_downloads <- function(package_name, daily_data) {
  if (nrow(daily_data) == 0) {
    return(tibble::tibble(
      package_name   = package_name,
      downloads_7d   = NA_integer_,
      downloads_30d  = NA_integer_,
      downloads_365d = NA_integer_,
      downloads_all  = NA_integer_
    ))
  }

  # Use the most recent date in the data as reference
  max_date <- max(daily_data$date, na.rm = TRUE)

  tibble::tibble(
    package_name   = package_name,
    downloads_7d   = as.integer(sum(
      daily_data$count[daily_data$date > (max_date - 7)], na.rm = TRUE
    )),
    downloads_30d  = as.integer(sum(
      daily_data$count[daily_data$date > (max_date - 30)], na.rm = TRUE
    )),
    downloads_365d = as.integer(sum(
      daily_data$count[daily_data$date > (max_date - 365)], na.rm = TRUE
    )),
    downloads_all  = as.integer(sum(daily_data$count, na.rm = TRUE))
  )
}

#' Fetch download statistics for all packages
#'
#' Uses `cranlogs::cran_downloads()` to fetch daily download counts, then
#' aggregates into 7d, 30d, 365d, and all-time windows. Processes packages
#' in batches (cranlogs supports multiple packages per request).
#'
#' @param package_names Character vector of package names.
#'
#' @return A tibble with one row per package and download count columns.
#'
#' @noRd
fetch_download_stats <- function(package_names) {
  tryCatch(
    {
      # cranlogs API accepts batches — split into groups of 30 for reliability
      batch_size <- 30
      batches <- split(package_names, ceiling(seq_along(package_names) / batch_size))

      all_daily <- lapply(batches, function(batch) {
        tryCatch(
          {
            cranlogs::cran_downloads(
              packages = batch,
              from = "2015-01-01",
              to = Sys.Date() - 2  # cranlogs data is ~2 days behind
            )
          },
          error = function(e) {
            logger::log_warn("cranlogs batch failed: {e$message}")
            data.frame(
              date = as.Date(character(0)),
              count = integer(0),
              package = character(0),
              stringsAsFactors = FALSE
            )
          }
        )
      })

      daily_data <- dplyr::bind_rows(all_daily)

      # Aggregate per package
      results <- lapply(package_names, function(pkg) {
        pkg_data <- daily_data[daily_data$package == pkg, ]
        aggregate_downloads(pkg, pkg_data)
      })

      dplyr::bind_rows(results)
    },
    error = function(e) {
      logger::log_warn("fetch_download_stats failed entirely: {e$message}")

      # Return NA for all packages
      tibble::tibble(
        package_name   = package_names,
        downloads_7d   = NA_integer_,
        downloads_30d  = NA_integer_,
        downloads_365d = NA_integer_,
        downloads_all  = NA_integer_
      )
    }
  )
}

# -----------------------------------------------------------------------------
# GitHub Metadata
# -----------------------------------------------------------------------------

#' Parse a GitHub repo URL into owner and repo
#'
#' Extracts the `owner` and `repo` components from a GitHub URL. Returns NULL
#' for non-GitHub URLs or NA input.
#'
#' @param url A character string with a GitHub URL.
#'
#' @return A list with `owner` and `repo`, or NULL if parsing fails.
#'
#' @noRd
parse_github_url <- function(url) {
  if (is.na(url) || !grepl("github\\.com", url)) {
    return(NULL)
  }

  # Match github.com/{owner}/{repo}, ignoring trailing slash or path
  match <- regmatches(url, regexec("github\\.com/([^/]+)/([^/]+)/?", url))[[1]]

  if (length(match) < 3) {
    return(NULL)
  }

  list(owner = match[2], repo = match[3])
}

#' Parse a GitHub API response into a standardised row
#'
#' Extracts the last update date from a GitHub API response. If the response
#' is NULL, returns NA.
#'
#' @param package_name The package name.
#' @param response A list returned by `gh::gh()`, or NULL.
#'
#' @return A one-row tibble with `package_name` and `github_updated`.
#'
#' @noRd
parse_github_response <- function(package_name, response) {
  if (is.null(response)) {
    return(tibble::tibble(
      package_name   = package_name,
      github_updated = as.Date(NA)
    ))
  }

  # pushed_at is more relevant than updated_at (which includes issue activity)
  pushed_at <- response$pushed_at %||% response$updated_at
  github_date <- tryCatch(
    as.Date(pushed_at),
    error = function(e) as.Date(NA)
  )

  tibble::tibble(
    package_name   = package_name,
    github_updated = github_date
  )
}

#' Fetch GitHub metadata for all packages
#'
#' Calls `gh::gh("GET /repos/{owner}/{repo}")` for each package with a
#' GitHub repo URL. Handles errors per-package.
#'
#' @param package_names Character vector of package names.
#' @param repo_urls Character vector of repository URLs (parallel to package_names).
#'
#' @return A tibble with one row per package and `github_updated` column.
#'
#' @noRd
fetch_github_metadata <- function(package_names, repo_urls) {
  results <- lapply(seq_along(package_names), function(i) {
    pkg <- package_names[i]
    url <- repo_urls[i]

    # Parse the GitHub URL
    parsed <- parse_github_url(url)

    if (is.null(parsed)) {
      return(parse_github_response(pkg, NULL))
    }

    tryCatch(
      {
        response <- gh::gh(
          "GET /repos/{owner}/{repo}",
          owner = parsed$owner,
          repo = parsed$repo,
          .token = Sys.getenv("GITHUB_PAT", "")
        )
        parse_github_response(pkg, response)
      },
      error = function(e) {
        logger::log_warn("GitHub metadata failed for '{pkg}': {e$message}")
        parse_github_response(pkg, NULL)
      }
    )
  })

  dplyr::bind_rows(results)
}

# -----------------------------------------------------------------------------
# Merge and Output
# -----------------------------------------------------------------------------

#' Merge all data sources into a single tibble
#'
#' Joins curated data, CRAN metadata, download stats, GitHub metadata, and
#' constructed URLs into a single tibble with all fields from the Package
#' Entity data model (SPEC section 3.1).
#'
#' @param curated Tibble from `read_curated_csv()`.
#' @param cran_meta Tibble from `fetch_cran_metadata()`.
#' @param downloads Tibble from `fetch_download_stats()`.
#' @param github_meta Tibble from `fetch_github_metadata()`.
#' @param urls Tibble from `construct_urls()`.
#'
#' @return A tibble with one row per package and all merged fields.
#'
#' @noRd
merge_package_data <- function(curated, cran_meta, downloads, github_meta, urls) {
  result <- curated |>
    dplyr::left_join(cran_meta, by = "package_name") |>
    dplyr::left_join(downloads, by = "package_name") |>
    dplyr::left_join(github_meta, by = "package_name") |>
    dplyr::left_join(urls, by = "package_name") |>
    dplyr::mutate(
      last_checked = Sys.Date()
    )

  result
}

#' Write a data frame to Parquet format
#'
#' Writes a data frame or tibble to a Parquet file using the arrow package.
#' Creates the output directory if it doesn't exist.
#'
#' @param df A data frame to write.
#' @param path The output file path (e.g., "data/packages.parquet").
#'
#' @return The path to the written file (invisibly).
#'
#' @noRd
write_parquet_output <- function(df, path) {
  # Ensure output directory exists
  dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)

  arrow::write_parquet(df, path)

  invisible(path)
}

#' Write pipeline metadata to Parquet
#'
#' Records the status and timestamp of each pipeline data source in a
#' Parquet file. Used for the footer "Data last updated" display and
#' internal monitoring.
#'
#' @param output_path Path to write the metadata Parquet file.
#' @param cran_status Status of the CRAN metadata fetch ("success" or "failed").
#' @param downloads_status Status of the cranlogs fetch.
#' @param github_status Status of the GitHub metadata fetch.
#'
#' @return The output path (invisibly).
#'
#' @noRd
write_metadata <- function(output_path, cran_status, downloads_status, github_status) {
  metadata <- tibble::tibble(
    source   = c("cran", "cranlogs", "github"),
    last_run = rep(as.character(Sys.time()), 3),
    status   = c(cran_status, downloads_status, github_status)
  )

  write_parquet_output(metadata, output_path)

  invisible(output_path)
}

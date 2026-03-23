# =============================================================================
# fct_pipeline.R
#
# Data pipeline functions for fetching, merging, and writing package data.
# Fetches metadata from CRAN (pkgsearch), download counts (cranlogs), and
# GitHub activity (gh). Handles per-package errors gracefully -- logs warnings
# and continues with NA values.
#
# Part of Milestone 2: Data Pipeline (Core) / Milestone 6: Code Examples
# =============================================================================

#' Check if a CRAN package has vignettes
#'
#' Makes a lightweight HTTP request to the package's CRAN vignettes
#' directory. Returns TRUE if the page exists and contains links to
#' .html, .pdf, or .Rmd files. Returns FALSE for 404s, non-CRAN
#' packages, or network errors.
#'
#' @param package_name Name of the CRAN package.
#'
#' @return Logical. TRUE if the package has vignettes on CRAN.
#'
#' @noRd
check_cran_vignettes <- function(package_name) {
  url <- paste0(
    "https://cran.r-project.org/web/packages/",
    package_name, "/vignettes/"
  )
  tryCatch(
    {
      con <- url(url)
      on.exit(close(con), add = TRUE)
      lines <- readLines(con, warn = FALSE, n = 50)
      any(grepl("\\.html|\\.pdf|\\.Rmd", lines))
    },
    error = function(e) FALSE
  )
}

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
      title          = NA_character_,
      description    = NA_character_,
      maintainer     = NA_character_,
      license        = NA_character_,
      cran_version   = NA_character_,
      cran_published = as.Date(NA),
      on_cran        = FALSE,
      has_vignettes  = FALSE
    ))
  }

  # Parse maintainer: "Name <email>" -> "Name"
  maintainer_raw <- response$Maintainer %||% NA_character_
  maintainer <- sub("\\s*<.*>$", "", maintainer_raw)

  # Detect vignettes: check the CRAN vignettes directory URL directly.
  # pkgsearch's vignettes field is unreliable (always empty for most packages).
  # A quick HTTP check of the vignettes directory is more accurate.
  has_vignettes <- check_cran_vignettes(package_name)

  # Published date: prefer response$Published, fall back to response$date
  # (pkgsearch sometimes returns an empty string for Published while
  # the date field has the correct ISO 8601 timestamp)
  published_raw <- response$Published %||% ""
  if (published_raw == "") {
    published_raw <- response$date %||% NA_character_
  }
  cran_published <- tryCatch(
    as.Date(published_raw),
    error = function(e) as.Date(NA)
  )

  tibble::tibble(
    package_name   = package_name,
    title          = response$Title %||% NA_character_,
    description    = response$Description %||% NA_character_,
    maintainer     = maintainer,
    license        = response$License %||% NA_character_,
    cran_version   = response$Version %||% NA_character_,
    cran_published = cran_published,
    on_cran        = TRUE,
    has_vignettes  = has_vignettes
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
      # cranlogs API accepts batches -- split into groups of 30 for reliability
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
#' @param github_meta Tibble from `fetch_github_metadata()`.
#' @param urls Tibble from `construct_urls()`.
#'
#' @return A tibble with one row per package and all merged fields (excluding
#'   download stats, which go in downloads.parquet separately per SPEC section 3.6).
#'
#' @noRd
merge_package_data <- function(curated, cran_meta, github_meta, urls) {
  result <- curated |>
    dplyr::left_join(cran_meta, by = "package_name") |>
    dplyr::left_join(github_meta, by = "package_name") |>
    dplyr::left_join(urls, by = "package_name") |>
    dplyr::mutate(
      last_checked = Sys.Date()
    )

  result
}

#' Post-process download stats: set non-CRAN packages to NA
#'
#' cranlogs returns 0 for packages not on CRAN, but NA is the correct
#' semantic value ("not applicable" vs "zero downloads"). This function
#' cross-references download stats with CRAN status and replaces 0s with NAs
#' for non-CRAN packages.
#'
#' @param downloads Tibble from `fetch_download_stats()`.
#' @param cran_meta Tibble from `fetch_cran_metadata()` (needs `on_cran` column).
#'
#' @return The downloads tibble with NA counts for non-CRAN packages.
#'
#' @noRd
fix_non_cran_downloads <- function(downloads, cran_meta) {
  downloads |>
    dplyr::left_join(
      dplyr::select(cran_meta, "package_name", "on_cran"),
      by = "package_name"
    ) |>
    dplyr::mutate(
      downloads_7d   = ifelse(.data$on_cran, .data$downloads_7d,   NA_integer_),
      downloads_30d  = ifelse(.data$on_cran, .data$downloads_30d,  NA_integer_),
      downloads_365d = ifelse(.data$on_cran, .data$downloads_365d, NA_integer_),
      downloads_all  = ifelse(.data$on_cran, .data$downloads_all,  NA_integer_)
    ) |>
    dplyr::select(-"on_cran")
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
#' internal monitoring. When the weekly pipeline renders code examples,
#' `examples_status` is included as a fourth row.
#'
#' @param output_path Path to write the metadata Parquet file.
#' @param cran_status Status of the CRAN metadata fetch ("success" or "failed").
#' @param downloads_status Status of the cranlogs fetch.
#' @param github_status Status of the GitHub metadata fetch.
#' @param examples_status Status of the code example rendering (NULL to omit).
#'
#' @return The output path (invisibly).
#'
#' @noRd
write_metadata <- function(output_path, cran_status, downloads_status, github_status,
                           examples_status = NULL) {
  sources <- c("cran", "cranlogs", "github")
  statuses <- c(cran_status, downloads_status, github_status)

  # Include examples status only when the weekly pipeline renders examples
  if (!is.null(examples_status)) {
    sources <- c(sources, "examples")
    statuses <- c(statuses, examples_status)
  }

  metadata <- tibble::tibble(
    source   = sources,
    # ISO 8601 UTC format for consistent parsing across environments
    last_run = rep(format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), length(sources)),
    status   = statuses
  )

  write_parquet_output(metadata, output_path)

  invisible(output_path)
}

#' Check whether code examples should be rendered
#'
#' Reads the `RENDER_EXAMPLES` environment variable to determine whether the
#' pipeline should run the code example rendering step. The weekly pipeline
#' (`examples.yml`) sets this to `"true"`; the daily pipeline does not set it.
#' This allows the same `_targets.R` to serve both schedules.
#'
#' @return Logical. `TRUE` if `RENDER_EXAMPLES` is set to `"true"` (case-insensitive).
#'
#' @noRd
should_render_examples <- function() {
  tolower(Sys.getenv("RENDER_EXAMPLES", unset = "")) == "true"
}

#' Export package data as JSON for AI agent consumption
#'
#' Produces a machine-readable JSON file matching the structure defined in
#' SPEC section 8. Combines package metadata with download statistics.
#' Categories are converted from pipe-separated strings to JSON arrays.
#'
#' @param packages Tibble with package data (from packages.parquet).
#' @param downloads Tibble with download data (from downloads.parquet).
#' @param output_path Path to write the JSON file.
#'
#' @return The output path (invisibly).
#'
#' @noRd
export_json <- function(packages, downloads, output_path = "inst/app/www/data/packages.json") {
  # Join packages with downloads for the export
  combined <- packages |>
    dplyr::left_join(downloads, by = "package_name")

  # Build the package list matching spec section 8 structure
  pkg_list <- lapply(seq_len(nrow(combined)), function(i) {
    row <- combined[i, ]
    list(
      name           = row$package_name,
      title          = if ("title" %in% names(row) && !is.na(row$title)) row$title else NULL,
      description    = if (is.na(row$description)) NULL else row$description,
      categories     = strsplit(row$categories, "\\|")[[1]],
      is_essential   = row$is_essential,
      on_cran        = row$on_cran,
      license        = if (is.na(row$license)) NULL else row$license,
      cran_version   = if (is.na(row$cran_version)) NULL else row$cran_version,
      cran_published = if (is.na(row$cran_published)) NULL else as.character(row$cran_published),
      github_updated = if (is.na(row$github_updated)) NULL else as.character(row$github_updated),
      downloads_30d  = if (is.na(row$downloads_30d)) NULL else row$downloads_30d,
      downloads_all  = if (is.na(row$downloads_all)) NULL else row$downloads_all,
      cran_url       = if (is.na(row$cran_url)) NULL else row$cran_url,
      website_url    = if (is.na(row$website_url)) NULL else row$website_url,
      repo_url       = if (is.na(row$repo_url)) NULL else row$repo_url
    )
  })

  # Build the top-level JSON structure
  json_data <- list(
    generated_at  = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    package_count = nrow(combined),
    packages      = pkg_list
  )

  # Ensure output directory exists
  dir.create(dirname(output_path), showWarnings = FALSE, recursive = TRUE)

  # Write JSON with pretty formatting
  jsonlite::write_json(
    json_data,
    output_path,
    pretty = TRUE,
    auto_unbox = TRUE,
    null = "null"
  )

  invisible(output_path)
}

# =============================================================================
# fct_filters.R
#
# Filtering and sorting functions for the package browse table. Applied
# server-side when sidebar controls change, then the filtered/sorted data
# is passed to the reactable for rendering.
#
# Part of Milestone 4: Sidebar Filters & Sorting
# =============================================================================

#' Filter packages by sidebar criteria
#'
#' Applies category, CRAN status, license, and essential-only filters to the
#' package dataset. All filters default to "show everything" so they compose
#' cleanly — any combination of filters can be applied.
#'
#' @param data A tibble of package data.
#' @param category Category to filter by, or "All" for no category filter.
#' @param cran_status One of "All", "On CRAN", "Not on CRAN".
#' @param license_filter License to filter by, or "All" for no license filter.
#' @param essential_only Logical. If TRUE, show only essential packages.
#'
#' @return A filtered tibble.
#'
#' @noRd
filter_packages <- function(
  data,
  category = "All",
  cran_status = "All",
  license_filter = "All",
  essential_only = FALSE
) {
  result <- data

  # Filter by category (check if category appears in pipe-separated list)
  if (!is.null(category) && category != "All") {
    result <- result |>
      dplyr::filter(
        grepl(paste0("(^|\\|)", category, "(\\||$)"), .data$categories)
      )
  }

  # Filter by CRAN status
  if (!is.null(cran_status) && cran_status != "All") {
    if (cran_status == "On CRAN") {
      result <- result |>
        dplyr::filter(.data$on_cran == TRUE)
    } else if (cran_status == "Not on CRAN") {
      result <- result |>
        dplyr::filter(.data$on_cran == FALSE)
    }
  }

  # Filter by license
  if (!is.null(license_filter) && license_filter != "All") {
    result <- result |>
      dplyr::filter(.data$license == license_filter)
  }

  # Filter essential only
  if (isTRUE(essential_only)) {
    result <- result |>
      dplyr::filter(.data$is_essential == TRUE)
  }

  result
}

#' Sort packages by the selected sort option
#'
#' Sorts the package dataset according to the sort-by dropdown value from
#' the sidebar. Handles all 10 sort options from SPEC section 5.3.
#'
#' @param data A tibble of package data.
#' @param sort_by The sort option string from the dropdown.
#'
#' @return A sorted tibble.
#'
#' @noRd
sort_packages <- function(data, sort_by = "Name (A\u2013Z)") {
  switch(sort_by,
    "Name (A\u2013Z)" = dplyr::arrange(data, .data$package_name),
    "Name (Z\u2013A)" = dplyr::arrange(data, dplyr::desc(.data$package_name)),
    "Creator (A\u2013Z)" = dplyr::arrange(data, .data$maintainer),
    "Creator (Z\u2013A)" = dplyr::arrange(data, dplyr::desc(.data$maintainer)),
    "Downloads (30d) \u2193" = dplyr::arrange(data, dplyr::desc(.data$downloads_30d)),
    "Downloads (All) \u2193" = dplyr::arrange(data, dplyr::desc(.data$downloads_all)),
    "CRAN Published (newest)" = dplyr::arrange(data, dplyr::desc(.data$cran_published)),
    "CRAN Published (oldest)" = dplyr::arrange(data, .data$cran_published),
    "GitHub Updated (newest)" = dplyr::arrange(data, dplyr::desc(.data$github_updated)),
    "GitHub Updated (oldest)" = dplyr::arrange(data, .data$github_updated),
    # Default fallback
    dplyr::arrange(data, .data$package_name)
  )
}

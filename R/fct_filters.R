# =============================================================================
# fct_filters.R
#
# Filtering and sorting functions for the package browse table. Applied
# server-side when sidebar controls change, then the filtered/sorted data
# is passed to the reactable for rendering.
#
# v1.2 (M0): essential_only → featured_only (filters on is_featured column).
#
# Part of Milestone 4: Sidebar Filters & Sorting
# =============================================================================

#' Filter packages by sidebar criteria
#'
#' Applies archived visibility, category, CRAN status, license,
#' featured-only, and recently added/updated filters to the package dataset.
#' All filters default to "show everything" so they compose cleanly via AND
#' logic. The recently added and recently updated filters use OR logic
#' between themselves (union), but AND with all other filters.
#'
#' @param data A tibble of package data.
#' @param category Category to filter by, or "All" for no category filter.
#' @param cran_status One of "All", "On CRAN", "Not on CRAN".
#' @param license_filter License to filter by, or "All" for no license filter.
#' @param featured_only Logical. If TRUE, show only packages featured in the
#'   book (is_featured == TRUE).
#' @param recently_added Logical. If TRUE, include recently added packages.
#' @param recently_updated Logical. If TRUE, include recently updated packages.
#' @param show_archived Logical. If FALSE (default), hide archived packages.
#'
#' @return A filtered tibble.
#'
#' @noRd
filter_packages <- function(
  data,
  category = "All",
  cran_status = "All",
  license_filter = "All",
  featured_only = FALSE,
  recently_added = FALSE,
  recently_updated = FALSE,
  show_archived = FALSE
) {
  result <- data

  # Filter archived packages (default: hidden) — applied first per SPEC-v1.1 §5.5.1
  # Defensive: only filter if is_archived column exists (transitional data may lack it)
  if (isFALSE(show_archived) && "is_archived" %in% names(result)) {
    result <- result |>
      dplyr::filter(.data$is_archived == FALSE | is.na(.data$is_archived))
  }

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

  # Filter featured only (packages covered in the companion book)
  if (isTRUE(featured_only)) {
    result <- result |>
      dplyr::filter(.data$is_featured == TRUE)
  }


  # Filter by recently added / recently updated.
  # When BOTH are checked: show union (OR) — packages matching either flag.
  # When only one is checked: show only that flag's matches.
  if (isTRUE(recently_added) && isTRUE(recently_updated)) {
    result <- result |>
      dplyr::filter(.data$recently_added | .data$recently_updated)
  } else if (isTRUE(recently_added)) {
    result <- result |>
      dplyr::filter(.data$recently_added)
  } else if (isTRUE(recently_updated)) {
    result <- result |>
      dplyr::filter(.data$recently_updated)
  }

  result
}

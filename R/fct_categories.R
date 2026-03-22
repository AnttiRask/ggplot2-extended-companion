# =============================================================================
# fct_categories.R
#
# Category display name mapping, colour palette, and badge rendering helpers.
# Reads category metadata from data-raw/categories.csv and provides functions
# for converting technical names to display names and rendering coloured
# badge HTML for both the browse table and detail view.
#
# Part of production-fix-polish: Category Infrastructure
# =============================================================================

#' Get category display name mapping
#'
#' Reads `data-raw/categories.csv` and returns a named character vector
#' mapping technical category identifiers (e.g., "arranging_plots") to
#' human-readable display names (e.g., "Arranging Plots").
#'
#' @return A named character vector: names are technical category IDs,
#'   values are display names.
#'
#' @noRd
# Module-level cache for display names (avoids re-reading CSV on every call).
# Populated on first access, then reused for the lifetime of the R session.
.category_cache <- new.env(parent = emptyenv())

get_category_display_names <- function() {
  # Return cached result if available

  if (!is.null(.category_cache$display_names)) {
    return(.category_cache$display_names)
  }

  # Try multiple paths to find categories.csv:
  # 1. Installed package location (works during R CMD check and deployed app)
  # 2. data-raw/ in project root (works during development with pkgload)
  # 3. Golem app_sys fallback
  csv_path <- system.file("extdata", "categories.csv",
                           package = "ggplot2.extended.companion")

  if (csv_path == "") {
    csv_path <- "data-raw/categories.csv"
  }

  if (!file.exists(csv_path)) {
    csv_path <- app_sys("../data-raw/categories.csv")
  }

  # na.strings = "" prevents R from converting the literal "NA" display
  # name into an R NA value
  cats <- read.csv(csv_path, stringsAsFactors = FALSE, na.strings = "")
  result <- stats::setNames(cats$display_name, cats$category)

  # Cache for subsequent calls
  .category_cache$display_names <- result

  result
}

#' Convert a single category technical name to its display name
#'
#' Looks up the display name for a category. Returns the technical name
#' unchanged if no mapping is found (graceful fallback for unknown categories).
#'
#' @param category A single character string (technical category name).
#'
#' @return The display name string, or the input unchanged if not found.
#'
#' @noRd
category_to_display_name <- function(category) {
  display_names <- get_category_display_names()

  if (category %in% names(display_names)) {
    display_names[[category]]
  } else {
    category
  }
}

#' Get the 19-colour category badge palette
#'
#' Returns a named character vector mapping each category to a distinct
#' hex colour. Colours are drawn from the Tailwind CSS palette for good
#' hue separation. Used by `build_category_badge()` for semi-transparent
#' badge backgrounds.
#'
#' @return A named character vector: names are technical category IDs,
#'   values are hex colour codes.
#'
#' @noRd
get_category_colours <- function() {
  c(
    animation         = "#8B5CF6",
    annotations       = "#3B82F6",
    arranging_plots   = "#06B6D4",
    coords            = "#14B8A6",
    data              = "#10B981",
    facets            = "#22C55E",
    finishing_touches  = "#84CC16",
    geoms             = "#C1272D",
    helpers           = "#F59E0B",
    interactive_plots = "#F97316",
    interactive_tools  = "#EF4444",
    maps              = "#0EA5E9",
    networks          = "#A855F7",
    python            = "#FBBF24",
    scales_and_guides = "#EC4899",
    sports            = "#6366F1",
    stats             = "#D946EF",
    themes            = "#78716C",
    na                = "#9CA3AF"
  )
}

#' Build a category badge as an HTML span
#'
#' Renders a pill-shaped badge with a semi-transparent background and
#' matching text colour. Works in both dark and light modes because the
#' background uses rgba() opacity rather than solid fills.
#'
#' @param category A single character string (technical category name).
#'
#' @return An `htmltools::span()` tag with badge styling.
#'
#' @noRd
build_category_badge <- function(category) {
  display_names <- get_category_display_names()
  colours <- get_category_colours()

  # Look up display name (fallback to technical name)
  display_name <- if (category %in% names(display_names)) {
    display_names[[category]]
  } else {
    category
  }

  # Look up colour (fallback to grey)
  colour <- if (category %in% names(colours)) {
    colours[[category]]
  } else {
    "#9CA3AF"
  }

  # Convert hex to RGB components for rgba() background
  r <- strtoi(substr(colour, 2, 3), base = 16)
  g <- strtoi(substr(colour, 4, 5), base = 16)
  b <- strtoi(substr(colour, 6, 7), base = 16)

  htmltools::span(
    class = "badge-category",
    style = sprintf(
      paste0(
        "background-color: rgba(%d, %d, %d, 0.18); ",
        "color: %s; ",
        "border: 1px solid rgba(%d, %d, %d, 0.35);"
      ),
      r, g, b, colour, r, g, b
    ),
    display_name
  )
}

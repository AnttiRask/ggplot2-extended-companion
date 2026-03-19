# =============================================================================
# app_server.R
#
# Main server function for the ggplot2 Extended Companion app. Loads package
# data at startup, renders sidebar controls with data-driven choices, applies
# sidebar filters/sorts to the data, and passes the result to the browse module.
#
# Part of Milestone 4: Sidebar Filters & Sorting
# =============================================================================

#' The application server-side logic
#'
#' Loads package data at startup from Parquet files, renders sidebar filter
#' controls populated with data-driven choices, applies filters and sorting,
#' and passes the filtered data to the browse module.
#'
#' @param input,output,session Internal parameters for `{shiny}`.
#'
#' @import shiny
#' @noRd
app_server <- function(input, output, session) {
  # -------------------------------------------------------------------------
  # Data loading (once at startup)
  # -------------------------------------------------------------------------

  app_data_raw <- load_app_data()

  # -------------------------------------------------------------------------
  # Sidebar controls (data-driven choices)
  # -------------------------------------------------------------------------

  # Extract unique categories and licenses from the data for dropdown choices
  all_categories <- if (!is.null(app_data_raw)) {
    unique(unlist(strsplit(app_data_raw$categories, "\\|")))
  } else {
    character(0)
  }

  all_licenses <- if (!is.null(app_data_raw)) {
    unique(stats::na.omit(app_data_raw$license))
  } else {
    character(0)
  }

  # Render sidebar controls with data-driven choices
  output$sidebar_controls <- renderUI({
    mod_sidebar_ui("sidebar", categories = all_categories, licenses = all_licenses)
  })

  # Sidebar module server — returns reactive filter/sort values
  sidebar_values <- mod_sidebar_server("sidebar")

  # -------------------------------------------------------------------------
  # Filtered and sorted data
  # -------------------------------------------------------------------------

  # Apply sidebar filters and sorting to produce the dataset for the table
  filtered_data <- reactive({
    if (is.null(app_data_raw)) return(NULL)

    # Get current filter values (with defaults for initial render before
    # sidebar inputs are available)
    category       <- sidebar_values$category()       %||% "All"
    cran_status    <- sidebar_values$cran_status()     %||% "All"
    license_filter <- sidebar_values$license()         %||% "All"
    essential_only <- sidebar_values$essential_only()   %||% FALSE
    sort_by        <- sidebar_values$sort_by()         %||% "Name (A\u2013Z)"

    # Apply filters
    result <- filter_packages(
      app_data_raw,
      category       = category,
      cran_status    = cran_status,
      license_filter = license_filter,
      essential_only = essential_only
    )

    # Apply sorting
    result <- sort_packages(result, sort_by)

    result
  })

  # -------------------------------------------------------------------------
  # Module server calls
  # -------------------------------------------------------------------------

  # Browse table module (M3) — receives filtered/sorted data
  selected_package <- mod_browse_server("browse", filtered_data)

  # Future modules:
  # M5: Detail view module (will use selected_package reactive)
  # M7: Recent packages, header, footer modules
}

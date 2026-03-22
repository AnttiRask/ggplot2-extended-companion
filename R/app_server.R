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

  logger::log_info("Starting ggplot2 extended (companion) app")
  app_data_raw <- load_app_data()

  if (!is.null(app_data_raw)) {
    logger::log_info("Loaded {nrow(app_data_raw)} packages")
  } else {
    logger::log_error("No package data available -- app will show empty state")
  }

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

  # Sidebar module server -- returns reactive filter/sort values
  sidebar_values <- mod_sidebar_server("sidebar")

  # -------------------------------------------------------------------------
  # Filtered and sorted data
  # -------------------------------------------------------------------------

  # Apply sidebar filters to produce the dataset for the table.
  # Sorting is handled client-side by reactable column headers.
  filtered_data <- reactive({
    if (is.null(app_data_raw)) return(NULL)

    # Get current filter values (with defaults for initial render before
    # sidebar inputs are available)
    category         <- sidebar_values$category()         %||% "All"
    cran_status      <- sidebar_values$cran_status()      %||% "All"
    license_filter   <- sidebar_values$license()          %||% "All"
    essential_only   <- sidebar_values$essential_only()    %||% FALSE
    recently_added   <- sidebar_values$recently_added()    %||% FALSE
    recently_updated <- sidebar_values$recently_updated()  %||% FALSE

    # Apply filters (sorting handled by reactable column headers)
    result <- filter_packages(
      app_data_raw,
      category         = category,
      cran_status      = cran_status,
      license_filter   = license_filter,
      essential_only   = essential_only,
      recently_added   = recently_added,
      recently_updated = recently_updated
    )

    # Default order: alphabetical by package_name
    result <- dplyr::arrange(result, .data$package_name)

    result
  })

  # -------------------------------------------------------------------------
  # Module server calls
  # -------------------------------------------------------------------------

  # Browse table module (M3) -- receives filtered/sorted data
  selected_package <- mod_browse_server("browse", filtered_data)

  # Load examples data (M6) -- may be NULL if examples haven't been rendered
  examples_data_raw <- load_examples()

  # Alphabetically sorted list of all package names (for prev/next navigation)
  all_packages_alpha <- reactive({
    if (!is.null(app_data_raw)) {
      sort(app_data_raw$package_name)
    } else {
      character(0)
    }
  })

  # Detail view module (M5+M6) -- receives selected package, full data, examples
  mod_detail_server(
    "detail",
    selected_package = selected_package,
    app_data = reactive({ app_data_raw }),
    examples_data = reactive({ examples_data_raw }),
    all_packages_alpha = all_packages_alpha,
    on_back = function() {
      # Clear selected package to return to browse view
      selected_package(NULL)
    },
    on_navigate = function(pkg_name) {
      # Navigate to a different package (updates URL via the observer)
      selected_package(pkg_name)
    }
  )

  # -------------------------------------------------------------------------
  # Browse/Detail toggle (M5) & URL routing
  # -------------------------------------------------------------------------

  # Output flag for conditionalPanel -- TRUE when a package is selected
  output$show_detail <- reactive({
    !is.null(selected_package())
  })
  # Allow conditionalPanel to access this output
  outputOptions(output, "show_detail", suspendWhenHidden = FALSE)

  # Parse URL query parameter on startup: ?package={name}
  shiny::observe({
    query <- shiny::parseQueryString(session$clientData$url_search)
    if (!is.null(query$package) && nchar(query$package) > 0) {
      # Validate the package name exists in the data
      if (!is.null(app_data_raw) &&
          query$package %in% app_data_raw$package_name) {
        selected_package(query$package)
      }
    }
  }) |> shiny::bindEvent(session$clientData$url_search, once = TRUE)

  # Update URL when selected_package changes.
  # Use "push" for package selection (creates history entry for back button),
  # "replace" for clearing (avoids extra history entry on startup/back).
  shiny::observe({
    pkg <- selected_package()
    if (!is.null(pkg)) {
      shiny::updateQueryString(paste0("?package=", pkg), mode = "push")
    } else {
      shiny::updateQueryString("?", mode = "replace")
    }
  })

  # Header module (M7) -- static intro content, no server logic needed
  mod_header_server("header")

  # Footer module (M7) -- loads metadata for data freshness timestamp
  mod_footer_server("footer")
}

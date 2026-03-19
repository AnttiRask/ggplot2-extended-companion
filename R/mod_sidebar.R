# =============================================================================
# mod_sidebar.R
#
# Shiny module for the sidebar filter and sort controls. Provides category
# dropdown, CRAN status radio buttons, license dropdown, essential-only
# checkbox, sort-by dropdown, and package submission link.
#
# Part of Milestone 4: Sidebar Filters & Sorting
# =============================================================================

#' Sidebar Module — UI
#'
#' Renders all sidebar filter and sort controls as defined in SPEC §5.3.
#'
#' @param id Module namespace ID.
#' @param categories Character vector of available category identifiers.
#' @param licenses Character vector of available license strings.
#'
#' @return A tagList of sidebar UI elements.
#'
#' @noRd
mod_sidebar_ui <- function(id, categories = character(0), licenses = character(0)) {
  ns <- shiny::NS(id)

  # Build category choices: "All" + sorted display-name versions
  category_choices <- c("All", sort(categories))

  # Build license choices: "All" + sorted unique licenses
  license_choices <- c("All", sort(licenses))

  # Sort options from SPEC §5.3

  sort_choices <- c(
    "Name (A\u2013Z)",
    "Name (Z\u2013A)",
    "Creator (A\u2013Z)",
    "Creator (Z\u2013A)",
    "Downloads (30d) \u2193",
    "Downloads (All) \u2193",
    "CRAN Published (newest)",
    "CRAN Published (oldest)",
    "GitHub Updated (newest)",
    "GitHub Updated (oldest)"
  )

  htmltools::tagList(
    # Category filter
    shiny::selectInput(
      ns("category"),
      label = "Category",
      choices = category_choices,
      selected = "All"
    ),

    # CRAN status filter
    shiny::radioButtons(
      ns("cran_status"),
      label = "CRAN Status",
      choices = c("All", "On CRAN", "Not on CRAN"),
      selected = "All"
    ),

    # License filter
    shiny::selectInput(
      ns("license"),
      label = "License",
      choices = license_choices,
      selected = "All"
    ),

    # Essential only checkbox
    shiny::checkboxInput(
      ns("essential_only"),
      label = "Essential Extensions only",
      value = FALSE
    ),

    # Sort by dropdown
    shiny::selectInput(
      ns("sort_by"),
      label = "Sort by",
      choices = sort_choices,
      selected = "Name (A\u2013Z)"
    ),

    # Divider
    htmltools::hr(),

    # Submit a package link (opens Google Form in new tab)
    htmltools::tags$a(
      href = "#",
      class = "btn btn-outline-primary w-100",
      target = "_blank",
      "Suggest a Package"
    )
  )
}

#' Sidebar Module — Server
#'
#' Returns a list of reactive values representing the current state of all
#' sidebar filter and sort controls. The parent server uses these to filter
#' and sort the package data before passing it to the browse module.
#'
#' @param id Module namespace ID.
#'
#' @return A list of reactive expressions:
#'   - `category`: selected category (or "All")
#'   - `cran_status`: selected CRAN status (or "All")
#'   - `license`: selected license (or "All")
#'   - `essential_only`: logical
#'   - `sort_by`: selected sort option string
#'
#' @noRd
mod_sidebar_server <- function(id) {
  shiny::moduleServer(id, function(input, output, session) {
    # Return all filter/sort values as reactives for the parent server
    list(
      category       = shiny::reactive(input$category),
      cran_status    = shiny::reactive(input$cran_status),
      license        = shiny::reactive(input$license),
      essential_only = shiny::reactive(input$essential_only),
      sort_by        = shiny::reactive(input$sort_by)
    )
  })
}

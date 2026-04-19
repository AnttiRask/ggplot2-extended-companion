# =============================================================================
# mod_sidebar.R
#
# Shiny module for the sidebar filter controls. Provides category dropdown
# (with display names), CRAN status radio buttons, license dropdown,
# featured-only checkbox, recently added/updated checkboxes, and package
# submission link.
#
# v1.2 (M0): featured_only input replaces the v1.1 legacy-name input; label
# reads "Featured in the Book" per SPEC-v1.2 §3.2, §5.7.
#
# Part of production-fix-polish: Sidebar Overhaul
# =============================================================================

#' Sidebar Module -- UI
#'
#' Renders all sidebar filter controls. Category dropdown uses display names
#' from categories.csv. Sorting is handled by reactable column headers, not
#' a sidebar dropdown.
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

  # Build category choices using display names.
  # selectInput needs c("Label" = "value") — names are shown, values returned.
  # So we need c("Animation" = "animation", "Geoms" = "geoms", ...)
  display_names <- get_category_display_names()
  available <- categories[categories %in% names(display_names)]
  # Create named vector: display name as name (shown), technical name as value (returned)
  tech_to_display <- display_names[available]
  display_to_tech <- stats::setNames(names(tech_to_display), unname(tech_to_display))
  category_choices <- c("All" = "All", sort(display_to_tech))

  # Build license choices: "All" + sorted unique licenses
  license_choices <- c("All", sort(licenses))

  htmltools::tagList(
    # Category filter (display names, technical name as value)
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

    # Featured-in-the-book checkbox (v1.2 renamed the legacy input ID/label).
    # The label uses Title Case intentionally — matches sibling sidebar labels
    # ("Category", "CRAN Status", "License", "Recently Added"). The detail-card
    # badge and the browse-table tooltip use sentence case ("Featured in the
    # book") because they are phrases embedded in UI chrome, not form labels.
    # Keep all three casings as specified by SPEC-v1.2 §3.2 — do not unify.
    #
    # Tooltip (Designer Fix #2) disambiguates "featured in *what* book?" for
    # first-time visitors who have not opened the intro accordion. bslib's
    # tooltip attaches aria-describedby wiring so assistive tech announces
    # the clarification too, not just sighted mouse users.
    bslib::tooltip(
      shiny::checkboxInput(
        ns("featured_only"),
        label = "Featured in the Book",
        value = FALSE
      ),
      "Packages featured in the companion book 'ggplot2 extended'"
    ),

    # Recently Added checkbox
    shiny::checkboxInput(
      ns("recently_added"),
      label = "Recently Added",
      value = FALSE
    ),

    # Recently Updated checkbox
    shiny::checkboxInput(
      ns("recently_updated"),
      label = "Recently Updated",
      value = FALSE
    ),

    # Show Archived Packages checkbox (v1.1 — last checkbox position)
    shiny::checkboxInput(
      ns("show_archived"),
      label = "Show Archived Packages",
      value = FALSE
    ),

    # Divider
    htmltools::hr(),

    # Submit a package link (v1.1 — activated with Google Form URL)
    htmltools::tags$a(
      href = get_golem_config("google_form_url"),
      target = "_blank",
      rel = "noopener noreferrer",
      class = "btn btn-outline-primary w-100",
      "Suggest a Package"
    )
  )
}

#' Sidebar Module -- Server
#'
#' Returns a list of reactive values representing the current state of all
#' sidebar filter controls. The parent server uses these to filter the
#' package data before passing it to the browse module.
#'
#' @param id Module namespace ID.
#'
#' @return A list of reactive expressions:
#'   - `category`: selected category technical name (or "All")
#'   - `cran_status`: selected CRAN status (or "All")
#'   - `license`: selected license (or "All")
#'   - `featured_only`: logical (v1.2 renamed the legacy reactive name)
#'   - `recently_added`: logical
#'   - `recently_updated`: logical
#'   - `show_archived`: logical
#'
#' @noRd
mod_sidebar_server <- function(id) {
  shiny::moduleServer(id, function(input, output, session) {
    # Return all filter values as reactives for the parent server
    list(
      category         = shiny::reactive(input$category),
      cran_status      = shiny::reactive(input$cran_status),
      license          = shiny::reactive(input$license),
      featured_only    = shiny::reactive(input$featured_only),
      recently_added   = shiny::reactive(input$recently_added),
      recently_updated = shiny::reactive(input$recently_updated),
      show_archived    = shiny::reactive(input$show_archived)
    )
  })
}

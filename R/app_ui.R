# =============================================================================
# app_ui.R
#
# Main UI function for the ggplot2 Extended Companion app. Defines the bslib
# page_sidebar() layout with Bootstrap 5 dark theme, sidebar placeholder,
# and main content area placeholder.
#
# Part of Milestone 0: Project Scaffold
# =============================================================================

#' The application User-Interface
#'
#' Builds the main UI for the ggplot2 Extended Companion app using bslib's
#' page_sidebar() layout. Sets up the Bootstrap 5 dark theme with custom
#' colours and typography, a sidebar for filters (placeholder in M0), and
#' a main content area (placeholder in M0).
#'
#' @param request Internal parameter for `{shiny}`.
#'
#' @return A shiny tagList containing the app UI.
#'
#' @import shiny
#' @importFrom bslib bs_theme page_sidebar sidebar input_dark_mode font_google font_collection
#' @importFrom htmltools tags tagList
#' @noRd
app_ui <- function(request) {
  tagList(
    # Add external resources (CSS, favicon, meta tags)
    golem_add_external_resources(),

    # Main page layout
    bslib::page_sidebar(
      title = "ggplot2 extended (companion)",
      theme = app_theme(),
      window_title = "ggplot2 extended (companion)",

      # Dark/light mode toggle in the navbar
      bslib::input_dark_mode(id = "colour_mode", mode = "dark"),

      # Sidebar with filter controls (M4)
      sidebar = bslib::sidebar(
        title = "Filters",
        width = 300,
        # Dynamic sidebar content -- populated with data-driven choices
        # by the server via mod_sidebar_ui
        shiny::uiOutput("sidebar_controls")
      ),

      # Main content area
      tags$div(
        class = "container-fluid",

        # Header: collapsible intro accordion (M7)
        mod_header_ui("header"),

        # Browse view: package table (M3)
        shiny::conditionalPanel(
          condition = "!output.show_detail",
          mod_browse_ui("browse")
        ),

        # Detail view: full package info (M5)
        shiny::conditionalPanel(
          condition = "output.show_detail",
          mod_detail_ui("detail")
        ),

        # Footer: disclaimer, credits, links (M7)
        mod_footer_ui("footer")
      )
    )
  )
}

#' Create the bslib theme
#'
#' Builds a Bootstrap 5 theme using bslib::bs_theme() with the colour palette
#' and typography defined in SPEC section 7.
#'
#' @return A bslib theme object.
#'
#' @noRd
app_theme <- function() {
  bslib::bs_theme(
    version = 5,

    # Colour palette from SPEC section 7.
    # IMPORTANT: Do NOT set bg/fg here — that sets the BASE (light) theme,
    # and Bootstrap 5.3 auto-inverts it for dark mode, causing the modes
    # to be flipped. Instead, set dark-mode colours via body-bg-dark/
    # body-color-dark and let Bootstrap handle light mode defaults (white).
    primary  = "#C1272D",
    success  = "#22c55e",
    warning  = "#f59e0b",
    "body-bg-dark"    = "#191414",
    "body-color-dark" = "#FFFFFF",

    # Typography — Montserrat for headings (clean geometric sans-serif,
    # replaces Gotham which had unverified licensing)
    heading_font = bslib::font_collection(
      bslib::font_google("Montserrat"),
      bslib::font_google("Inter"),
      "sans-serif"
    ),
    base_font = bslib::font_collection(
      bslib::font_google("Inter"),
      "sans-serif"
    ),
    code_font = bslib::font_collection(
      bslib::font_google("Fira Code"),
      "Source Code Pro",
      "monospace"
    ),

    # Base font size: 1.0 = 16px Bootstrap default (SPEC section 7)
    font_scale = 1.0
  )
}

#' Add external resources to the app
#'
#' Bundles external CSS, JavaScript, and meta tags using golem's resource
#' management. Reads files from `inst/app/www/`.
#'
#' @return A tagList of HTML head elements.
#'
#' @importFrom golem add_resource_path bundle_resources
#' @noRd
golem_add_external_resources <- function() {
  golem::add_resource_path("www", app_sys("app/www"))

  tags$head(
    golem::bundle_resources(
      path = app_sys("app/www"),
      app_title = "ggplot2 extended (companion)"
    ),

    # Meta tags for AI agent compatibility (SPEC section 8)
    tags$meta(
      name = "description",
      content = paste(
        "Searchable directory of 455+ ggplot2 extension packages",
        "with download statistics and code examples."
      )
    ),
    tags$meta(property = "og:title", content = "ggplot2 extended (companion)"),
    tags$meta(
      property = "og:description",
      content = paste(
        "Searchable directory of 455+ ggplot2 extension packages",
        "with download statistics and code examples."
      )
    ),
    tags$meta(property = "og:type", content = "website")
  )
}

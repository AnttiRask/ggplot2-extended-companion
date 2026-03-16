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
      title = "ggplot2 Extended Companion",
      theme = app_theme(),
      window_title = "ggplot2 Extended Companion",

      # Dark/light mode toggle in the navbar
      bslib::input_dark_mode(id = "colour_mode", mode = "dark"),

      # Sidebar with placeholder content
      sidebar = bslib::sidebar(
        title = "Filters",
        width = 300,
        # Placeholder — filter controls will be added in M4
        tags$p(
          class = "text-muted",
          "Filter controls coming soon."
        )
      ),

      # Main content area with placeholder
      tags$div(
        class = "container-fluid",
        tags$h2("Welcome to the ggplot2 Extended Companion"),
        tags$p(
          class = "lead text-muted",
          "A searchable, filterable directory of ggplot2 extension packages."
        ),
        tags$p(
          class = "text-muted",
          "The package table and detail views will be added in upcoming milestones."
        )
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

    # Colour palette from SPEC section 7
    bg       = "#191414",
    fg       = "#FFFFFF",
    primary  = "#C1272D",
    success  = "#22c55e",
    warning  = "#f59e0b",

    # Typography
    heading_font = bslib::font_collection(
      "Gotham",
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

    # Base font size
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
      app_title = "ggplot2 Extended Companion"
    ),

    # Meta tags for AI agent compatibility (SPEC section 8)
    tags$meta(
      name = "description",
      content = paste(
        "Searchable directory of 455+ ggplot2 extension packages",
        "with download statistics and code examples."
      )
    ),
    tags$meta(property = "og:title", content = "ggplot2 Extended Companion"),
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

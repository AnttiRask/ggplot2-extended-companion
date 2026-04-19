# =============================================================================
# app_ui.R
#
# Main UI function for the ggplot2 extended (companion) app.
#
# v1.2 (M1): per-view layout swap (SPEC-v1.2 §5.1). app_ui() no longer
# renders a bslib page wrapper directly. Instead, it exposes a single
# uiOutput("main_page") slot, and the server-side output$main_page
# dispatches either render_browse_page() (page_sidebar with filters)
# or render_detail_page() (page_fillable, no sidebar) based on
# selected_package(). The two helpers below return complete pages,
# not fragments — see design.md Decision §3.
#
# Part of Milestone 0: Project Scaffold (original)
#   + Milestone 1 v1.2: Per-view layout + sidebar defaults
# =============================================================================

#' The application User-Interface
#'
#' Returns the top-level tag list: external resources (CSS, favicon, meta
#' tags) plus a single uiOutput("main_page") slot. The server dispatches
#' render_browse_page() or render_detail_page() into that slot based on
#' whether a package is selected. See SPEC-v1.2 §5.1.
#'
#' @param request Internal parameter for `{shiny}`.
#'
#' @return A shiny tagList containing the app UI.
#'
#' @import shiny
#' @importFrom bslib bs_theme page_sidebar page_fillable sidebar input_dark_mode font_google font_collection
#' @importFrom htmltools tags tagList
#' @noRd
app_ui <- function(request) {
  tagList(
    # Add external resources (CSS, favicon, meta tags)
    golem_add_external_resources(),

    # Main page slot -- filled by output$main_page, which dispatches
    # render_browse_page() or render_detail_page() based on
    # selected_package(). See app_server.R and SPEC-v1.2 §5.1.
    shiny::uiOutput("main_page")
  )
}

#' Render the browse-view page wrapper
#'
#' Returns a complete `bslib::page_sidebar()` for the browse view: the
#' filters sidebar (left), the header accordion, the package table, and
#' the footer. Dispatched by `output$main_page` in `app_server()` when
#' no package is selected. See SPEC-v1.2 §5.1 for the per-view layout
#' contract.
#'
#' The sidebar opens by default on desktop (≥992 px) and closes by
#' default on mobile (<992 px). bslib auto-inserts a hamburger toggle
#' on mobile when the breakpoint is "closed" (SPEC-v1.2 §5.3).
#'
#' @return A complete bslib page object (not a fragment).
#'
#' @importFrom bslib page_sidebar sidebar input_dark_mode
#' @noRd
render_browse_page <- function() {
  bslib::page_sidebar(
    title = "ggplot2 extended (companion)",
    window_title = "ggplot2 extended (companion)",
    theme = app_theme(),

    # Dark/light mode toggle in the navbar (SPEC-v1.2 §5.4 changes
    # deferred to a later milestone per OpenSpec design.md §2).
    bslib::input_dark_mode(id = "colour_mode", mode = "dark"),

    # Filters sidebar -- open on desktop, closed on mobile with a
    # bslib-provided hamburger toggle (SPEC-v1.2 §5.3).
    sidebar = bslib::sidebar(
      id = "filters_sidebar",
      title = "Filters",
      width = 300,
      open = list(desktop = "open", mobile = "closed"),
      # Dynamic sidebar content -- populated with data-driven choices
      # by the server via mod_sidebar_ui.
      shiny::uiOutput("sidebar_controls")
    ),

    # Main content area
    tags$div(
      class = "container-fluid",

      # Header: intro accordion
      mod_header_ui("header"),

      # Spacer between header and content
      htmltools::tags$div(class = "mb-3"),

      # Browse view: package table
      mod_browse_ui("browse"),

      # Footer: disclaimer, credits, links
      mod_footer_ui("footer")
    )
  )
}

#' Render the detail-view page wrapper
#'
#' Returns a complete `bslib::page_fillable()` for the detail view: no
#' sidebar, full-width content (header, detail card stack, footer).
#' Dispatched by `output$main_page` in `app_server()` when a package
#' is selected. See SPEC-v1.2 §5.1 for the per-view layout contract.
#'
#' The detail view intentionally drops the sidebar entirely — unlike
#' the v1.1 baseline, no sidebar element is present in the DOM when
#' a package is selected. The full viewport width is available for
#' the detail card stack (SPEC-v1.2 §9 M1 DoD).
#'
#' @return A complete bslib page object (not a fragment).
#'
#' @importFrom bslib page_fillable input_dark_mode
#' @noRd
render_detail_page <- function() {
  bslib::page_fillable(
    title = "ggplot2 extended (companion)",
    window_title = "ggplot2 extended (companion)",
    theme = app_theme(),

    # Dark/light mode toggle in the navbar (same as browse view —
    # SPEC-v1.2 §5.4 changes deferred per OpenSpec design.md §2).
    bslib::input_dark_mode(id = "colour_mode", mode = "dark"),

    # Main content area -- no sidebar slot.
    tags$div(
      class = "container-fluid",

      # Header: intro accordion
      mod_header_ui("header"),

      # Spacer between header and content
      htmltools::tags$div(class = "mb-3"),

      # Detail view: full package info
      mod_detail_ui("detail"),

      # Footer: disclaimer, credits, links
      mod_footer_ui("footer")
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

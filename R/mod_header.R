# =============================================================================
# mod_header.R
#
# Shiny module for the introductory header. A collapsible accordion panel
# above the recent lists, collapsed by default for returning users.
#
# Part of Milestone 7: Recently Added / Updated & Header
# =============================================================================

#' Header Module -- UI
#'
#' Renders a collapsible accordion with introductory text about ggplot2
#' extensions. Collapsed by default so returning users can skip it.
#'
#' @param id Module namespace ID.
#' @return A bslib accordion panel.
#' @noRd
mod_header_ui <- function(id) {
  ns <- shiny::NS(id)

  bslib::accordion(
    id = ns("intro_accordion"),
    open = FALSE,  # Collapsed by default
    bslib::accordion_panel(
      title = "What are ggplot2 extensions?",
      htmltools::tagList(
        htmltools::tags$p(
          "ggplot2 extensions are R packages that build on top of ggplot2 to add",
          "new geoms, stats, scales, themes, and other capabilities. They let you",
          "create specialised visualisations -- from animated plots to network",
          "diagrams to maps -- while staying within the familiar ggplot2 grammar."
        ),
        htmltools::tags$p(
          "This directory catalogues over 450 extension packages with download",
          "statistics, metadata, and links to help you discover the right tool",
          "for your visualisation needs."
        ),
        htmltools::tags$p(
          htmltools::tags$a(
            href = "https://exts.ggplot2.tidyverse.org/",
            target = "_blank",
            "ggplot2 extensions gallery"
          ),
          " | ",
          htmltools::tags$a(
            href = "https://ggplot2.tidyverse.org/",
            target = "_blank",
            "ggplot2 documentation"
          )
        )
      )
    )
  )
}

#' Header Module -- Server
#'
#' No server logic needed for the header -- it's purely static content.
#'
#' @param id Module namespace ID.
#' @noRd
mod_header_server <- function(id) {
  shiny::moduleServer(id, function(input, output, session) {
    # Static content -- no server logic required
  })
}

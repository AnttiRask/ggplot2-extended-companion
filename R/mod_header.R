# =============================================================================
# mod_header.R
#
# Shiny module for the introductory header. Plain text (always visible)
# with a brief description and links.
#
# Part of production-fix-polish: Header & Footer Content Updates
# =============================================================================

#' Header Module -- UI
#'
#' Renders introductory text about ggplot2 extensions as plain paragraphs
#' (always visible, no collapsible accordion).
#'
#' @param id Module namespace ID.
#' @return An htmltools tagList with intro text.
#' @noRd
mod_header_ui <- function(id) {
  ns <- shiny::NS(id)

  htmltools::tagList(
    htmltools::tags$p(
      "ggplot2 extensions are R packages that build on top of ggplot2 to add",
      "new geoms, stats, scales, themes, and other capabilities. They let you",
      "create specialised visualisations \u2014 from animated plots to network",
      "diagrams to maps \u2014 while staying within the familiar ggplot2 grammar."
    ),
    htmltools::tags$p(
      "This directory catalogues over 450 extension packages with download",
      "statistics, metadata, and links to help you discover the right tool",
      "for your visualisation needs."
    ),
    htmltools::tags$p(
      htmltools::tags$a(
        href = "https://ggplot2-extended-book.com/",
        target = "_blank",
        "ggplot2 extended (the book)"
      ),
      " | ",
      htmltools::tags$a(
        href = "https://ggplot2.tidyverse.org/",
        target = "_blank",
        "ggplot2 documentation"
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

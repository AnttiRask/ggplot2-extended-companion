# =============================================================================
# mod_footer.R
#
# Shiny module for the app footer. Displays disclaimer, data freshness
# timestamp, submission link, credits, and cross-links.
#
# Part of Milestone 7: Recently Added / Updated & Header
# =============================================================================

#' Footer Module -- UI
#'
#' Renders the full-width footer with disclaimer, credits, and links
#' as defined in SPEC section 5.7.
#'
#' @param id Module namespace ID.
#' @return A tagList with footer content.
#' @noRd
mod_footer_ui <- function(id) {
  ns <- shiny::NS(id)

  htmltools::tags$footer(
    class = "mt-4 pt-4 border-top",
    htmltools::tags$div(
      class = "container-fluid",

      # Data freshness timestamp (dynamic from metadata)
      shiny::uiOutput(ns("data_freshness")),

      # Disclaimer
      htmltools::tags$p(
        class = "text-muted small",
        "If you have concerns about information presented on this site",
        "(licensing, metadata accuracy, etc.), please reach out via email at",
        htmltools::tags$a(href = "mailto:antti@youcanbeapirate.com", "antti@youcanbeapirate.com"),
        "to have it corrected or removed."
      ),

      # Submission link
      htmltools::tags$p(
        class = "text-muted small",
        "Know a ggplot2 extension we're missing? ",
        htmltools::tags$a(
          href = "#",
          target = "_blank",
          "Submit it here"
        ),
        "."
      ),

      # Links
      htmltools::tags$p(
        class = "text-muted small",
        htmltools::tags$a(
          href = "https://exts.ggplot2.tidyverse.org/",
          target = "_blank",
          "ggplot2 extensions gallery"
        ),
        " | ",
        htmltools::tags$a(
          href = "https://youcanbeapirate.com",
          target = "_blank",
          "youcanbeapirate.com"
        )
      ),

      # Machine-readable data link (SPEC section 8)
      htmltools::tags$p(
        class = "text-muted small",
        "Machine-readable data: ",
        htmltools::tags$a(
          href = "data/packages.json",
          target = "_blank",
          "packages.json"
        )
      ),

      # Credits
      htmltools::tags$p(
        class = "text-muted small",
        "Created by ",
        htmltools::tags$a(
          href = "https://youcanbeapirate.com",
          target = "_blank",
          "Antti Rask"
        ),
        " | youcanbeapirate.com"
      )
    )
  )
}

#' Footer Module -- Server
#'
#' Loads pipeline metadata and displays the "Data last updated" timestamp.
#'
#' @param id Module namespace ID.
#' @noRd
mod_footer_server <- function(id) {
  shiny::moduleServer(id, function(input, output, session) {
    output$data_freshness <- shiny::renderUI({
      metadata <- load_metadata()

      if (is.null(metadata)) {
        return(htmltools::tags$p(
          class = "text-muted small",
          htmltools::tags$em("Data freshness information not available.")
        ))
      }

      # Use the most recent last_run timestamp
      last_run <- max(metadata$last_run, na.rm = TRUE)

      htmltools::tags$p(
        class = "text-muted small",
        htmltools::tags$strong("Package data last updated: "),
        last_run
      )
    })
  })
}

# =============================================================================
# mod_recent.R
#
# Shiny module for the "Recently Added" and "Recently Updated" package lists.
# Displays two horizontally arranged cards above the main table.
#
# Part of Milestone 7: Recently Added / Updated & Header
# =============================================================================

#' Recent Module — UI
#'
#' @param id Module namespace ID.
#' @return A tagList with two horizontally arranged cards.
#' @noRd
mod_recent_ui <- function(id) {
  ns <- shiny::NS(id)

  bslib::layout_column_wrap(
    width = 1 / 2,
    bslib::card(
      bslib::card_header("Recently Added"),
      bslib::card_body(
        shiny::uiOutput(ns("recently_added"))
      )
    ),
    bslib::card(
      bslib::card_header("Recently Updated"),
      bslib::card_body(
        shiny::uiOutput(ns("recently_updated"))
      )
    )
  )
}

#' Recent Module — Server
#'
#' @param id Module namespace ID.
#' @param app_data Reactive containing the full package dataset.
#' @param on_select Callback function called with package_name when clicked.
#' @noRd
mod_recent_server <- function(id, app_data, on_select) {
  shiny::moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Recently Added list
    output$recently_added <- shiny::renderUI({
      data <- app_data()
      if (is.null(data)) return(NULL)

      recent <- get_recently_added(data, n = 10)
      build_recent_list(recent, "date_added", ns, label_col = NULL)
    })

    # Recently Updated list
    output$recently_updated <- shiny::renderUI({
      data <- app_data()
      if (is.null(data)) return(NULL)

      recent <- get_recently_updated(data, n = 10)
      build_recent_list(recent, "update_date", ns, label_col = "update_source")
    })

    # Handle package clicks from the recent lists
    shiny::observeEvent(input$select_pkg, {
      on_select(input$select_pkg)
    })
  })
}

#' Build a compact list of recent packages
#'
#' @param data Tibble with package data (must include package_name).
#' @param date_col Name of the date column to display.
#' @param ns Module namespace function.
#' @param label_col Optional column name for a source label (e.g., "CRAN" or "GitHub").
#' @return A tagList of clickable package entries.
#' @noRd
build_recent_list <- function(data, date_col, ns, label_col = NULL) {
  entries <- lapply(seq_len(nrow(data)), function(i) {
    pkg_name <- data$package_name[i]
    date_val <- data[[date_col]][i]
    date_str <- if (is.na(date_val)) "\u2014" else format(as.Date(date_val), "%Y-%m-%d")

    # Optional source label (e.g., "CRAN" or "GitHub")
    label <- if (!is.null(label_col) && !is.na(data[[label_col]][i])) {
      htmltools::span(
        class = "badge bg-secondary ms-1",
        data[[label_col]][i]
      )
    }

    htmltools::tags$div(
      class = "d-flex justify-content-between align-items-center py-1 border-bottom",
      htmltools::tags$a(
        class = "package-link",
        href = "#",
        onclick = sprintf(
          "Shiny.setInputValue('%s', '%s', {priority: 'event'})",
          ns("select_pkg"), pkg_name
        ),
        pkg_name
      ),
      htmltools::tags$span(
        class = "text-muted small",
        date_str,
        label
      )
    )
  })

  htmltools::tagList(entries)
}

# =============================================================================
# run_app.R
#
# Entry point function for the ggplot2 Extended Companion app. Wraps the
# golem app launch with golem_options for configuration.
#
# Part of Milestone 0: Project Scaffold
# =============================================================================

#' Run the Shiny Application
#'
#' Launches the ggplot2 Extended Companion Shiny app. This is the primary
#' entry point for running the app, using golem's configuration system.
#'
#' @param ... Additional golem options. Can be accessed at runtime with
#'   `golem::get_golem_options()`.
#'
#' @return A Shiny app object.
#'
#' @export
#' @importFrom shiny shinyApp
#' @importFrom golem with_golem_options
run_app <- function(...) {
  golem::with_golem_options(
    app = shiny::shinyApp(
      ui     = app_ui,
      server = app_server
    ),
    golem_opts = list(...)
  )
}

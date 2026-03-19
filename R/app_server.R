# =============================================================================
# app_server.R
#
# Main server function for the ggplot2 Extended Companion app. Loads package
# data at startup from Parquet files and wires up Shiny modules.
#
# Part of Milestone 3: Data Loading & Browse Table
# =============================================================================

#' The application server-side logic
#'
#' Loads package data at startup from Parquet files, then initialises
#' the browse module. Data is loaded once and shared across modules
#' via reactive values.
#'
#' @param input,output,session Internal parameters for `{shiny}`.
#'
#' @import shiny
#' @noRd
app_server <- function(input, output, session) {
  # -------------------------------------------------------------------------
  # Data loading (once at startup)
  # -------------------------------------------------------------------------

  # Load all package + download data from Parquet files
  app_data_raw <- load_app_data()

  # Wrap in reactive for module consumption
  # In M4 this will become a filtered reactive; for now it's the full dataset
  app_data <- reactive({
    app_data_raw
  })

  # -------------------------------------------------------------------------
  # Module server calls
  # -------------------------------------------------------------------------

  # Browse table module (M3)
  selected_package <- mod_browse_server("browse", app_data)

  # Future modules:
  # M4: Sidebar filters module
  # M5: Detail view module (will use selected_package reactive)
  # M7: Recent packages, header, footer modules
}

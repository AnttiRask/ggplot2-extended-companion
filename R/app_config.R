# =============================================================================
# app_config.R
#
# Golem configuration helpers. Provides utility functions for accessing
# package resources and reading configuration values.
#
# Part of Milestone 0: Project Scaffold
# =============================================================================

#' Access files in the installed package directory
#'
#' Returns the path to a file within the installed package's `inst/` directory.
#' This is the golem convention for accessing bundled resources (CSS, data, etc.).
#'
#' @param ... Character vectors specifying subdirectories and file name
#'   (e.g., "app", "www", "styles.css").
#'
#' @return A character string with the full file path.
#'
#' @noRd
app_sys <- function(...) {
  system.file(..., package = "ggplot2.extended.companion")
}

#' Read app configuration value
#'
#' Reads a value from the golem configuration file (`inst/golem-config.yml`).
#' Falls back to the default configuration if the requested value or file
#' is not found.
#'
#' @param value The configuration key to look up.
#' @param config The configuration environment (default: `Sys.getenv("GOLEM_CONFIG_ACTIVE", "default")`).
#' @param use_parent Logical. If TRUE, merge with parent configurations.
#'
#' @return The configuration value, or NULL if not found.
#'
#' @noRd
get_golem_config <- function(
  value,
  config = Sys.getenv("GOLEM_CONFIG_ACTIVE", "default"),
  use_parent = TRUE
) {
  config::get(
    value  = value,
    config = config,
    file   = app_sys("golem-config.yml"),
    use_parent = use_parent
  )
}

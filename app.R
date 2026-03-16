# =============================================================================
# app.R
#
# Golem entry point. Loads the package and launches the app.
# This file is used by deployment platforms (RStudio Connect, ShinyApps.io)
# and Docker containers.
#
# Part of Milestone 0: Project Scaffold
# =============================================================================

# Load all package functions
pkgload::load_all(
  export_all = FALSE,
  helpers    = FALSE,
  attach_testthat = FALSE
)

# Launch the app
run_app()

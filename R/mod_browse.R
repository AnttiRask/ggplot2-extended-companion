# =============================================================================
# mod_browse.R
#
# Shiny module for the package browsing table. Displays a searchable, sortable
# reactable table of all ggplot2 extension packages with columns for name,
# description, category, license, downloads, version, and dates.
#
# Part of Milestone 3: Data Loading & Browse Table
# =============================================================================

#' Browse Module -- UI
#'
#' Renders the main package browsing table using reactable. Includes
#' client-side search and column sorting.
#'
#' @param id Module namespace ID.
#'
#' @return A tagList with the reactable output.
#'
#' @noRd
mod_browse_ui <- function(id) {
  ns <- shiny::NS(id)

  htmltools::tagList(
    # Loading spinner shown until reactable renders
    shiny::conditionalPanel(
      condition = sprintf("!output['%s']", ns("package_table")),
      ns = identity,
      htmltools::tags$div(
        class = "text-center py-5",
        htmltools::tags$div(class = "spinner-border text-primary"),
        htmltools::tags$p(class = "text-muted mt-2", "Loading packages...")
      )
    ),
    reactable::reactableOutput(ns("package_table"))
  )
}

#' Browse Module -- Server
#'
#' Builds and renders the reactable package table. Receives the dataset
#' as a reactive value from the parent server, enabling external filtering
#' (M4) to update the table by changing the reactive data.
#'
#' @param id Module namespace ID.
#' @param app_data Reactive containing the package dataset (tibble with
#'   package and download columns).
#'
#' @return A reactive value holding the currently selected package name
#'   (or NULL if no package is selected). Used by the detail view (M5).
#'
#' @noRd
mod_browse_server <- function(id, app_data) {
  shiny::moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Reactive value to track the selected package (for detail view in M5)
    selected_package <- shiny::reactiveVal(NULL)

    # Render the reactable table
    output$package_table <- reactable::renderReactable({
      data <- app_data()

      # Guard against NULL or empty data — differentiate between
      # "data not loaded" and "no results match filters".
      # Empty-state tables use the same theme as the main table so
      # text colour matches the current dark/light mode.
      if (is.null(data)) {
        return(reactable::reactable(
          data.frame(Message = "Package data is currently unavailable. Please try refreshing the page."),
          columns = list(Message = reactable::colDef(align = "center")),
          theme = browse_theme()
        ))
      }
      if (nrow(data) == 0) {
        return(reactable::reactable(
          data.frame(
            Message = paste(
              "No packages match your current filters.",
              "Try adjusting your category, CRAN status, or license selections,",
              "or clearing the search."
            )
          ),
          columns = list(Message = reactable::colDef(align = "center")),
          theme = browse_theme()
        ))
      }

      build_package_table(data, ns)
    })

    # Listen for package name clicks from JavaScript
    shiny::observeEvent(input$selected_pkg, {
      selected_package(input$selected_pkg)
    })

    # Return the selected package reactive for use by detail view (M5)
    return(selected_package)
  })
}

#' Build the reactable package table
#'
#' Constructs the reactable table with 9 columns matching SPEC section 5.2:
#' Name, Description, Category, License, Downloads (30d), Downloads (All),
#' CRAN Version, CRAN Published, GitHub Updated.
#'
#' @param data A tibble with package and download data.
#' @param ns The module's namespace function (for JavaScript callbacks).
#'
#' @return A reactable object.
#'
#' @noRd
build_package_table <- function(data, ns) {
  # Build the full column definitions list, then filter to only columns

  # that exist in the data. This prevents reactable errors when the parquet
  # is missing v1.1 columns (e.g., version, is_archived, github_*) during
  # transitional pipeline runs.
  all_columns <- list(
      # Name -- clickable, bold, 150px
      package_name = reactable::colDef(
        name = "Name",
        minWidth = 150,
        cell = function(value, index) {
          # Bold text, styled as clickable link
          # Essential packages get a star badge, archived get a folder badge
          is_essential <- data$is_essential[index]
          is_archived <- if ("is_archived" %in% names(data)) data$is_archived[index] else FALSE

          essential_badge <- if (isTRUE(is_essential)) {
            htmltools::span(class = "badge-essential", "\u2B50 ")
          } else {
            NULL
          }

          archived_badge <- if (isTRUE(is_archived)) {
            htmltools::span(class = "badge-archived", "\U0001F4C1 ")
          } else {
            NULL
          }

          htmltools::tagList(
            essential_badge,
            archived_badge,
            htmltools::tags$a(
              class = "package-link",
              href = "#",
              onclick = sprintf(
                "Shiny.setInputValue('%s', '%s', {priority: 'event'})",
                ns("selected_pkg"), value
              ),
              value
            )
          )
        }
      ),

      # Title -- flex width, truncated, sortable
      title = reactable::colDef(
        name = "Title",
        minWidth = 200,
        sortable = TRUE,
        cell = function(value) {
          if (is.na(value)) return("\u2014")
          # Truncate to ~100 characters with ellipsis
          if (nchar(value) > 100) {
            paste0(substr(value, 1, 97), "...")
          } else {
            value
          }
        }
      ),

      # Category -- all badges with category-specific colours, sortable
      categories = reactable::colDef(
        name = "Category",
        minWidth = 180,
        sortable = TRUE,
        cell = function(value) {
          if (is.na(value) || value == "na") return("\u2014")
          cats <- strsplit(value, "\\|")[[1]]
          # Show ALL categories as separate coloured badges
          badges <- lapply(cats, build_category_badge)
          htmltools::tags$div(
            class = "d-flex flex-wrap gap-1",
            badges
          )
        }
      ),

      # License -- plain text, 100px, sortable
      license = reactable::colDef(
        name = "License",
        minWidth = 100,
        sortable = TRUE,
        cell = function(value) {
          if (is.na(value)) "\u2014" else value
        }
      ),

      # Downloads (30d) -- numeric, comma-formatted, 100px, right-aligned
      downloads_30d = reactable::colDef(
        name = "Downloads (30d)",
        minWidth = 100,
        align = "right",
        cell = function(value) {
          if (is.na(value)) "\u2014" else format(value, big.mark = ",")
        }
      ),

      # Downloads (All) -- numeric, comma-formatted, 100px, right-aligned
      downloads_all = reactable::colDef(
        name = "Downloads (All)",
        minWidth = 100,
        align = "right",
        cell = function(value) {
          if (is.na(value)) "\u2014" else format(value, big.mark = ",")
        }
      ),

      # Version -- source-agnostic (CRAN or GitHub), 90px, not sortable
      # v1.1: renamed from "CRAN Version", uses derived version field
      version = reactable::colDef(
        name = "Version",
        minWidth = 90,
        sortable = FALSE,
        cell = function(value) {
          if (is.na(value)) "\u2014" else value
        }
      ),

      # cran_version hidden — version column shows derived value instead
      cran_version = reactable::colDef(show = FALSE),

      # CRAN Published -- date, 110px
      cran_published = reactable::colDef(
        name = "CRAN Published",
        minWidth = 110,
        cell = function(value) {
          if (is.na(value)) "\u2014" else format(as.Date(value), "%Y-%m-%d")
        }
      ),

      # GitHub Updated -- date, 110px
      github_updated = reactable::colDef(
        name = "GitHub Updated",
        minWidth = 110,
        cell = function(value) {
          if (is.na(value)) "\u2014" else format(as.Date(value), "%Y-%m-%d")
        }
      ),

      # Hidden columns -- present in data but not displayed in table
      description = reactable::colDef(show = FALSE),
      is_essential = reactable::colDef(show = FALSE),
      is_archived = reactable::colDef(show = FALSE),
      github_title = reactable::colDef(show = FALSE),
      github_description = reactable::colDef(show = FALSE),
      github_license = reactable::colDef(show = FALSE),
      github_maintainer = reactable::colDef(show = FALSE),
      github_version = reactable::colDef(show = FALSE),
      on_cran = reactable::colDef(show = FALSE),
      has_vignettes = reactable::colDef(show = FALSE),
      maintainer = reactable::colDef(show = FALSE),
      website_url = reactable::colDef(show = FALSE),
      repo_url = reactable::colDef(show = FALSE),
      cran_url = reactable::colDef(show = FALSE),
      manual_url = reactable::colDef(show = FALSE),
      vignettes_url = reactable::colDef(show = FALSE),
      date_added = reactable::colDef(show = FALSE),
      last_checked = reactable::colDef(show = FALSE),
      notes = reactable::colDef(show = FALSE),
      downloads_7d = reactable::colDef(show = FALSE),
      downloads_365d = reactable::colDef(show = FALSE),
      recently_added = reactable::colDef(show = FALSE),
      recently_updated = reactable::colDef(show = FALSE)
    )

  # Filter to only columns that exist in the data
  columns <- all_columns[names(all_columns) %in% names(data)]

  reactable::reactable(
    data,
    columns = columns,

    # Table options
    searchable = TRUE,
    pagination = TRUE,
    defaultPageSize = 25,
    striped = TRUE,
    highlight = TRUE,
    compact = TRUE,
    defaultSorted = list(package_name = "asc"),

    theme = browse_theme()
  )
}

#' Reactable theme for the browse table
#'
#' Uses inherit and neutral rgba() values so the table works in both
#' dark and light modes. Shared between the main table and empty-state
#' tables to ensure consistent text colour.
#'
#' @return A reactableTheme object.
#' @noRd
browse_theme <- function() {
  reactable::reactableTheme(
    color = "inherit",
    backgroundColor = "transparent",
    borderColor = "rgba(128, 128, 128, 0.2)",
    headerStyle = list(borderBottomColor = "rgba(128, 128, 128, 0.3)"),
    searchInputStyle = list(
      backgroundColor = "transparent",
      color = "inherit",
      border = "1px solid rgba(128, 128, 128, 0.3)"
    ),
    paginationStyle = list(color = "inherit"),
    pageButtonHoverStyle = list(backgroundColor = "rgba(128, 128, 128, 0.1)"),
    pageButtonActiveStyle = list(backgroundColor = "rgba(193, 39, 45, 0.2)")
  )
}

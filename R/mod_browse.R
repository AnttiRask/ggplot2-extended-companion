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
      # "data not loaded" and "no results match filters"
      if (is.null(data)) {
        return(reactable::reactable(
          data.frame(Message = "Package data is currently unavailable. Please try refreshing the page."),
          columns = list(Message = reactable::colDef(align = "center"))
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
          columns = list(Message = reactable::colDef(align = "center"))
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
  reactable::reactable(
    data,
    columns = list(
      # Name -- clickable, bold, 150px
      package_name = reactable::colDef(
        name = "Name",
        minWidth = 150,
        cell = function(value, index) {
          # Bold text, styled as clickable link
          # Essential packages get a star badge
          is_essential <- data$is_essential[index]
          essential_badge <- if (isTRUE(is_essential)) {
            htmltools::span(class = "badge-essential", "\u2B50 ")
          } else {
            NULL
          }

          htmltools::tagList(
            essential_badge,
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

      # Description -- flex width, truncated, not sortable
      description = reactable::colDef(
        name = "Description",
        minWidth = 200,
        sortable = FALSE,
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

      # Category -- badges, 140px, not sortable
      categories = reactable::colDef(
        name = "Category",
        minWidth = 140,
        sortable = FALSE,
        cell = function(value) {
          if (is.na(value) || value == "na") return("\u2014")
          cats <- strsplit(value, "\\|")[[1]]
          # Show first category as badge, "+N" if multiple
          first_badge <- htmltools::span(
            class = "badge-category",
            gsub("_", " ", cats[1])
          )
          if (length(cats) > 1) {
            htmltools::tagList(
              first_badge,
              htmltools::span(
                class = "text-muted",
                style = "margin-left: 4px; font-size: 0.8em;",
                paste0("+", length(cats) - 1)
              )
            )
          } else {
            first_badge
          }
        }
      ),

      # License -- plain text, 100px, not sortable
      license = reactable::colDef(
        name = "License",
        minWidth = 100,
        sortable = FALSE,
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

      # CRAN Version -- 90px, not sortable
      cran_version = reactable::colDef(
        name = "CRAN Version",
        minWidth = 90,
        sortable = FALSE,
        cell = function(value) {
          if (is.na(value)) "\u2014" else value
        }
      ),

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
      is_essential = reactable::colDef(show = FALSE),
      on_cran = reactable::colDef(show = FALSE),
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
      downloads_365d = reactable::colDef(show = FALSE)
    ),

    # Table options
    searchable = TRUE,
    pagination = TRUE,
    defaultPageSize = 25,
    striped = TRUE,
    highlight = TRUE,
    compact = TRUE,
    defaultSorted = list(package_name = "asc"),

    # Theme using inherit and neutral rgba() values so the table works
    # in both dark and light modes without hardcoding colours
    theme = reactable::reactableTheme(
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
  )
}

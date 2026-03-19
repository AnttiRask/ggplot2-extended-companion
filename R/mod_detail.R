# =============================================================================
# mod_detail.R
#
# Shiny module for the package detail view. Displays full metadata for a
# single selected package: header card, links card, download statistics
# (value boxes), and version info. Replaces the browse table when a
# package is selected.
#
# Part of Milestone 5: Package Detail View
# =============================================================================

#' Detail Module -- UI
#'
#' Placeholder UI for the detail view. Content is rendered dynamically
#' by the server based on the selected package.
#'
#' @param id Module namespace ID.
#'
#' @return A tagList with uiOutput for dynamic detail content.
#'
#' @noRd
mod_detail_ui <- function(id) {
  ns <- shiny::NS(id)

  htmltools::tagList(
    shiny::uiOutput(ns("detail_content"))
  )
}

#' Detail Module -- Server
#'
#' Renders the full detail view for the selected package. Looks up package
#' data from the full dataset by package_name and builds all detail cards.
#'
#' @param id Module namespace ID.
#' @param selected_package Reactive value holding the selected package name
#'   (or NULL for browse view).
#' @param app_data Reactive containing the full package dataset.
#' @param examples_data Reactive containing examples data (tibble or NULL).
#' @param on_back Callback function to execute when the back button is clicked
#'   (clears selected_package to return to browse view).
#'
#' @noRd
mod_detail_server <- function(id, selected_package, app_data, examples_data = reactive(NULL), on_back) {
  shiny::moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Render detail content when a package is selected
    output$detail_content <- shiny::renderUI({
      pkg_name <- selected_package()
      if (is.null(pkg_name)) return(NULL)

      data <- app_data()
      if (is.null(data)) return(NULL)

      # Look up the selected package
      pkg <- data[data$package_name == pkg_name, ]
      if (nrow(pkg) == 0) {
        return(htmltools::tags$p(
          class = "text-muted",
          paste0("Package '", pkg_name, "' not found.")
        ))
      }

      # Look up example data for this package (if available)
      examples <- examples_data()
      example_row <- if (!is.null(examples)) {
        ex <- examples[examples$package_name == pkg_name, ]
        if (nrow(ex) > 0) ex else NULL
      }

      # Build the detail view as a stack of cards
      htmltools::tagList(
        # Back button
        build_back_button(ns),

        # Package header card
        build_header_card(pkg),

        # Links card
        build_links_card(pkg),

        # Download statistics card
        build_downloads_card(pkg),

        # Version info card
        build_version_card(pkg),

        # Code example card (M6)
        build_example_card(example_row)
      )
    })

    # Handle back button click
    shiny::observeEvent(input$back_btn, {
      on_back()
    })
  })
}

# =============================================================================
# Card builder functions (internal helpers)
# =============================================================================

#' Build the back button
#' @noRd
build_back_button <- function(ns) {
  shiny::actionButton(
    ns("back_btn"),
    label = htmltools::tagList(
      htmltools::HTML("&larr;"), " Back to all packages"
    ),
    class = "btn btn-outline-secondary mb-3"
  )
}

#' Build the package header card
#' @noRd
build_header_card <- function(pkg) {
  # Category badges (all categories, not just first)
  cats <- strsplit(pkg$categories, "\\|")[[1]]
  cat_badges <- lapply(cats, function(cat) {
    if (cat == "na") return(NULL)
    htmltools::span(
      class = "badge-category me-1",
      gsub("_", " ", cat)
    )
  })

  # Essential badge
  essential_badge <- if (isTRUE(pkg$is_essential)) {
    htmltools::span(
      class = "badge bg-warning text-dark ms-2",
      "\u2B50 Essential Extension"
    )
  }

  bslib::card(
    bslib::card_body(
      # Package name heading
      htmltools::tags$h2(
        pkg$package_name,
        essential_badge
      ),

      # Full description
      htmltools::tags$p(
        class = "lead",
        if (is.na(pkg$description)) "No description available." else pkg$description
      ),

      # Maintainer
      if (!is.na(pkg$maintainer)) {
        htmltools::tags$p(
          htmltools::tags$strong("Maintainer: "),
          pkg$maintainer
        )
      },

      # Category badges
      htmltools::tags$div(class = "mb-2", cat_badges),

      # License
      if (!is.na(pkg$license)) {
        htmltools::tags$p(
          class = "text-muted",
          htmltools::tags$strong("License: "),
          pkg$license
        )
      }
    )
  )
}

#' Build the links card
#'
#' Shows links for Website, GitHub/GitLab, CRAN, Reference Manual, Vignettes.
#' Links that are NA are hidden (not greyed out), per SPEC section 5.4.
#' @noRd
build_links_card <- function(pkg) {
  # Build link list -- only include non-NA links
  links <- list()

  if (!is.na(pkg$website_url)) {
    links <- c(links, list(make_link_button("Website", pkg$website_url, "\U0001F310")))
  }
  if (!is.na(pkg$repo_url)) {
    links <- c(links, list(make_link_button("GitHub/GitLab", pkg$repo_url, "\U0001F4BB")))
  }
  if (!is.na(pkg$cran_url)) {
    links <- c(links, list(make_link_button("CRAN", pkg$cran_url, "\U0001F4E6")))
  }
  if (!is.na(pkg$manual_url)) {
    links <- c(links, list(make_link_button("Manual", pkg$manual_url, "\U0001F4D6")))
  }
  if (!is.na(pkg$vignettes_url)) {
    links <- c(links, list(make_link_button("Vignettes", pkg$vignettes_url, "\U0001F4D1")))
  }

  # Only show the card if there are links to display

  if (length(links) == 0) return(NULL)

  bslib::card(
    bslib::card_header("Links"),
    bslib::card_body(
      htmltools::tags$div(
        class = "d-flex flex-wrap gap-2",
        links
      )
    )
  )
}

#' Create a link button for the links card
#' @noRd
make_link_button <- function(label, url, icon = "") {
  htmltools::tags$a(
    href = url,
    target = "_blank",
    rel = "noopener noreferrer",
    class = "btn btn-outline-primary btn-sm",
    paste(icon, label)
  )
}

#' Build the download statistics card with 4 value boxes
#' @noRd
build_downloads_card <- function(pkg) {
  format_dl <- function(value) {
    if (is.na(value)) "\u2014" else format(value, big.mark = ",")
  }

  bslib::card(
    bslib::card_header("Download Statistics"),
    bslib::card_body(
      bslib::layout_column_wrap(
        width = 1 / 4,
        bslib::value_box(
          title = "Last 7 days",
          value = format_dl(pkg$downloads_7d),
          showcase = htmltools::tags$span("\U0001F4C8"),
          theme = "primary"
        ),
        bslib::value_box(
          title = "Last 30 days",
          value = format_dl(pkg$downloads_30d),
          showcase = htmltools::tags$span("\U0001F4C8"),
          theme = "primary"
        ),
        bslib::value_box(
          title = "Last 365 days",
          value = format_dl(pkg$downloads_365d),
          showcase = htmltools::tags$span("\U0001F4C8"),
          theme = "primary"
        ),
        bslib::value_box(
          title = "All time (since 2015)",
          value = format_dl(pkg$downloads_all),
          showcase = htmltools::tags$span("\U0001F4C8"),
          theme = "primary"
        )
      )
    )
  )
}

#' Build the version info card
#' @noRd
build_version_card <- function(pkg) {
  bslib::card(
    bslib::card_header("Version Info"),
    bslib::card_body(
      if (isTRUE(pkg$on_cran)) {
        htmltools::tagList(
          htmltools::tags$p(
            htmltools::tags$strong("Latest CRAN version: "),
            if (is.na(pkg$cran_version)) "\u2014" else pkg$cran_version
          ),
          htmltools::tags$p(
            htmltools::tags$strong("Published: "),
            if (is.na(pkg$cran_published)) {
              "\u2014"
            } else {
              format(as.Date(pkg$cran_published), "%Y-%m-%d")
            }
          )
        )
      } else {
        htmltools::tags$p(class = "text-muted", "Not available on CRAN.")
      },

      if (!is.na(pkg$github_updated)) {
        htmltools::tags$p(
          htmltools::tags$strong("GitHub last updated: "),
          format(as.Date(pkg$github_updated), "%Y-%m-%d")
        )
      }
    )
  )
}

#' Build the code example card
#'
#' Shows syntax-highlighted code, copy-to-clipboard button, rendered PNG image,
#' and timestamp. Handles three states: successful render, failed render
#' (code only), and license not allowed (message only).
#'
#' @param example A one-row data frame with example data, or NULL if no data.
#' @return A bslib card, or NULL if no example data available.
#' @noRd
build_example_card <- function(example) {
  if (is.null(example)) return(NULL)

  # License not allowed -- show message, no code

  if (!isTRUE(example$license_allowed)) {
    return(bslib::card(
      bslib::card_header("Code Example"),
      bslib::card_body(
        htmltools::tags$p(
          class = "text-muted",
          "Code example not available \u2014 package license could not be verified."
        )
      )
    ))
  }

  # No example code available
  if (is.na(example$example_code)) {
    return(bslib::card(
      bslib::card_header("Code Example"),
      bslib::card_body(
        htmltools::tags$p(
          class = "text-muted",
          "No code example available for this package."
        )
      )
    ))
  }

  # Build the code block with copy button
  code_id <- paste0("code-", example$package_name)
  btn_id <- paste0("copy-btn-", example$package_name)

  code_block <- htmltools::tagList(
    # Copy to clipboard button
    htmltools::tags$button(
      id = btn_id,
      class = "btn btn-outline-secondary btn-sm mb-2",
      onclick = sprintf("copyCodeToClipboard('%s', '%s')", code_id, btn_id),
      "\U0001F4CB Copy to clipboard"
    ),

    # Syntax-highlighted code block
    htmltools::tags$pre(
      htmltools::tags$code(
        id = code_id,
        class = "language-r",
        example$example_code
      )
    )
  )

  # Image (if render succeeded)
  image_block <- if (isTRUE(example$example_success) && !is.na(example$example_image)) {
    htmltools::tags$div(
      class = "mt-3",
      htmltools::tags$img(
        src = paste0("www/examples/", example$example_image),
        alt = paste("Example output for", example$package_name),
        class = "img-fluid rounded",
        style = "max-width: 100%;"
      )
    )
  } else {
    htmltools::tags$p(
      class = "text-muted mt-2",
      "Output preview not available for this package."
    )
  }

  # Timestamp
  timestamp <- if (!is.na(example$example_rendered_at)) {
    htmltools::tags$p(
      class = "text-muted small mt-2",
      paste("Example last rendered:", example$example_rendered_at)
    )
  }

  bslib::card(
    bslib::card_header("Code Example"),
    bslib::card_body(
      code_block,
      image_block,
      timestamp
    )
  )
}

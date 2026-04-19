# =============================================================================
# mod_detail.R
#
# Shiny module for the package detail view. Displays full metadata for a
# single selected package: header card, links card, download statistics
# (value boxes), and version info. Replaces the browse table when a
# package is selected.
#
# v1.2 (M0): the header-card badge reads "⭐ Featured in the book" (renamed
# from the v1.1 legacy label) and is driven by pkg$is_featured per
# SPEC-v1.2 §5.9.
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
mod_detail_server <- function(id, selected_package, app_data,
                              examples_data = reactive(NULL),
                              all_packages_alpha = reactive(NULL),
                              on_back, on_navigate = NULL) {
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

      # Determine prev/next package for navigation arrows
      all_pkgs <- all_packages_alpha()

      # Warning banner for archived packages (v1.1 — above header card)
      archived_banner <- if (isTRUE(pkg$is_archived)) {
        htmltools::div(
          class = "alert alert-warning d-flex flex-column mb-3",
          role = "alert",
          htmltools::tags$strong("This package is no longer actively maintained."),
          if (!is.na(pkg$notes) && nchar(trimws(pkg$notes)) > 0) {
            htmltools::tags$p(class = "mb-0 mt-2", pkg$notes)
          }
        )
      }

      # Build the detail view as a stack of cards with consistent spacing
      htmltools::tagList(
        # Navigation bar: back + prev/next (top — distinct IDs from bottom)
        build_nav_bar(ns, pkg_name, all_pkgs, suffix = "top"),

        # Archived warning banner (if applicable)
        archived_banner,

        # Card stack with consistent gap-3 spacing
        htmltools::tags$div(
          class = "d-grid gap-3",

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
        ),

        # Navigation bar (bottom — distinct IDs from top)
        htmltools::tags$div(class = "mt-3",
          build_nav_bar(ns, pkg_name, all_pkgs, suffix = "bottom")
        )
      )
    })

    # Handle back button clicks (both top and bottom nav bars)
    shiny::observeEvent(input$back_btn_top, { on_back() })
    shiny::observeEvent(input$back_btn_bottom, { on_back() })

    # Helper for prev/next navigation logic
    navigate_to <- function(direction) {
      pkg_name <- selected_package()
      all_pkgs <- all_packages_alpha()
      if (!is.null(pkg_name) && !is.null(all_pkgs)) {
        idx <- match(pkg_name, all_pkgs)
        new_idx <- idx + direction
        if (!is.na(idx) && new_idx >= 1 && new_idx <= length(all_pkgs)) {
          new_pkg <- all_pkgs[new_idx]
          if (!is.null(on_navigate)) on_navigate(new_pkg)
          else selected_package(new_pkg)
        }
      }
    }

    # Handle prev button clicks (both top and bottom)
    shiny::observeEvent(input$prev_btn_top, { navigate_to(-1) })
    shiny::observeEvent(input$prev_btn_bottom, { navigate_to(-1) })

    # Handle next button clicks (both top and bottom)
    shiny::observeEvent(input$next_btn_top, { navigate_to(1) })
    shiny::observeEvent(input$next_btn_bottom, { navigate_to(1) })
  })
}

# =============================================================================
# Card builder functions (internal helpers)
# =============================================================================

#' Build the navigation bar with back, prev, and next buttons
#'
#' Renders a horizontal flex row with "Back to all packages",
#' "← Prev", and "Next →" buttons. Prev/next are disabled at
#' the boundaries of the alphabetical package list. Uses a suffix
#' to generate unique IDs when rendered at both top and bottom.
#'
#' @param ns The module's namespace function.
#' @param current_pkg The currently selected package name.
#' @param all_pkgs Character vector of all package names (alphabetically sorted).
#' @param suffix A string ("top" or "bottom") to ensure unique button IDs.
#' @return An htmltools tag with the navigation bar.
#' @noRd
build_nav_bar <- function(ns, current_pkg, all_pkgs, suffix = "top") {
  # Determine position for prev/next button state
  idx <- if (!is.null(all_pkgs)) match(current_pkg, all_pkgs) else NA
  is_first <- is.na(idx) || idx == 1
  is_last <- is.na(idx) || idx == length(all_pkgs)

  htmltools::tags$div(
    class = "d-flex gap-2 mb-3",

    # Back button
    shiny::actionButton(
      ns(paste0("back_btn_", suffix)),
      label = htmltools::tagList(
        htmltools::HTML("&larr;"), " Back to all packages"
      ),
      class = "btn btn-back"
    ),

    # Prev button (same red styling as back button)
    shiny::actionButton(
      ns(paste0("prev_btn_", suffix)),
      label = htmltools::tagList(htmltools::HTML("&larr;"), " Prev"),
      class = paste("btn btn-back", if (is_first) "disabled" else ""),
      disabled = if (is_first) NA else NULL
    ),

    # Next button (same red styling as back button)
    shiny::actionButton(
      ns(paste0("next_btn_", suffix)),
      label = htmltools::tagList("Next ", htmltools::HTML("&rarr;")),
      class = paste("btn btn-back", if (is_last) "disabled" else ""),
      disabled = if (is_last) NA else NULL
    )
  )
}

#' Build the package header card
#'
#' Shows package name as heading, title as lead subtitle, full description
#' as body paragraph, maintainer, category badges with colours, and license.
#' @noRd
build_header_card <- function(pkg) {
  # Category badges with category-specific colours
  cats <- strsplit(pkg$categories, "\\|")[[1]]
  cat_badges <- lapply(cats, function(cat) {
    if (cat == "na") return(NULL)
    build_category_badge(cat)
  })

  # Featured-in-the-book badge (v1.2 §5.9 renamed the legacy label text).
  #
  # The badge text is sentence case ("Featured in the book") intentionally —
  # it is a phrase embedded in UI chrome. The sidebar's form-label sibling
  # uses Title Case ("Featured in the Book") to match its neighbours
  # ("Category", "License", ...). Keep both casings as SPEC-v1.2 §3.2
  # specifies — do not unify.
  #
  # The visual treatment (full Bootstrap warning pill with badge text) is
  # deliberately heavier than the browse-table version (compact amber star
  # glyph only). Rationale: on the detail view a single package is read in
  # depth, so a prominent pill reinforces "notable package" and balances
  # the "Archived Package" pill beside it. The browse table renders dozens
  # of rows at once; a pill on every featured row would steal attention
  # from the package name and title. Keep the two treatments — SPEC-v1.2
  # §5.9 shows both patterns verbatim.
  #
  # Tooltip (Designer Fix #6) mirrors the disambiguating body of the
  # sidebar-checkbox tooltip so the answer to "featured in *what* book?" is
  # consistent across every surface the user might first encounter it on.
  # The framing is singular ("Featured in…") rather than plural ("Packages
  # featured in…") because the detail view is about one package at a time —
  # plural framing here would create a mild cognitive stutter (Designer
  # round-02 finding #1). The core disambiguating phrase
  # ("companion book 'ggplot2 extended'") is identical between the two
  # tooltip bodies; the framing adapts to context.
  featured_badge <- if (isTRUE(pkg$is_featured)) {
    bslib::tooltip(
      htmltools::span(
        class = "badge bg-warning text-dark ms-2",
        "\u2B50 Featured in the book"
      ),
      FEATURED_TOOLTIP_BODY_DETAIL
    )
  }

  # Archived badge (v1.1)
  archived_badge <- if (isTRUE(pkg$is_archived)) {
    htmltools::span(
      class = "badge bg-secondary ms-2",
      "\U0001F4C1 Archived Package"
    )
  }

  # Title: prefer CRAN title, fall back to GitHub title (v1.1 §5.4.4)
  # Extra fallback levels vs other fields because title is always displayed
  # as lead subtitle — we need a value even if both CRAN and GitHub are NA
  display_title <- if ("title" %in% names(pkg) && !is.na(pkg$title)) {
    pkg$title
  } else if ("github_title" %in% names(pkg) && !is.na(pkg$github_title)) {
    pkg$github_title
  } else if (!is.na(pkg$description)) {
    # Last resort fallback for data without separate title field
    pkg$description
  } else {
    "No title available."
  }

  # Description: prefer CRAN, fall back to GitHub (v1.1 §5.4.4)
  display_description <- if ("description" %in% names(pkg) && !is.na(pkg$description)) {
    pkg$description
  } else if ("github_description" %in% names(pkg) && !is.na(pkg$github_description)) {
    pkg$github_description
  } else {
    NULL
  }
  desc_block <- if (!is.null(display_description)) {
    htmltools::tags$p(display_description)
  }

  # Maintainer: prefer CRAN, fall back to GitHub (v1.1 §5.4.4)
  display_maintainer <- if (!is.na(pkg$maintainer)) {
    pkg$maintainer
  } else if ("github_maintainer" %in% names(pkg) && !is.na(pkg$github_maintainer)) {
    pkg$github_maintainer
  } else {
    NULL
  }

  # License: prefer CRAN, fall back to GitHub (v1.1 §5.4.4)
  display_license <- if (!is.na(pkg$license)) {
    pkg$license
  } else if ("github_license" %in% names(pkg) && !is.na(pkg$github_license)) {
    pkg$github_license
  } else {
    NULL
  }

  bslib::card(
    bslib::card_body(
      # Package name heading
      htmltools::tags$h2(
        pkg$package_name,
        featured_badge,
        archived_badge
      ),

      # Title as lead subtitle
      htmltools::tags$p(class = "lead", display_title),

      # Full description as body text
      desc_block,

      # Maintainer
      if (!is.null(display_maintainer)) {
        htmltools::tags$p(
          htmltools::tags$strong("Maintainer: "),
          display_maintainer
        )
      },

      # Category badges with colours
      htmltools::tags$div(class = "d-flex flex-wrap gap-1 mb-2", cat_badges),

      # License (same colour as other text in the card)
      if (!is.null(display_license)) {
        htmltools::tags$p(
          htmltools::tags$strong("License: "),
          display_license
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
    links <- c(links, list(make_link_button("Repo (GitHub, etc.)", pkg$repo_url, "\U0001F4BB")))
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
          theme = "primary"
        ),
        bslib::value_box(
          title = "Last 30 days",
          value = format_dl(pkg$downloads_30d),
          theme = "primary"
        ),
        bslib::value_box(
          title = "Last 365 days",
          value = format_dl(pkg$downloads_365d),
          theme = "primary"
        ),
        bslib::value_box(
          title = "Since 2015",
          value = format_dl(pkg$downloads_all),
          theme = "primary"
        )
      )
    )
  )
}

#' Build the version info card
#'
#' v1.1: Source-agnostic labels. Uses derived `version` field (CRAN or GitHub).
#' Removed "Not available on CRAN." text — non-CRAN packages now show GitHub
#' version when available, or em dash when not.
#'
#' @noRd
build_version_card <- function(pkg) {
  # Determine version to display (CRAN or GitHub via derived field)
  display_version <- if ("version" %in% names(pkg) && !is.na(pkg$version)) {
    pkg$version
  } else {
    NA_character_
  }

  bslib::card(
    bslib::card_header("Version Info"),
    bslib::card_body(
      # Version line (source-agnostic)
      htmltools::tags$p(
        htmltools::tags$strong("Latest Version: "),
        if (is.na(display_version)) "\u2014" else display_version
      ),

      # Published date (CRAN only — meaningful date)
      if (isTRUE(pkg$on_cran) && !is.na(pkg$cran_published)) {
        htmltools::tags$p(
          htmltools::tags$strong("Published: "),
          format(as.Date(pkg$cran_published), "%Y-%m-%d")
        )
      },

      # GitHub last updated (shown for all packages with GitHub data)
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

  # No example code available (skip license check — show code for all packages)
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

  # Build the code block with copy button.
  # Prepend install.packages() and library() lines for display and copy,
  # but do NOT modify the stored example_code in Parquet.
  code_id <- paste0("code-", example$package_name)
  btn_id <- paste0("copy-btn-", example$package_name)

  display_code <- paste0(
    "# Install if needed:\n",
    "# install.packages(\"", example$package_name, "\")\n",
    "library(", example$package_name, ")\n\n",
    "# Example:\n",
    example$example_code
  )

  code_block <- htmltools::tagList(
    # Copy to clipboard button (red btn-back styling, matching nav buttons)
    htmltools::tags$button(
      id = btn_id,
      class = "btn btn-back btn-sm mb-2",
      onclick = sprintf("copyCodeToClipboard('%s', '%s')", code_id, btn_id),
      "\U0001F4CB Copy to clipboard"
    ),

    # Syntax-highlighted code block (includes install/library preamble).
    # Use HTML() to prevent htmltools from auto-indenting inside <pre>,
    # which would add unwanted leading whitespace to every line.
    htmltools::HTML(sprintf(
      '<pre><code id="%s" class="language-r">%s</code></pre>',
      code_id,
      htmltools::htmlEscape(display_code)
    ))
  )

  bslib::card(
    bslib::card_header("Code Example"),
    bslib::card_body(
      code_block
    )
  )
}

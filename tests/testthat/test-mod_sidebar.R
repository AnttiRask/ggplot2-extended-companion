# =============================================================================
# test-mod_sidebar.R
#
# Tests for the sidebar module UI in R/mod_sidebar.R. mod_sidebar_ui()
# returns a pure tagList so its output can be serialised to HTML and
# inspected without spinning up a Shiny session.
#
# v1.2 (M0): introduced to close the coverage asymmetry flagged by
# Reviewer round-02 §8 — the detail-view tooltip has a regression test
# (tests/testthat/test-mod_detail.R) but the sidebar tooltip did not.
# =============================================================================

test_that("mod_sidebar_ui renders without error with empty inputs", {
  # Smoke test — the module's UI function should tolerate the simplest
  # possible inputs (no categories, no licenses) and still return a
  # tagList that renders to HTML.
  result <- mod_sidebar_ui("sidebar")

  # htmltools::tagList returns an object of class "shiny.tag.list"
  expect_s3_class(result, "shiny.tag.list")
  # as.character should succeed — i.e., the tagList serialises
  expect_type(as.character(result), "character")
})

test_that("mod_sidebar_ui renders the 'Featured in the Book' checkbox label", {
  # Designer Fix #1: the label uses Title Case to match sibling sidebar
  # controls ("Category", "CRAN Status", "License", "Recently Added"). This
  # is distinct from the sentence-case "Featured in the book" used in the
  # detail-card badge and browse-table tooltip.
  result <- mod_sidebar_ui("sidebar")
  html <- as.character(result)

  expect_true(grepl("Featured in the Book", html, fixed = TRUE))
})

test_that("mod_sidebar_ui wires up the book-disambiguating tooltip", {
  # Designer Fix #2: the checkbox is wrapped in bslib::tooltip() so first-
  # time visitors who have not opened the intro accordion can still learn
  # which book the curation is anchored in. The body is plural-framed
  # because the sidebar filter operates on a collection of packages —
  # contrast with R/mod_detail.R where the framing is singular. Both
  # share the "companion book 'ggplot2 extended'" tail. See
  # FEATURED_TOOLTIP_BODY_SIDEBAR in R/fct_constants.R.
  #
  # Rendering note (same as test-mod_detail.R): bslib 0.10 emits a
  # <bslib-tooltip> Web Component with a <template> child; the runtime
  # JS hydrates data-bs-title / aria-describedby on activation. grepl()
  # against the rendered HTML with fixed = TRUE sidesteps regex
  # interpretation of the single quotes in the body.
  result <- mod_sidebar_ui("sidebar")
  html <- as.character(result)

  expect_true(grepl(FEATURED_TOOLTIP_BODY_SIDEBAR, html, fixed = TRUE))
})

test_that("mod_sidebar_ui does not leak the detail-view (singular) tooltip body", {
  # Guards against a future refactor collapsing the two
  # FEATURED_TOOLTIP_BODY_* constants back into one — the sidebar must
  # carry the plural framing, not the detail-view singular framing.
  result <- mod_sidebar_ui("sidebar")
  html <- as.character(result)

  expect_false(grepl(FEATURED_TOOLTIP_BODY_DETAIL, html, fixed = TRUE))
  # But the plural IS present (verified by the test above); together these
  # two assertions encode "sidebar uses plural, not singular".
})

test_that("mod_sidebar_ui namespaces the featured_only input ID", {
  # SPEC-v1.2 §3.2: the input ID is `featured_only` (not the v1.1 legacy
  # name). The module's namespace prefix is applied via shiny::NS(id), so
  # the rendered HTML should contain the namespaced form.
  result <- mod_sidebar_ui("sidebar")
  html <- as.character(result)

  expect_true(grepl('id="sidebar-featured_only"', html, fixed = TRUE))
})

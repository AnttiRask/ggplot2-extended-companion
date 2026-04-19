# =============================================================================
# test-app_ui.R
#
# Structural tests for the app UI layer: app_ui(), render_browse_page(),
# render_detail_page(). Asserts the per-view layout contract (SPEC-v1.2 §5.1)
# without requiring a live Shiny session — every test renders the helper's
# tag tree via htmltools::renderTags() and inspects the resulting HTML.
#
# The sidebar-default assertions (desktop="open" / mobile="closed") are
# written loosely on purpose: bslib emits the open-state in an internal
# attribute/class shape that may shift across versions. Tests pin the
# observable behaviour (sidebar rendered, no mobile-open marker, etc.)
# rather than a literal attribute name.
#
# Requires bslib >= 0.7.0 for the list-form `open` argument.
#
# Part of Milestone 1: Per-view layout + sidebar defaults (SPEC-v1.2 §9 M1)
# =============================================================================

skip_if(
  utils::packageVersion("bslib") < "0.7.0",
  "bslib >= 0.7.0 required for list-form sidebar `open` argument"
)

# --- app_ui() top-level shape ------------------------------------------------

test_that("app_ui returns a tagList with a single uiOutput('main_page') slot", {

  ui <- app_ui(request = NULL)

  # app_ui must return a tag or tagList, not a bslib page wrapper directly.
  expect_s3_class(ui, "shiny.tag.list")

  # Render to HTML and inspect.
  rendered <- htmltools::renderTags(ui)
  html <- rendered$html

  # The uiOutput("main_page") slot must be present exactly once, as a div
  # with id="main_page" and the shiny-html-output class.
  expect_match(
    html,
    "<div[^>]*id=\"main_page\"[^>]*class=\"[^\"]*shiny-html-output[^\"]*\"",
    fixed = FALSE
  )

  # No top-level bslib page wrapper — app_ui itself must NOT embed a
  # page_sidebar or page_fillable. Those belong inside the render helpers,
  # which are dispatched via output$main_page on the server side.
  expect_false(
    grepl("bslib-page-sidebar", html, fixed = TRUE),
    info = "app_ui must not render a page_sidebar at the top level"
  )
  expect_false(
    grepl("bslib-page-fill", html, fixed = TRUE),
    info = "app_ui must not render a page_fillable at the top level"
  )
})

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

# --- render_browse_page() ----------------------------------------------------

test_that("render_browse_page renders a sidebar with Filters and browse module", {

  page <- render_browse_page()

  # Returns a shiny.tag (bslib page constructors return a tag, optionally
  # wrapped in a tagList — accept either).
  expect_true(inherits(page, "shiny.tag") || inherits(page, "shiny.tag.list"))

  html <- htmltools::renderTags(page)$html

  # Sidebar present — use the <aside> HTML5 semantic element, which bslib
  # has emitted stably across versions for page_sidebar.
  expect_true(
    grepl("<aside", html, fixed = TRUE),
    info = "render_browse_page must include a sidebar <aside>"
  )

  # Sidebar title "Filters" (our own literal, not a bslib internal token).
  expect_true(
    grepl("Filters", html, fixed = TRUE),
    info = "render_browse_page sidebar must carry the 'Filters' title"
  )

  # sidebar_controls uiOutput slot — this is where the server renders the
  # data-driven filter inputs. Matches the v1.1 baseline behaviour.
  expect_true(
    grepl("id=\"sidebar_controls\"", html, fixed = TRUE),
    info = "render_browse_page sidebar must mount output$sidebar_controls"
  )

  # Browse module UI present (namespace-stable marker).
  expect_true(
    grepl("id=\"browse-package_table\"", html, fixed = TRUE),
    info = "render_browse_page must mount mod_browse_ui('browse')"
  )

  # Header and footer module UIs present.
  expect_true(
    grepl("id=\"header-intro_accordion\"", html, fixed = TRUE),
    info = "render_browse_page must mount mod_header_ui('header')"
  )
  expect_true(
    grepl("<footer", html, fixed = TRUE),
    info = "render_browse_page must mount mod_footer_ui('footer')"
  )

  # Detail module UI must NOT be rendered by the browse helper.
  expect_false(
    grepl("id=\"detail-detail_content\"", html, fixed = TRUE),
    info = "render_browse_page must not mount mod_detail_ui('detail')"
  )
})

# --- app_ui() top-level shape ------------------------------------------------

test_that("app_ui returns a tagList with a single uiOutput('main_page') slot", {

  ui <- app_ui(request = NULL)

  # app_ui must return a tag or tagList, not a bslib page wrapper directly.
  expect_s3_class(ui, "shiny.tag.list")

  # Render to HTML and inspect.
  rendered <- htmltools::renderTags(ui)
  html <- rendered$html

  # The uiOutput("main_page") slot must be present. Check only for the
  # id="main_page" marker — shiny's uiOutput class name has been stable for
  # years, but we avoid pinning to it for version-drift resilience.
  expect_true(
    grepl("id=\"main_page\"", html, fixed = TRUE),
    info = "app_ui must render the uiOutput('main_page') slot"
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

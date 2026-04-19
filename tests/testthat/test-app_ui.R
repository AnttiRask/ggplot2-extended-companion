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

test_that("render_browse_page sidebar opens on desktop, closes on mobile", {

  html <- htmltools::renderTags(render_browse_page())$html

  # bslib reflects the `open = list(desktop = ..., mobile = ...)` argument
  # as data attributes on the sidebar container. These attributes are part
  # of bslib's public contract for its JS to pick up at runtime.
  #
  # If these attribute names change in a future bslib release, these two
  # assertions will need updating — but the design.md §4 guidance is to
  # pin to the observable contract, not to avoid it entirely.
  expect_true(
    grepl("data-open-desktop=\"open\"", html, fixed = TRUE),
    info = "sidebar must carry data-open-desktop=\"open\""
  )
  expect_true(
    grepl("data-open-mobile=\"closed\"", html, fixed = TRUE),
    info = "sidebar must carry data-open-mobile=\"closed\""
  )

  # Resilience cross-check: even if the attribute names drift, the
  # semantics must hold — the sidebar must never declare itself
  # mobile-open on render, because that would defeat the off-canvas
  # drawer behaviour on small viewports.
  expect_false(
    grepl("data-open-mobile=\"open\"", html, fixed = TRUE),
    info = "sidebar must not open by default on mobile"
  )
  expect_false(
    grepl("data-open-mobile=\"always\"", html, fixed = TRUE),
    info = "sidebar must not be forced-open on mobile"
  )
})

# --- render_detail_page() ----------------------------------------------------

test_that("render_detail_page renders detail UI with no sidebar", {

  page <- render_detail_page()

  expect_true(inherits(page, "shiny.tag") || inherits(page, "shiny.tag.list"))

  html <- htmltools::renderTags(page)$html

  # Detail module UI present (namespace-stable marker).
  expect_true(
    grepl("id=\"detail-detail_content\"", html, fixed = TRUE),
    info = "render_detail_page must mount mod_detail_ui('detail')"
  )

  # Header and footer still mount on the detail page.
  expect_true(
    grepl("id=\"header-intro_accordion\"", html, fixed = TRUE),
    info = "render_detail_page must mount mod_header_ui('header')"
  )
  expect_true(
    grepl("<footer", html, fixed = TRUE),
    info = "render_detail_page must mount mod_footer_ui('footer')"
  )

  # No sidebar anywhere in the detail view — the whole point of the
  # per-view layout swap (SPEC-v1.2 §5.1, §9 M1 DoD).
  expect_false(
    grepl("<aside", html, fixed = TRUE),
    info = "render_detail_page must not render a sidebar <aside>"
  )
  expect_false(
    grepl("Filters", html, fixed = TRUE),
    info = "render_detail_page must not render the 'Filters' title"
  )
  expect_false(
    grepl("id=\"sidebar_controls\"", html, fixed = TRUE),
    info = "render_detail_page must not mount output$sidebar_controls"
  )
  expect_false(
    grepl("id=\"filters_sidebar\"", html, fixed = TRUE),
    info = "render_detail_page must not include the browse filters_sidebar"
  )

  # Browse module UI must NOT be rendered by the detail helper.
  expect_false(
    grepl("id=\"browse-package_table\"", html, fixed = TRUE),
    info = "render_detail_page must not mount mod_browse_ui('browse')"
  )
})

# --- page-helper class + shared navbar ---------------------------------------

test_that("both page helpers return bslib_page objects", {

  # Spec delta requires both helpers to return *complete* page objects,
  # not fragments. bslib labels complete pages with the "bslib_page"
  # class — asserting on it here catches a future "let's factor out
  # the page shell to app_ui()" regression that the HTML-shape tests
  # might not flag. (Code Review round 01, Suggestion #6.)
  expect_s3_class(render_browse_page(), "bslib_page")
  expect_s3_class(render_detail_page(), "bslib_page")
})

test_that("both page helpers render the shared brand navbar", {

  # Regression guard: the M1 round-01 design review caught that
  # render_detail_page() shipped without a visible app title (bslib's
  # page_fillable does not auto-emit a navbar from `title`). The fix
  # adds an explicit app_navbar() as the first body child of both
  # helpers. These assertions pin the contract so the regression
  # cannot quietly come back. (DESIGN review round 01, Fix #1.)

  for (helper in list(
    list(name = "render_browse_page", page = render_browse_page()),
    list(name = "render_detail_page", page = render_detail_page())
  )) {
    html <- htmltools::renderTags(helper$page)$html

    expect_true(
      grepl("navbar-brand", html, fixed = TRUE),
      info = paste0(
        helper$name, " must emit an <h1 class=\"... navbar-brand\">"
      )
    )
    expect_true(
      grepl("ggplot2 extended (companion)", html, fixed = TRUE),
      info = paste0(
        helper$name, " must render the app brand text in the navbar"
      )
    )
    # The dark-mode toggle must now live inside the shared navbar so
    # it sits in the same top-right slot on both views.
    expect_true(
      grepl(
        "<div class=\"navbar[^\"]*\"[\\s\\S]*?id=\"colour_mode\"",
        html,
        perl = TRUE
      ),
      info = paste0(
        helper$name, " must place input_dark_mode inside the navbar"
      )
    )
  }
})

test_that("render_detail_page does not leak window_title as a body attribute", {

  # page_fillable() has no window_title formal; passing it would
  # silently forward the arg into ... and emit a raw
  # window_title="..." attribute on <body>. (DESIGN review round 01,
  # Fix #2.)
  html <- htmltools::renderTags(render_detail_page())$html

  expect_false(
    grepl("window_title=\"", html, fixed = TRUE),
    info = "render_detail_page must not emit a stray window_title attribute"
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

  # The uiOutput("main_page") slot must be present EXACTLY ONCE. The
  # spec delta's first scenario says "SHALL contain exactly one element
  # with id='main_page'" — asserting on the count (not just presence)
  # catches a future regression where the slot is duplicated via
  # accidental paste or a server-side uiOutput() duplication.
  # (Code Review round 01, Suggestion #5.)
  matches <- gregexpr("id=\"main_page\"", html, fixed = TRUE)[[1]]
  match_count <- if (length(matches) == 1L && matches[[1]] == -1L) 0L else length(matches)
  expect_equal(
    match_count,
    1L,
    info = "app_ui must render exactly one uiOutput('main_page') slot"
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

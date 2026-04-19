## ADDED Requirements

### Requirement: app_ui dispatches via uiOutput("main_page")

The `app_ui(request)` function SHALL return a `shiny::tagList` whose body contains `shiny::uiOutput("main_page")` as its page-shaping element, together with whatever `golem_add_external_resources()` returns. The function SHALL NOT call `bslib::page_sidebar()`, `bslib::page_fillable()`, or any other bslib page constructor directly.

#### Scenario: Top-level shape contains uiOutput marker

- **WHEN** `app_ui(request = NULL)` is rendered via `htmltools::renderTags()`
- **THEN** the resulting HTML SHALL contain exactly one element with `id="main_page"` and class `shiny-html-output`

#### Scenario: No top-level page wrapper

- **WHEN** `app_ui(request = NULL)` is rendered via `htmltools::renderTags()`
- **THEN** the resulting HTML SHALL NOT contain a `bslib-page-sidebar` or `bslib-page-fillable` wrapper as a direct child of the outer `tagList`

### Requirement: render_browse_page returns a complete page_sidebar

The `render_browse_page()` function SHALL return a complete `bslib::page_sidebar(...)` object — not a fragment — configured with `title`, `window_title`, `theme = app_theme()`, the dark-mode toggle input (`id = "colour_mode"`), a sidebar region with title `"Filters"` and content `shiny::uiOutput("sidebar_controls")`, and a body containing the header module UI, browse module UI, and footer module UI in that order.

#### Scenario: Sidebar region present with the Filters title

- **WHEN** `render_browse_page()` is rendered via `htmltools::renderTags()`
- **THEN** the resulting HTML SHALL contain a sidebar region (element `<aside>` or matching bslib sidebar class) whose contents include the literal text `"Filters"`

#### Scenario: Browse module UI is mounted

- **WHEN** `render_browse_page()` is rendered via `htmltools::renderTags()`
- **THEN** the resulting HTML SHALL contain the shiny output marker for `mod_browse_ui("browse")`

#### Scenario: Header and footer module UI are mounted

- **WHEN** `render_browse_page()` is rendered via `htmltools::renderTags()`
- **THEN** the resulting HTML SHALL contain the shiny output markers for both `mod_header_ui("header")` and `mod_footer_ui("footer")`

### Requirement: render_browse_page sidebar opens on desktop and closes on mobile

The sidebar region inside `render_browse_page()` SHALL be configured with `open = list(desktop = "open", mobile = "closed")` so that desktop viewports (≥992 px) display the sidebar open by default, and mobile viewports (<992 px) display the sidebar closed with an auto-inserted hamburger toggle provided by bslib.

#### Scenario: Sidebar attribute reflects desktop-open default

- **WHEN** `render_browse_page()` is rendered via `htmltools::renderTags()`
- **THEN** the resulting HTML SHALL contain a bslib-emitted attribute or class expressing the desktop-open default (exact token may vary by bslib version; the test SHALL assert that the `open` list-form was accepted by bslib without error AND that the rendered attributes do not mark the sidebar as desktop-closed)

#### Scenario: Sidebar attribute reflects mobile-closed default

- **WHEN** `render_browse_page()` is rendered via `htmltools::renderTags()`
- **THEN** the resulting HTML SHALL contain a bslib-emitted attribute or class expressing the mobile-closed default (exact token may vary by bslib version; the test SHALL assert that the rendered output does not mark the sidebar as mobile-open)

### Requirement: render_detail_page returns a complete page_fillable with no sidebar

The `render_detail_page()` function SHALL return a complete `bslib::page_fillable(...)` object — not a fragment — configured with `title`, `window_title`, `theme = app_theme()`, the dark-mode toggle input (`id = "colour_mode"`), and a body containing the header module UI, detail module UI, and footer module UI in that order. The function SHALL NOT configure any sidebar.

#### Scenario: Detail module UI is mounted

- **WHEN** `render_detail_page()` is rendered via `htmltools::renderTags()`
- **THEN** the resulting HTML SHALL contain the shiny output marker for `mod_detail_ui("detail")`

#### Scenario: No sidebar in detail HTML

- **WHEN** `render_detail_page()` is rendered via `htmltools::renderTags()`
- **THEN** the resulting HTML SHALL NOT contain any `<aside>` element, any element with a class matching `sidebar`, or the literal text `"Filters"`

#### Scenario: Header and footer module UI are mounted on detail too

- **WHEN** `render_detail_page()` is rendered via `htmltools::renderTags()`
- **THEN** the resulting HTML SHALL contain the shiny output markers for both `mod_header_ui("header")` and `mod_footer_ui("footer")`

### Requirement: app_server dispatches main_page via renderUI based on selected_package

The `app_server()` function SHALL define `output$main_page` as a `shiny::renderUI(...)` that returns `render_browse_page()` when `selected_package()` is NULL and `render_detail_page()` otherwise. The function SHALL call `shiny::outputOptions(output, "main_page", suspendWhenHidden = FALSE)` immediately after the `renderUI` definition.

#### Scenario: Browse render when no package selected

- **WHEN** a new Shiny session starts and `selected_package()` returns NULL
- **THEN** `output$main_page` SHALL render the output of `render_browse_page()`

#### Scenario: Detail render when a package is selected

- **WHEN** `selected_package()` returns a non-NULL character scalar matching a known package name
- **THEN** `output$main_page` SHALL render the output of `render_detail_page()`

#### Scenario: Output survives view switch without flicker

- **WHEN** the user toggles from browse to detail (via `selected_package(pkg)`) and back (via `selected_package(NULL)`)
- **THEN** the `#main_page` DOM node SHALL persist across the switch (only its children swap), because `outputOptions(..., suspendWhenHidden = FALSE)` keeps the output active

### Requirement: Legacy show_detail output is removed

The `app_server()` function SHALL NOT define `output$show_detail` nor call `shiny::outputOptions(output, "show_detail", ...)`. Any `conditionalPanel(condition = "!output.show_detail")` or `conditionalPanel(condition = "output.show_detail")` guards in the UI are removed in this change.

#### Scenario: show_detail output absent from app_server

- **WHEN** the source of `R/app_server.R` is read
- **THEN** it SHALL NOT contain a line defining `output$show_detail`

#### Scenario: No conditionalPanel guards remain

- **WHEN** the source of `R/app_ui.R` is read
- **THEN** it SHALL NOT contain any call to `shiny::conditionalPanel(condition = "!output.show_detail")` or `shiny::conditionalPanel(condition = "output.show_detail")`

### Requirement: Module server calls remain top-level and run once per session

Every `mod_*_server(...)` call in `app_server()` SHALL remain at the top level of the function body (not nested inside `output$main_page <- renderUI(...)` or any other reactive expression). Consequently, every module server SHALL run exactly once per session — identical to the v1.1 baseline.

#### Scenario: Server calls are not inside the renderUI

- **WHEN** the source of `R/app_server.R` is read
- **THEN** the function bodies of `mod_sidebar_server`, `mod_browse_server`, `mod_detail_server`, `mod_header_server`, and `mod_footer_server` SHALL all be referenced at the top level of `app_server()` — specifically, not inside the `{ ... }` block passed to `shiny::renderUI` for `output$main_page`

### Requirement: URL query parameter ?package=<name> still parses on startup and updates on navigation

The existing v1.1 URL-routing behaviour SHALL be preserved: on session startup, `?package=<name>` in the URL SHALL set `selected_package()` to `<name>` if and only if `<name>` matches a row in the loaded package data. When `selected_package()` changes to a non-NULL value, the URL SHALL be updated to `?package=<name>` via `shiny::updateQueryString(..., mode = "push")`; when `selected_package()` changes to NULL, the URL SHALL be cleared to `?` via `mode = "replace"`.

#### Scenario: Startup with valid ?package= loads detail view

- **WHEN** a session starts with `session$clientData$url_search == "?package=ggrepel"` and `ggrepel` is present in `app_data_raw$package_name`
- **THEN** `selected_package()` SHALL be set to `"ggrepel"` before the first render, causing `output$main_page` to render `render_detail_page()`

#### Scenario: Startup with invalid ?package= falls back to browse

- **WHEN** a session starts with `session$clientData$url_search == "?package=nonexistent"` and `"nonexistent"` is not present in `app_data_raw$package_name`
- **THEN** `selected_package()` SHALL remain NULL, causing `output$main_page` to render `render_browse_page()`

#### Scenario: Selecting a package pushes to history

- **WHEN** the user selects a package via the browse table and `selected_package()` is set to `"ggrepel"`
- **THEN** `shiny::updateQueryString("?package=ggrepel", mode = "push")` SHALL be called, adding a browser history entry

#### Scenario: Returning to browse clears the query string

- **WHEN** the user clicks the back button in the detail view and `selected_package()` is set to NULL
- **THEN** `shiny::updateQueryString("?", mode = "replace")` SHALL be called

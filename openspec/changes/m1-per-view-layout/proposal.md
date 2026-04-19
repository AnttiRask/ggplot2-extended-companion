## Why

SPEC-v1.2 §5.1 resolves open question Q6 with a **per-view layout swap**: the browse view keeps the sidebar (`bslib::page_sidebar()`) and the detail view drops it entirely (`bslib::page_fillable()`). The v1.1 baseline renders both views inside a single `page_sidebar()` with `conditionalPanel()` guards on `output.show_detail` — the sidebar is always in the DOM on detail, and on mobile it dumps below the main content. The per-view swap is architecturally cleaner: the sidebar is removed from the DOM on detail, the detail view gets the full viewport width, and the browse-vs-detail mental model is expressed in the page wrapper rather than hidden in a conditional guard.

M1 also establishes the correct mobile/desktop sidebar defaults (SPEC-v1.2 §5.3): `open = list(desktop = "open", mobile = "closed")`. bslib renders an off-canvas drawer with an auto-inserted hamburger toggle when the mobile breakpoint is `"closed"`, so no custom JS is required.

Two v1.2 features that SPEC-v1.2 §9 mentions alongside M1 are explicitly deferred (see `design.md` Decisions §1 and §2 for rationale):

- `mod_reconnect_ui("reconnect")` in the top-level `tagList` — SPEC-v1.2 §9 M1 and §9 M2 both list this change. The module doesn't exist until M2 creates it, so we defer to M2 where it can be implemented and mounted together.
- SPEC-v1.2 §5.4 theme toggle changes (four sub-items) — not in the §9 M1 Definition of Done and unassigned to any milestone in §9. Deferred to a future milestone that owns it.

## What Changes

**R/app_ui.R:**
- `app_ui(request)` returns `tagList(golem_add_external_resources(), shiny::uiOutput("main_page"))` — one top-level page slot, rendered by the server.
- New helper `render_browse_page()` — returns a complete `bslib::page_sidebar(...)` with `title`, `window_title`, `theme = app_theme()`, `input_dark_mode(id = "colour_mode", mode = "dark")` (unchanged — §5.4 deferred), sidebar `open = list(desktop = "open", mobile = "closed")`, `mod_header_ui("header")`, `mod_browse_ui("browse")`, `mod_footer_ui("footer")`.
- New helper `render_detail_page()` — returns a complete `bslib::page_fillable(...)` with `title`, `window_title`, `theme = app_theme()`, the same dark-mode toggle, `mod_header_ui("header")`, `mod_detail_ui("detail")`, `mod_footer_ui("footer")`. No sidebar slot.
- `app_theme()` and `golem_add_external_resources()` unchanged.

**R/app_server.R:**
- Add `output$main_page <- shiny::renderUI(...)` that dispatches `render_browse_page()` vs `render_detail_page()` based on `selected_package()`.
- Add `shiny::outputOptions(output, "main_page", suspendWhenHidden = FALSE)` so the rendered UI survives view switches without flicker or reactive teardown.
- Remove `output$show_detail` and its `shiny::outputOptions(..., "show_detail", ...)` call — no longer needed once the `conditionalPanel` guards are gone.
- All `mod_*_server(...)` calls stay at the top level of `app_server()` and run exactly once per session. **No module server call moves into `renderUI`** — SPEC-v1.2 §5.1 flags this explicitly as the common mistake to avoid.
- URL query parsing (`?package=<name>`) and `updateQueryString()` observers stay unchanged.

**tests/testthat/test-app_ui.R (new):**
- Structural assertions on `render_browse_page()`: returns an object whose class set includes a bslib page class; its HTML contains a sidebar region; the sidebar's data attributes reflect `desktop="open"` / `mobile="closed"`.
- Structural assertions on `render_detail_page()`: returns an object whose class set includes a bslib page class; its HTML contains no sidebar region.
- Assertion on `app_ui()`: returns a tagList whose body contains a single `uiOutput("main_page")` and no `page_sidebar` at the top level.

## Capabilities

### New Capabilities

- `per-view-layout`: The rule that browse and detail views render inside separate bslib page wrappers (`page_sidebar` vs `page_fillable`), dispatched by `output$main_page` based on `selected_package()`. Covers the helper contracts, sidebar defaults, module-server-lifecycle invariant, and the flicker-free view switch.

### Modified Capabilities

None. This change creates a new structural capability but does not modify any previously codified capability — v1.1 had no per-view layout capability spec.

## Impact

**Files modified:** 2 R source files (`R/app_ui.R`, `R/app_server.R`).
**Files created:** 1 test file (`tests/testthat/test-app_ui.R`).
**Files deleted:** 0.

**No new package dependencies.** All work is bslib, shiny, htmltools — already present.

**Out of scope (deferred with rationale in `design.md`):**
- `mod_reconnect_ui("reconnect")` in the top-level tagList — defer to M2 (module doesn't exist yet).
- SPEC-v1.2 §5.4 theme toggle changes — defer (not in §9 M1 DoD).

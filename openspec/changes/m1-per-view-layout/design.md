## Context

SPEC-v1.2 §5.1 resolves open question Q6 (the v1.1 sidebar-on-detail layout bug) by swapping the entire page wrapper per view rather than conditionally rendering the sidebar. The canonical pattern, quoted from §5.1:

> The `app_ui()` top-level return is a `tagList` with `uiOutput("main_page")` as its only body element. Each page helper returns a **complete** `bslib::page_sidebar()` or `bslib::page_fillable()` (not a fragment to embed inside another page) — `renderUI` dispatches one or the other.

And (critical module-server-lifecycle warning, quoted verbatim from §5.1):

> The module **server** calls (`mod_browse_server("browse")`, `mod_detail_server("detail")`, `mod_sidebar_server("sidebar")`, `mod_header_server("header")`, `mod_footer_server("footer")`, `mod_reconnect_server("reconnect")`) stay at the top level of `app_server()` and run **exactly once** at session start — exactly as they do in the v1.1 baseline. Only the UI placements move into the page helpers. **Do not** move any `mod_*_server()` calls into the `renderUI` — doing so would re-register observers on every view switch and drop reactive state (selected row, scroll position, filter URL sync). `renderUI` re-evaluates the UI on each view switch; the module servers must not.

M1 is the smallest milestone in v1.2 (two source files + one test file) but it's also the most architecturally load-bearing — M2, M3, and M6 all attach JS and DOM markers to the page shells M1 establishes. Getting the page-helper contract right and preserving the module-server lifecycle is the entire point.

M0 (`is_essential → is_featured` rename) is already merged (PRs #3, #4) and the repo-wide grep for `is_essential|essential_only|Essential Extension|badge-essential` returns zero matches, so the M1 dependency is satisfied.

## Goals / Non-Goals

**Goals:**

- Split `app_ui.R` so that browse and detail views render inside separate, complete bslib page wrappers dispatched via `uiOutput("main_page")`.
- Set sidebar defaults `open = list(desktop = "open", mobile = "closed")` inside `render_browse_page()` so desktop users see the sidebar and mobile users get an off-canvas drawer with bslib's auto-inserted hamburger toggle.
- Keep the module-server lifecycle intact: every `mod_*_server(...)` call stays at the top level of `app_server()` and runs exactly once per session. No reactive state is lost across view switches.
- Preserve v1.1 URL-routing behaviour: `?package=<name>` still parses on startup and still updates on navigation.
- Add `test-app_ui.R` with structural assertions that lock in the page-helper contract without requiring a live Shiny session.
- Satisfy the four M1 Definition-of-Done checks from SPEC-v1.2 §9 (sidebar defaults, no-sidebar-on-detail, no flicker, URL routing).

**Non-Goals:**

- Mounting `mod_reconnect_ui("reconnect")` in the top-level `tagList` (deferred to M2 — module does not exist yet; see Decisions §1).
- Any SPEC-v1.2 §5.4 theme-toggle changes: removing `mode = "dark"`, extending `dark-mode-icons.js`, live OS-sync behaviour (deferred — not in §9 M1 DoD; see Decisions §2).
- New keep-alive JS, reconnect card, filter-URL sync, intro-copy rewrite, empty-state button, visual audit, e2e smoke test, accessibility floor, README updates (separately scoped to M2–M7).
- Behavioural testing of the bslib sidebar drawer via `shinytest2` (depends on M5 setup; see Decisions §4).
- Refactoring unrelated helpers in `app_server.R` (e.g. `filtered_data()`, sidebar-controls rendering) — out of scope.

## Decisions

**1. Defer `mod_reconnect_ui("reconnect")` in the top-level tagList to M2 — despite SPEC-v1.2 §9 M1 listing it**

- **Rationale**: SPEC-v1.2 §9 M1's file list says `app_ui()` becomes `tagList(golem_add_external_resources(), uiOutput("main_page"), mod_reconnect_ui("reconnect"))`. But SPEC-v1.2 §9 M2's file list separately says `R/app_ui.R — mount mod_reconnect_ui("reconnect") in the top-level tagList below uiOutput("main_page")`. The module itself (`R/mod_reconnect.R`) is a §9 M2 deliverable — it does not exist at the start of M1. Calling a non-existent UI constructor would fail `app_ui()` at load time and break every test. The only workable reading of the spec is that M1 sets up the tagList slot shape and M2 fills it. This matches the wording of §9 M2.
- **Alternative**: Stub `mod_reconnect_ui()` as a no-op in M1 so the call works syntactically, then flesh it out in M2. Rejected — ships dead code, violates the spec's module ownership (M2 owns the module), and the "stub + flesh out" split makes the M2 review noisier than necessary.
- **Risk this creates**: The top-level tagList will need to be edited twice (M1 adds `uiOutput("main_page")`; M2 adds `mod_reconnect_ui("reconnect")` below it). Acceptable — it's one line of diff in each milestone, matching the spec's own partitioning.

**2. Defer all SPEC-v1.2 §5.4 theme-toggle changes out of M1**

- **Rationale**: SPEC-v1.2 §9 M1's file list mentions `app_ui.R` only for the page-helper split, not for the theme toggle. The M1 Definition of Done lists four items (sidebar defaults, no-sidebar-on-detail, no flicker, URL routing) — none of them touch the theme toggle. §5.4 is unassigned in §9. Including theme changes would muddle the M1 review (two unrelated concerns on the same branch) and lengthen the PR for no scope reason.
- **Alternative**: Remove `mode = "dark"` in M1 because the line is on an argument I'm already rewriting. Rejected — the one-line saving is real but the review-clarity cost is bigger. §5.4 will land cleanly in whichever later milestone adopts it (natural fit: M2 alongside the keep-alive JS, since §5.4 item 4 is also JS).
- **Risk this creates**: v1.2 ships §5.4 items sequenced after M1. Acceptable — the current v1.1 behaviour (dark forced on first visit via `mode = "dark"`) is not a regression; it's just not the v1.2 target yet.

**3. `render_browse_page()` and `render_detail_page()` return complete `bslib::page_sidebar()` / `bslib::page_fillable()` — not fragments**

- **Rationale**: SPEC-v1.2 §5.1 is explicit: "each page helper returns a **complete** `bslib::page_sidebar()` or `bslib::page_fillable()` (not a fragment to embed inside another page) — `renderUI` dispatches one or the other." The alternative (a fragment pattern where `app_ui()` owns the outer page wrapper and the helpers return body fragments) would force one page shape to dominate and defeats the entire purpose of the per-view swap (no-sidebar detail).
- **Consequence**: Both helpers must independently set `title`, `window_title`, `theme = app_theme()`, and host the `input_dark_mode(id = "colour_mode", mode = "dark")` toggle and the header/footer module UI mounts. This is mild duplication (~10 lines of arguments repeated), but it's the right duplication — the two pages genuinely need the same navbar shell, and bslib has no "shared header" primitive that spans `page_sidebar` and `page_fillable`.
- **Alternative considered**: Extract a helper `app_navbar_header()` that returns the shared args (title, theme, dark-mode toggle) as a list and splat-injects into both helpers. Rejected for M1 — minor abstraction, adds a file, and neither page-helper is re-used elsewhere to justify the indirection. If a future milestone adds a third page shape, revisit.

**4. Testing strategy: structural assertions on the helpers' HTML, no live Shiny session**

- **Rationale**: The M1 DoD is observable via shape: does `render_browse_page()` return an object whose rendered HTML contains a sidebar region with the right open-state attributes? Does `render_detail_page()` return an object whose rendered HTML contains no sidebar? `htmltools::renderTags()` resolves a `shiny.tag` into HTML string + head deps without requiring a running server. That's enough to lock in the contract.
- **What the tests will assert** (exact shape to be confirmed during RED → GREEN):
  - `render_browse_page()` returns a `shiny.tag.list` / `shiny.tag` whose class attribute contains `bslib-page-sidebar` (or whatever class bslib stamps on the page) and whose rendered HTML contains a `<div class="... sidebar ...">` region.
  - `render_detail_page()` returns a `shiny.tag.list` / `shiny.tag` whose rendered HTML does not contain any sidebar region (grep the HTML string).
  - `app_ui(request)` returns a `shiny.tag.list` whose rendered HTML contains exactly one `<div id="main_page" ...>` (the shiny uiOutput marker) at top level.
- **Alternative considered**: `shinytest2` browser tests that actually click the hamburger toggle and observe the sidebar opening on mobile. Rejected for M1 — `shinytest2` is an M5 deliverable (new dev dep, new CI job, renv.lock update). Structural tests are sufficient to catch regressions in M1's invariants (module-server calls still top-level, no `conditionalPanel("!output.show_detail")` left behind, sidebar absent from detail DOM).
- **Fallback**: If bslib's internal class names prove unstable across versions, fall back to asserting the presence of the `<aside>` element (semantic marker) rather than a specific bslib class. The rendered-HTML approach keeps the fallback easy.

**5. Flicker mitigation: `outputOptions(..., "main_page", suspendWhenHidden = FALSE)`**

- **Rationale**: Quoted from SPEC-v1.2 §12 risk table: "Per-view layout swap (§5.1) introduces flicker when toggling browse↔detail" → mitigation: "`uiOutput("main_page")` + `outputOptions(suspendWhenHidden = FALSE)`; manual verification in M1 DoD". Without `suspendWhenHidden = FALSE`, `renderUI` suspends between active observations, and the rendered HTML is torn down and rebuilt on every view switch — visible as a flash. Setting it to FALSE keeps the rendered output alive, so the reactive change only swaps the children of `#main_page`, not the node itself.
- **Alternative**: Use `shiny::renderCachedUI` with a cache key derived from `is.null(selected_package())`. Rejected — cached UI is opinionated about object identity, and the reactable state inside `mod_browse_ui()` is the actual concern (we don't want to re-mount it when switching browse→detail→browse). `suspendWhenHidden = FALSE` is the spec-mandated approach and the standard Shiny idiom.

**6. Ordering in `app_server()`: `selected_package` reactive must exist before `output$main_page` reads it**

- **Rationale**: `output$main_page <- renderUI({ if (is.null(selected_package())) ... })` observes `selected_package()`. In v1.1, `selected_package` is created as the return value of `mod_browse_server("browse", filtered_data)`. The v1.2 `app_server()` must still create `selected_package` (via `mod_browse_server`) **before** defining `output$main_page`. The current v1.1 ordering (data load → sidebar controls → sidebar server → filtered_data → mod_browse_server → ... → URL observers) already places `mod_browse_server` before the URL observers, so the natural v1.2 ordering is: keep all existing module-server calls in place; add `output$main_page` (and drop `output$show_detail`) after `mod_browse_server` returns `selected_package`.
- **Risk this creates**: If a future refactor reorders `app_server()` so that `output$main_page` is defined before `mod_browse_server`, the `selected_package()` inside `renderUI` will fail with an "object not found" error at session start. Mitigation: the test file locks in the shape (`app_ui()` returns a `uiOutput("main_page")` slot); the server-side ordering is documented in the `app_server.R` file-header comment.

## Risks / Trade-offs

- **[Risk] bslib's sidebar-drawer behaviour depends on the `open = list(desktop = ..., mobile = ...)` argument being supported by the installed bslib version.** Mitigated by checking `packageVersion("bslib") >= "0.7.0"` (the version that introduced list-form `open`) during an early RED test. The project's `renv.lock` should already be at a compatible version since SPEC-v1.2 assumes it; if not, pin in M1's PR.

- **[Risk] Switching browse → detail → browse loses the reactable's scroll / sort / page state.** Mitigated primarily by `suspendWhenHidden = FALSE` (keeps the output alive) and by keeping `mod_browse_server("browse", ...)` at the top level (the server-side reactable state persists). The client-side scroll/sort/page state of a reactable inside a `renderUI`-controlled subtree is less guaranteed — bslib may tear down and re-mount. If the M1 DoD "no layout flicker when switching views" manual test also reveals client-state loss, the fallback is CSS-based visibility toggling (render both pages, `display: none` the inactive one), but that reintroduces the sidebar-in-DOM-on-detail problem we're here to fix. If the loss is observed and severe, escalate to the stakeholder before shipping.

- **[Trade-off] Two page helpers duplicate ~10 lines of bslib page-header args.** Accepted — explicit duplication is clearer than premature abstraction for two call sites. Revisit if a third page wrapper appears.

- **[Trade-off] No behavioural (browser) tests in M1.** Accepted — `shinytest2` is an M5 deliverable; M1's structural tests cover the contract invariants (page shape, sidebar absence on detail, `uiOutput` slot). The DoD items that require a browser (mobile hamburger behaviour, no-flicker view switch) are manual-verified per SPEC-v1.2 §9 M1 and will be covered by M5's happy-path smoke test once it lands.

- **[Trade-off] Deferring §5.4 theme toggle means the app still forces dark mode on first visit in M1.** Accepted — this is unchanged from v1.1, so it's not a regression; the spec just hasn't assigned §5.4 to a milestone yet.

- **[Trade-off] Round-02 review surfaced a navbar-structural-position asymmetry between the two views.** Discovered during round-02 re-review (see `comments/DESIGN_FIXES-m1-per-view-layout-02.md` Fix #4). Because `page_sidebar()` nests positional children inside `<main class="bslib-page-main">` (grid-column 2/3 of the `.bslib-sidebar-layout` CSS grid) but `page_fillable()` places them as direct `<body>` children, the `app_navbar()` call ends up inside the main column on browse (x≈300px on desktop) and at `<body>` level on detail (x=0). Clicking a package visually slides the brand ~300px left; clicking Back slides it right. **Deferred to M4 Visual Audit** rather than fixed in M1 because: (1) the proposed Option A fix (restore `title = "..."` on browse, drop `app_navbar()` on browse) un-fixes the round-01 Fix #3 "dark-mode toggle placement divergence" that we explicitly resolved — the toggle would return to its round-00 position inside `<main>`, not inside the navbar; (2) the proposed Option B fix (`tagList(app_navbar(), page_sidebar(title = NULL, ...))`) likely breaks the `expect_s3_class(..., "bslib_page")` regression test added in round 02; (3) the Designer explicitly framed this as a judgement call and marked [SHOULD FIX], not [MUST FIX], with "it can roll into the M4 Visual Audit". M4 can catalogue this alongside other layout inconsistencies and decide whether the right fix is Option A (re-trade toggle placement), Option B (pay the test-assertion cost), or a broader restructure (`page_navbar()`, CSS-level pull-to-full-width on browse, or a different primitive entirely).

## See Also

- `SPEC-v1.2.md` §5.1 — per-view page shape (the authoritative contract)
- `SPEC-v1.2.md` §5.3 — sidebar open-state defaults (`list(desktop = "open", mobile = "closed")`)
- `SPEC-v1.2.md` §5.4 — theme toggle changes (deferred; not in M1)
- `SPEC-v1.2.md` §9 M1 — milestone goal, file list, and definition of done
- `SPEC-v1.2.md` §9 M2 — where `mod_reconnect_ui("reconnect")` is mounted
- `SPEC-v1.2.md` §12 — risk table entry for flicker mitigation
- `SPEC-v1.2.md` §14 — Q6 resolution (per-view layout swap over conditional-render)
- `openspec/changes/archive/2026-04-19-m0-is-featured-rename/` — sibling change; same RED/GREEN/REFACTOR cadence and house formatting

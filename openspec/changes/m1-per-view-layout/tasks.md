## 1. Structural test scaffold

- [ ] 1.1 Create `tests/testthat/test-app_ui.R` with a file-header comment, describe blocks for each helper, and a skip-if-bslib-too-old guard (`skip_if(utils::packageVersion("bslib") < "0.7.0")`).
- [ ] 1.2 RED: Add a test asserting `app_ui(request = NULL)` returns a `shiny.tag.list` whose rendered HTML contains a `<div id="main_page" class="shiny-html-output"` marker and **does not** contain a top-level `<div class=".*page-sidebar.*">` wrapper.
- [ ] 1.3 Run the test; confirm it fails because today's `app_ui()` returns a `page_sidebar` directly.

## 2. `render_browse_page()` helper

- [ ] 2.1 RED: Add a test asserting `render_browse_page()` returns an object whose rendered HTML contains (a) a sidebar region (match a bslib-stable marker such as `<aside` or `class=".*sidebar.*"`), (b) the text `"Filters"` (the sidebar title), and (c) the `mod_browse_ui("browse")` output marker. Run; confirm RED because `render_browse_page` is undefined.
- [ ] 2.2 GREEN: Add `render_browse_page()` to `R/app_ui.R` returning a complete `bslib::page_sidebar(...)` with `title`, `window_title`, `theme = app_theme()`, `input_dark_mode(id = "colour_mode", mode = "dark")`, `sidebar = bslib::sidebar(title = "Filters", width = 300, open = list(desktop = "open", mobile = "closed"), shiny::uiOutput("sidebar_controls"))`, and the main content `div` containing `mod_header_ui("header")` → spacer → `mod_browse_ui("browse")` → `mod_footer_ui("footer")`.
- [ ] 2.3 RED (sidebar defaults): Add a test asserting the rendered sidebar element has `data-open-desktop="open"` / `data-open-mobile="closed"` (or whatever attribute bslib emits — determine during RED; fall back to `grepl("desktop", html)` and `grepl("closed", html)` if the exact attrs are unstable).
- [ ] 2.4 GREEN: Confirm the `open = list(desktop = "open", mobile = "closed")` argument is present; adjust the test assertion to match bslib's actual rendered attribute shape.
- [ ] 2.5 REFACTOR: Review `render_browse_page()` for readability; ensure the arg order matches bslib's idiom (title first, theme next, then navbar items, then sidebar, then body). Re-run tests.

## 3. `render_detail_page()` helper

- [ ] 3.1 RED: Add a test asserting `render_detail_page()` returns an object whose rendered HTML (a) contains the `mod_detail_ui("detail")` output marker and (b) **does not** contain any sidebar marker (`<aside`, `class=".*sidebar.*"`, or the text "Filters"). Run; confirm RED.
- [ ] 3.2 GREEN: Add `render_detail_page()` to `R/app_ui.R` returning a complete `bslib::page_fillable(...)` with `title`, `window_title`, `theme = app_theme()`, `input_dark_mode(id = "colour_mode", mode = "dark")`, and a body `div` containing `mod_header_ui("header")` → spacer → `mod_detail_ui("detail")` → `mod_footer_ui("footer")`. No `sidebar = ...` argument.
- [ ] 3.3 REFACTOR: Ensure `render_detail_page()` and `render_browse_page()` present identical shared-args structure (title/window_title/theme/dark-mode) so diffing them reads cleanly. Re-run tests.

## 4. `app_ui()` top-level rewrite

- [ ] 4.1 GREEN: Replace the body of `app_ui(request)` in `R/app_ui.R` with `tagList(golem_add_external_resources(), shiny::uiOutput("main_page"))`. Remove the inline `page_sidebar()` call and the two `conditionalPanel()` guards.
- [ ] 4.2 Update the `R/app_ui.R` file-header comment from "Part of Milestone 0: Project Scaffold" to reflect the M1 restructure (keep the M0 attribution in a `# v1.2 (M1): …` note, matching the house pattern seen in `R/app_server.R`'s v1.2 M0 note).
- [ ] 4.3 Re-run the test from 1.2; it should now pass (GREEN).

## 5. `app_server.R` — `output$main_page` + remove `output$show_detail`

- [ ] 5.1 RED (smoke): Add a minimal test under `tests/testthat/test-app_ui.R` (or a new `test-app_server.R` if the app_server concerns grow) that loads `pkgload::load_all(export_all = TRUE)` and verifies `app_server` is a function with the expected formals. (This is a cheap smoke assertion; the deeper behaviour is covered by existing module tests.)
- [ ] 5.2 GREEN: In `R/app_server.R`, add `output$main_page <- shiny::renderUI({ if (is.null(selected_package())) render_browse_page() else render_detail_page() })` placed **after** `selected_package <- mod_browse_server("browse", filtered_data)` (see Design §6 — ordering constraint).
- [ ] 5.3 GREEN: Add `shiny::outputOptions(output, "main_page", suspendWhenHidden = FALSE)` immediately after the `renderUI` call.
- [ ] 5.4 GREEN: Remove `output$show_detail <- reactive(...)` and its `outputOptions(output, "show_detail", suspendWhenHidden = FALSE)` line. Update the block's section header comment from "Browse/Detail toggle (M5) & URL routing" to "Main page dispatch (M1) & URL routing".
- [ ] 5.5 Verify that every module-server call (`mod_sidebar_server`, `mod_browse_server`, `mod_detail_server`, `mod_header_server`, `mod_footer_server`) remains at the top level of `app_server()` — no call moved inside the `renderUI`. Re-read the block against Design §6 and SPEC-v1.2 §5.1's "Critical — module server lifecycle" warning.
- [ ] 5.6 Update the `R/app_server.R` file-header comment to add a `# v1.2 (M1): …` note documenting the `output$main_page` dispatch.

## 6. Full test run

- [ ] 6.1 Run `devtools::test()`; expect all existing tests green plus the new `test-app_ui.R` tests green.
- [ ] 6.2 Run `pkgload::load_all(); run_app()` in an interactive session and verify:
  - Browse view renders with the sidebar open on desktop (≥992 px).
  - Resize below 992 px: sidebar closes, hamburger toggle appears, clicking it opens the off-canvas drawer.
  - Click a package → detail view renders, **no sidebar in the DOM** (verify via DevTools Elements tab — no `<aside>` or `.sidebar` element).
  - Click Back → browse view restores; no visible flicker during the swap.
  - Reload with `?package=ggrepel`: detail view opens directly. Click Back: URL clears to `?`. (SPEC-v1.2 §9 M1 DoD.)
- [ ] 6.3 Run `openspec validate m1-per-view-layout --strict`; expect valid.

## 7. PR prep

- [ ] 7.1 `git push -u origin feature/m1-per-view-layout`.
- [ ] 7.2 Open PR via `gh pr create --base main` with a body that: (a) summarises scope, (b) links this change folder, (c) lists the §9 M1 DoD items as a test-plan checklist, (d) explicitly calls out the two deferrals (`mod_reconnect_ui` → M2; §5.4 theme toggle → later).
- [ ] 7.3 Await stakeholder review. On request-changes: commit fixes to the same branch; request re-review.
- [ ] 7.4 On explicit merge go-ahead: `gh pr merge <n> --merge --delete-branch`.

## 8. Post-merge housekeeping

- [ ] 8.1 `git checkout main && git pull && git remote prune origin`.
- [ ] 8.2 Verify: `git log --oneline -5 origin/main` shows the merge commit; `gh pr view <n>` reports `state: MERGED`.
- [ ] 8.3 Open follow-up `chore/archive-m1-per-view-layout` PR: run `openspec archive m1-per-view-layout`, commit the moved folder, push, open PR, request merge. (Matches the M0 pattern, PRs #3 → #4.)

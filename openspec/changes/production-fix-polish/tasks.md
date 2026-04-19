## 1. Pipeline: Title/Description Split & Vignettes Detection

- [ ] 1.1 Update `parse_cran_response()` in `R/fct_pipeline.R` to store `response$Title` as `title` and `response$Description` as `description` (two separate fields instead of one `description` field)
- [ ] 1.2 Add `has_vignettes` detection to `parse_cran_response()`: derive from `length(response$vignettes) > 0` or presence of vignettes field in pkgsearch response
- [ ] 1.3 Update `merge_package_data()` in `R/fct_pipeline.R` to include `title`, `description`, and `has_vignettes` columns in the merged output
- [ ] 1.4 Update `construct_urls()` in `R/fct_urls.R` to accept `has_vignettes` and set `vignettes_url = NA` when `has_vignettes == FALSE` (not just when `on_cran == FALSE`)
- [ ] 1.5 Update `_targets.R` to pass `has_vignettes` from `cran_metadata` to `construct_urls()`
- [ ] 1.6 Update `export_json()` in `R/fct_pipeline.R` to include both `title` and `description` fields in the JSON output
- [ ] 1.7 Update tests in `tests/testthat/test-fct_pipeline.R` for the new `title`/`description` field mapping and `has_vignettes` detection
- [ ] 1.8 Update tests in `tests/testthat/test-fct_urls.R` for conditional `vignettes_url` based on `has_vignettes`
- [ ] 1.9 Update mock fixture `tests/testthat/fixtures/cran_response.json` to include `Description` and `vignettes` fields

## 2. Category Infrastructure: Display Names & Badge Colours

- [ ] 2.1 Create `R/fct_categories.R` with `get_category_display_names()` that reads `data-raw/categories.csv` and returns a named character vector mapping `category` → `display_name`
- [ ] 2.2 Add `get_category_colours()` to `R/fct_categories.R` returning a named list of 19 hex colours (animation=#8B5CF6, annotations=#3B82F6, arranging_plots=#06B6D4, coords=#14B8A6, data=#10B981, facets=#22C55E, finishing_touches=#84CC16, geoms=#C1272D, helpers=#F59E0B, interactive_plots=#F97316, interactive_tools=#EF4444, maps=#0EA5E9, networks=#A855F7, python=#FBBF24, scales_and_guides=#EC4899, sports=#6366F1, stats=#D946EF, themes=#78716C, na=#9CA3AF)
- [ ] 2.3 Add `build_category_badge()` to `R/fct_categories.R` that returns an `htmltools::span()` with pill styling, semi-transparent background, matching text colour, and `display_name` text
- [ ] 2.4 Add `category_to_display_name()` helper for single-value lookups
- [ ] 2.5 Create `tests/testthat/test-fct_categories.R` with tests for mapping completeness (all 19 categories), colour uniqueness, and badge HTML output

## 3. App Rename & Meta Tags

- [ ] 3.1 Update `R/app_ui.R`: change `title` and `window_title` in `page_sidebar()` from "ggplot2 Extended Companion" to "ggplot2 extended (companion)"
- [ ] 3.2 Update `golem_add_external_resources()` in `R/app_ui.R`: change `app_title` to "ggplot2 extended (companion)"
- [ ] 3.3 Update `og:title` meta tag in `R/app_ui.R` to "ggplot2 extended (companion)"
- [ ] 3.4 Update the logger startup message in `R/app_server.R` to use the new app name

## 4. Sidebar Overhaul

- [ ] 4.1 Remove the `sort_by` selectInput from `mod_sidebar_ui()` in `R/mod_sidebar.R`
- [ ] 4.2 Change category dropdown choices in `mod_sidebar_ui()` to use `display_name` values from `get_category_display_names()` (keep "All" as first choice)
- [ ] 4.3 Fix the essential checkbox label from "Essential Extensions only" to "Essential Extensions Only" in `R/mod_sidebar.R`
- [ ] 4.4 Add `recently_added` checkboxInput to `mod_sidebar_ui()` with label "Recently Added"
- [ ] 4.5 Add `recently_updated` checkboxInput to `mod_sidebar_ui()` with label "Recently Updated"
- [ ] 4.6 Update `mod_sidebar_server()` to return `recently_added` and `recently_updated` reactive values, remove `sort_by` from return list
- [ ] 4.7 Update `filter_packages()` in `R/fct_filters.R` to accept `recently_added` and `recently_updated` boolean parameters with OR logic between them
- [ ] 4.8 Remove `sort_packages()` function from `R/fct_filters.R`
- [ ] 4.9 Update `load_app_data()` in `R/fct_data.R` to compute `recently_added` and `recently_updated` derived columns at load time
- [ ] 4.10 Update `R/app_server.R`: remove `sort_packages()` call, pass `recently_added` and `recently_updated` sidebar values to `filter_packages()`, implement display-name-to-technical-name reverse mapping for category filtering
- [ ] 4.11 Add compact sidebar CSS to `inst/app/www/styles.css`: reduce `.form-group` margins, sidebar title margin, radio button padding
- [ ] 4.12 Update tests in `tests/testthat/test-fct_filters.R`: remove sort tests, add recently_added/recently_updated filter tests including OR logic

## 5. Browse Table: Title Column, All Category Badges, Column Sorting

- [ ] 5.1 Rename the `description` colDef to use field `title` with label "Title" and set `sortable = TRUE` in `build_package_table()` in `R/mod_browse.R`
- [ ] 5.2 Update the `categories` colDef cell renderer to show ALL categories as separate badges using `build_category_badge()` from `fct_categories.R`, increase `minWidth` to 180
- [ ] 5.3 Set `categories` colDef `sortable = TRUE` — reactable sorts by cell text content which will be the display names
- [ ] 5.4 Set `license` colDef `sortable = TRUE` in `R/mod_browse.R`
- [ ] 5.5 Add `title` to the data passed to reactable (it replaces `description` as the visible column) and add `description` to the hidden columns list
- [ ] 5.6 Ensure `defaultSorted = list(package_name = "asc")` is set as initial sort state in the reactable
- [ ] 5.7 In `R/app_server.R`, ensure `filtered_data()` returns data arranged by `package_name` ascending as default order

## 6. Detail View Fixes

- [ ] 6.1 Update `build_header_card()` in `R/mod_detail.R`: show `title` as `<p class="lead">` subtitle under the `<h2>` package name, show `description` as a separate `<p>` paragraph below
- [ ] 6.2 Update category badges in `build_header_card()` to use `build_category_badge()` with display names and category-specific colours
- [ ] 6.3 Update `build_links_card()`: change "GitHub/GitLab" label to "Repo (GitHub, etc.)"
- [ ] 6.4 Update `build_links_card()`: hide vignettes link when `has_vignettes == FALSE` OR `vignettes_url` is NA
- [ ] 6.5 Update `build_downloads_card()`: remove `showcase = htmltools::tags$span("\U0001F4C8")` from all four value boxes
- [ ] 6.6 Update `build_downloads_card()`: change fourth value box title from "All time (since 2015)" to "Since 2015"
- [ ] 6.7 Update `build_back_button()`: change class to include red border styling, add `btn-back` CSS class
- [ ] 6.8 Add `.btn-back` CSS rules to `inst/app/www/styles.css`: `border-color: #C1272D`, hover state with red background/border/text

## 7. Dark/Light Mode Consistency

- [ ] 7.1 Add `[data-bs-theme="light"] .rt-search` CSS rule in `styles.css`: white background, dark text, light grey border
- [ ] 7.2 Add `[data-bs-theme="light"] body` CSS rule if needed: `background-color: #FFFFFF; color: #1a1a1a`
- [ ] 7.3 Add `[data-bs-theme="light"]` CSS rules for value boxes to ensure they render correctly in light mode
- [ ] 7.4 Verify all `renderUI()` output in `mod_detail.R` uses `bslib::card()` components that respect the `data-bs-theme` attribute
- [ ] 7.5 Test dark/light toggle persistence across browse → detail → browse navigation flow
- [ ] 7.6 Add `[data-bs-theme="light"]` CSS rules for category badges (lighter background opacity, darkened text)

## 8. Header & Footer Content Updates

- [ ] 8.1 Replace `bslib::accordion()` in `mod_header_ui()` with plain `htmltools::tagList()` of `<p>` tags — always visible, no collapsible behaviour
- [ ] 8.2 Update header links: remove "ggplot2 extensions gallery", add "ggplot2 extended (the book)" → `https://ggplot2-extended-book.com/`
- [ ] 8.3 Update footer email from `antti@youcanbeapirate.com` to `anttilennartrask@gmail.com` in `R/mod_footer.R`
- [ ] 8.4 Remove the "ggplot2 extensions gallery | youcanbeapirate.com" line from footer
- [ ] 8.5 Add book link to footer: "Check out the book (in progress): ggplot2 extended" → `https://ggplot2-extended-book.com/`
- [ ] 8.6 Verify footer submission link is disabled with "Coming soon" tooltip (already implemented, just verify)

## 9. Remove mod_recent & Clean Up

- [ ] 9.1 Delete `R/mod_recent.R`
- [ ] 9.2 Remove `mod_recent_ui("recent")` call and the spacer div (`tags$div(class = "my-4")`) from `R/app_ui.R`
- [ ] 9.3 Remove `mod_recent_server("recent", ...)` call and `on_select` callback from `R/app_server.R`
- [ ] 9.4 Remove or keep `get_recently_added()` and `get_recently_updated()` in `R/fct_data.R` — remove if no longer referenced
- [ ] 9.5 Run `R CMD check` to verify no dead code warnings or missing references

## 10. Shareable Package Links

- [ ] 10.1 Add URL parsing on app startup in `R/app_server.R`: parse `session$clientData$url_search` for `package` parameter and set `selected_package()` if present
- [ ] 10.2 Add `shiny::updateQueryString()` call when `selected_package()` changes: set `?package={name}` when a package is selected, clear to `?` when returning to browse
- [ ] 10.3 Handle invalid package names in URL: if the `package` parameter doesn't match any package_name, fall back to browse view
- [ ] 10.4 Test round-trip: navigate to `?package=ggrepel` → detail view loads → back button clears URL

## 11. Navigation Arrows Between Packages

- [ ] 11.1 Add `all_packages_alpha` parameter to `mod_detail_server()` — a reactive containing the alphabetically sorted vector of all `package_name` values
- [ ] 11.2 Build "← Prev" and "Next →" action buttons in the detail view navigation bar, alongside the back button in a flex row
- [ ] 11.3 Implement prev/next logic: find current package index in sorted vector, navigate to adjacent package
- [ ] 11.4 Disable "← Prev" at the first package and "Next →" at the last package alphabetically
- [ ] 11.5 Pass `all_packages_alpha` reactive from `R/app_server.R` to `mod_detail_server()`
- [ ] 11.6 Add `on_navigate` callback that sets `selected_package()` to the new package name (triggers URL update from task 10.2)

## 12. Code Example Enhancements

- [ ] 12.1 Update `build_example_card()` in `R/mod_detail.R`: when `example_code` is present and `license_allowed == TRUE`, prepend `install.packages("{package_name}")` and `library({package_name})` followed by a blank line and `# Example:` comment
- [ ] 12.2 Verify "Copy to clipboard" copies the full block including prepended lines
- [ ] 12.3 Ensure the prepended lines are a display-time transformation only — do not modify stored `example_code` in Parquet

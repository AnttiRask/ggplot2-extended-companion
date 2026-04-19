## 1. Validation layer

- [ ] 1.1 RED: Update `tests/testthat/test-fct_validation.R` — rename `validate_is_essential` → `validate_is_featured`, update fixture columns, add missing-column case parallel to `validate_is_archived`
- [ ] 1.2 GREEN: Rename `validate_is_essential()` → `validate_is_featured()` in `R/fct_validation.R`; update roxygen, file-header comment, and `validate_curated_csv()` dispatch
- [ ] 1.3 REFACTOR: Confirm the new function matches the `validate_is_archived` pattern (missing-column → NA-values → non-logical branches)

## 2. Filter layer

- [ ] 2.1 RED: Update `tests/testthat/test-fct_filters.R` — `essential_only` → `featured_only` argument, fixture column `is_essential` → `is_featured`
- [ ] 2.2 GREEN: Rename `essential_only` → `featured_only` parameter in `filter_packages()` in `R/fct_filters.R`; update `.data$is_essential` → `.data$is_featured`, roxygen `@param`

## 3. Pipeline & JSON export

- [ ] 3.1 RED: Update `tests/testthat/test-fct_pipeline.R` — rename field assertions in `merge_package_data()` and `export_json()` tests
- [ ] 3.2 RED: Update `tests/testthat/test-fct_json.R` — rename JSON export key assertions
- [ ] 3.3 GREEN: Rename `is_essential` → `is_featured` in `R/fct_pipeline.R` — `export_json()` per-package JSON object key, `merge_package_data()` references, file-header doc
- [ ] 3.4 Check `_targets.R` for any `is_essential` references (inventory only — likely none, since the pipeline passes rows through unchanged)

## 4. Shiny modules

- [ ] 4.1 RED: Update `tests/testthat/test-mod_detail.R` — badge label assertion "Featured in the book"
- [ ] 4.2 GREEN: Rename in `R/mod_sidebar.R` — `ns("essential_only")` → `ns("featured_only")`, label "Featured in the Book", return-list key, roxygen
- [ ] 4.3 GREEN: Rename in `R/mod_browse.R` — `is_essential <- data$is_essential[index]` → `is_featured`; `essential_badge` var → `featured_badge`; tooltip and aria-label "Featured in the book"; `is_essential = reactable::colDef(show = FALSE)` → `is_featured`
- [ ] 4.4 GREEN: Rename in `R/mod_detail.R` — `essential_badge` var → `featured_badge`, badge text "⭐ Featured in the book", isTRUE check on `pkg$is_featured`

## 5. App server

- [ ] 5.1 GREEN: Rename in `R/app_server.R` — `sidebar_values$essential_only()` → `sidebar_values$featured_only()`, pass `featured_only = ...` to `filter_packages()`

## 6. Styling

- [ ] 6.1 Rename `.badge-essential` → `.badge-featured` in `inst/app/www/styles.css` (rule body unchanged)

## 7. Data source

- [ ] 7.1 Rename header row `is_essential` → `is_featured` in `data-raw/packages_curated.csv` (values unchanged, 455 rows)
- [ ] 7.2 Update `data-raw/migrate_notion.R` literal references (inventory + apply)

## 8. Test fixtures & integration

- [ ] 8.1 Update `tests/testthat/test-fct_data.R` fixture references to `is_featured`
- [ ] 8.2 Search `tests/testthat/fixtures/` for any `is_essential` literal values (e.g., CSV fixtures) and rename

## 9. Definition of done

- [ ] 9.1 `grep -rn "is_essential\|essential_only\|Essential Extension\|badge-essential" R/ inst/ tests/ data-raw/` returns zero matches
- [ ] 9.2 `devtools::test()` runs clean
- [ ] 9.3 Manual smoke: `pkgload::load_all(); run_app()` — sidebar label "Featured in the Book", detail badge "⭐ Featured in the book"
- [ ] 9.4 `validate_curated_csv(curated, cats$category)` succeeds with renamed column

## 10. Review hand-off

- [ ] 10.1 Push branch `feature/m0-is-featured-rename`
- [ ] 10.2 Request review (Reviewer for code; UX/UI Designer for label and badge text changes)
